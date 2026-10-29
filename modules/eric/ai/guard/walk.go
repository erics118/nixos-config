package main

import (
	"fmt"
	"maps"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strings"

	"mvdan.cc/sh/v3/expand"
	"mvdan.cc/sh/v3/syntax"
)

var parser = syntax.NewParser(syntax.Variant(syntax.LangZsh))

// nested scripts and function calls are followed this many levels deep. deeper ones deny
const maxDepth = 16

// loops walk their bodies twice, so the walk denies past this many statements instead of growing exponentially
const maxSteps = 10000

type shellVar struct {
	value    string
	known    bool
	exported bool
}

// state is what the walk knows about the shell before a command runs
type state struct {
	// dir is the working directory, or "" when the walk cannot tell
	dir string
	// maybe lists the directories a branch could have left the shell in, when dir is ""
	maybe []string
	// moved marks a dir that a cd in this command changed
	moved bool
	// mayBeHome marks a cd to a bare $var or $(...), which goes to $HOME when it expands to nothing
	mayBeHome bool
	// piped marks commands that read the output of the command before a pipe
	piped bool
	// pipe numbers the pipeline the commands are part of, or is 0 outside one
	pipe int
	// prev is the directory before the last cd, for cd -
	prev  string
	stack []string
	// stackLost marks a pushd stack a branch may have changed
	stackLost bool
	// cdpath is the directories a cdpath or CDPATH assignment lets a relative cd land in
	cdpath []string
	vars   map[string]shellVar
	funcs  map[string]*syntax.Stmt
}

func newState(dir string) *state {
	return &state{dir: dir, vars: map[string]shellVar{}, funcs: map[string]*syntax.Stmt{}}
}

func (s *state) clone() *state {
	c := *s
	c.maybe = slices.Clone(s.maybe)
	c.stack = slices.Clone(s.stack)
	c.cdpath = slices.Clone(s.cdpath)
	c.vars = maps.Clone(s.vars)
	c.funcs = maps.Clone(s.funcs)
	return &c
}

// child is the state a new shell starts in, which sees only exported variables
func (s *state) child(dir string) *state {
	c := newState(dir)
	c.moved, c.mayBeHome = s.moved, s.mayBeHome
	if dir == "" {
		c.maybe = slices.Clone(s.maybe)
	}
	for k, v := range s.vars {
		if v.exported {
			c.vars[k] = v
		}
	}
	if s.vars["CDPATH"].exported {
		c.cdpath = slices.Clone(s.cdpath)
	}
	return c
}

// dirs is where the shell may be: dir when known, else what a branch could have left
func (s *state) dirs() []string {
	if s.dir != "" {
		return []string{s.dir}
	}
	return s.maybe
}

// merge folds in a branch that may or may not run, so whatever it changed becomes unknown
func (s *state) merge(branch *state) {
	if s.dir == "" || branch.dir != s.dir || branch.mayBeHome != s.mayBeHome {
		maybe := slices.Concat(s.dirs(), branch.dirs())
		slices.Sort(maybe)
		s.dir, s.maybe = "", slices.Compact(maybe)
		s.moved = s.moved || branch.moved
		s.mayBeHome = s.mayBeHome || branch.mayBeHome
	}
	if branch.prev != s.prev {
		s.prev = ""
	}
	if s.stackLost = s.stackLost || branch.stackLost || !slices.Equal(s.stack, branch.stack); s.stackLost {
		s.stack = nil
	}
	s.cdpath = slices.Compact(slices.Sorted(slices.Values(slices.Concat(s.cdpath, branch.cdpath))))
	for k, v := range branch.vars {
		if s.vars[k] != v {
			s.vars[k] = shellVar{exported: v.exported}
		}
	}
	for k, v := range s.vars {
		if _, ok := branch.vars[k]; !ok {
			s.vars[k] = shellVar{exported: v.exported}
		}
	}
	maps.Copy(s.funcs, branch.funcs)
}

func (s *state) setDir(d string) {
	s.prev, s.dir, s.maybe, s.moved, s.mayBeHome = s.dir, d, nil, true, false
}

// cdTo moves to p, relative to every directory the shell may be in or a cdpath entry offers.
// a glob lands in whichever directory it matches
func (s *state) cdTo(p string) {
	bases := s.dirs()
	if len(bases) == 0 {
		bases = []string{""}
	}
	if !strings.HasPrefix(p, "/") && !strings.HasPrefix(p, ".") && !strings.HasPrefix(p, "~") {
		bases = append(bases, s.cdpath...)
	}
	var to []string
	for _, d := range bases {
		r := resolveIn(d, p)
		switch {
		case r == "":
		case globChars.MatchString(r):
			matches, _ := filepath.Glob(r)
			to = append(to, matches...)
		default:
			to = append(to, r)
		}
	}
	if len(to) == 1 {
		s.setDir(to[0])
		return
	}
	s.setDir("")
	s.maybe = to
}

// resolveIn expands a leading ~, ~user, $HOME, or $PWD and joins a relative path onto dir.
// it returns "" when the result depends on something unknown
func resolveIn(dir, p string) string {
	home := os.Getenv("HOME")
	switch {
	case p == "~" || strings.HasPrefix(p, "~/"):
		p = home + p[1:]
	case p == "~+" || strings.HasPrefix(p, "~+/"):
		if dir == "" {
			return ""
		}
		p = dir + p[2:]
	case strings.HasPrefix(p, "~-") || strings.HasPrefix(p, "~$"):
		return ""
	case strings.HasPrefix(p, "~"):
		// ~user is that user's home, a sibling of this one
		user, rest, _ := strings.Cut(p[1:], "/")
		p = filepath.Join(filepath.Dir(home), user, rest)
	case strings.HasPrefix(p, "$HOME"):
		p = home + p[len("$HOME"):]
	case strings.HasPrefix(p, "$PWD"):
		if dir == "" {
			return ""
		}
		p = dir + p[len("$PWD"):]
	}
	// a variable the command never set, such as $TMPDIR, has the value the guard's own environment gives it
	known := !strings.Contains(p, "$(")
	p = os.Expand(p, func(name string) string {
		v, ok := os.LookupEnv(name)
		known = known && ok && name != ""
		return v
	})
	if !known || strings.Contains(p, "$") {
		return ""
	}
	if strings.HasPrefix(p, "/") {
		return filepath.Clean(p)
	}
	if dir == "" {
		return ""
	}
	return filepath.Join(dir, p)
}

var cdFlags = regexp.MustCompile(`^-[LPe@qs]+$`)

// apply records what a cd, pushd, popd, unset, or variable-reading builtin does to the shell
func (s *state) apply(c call) {
	args := c.args()
	switch c.tool() {
	case "cd", "pushd":
		i := 0
		for i < len(args) && cdFlags.MatchString(args[i]) {
			i++
		}
		if i < len(args) && args[i] == "--" {
			i++
		}
		top := s.dir
		switch rest := args[i:]; {
		case len(rest) == 0 && c.tool() == "cd":
			s.setDir(os.Getenv("HOME"))
		case len(rest) == 1 && rest[0] == "-" && c.tool() == "cd":
			s.setDir(s.prev)
		case len(rest) != 1 || strings.HasPrefix(rest[0], "-") || strings.HasPrefix(rest[0], "+"):
			s.setDir("")
		case c.dyn[1+i]:
			s.setDir("")
			s.mayBeHome = true
		default:
			s.cdTo(rest[0])
		}
		if c.tool() == "pushd" {
			s.stack = append(s.stack, top)
		}
	case "popd":
		if n := len(s.stack); n > 0 && !s.stackLost {
			s.setDir(s.stack[n-1])
			s.stack = s.stack[:n-1]
		} else {
			s.setDir("")
		}
	case "unset":
		for _, a := range args {
			delete(s.vars, a)
		}
	// these set the variables they name to values the walk cannot see
	case "read", "mapfile", "readarray", "getopts", "printf", "print", "vared", "zparseopts":
		for _, a := range args {
			if v, ok := s.vars[a]; ok {
				s.vars[a] = shellVar{exported: v.exported}
			}
		}
	}
}

// assign records a variable a bare assignment, export, local, or declare sets
func (s *state) assign(a *syntax.Assign, export bool) {
	if a.Name == nil {
		return
	}
	name := a.Name.Value
	old := s.vars[name]
	if a.Naked {
		if _, ok := s.vars[name]; ok || !export {
			old.exported = old.exported || export
			s.vars[name] = old
		}
		return
	}
	v := shellVar{exported: old.exported || export}
	if !a.Append && a.Index == nil && a.Array == nil {
		v.value, v.known = s.literal(a.Value)
	}
	s.vars[name] = v
	switch name {
	case "cdpath":
		s.cdpath = nil
		if a.Array != nil {
			for _, e := range a.Array.Elems {
				s.cdpath = append(s.cdpath, s.word(e.Value))
			}
		}
	case "CDPATH":
		s.cdpath = strings.Split(v.value, ":")
	}
}

// walker collects every simple command with the state the shell is in when it runs
type walker struct {
	calls   []call
	visited map[*syntax.CallExpr]bool
	// missed counts the calls only the fallback reached
	missed int
	steps  int
	pipes  int
	// spans marks a walk of the agent's own command, whose top-level calls keep their words' positions
	spans bool
}

// parseCalls walks the agent's command, keeping where each top-level word sits in it
func parseCalls(src, cwd string) ([]call, error) { return walk(src, cwd, true) }

// parseScript walks shell code from elsewhere, such as a git alias body, whose positions name nothing in the command
func parseScript(src, cwd string) ([]call, error) { return walk(src, cwd, false) }

func walk(src, cwd string, spans bool) ([]call, error) {
	w := walker{visited: map[*syntax.CallExpr]bool{}, spans: spans}
	err := w.file(src, newState(cwd), 0)
	return w.calls, err
}

func (w *walker) file(src string, st *state, depth int) error {
	if depth > maxDepth {
		return fmt.Errorf("scripts nest more than %d levels deep", maxDepth)
	}
	f, err := parser.Parse(strings.NewReader(src), "")
	if err != nil {
		if depth > 0 {
			return fmt.Errorf("%v in the nested script: %s", err, src)
		}
		return err
	}
	if err := w.stmts(f.Stmts, st, depth); err != nil {
		return err
	}
	// a call the walk did not reach is still checked, from an unknown directory
	var missed []*syntax.Stmt
	syntax.Walk(f, func(n syntax.Node) bool {
		if s, ok := n.(*syntax.Stmt); ok {
			if ce, ok := s.Cmd.(*syntax.CallExpr); ok && !w.visited[ce] {
				missed = append(missed, s)
			}
		}
		return true
	})
	for _, s := range missed {
		if ce := s.Cmd.(*syntax.CallExpr); !w.visited[ce] {
			w.missed++
			if err := w.call(ce, s.Redirs, newState(""), depth); err != nil {
				return err
			}
		}
	}
	return nil
}

func (w *walker) stmts(list []*syntax.Stmt, st *state, depth int) error {
	for _, s := range list {
		if err := w.stmt(s, st, depth); err != nil {
			return err
		}
	}
	return nil
}

func (w *walker) stmt(s *syntax.Stmt, st *state, depth int) error {
	if w.steps++; w.steps > maxSteps {
		return fmt.Errorf("the command has more than %d statements to walk", maxSteps)
	}
	// a background job runs in a subshell
	if s.Background || s.Coprocess || s.Disown {
		st = st.clone()
	}
	if _, ok := s.Cmd.(*syntax.CallExpr); !ok {
		// a compound command's redirects, or a bare one that zsh runs as cat, still write
		if len(s.Redirs) > 0 {
			w.calls = append(w.calls, st.newCall(s.Redirs, false))
		}
		for _, r := range s.Redirs {
			if err := w.inner(r, st, depth); err != nil {
				return err
			}
		}
	}
	switch c := s.Cmd.(type) {
	case nil:
		return nil
	case *syntax.CallExpr:
		return w.call(c, s.Redirs, st, depth)
	case *syntax.BinaryCmd:
		return w.binary(c, st, depth)
	case *syntax.Subshell:
		return w.stmts(c.Stmts, st.clone(), depth)
	case *syntax.Block:
		return w.stmts(c.Stmts, st, depth)
	case *syntax.IfClause:
		return w.ifClause(c, st, depth)
	case *syntax.CaseClause:
		if err := w.inner(c.Word, st, depth); err != nil {
			return err
		}
		arms := []*state{}
		for _, item := range c.Items {
			arm := st.clone()
			if err := w.stmts(item.Stmts, arm, depth); err != nil {
				return err
			}
			arms = append(arms, arm)
		}
		for _, arm := range arms {
			st.merge(arm)
		}
		return nil
	case *syntax.WhileClause:
		return w.loop(st, depth, func(in *state) error {
			if err := w.stmts(c.Cond, in, depth); err != nil {
				return err
			}
			return w.stmts(c.Do, in, depth)
		})
	case *syntax.ForClause:
		var name string
		if it, ok := c.Loop.(*syntax.WordIter); ok {
			name = it.Name.Value
		}
		if err := w.inner(c.Loop, st, depth); err != nil {
			return err
		}
		return w.loop(st, depth, func(in *state) error {
			if name != "" {
				in.vars[name] = shellVar{exported: in.vars[name].exported}
			}
			return w.stmts(c.Do, in, depth)
		})
	case *syntax.DeclClause:
		if err := w.declare(c, st, depth); err != nil {
			return err
		}
		for _, a := range c.Args {
			if err := w.inner(a, st, depth); err != nil {
				return err
			}
			st.assign(a, c.Variant != nil && c.Variant.Value == "export")
		}
		return nil
	case *syntax.FuncDecl:
		if c.Name != nil {
			st.funcs[c.Name.Value] = c.Body
		}
		// a definition runs nothing, so its body is walked here only to collect it
		return w.stmt(c.Body, st.clone(), depth)
	}
	// a test, arithmetic, time, or coproc may change state the walk does not model
	branch := st.clone()
	err := w.inner(s.Cmd, branch, depth)
	st.merge(branch)
	return err
}

// binary walks a && or || chain, or a pipe
func (w *walker) binary(c *syntax.BinaryCmd, st *state, depth int) error {
	switch c.Op {
	case syntax.AndStmt:
		// the first part always runs. each later part runs only when the ones before it succeed,
		// so it sees their cds, but after the chain they may not hold
		parts := andChain(c)
		if err := w.stmt(parts[0], st, depth); err != nil {
			return err
		}
		rest := st.clone()
		err := w.stmts(parts[1:], rest, depth)
		st.merge(rest)
		return err
	case syntax.OrStmt:
		if err := w.stmt(c.X, st, depth); err != nil {
			return err
		}
		y := st.clone()
		err := w.stmt(c.Y, y, depth)
		st.merge(y)
		return err
	}
	// bash runs every side of a pipe in a subshell, zsh keeps the last one in the shell
	x, y := st.clone(), st.clone()
	if st.pipe == 0 {
		x.pipe, y.pipe = w.newPipe(), w.pipes
	}
	if err := w.stmt(c.X, x, depth); err != nil {
		return err
	}
	y.piped = true
	err := w.stmt(c.Y, y, depth)
	st.merge(y)
	return err
}

// andChain flattens a && b && c, which parses as (a && b) && c
func andChain(c *syntax.BinaryCmd) []*syntax.Stmt {
	if x, ok := c.X.Cmd.(*syntax.BinaryCmd); ok && x.Op == syntax.AndStmt && plainStmt(c.X) {
		return append(andChain(x), c.Y)
	}
	return []*syntax.Stmt{c.X, c.Y}
}

func plainStmt(s *syntax.Stmt) bool {
	return !s.Negated && !s.Background && !s.Coprocess && !s.Disown && len(s.Redirs) == 0
}

// ifClause runs the condition, then one arm, each from the state the condition leaves
func (w *walker) ifClause(c *syntax.IfClause, st *state, depth int) error {
	if err := w.stmts(c.Cond, st, depth); err != nil {
		return err
	}
	then := st.clone()
	if err := w.stmts(c.Then, then, depth); err != nil {
		return err
	}
	other := st.clone()
	if c.Else != nil {
		if err := w.ifClause(c.Else, other, depth); err != nil {
			return err
		}
	}
	st.merge(then)
	st.merge(other)
	return nil
}

// loop walks a body twice: once as the first pass sees the shell, and once as any later pass might
func (w *walker) loop(st *state, depth int, body func(*state) error) error {
	first := st.clone()
	if err := body(first); err != nil {
		return err
	}
	later := st.clone()
	later.merge(first)
	if err := body(later); err != nil {
		return err
	}
	st.merge(later)
	return nil
}

// inner walks the statements and substitutions directly inside node, with $(...) and <(...) in subshells
func (w *walker) inner(node syntax.Node, st *state, depth int) error {
	var err error
	syntax.Walk(node, func(n syntax.Node) bool {
		if err != nil {
			return false
		}
		switch n := n.(type) {
		case *syntax.Stmt:
			err = w.stmt(n, st, depth)
			return false
		case *syntax.CmdSubst:
			err = w.stmts(n.Stmts, st.clone(), depth)
			return false
		case *syntax.ProcSubst:
			// >(...) reads the output written to it, as the end of a pipe does
			sub := st.clone()
			if n.Op == syntax.CmdOut {
				sub.piped, sub.pipe = true, w.newPipe()
			}
			err = w.stmts(n.Stmts, sub, depth)
			return false
		// ${x:=v} and ${x=v} assign x a value the walk does not track
		case *syntax.ParamExp:
			if n.Param != nil && n.Exp != nil && strings.Contains(n.Exp.Op.String(), "=") {
				st.vars[n.Param.Value] = shellVar{exported: st.vars[n.Param.Value].exported}
			}
		}
		return true
	})
	return err
}

func (s *state) redirs(rs []*syntax.Redirect, top bool) []redir {
	var out []redir
	for _, r := range rs {
		rd := redir{op: r.Op, word: s.word(r.Word)}
		if r.Hdoc != nil {
			h := s.word(r.Hdoc)
			rd.hdoc = &h
			if top {
				rd.hdocSpan = &[2]int{int(r.Hdoc.Pos().Offset()), int(r.Hdoc.End().Offset())}
			}
		}
		out = append(out, rd)
	}
	return out
}

func (w *walker) call(ce *syntax.CallExpr, rs []*syntax.Redirect, st *state, depth int) error {
	w.visited[ce] = true
	top := w.spans && depth == 0
	c := st.newCall(rs, top)
	c.env = st.env(ce.Assigns)
	for _, a := range ce.Args {
		words := st.fields(a)
		c.argv = append(c.argv, words...)
		for range words {
			c.dyn = append(c.dyn, st.dynamic(a))
			if top {
				c.spans = append(c.spans, [2]int{int(a.Pos().Offset()), int(a.End().Offset())})
			}
		}
	}
	if len(ce.Args) > 0 && st.opaque(ce.Args[0]) {
		c.hidden = hiddenName
	}
	if runsZshCode(ce) {
		c.hidden = hiddenZsh
	}
	out := callsOf(c)
	w.calls = append(w.calls, out...)
	for _, a := range ce.Assigns {
		if err := w.inner(a, st, depth); err != nil {
			return err
		}
	}
	for _, a := range ce.Args {
		if err := w.inner(a, st, depth); err != nil {
			return err
		}
	}
	for _, r := range rs {
		if err := w.inner(r, st, depth); err != nil {
			return err
		}
	}
	if len(ce.Args) == 0 {
		for _, a := range ce.Assigns {
			st.assign(a, false)
		}
		return w.scripts(out, nil, st, depth)
	}
	real := out[len(out)-1]
	// a function call runs its body in this shell, where the definition left it
	if body, ok := st.funcs[real.tool()]; ok && len(real.prefix) == 0 {
		return w.inlined(body, st, depth+1)
	}
	if err := w.scripts(out, ce.Assigns, st, depth); err != nil {
		return err
	}
	st.apply(real)
	return nil
}

// newCall is a call with what the shell's state says about where and how it runs. top keeps its heredocs' positions
func (s *state) newCall(rs []*syntax.Redirect, top bool) call {
	return call{dir: s.dir, maybe: slices.Clone(s.maybe), moved: s.moved, mayBeHome: s.mayBeHome, piped: s.piped, pipe: s.pipe, redirs: s.redirs(rs, top)}
}

func (w *walker) newPipe() int {
	w.pipes++
	return w.pipes
}

// declare records an export, local, or declare as a call with no command, so its assignments are checked like a prefix's
func (w *walker) declare(c *syntax.DeclClause, st *state, depth int) error {
	dc := st.newCall(nil, false)
	dc.env = st.env(c.Args)
	out := callsOf(dc)
	w.calls = append(w.calls, out...)
	return w.scripts(out, nil, st, depth)
}

// scripts walks the shell code each call runs. eval runs its script in this shell, so its cds and assignments stay.
// any other script runs in a child shell, which sees the call's assignments
func (w *walker) scripts(out []call, assigns []*syntax.Assign, st *state, depth int) error {
	for _, oc := range out {
		for _, s := range oc.scripts {
			if oc.tool() == "eval" {
				if err := w.file(s, st, depth+1); err != nil {
					return err
				}
				continue
			}
			child := st.child(oc.dir)
			// a wrapper's NAME=value words reach the child with values the walk does not track
			for _, kv := range oc.env {
				name, _, _ := strings.Cut(kv, "=")
				child.vars[name] = shellVar{exported: true}
			}
			for _, a := range assigns {
				child.assign(a, true)
			}
			if err := w.file(s, child, depth+1); err != nil {
				return err
			}
		}
	}
	return nil
}

// env is the NAME=value text of the assignments that set a value
func (s *state) env(assigns []*syntax.Assign) []string {
	var out []string
	for _, a := range assigns {
		if a.Name != nil && !a.Naked {
			out = append(out, a.Name.Value+"="+s.word(a.Value))
		}
	}
	return out
}

// fields is the words w expands to. bash splits an unquoted known value on whitespace, so "rm f" in $x is two words.
// zsh does not, but checking the split form covers both shells
func (s *state) fields(w *syntax.Word) []string {
	if len(w.Parts) == 1 {
		if p, ok := w.Parts[0].(*syntax.ParamExp); ok {
			if v, known := s.value(p); known && strings.ContainsAny(v, " \t\n") {
				return strings.Fields(v)
			}
		}
	}
	return []string{s.word(w)}
}

// a zsh glob qualifier that runs code, (e:...:) or (+func), after a glob
var codeQualifier = regexp.MustCompile(`^\([^)]*(e[^A-Za-z0-9\s)]|\+)`)

// runsZshCode reports zsh's (e) expansion flag or a glob qualifier that runs code, anywhere in the call's words
func runsZshCode(ce *syntax.CallExpr) bool {
	found := false
	syntax.Walk(ce, func(n syntax.Node) bool {
		switch n := n.(type) {
		case *syntax.ParamExp:
			found = found || (n.Flags != nil && strings.Contains(n.Flags.Value, "e"))
		case *syntax.Lit:
			found = found || codeQualifier.MatchString(n.Value)
		}
		return !found
	})
	return found
}

func (w *walker) inlined(body *syntax.Stmt, st *state, depth int) error {
	if depth > maxDepth {
		return fmt.Errorf("function calls nest more than %d levels deep", maxDepth)
	}
	return w.stmt(body, st, depth)
}

// plainParam is $name or ${name} with no operator, which a known variable can stand in for
func plainParam(p *syntax.ParamExp) bool {
	return p.Param != nil && p.Flags == nil && !p.Excl && !p.Length && !p.Width && !p.IsSet &&
		p.Split == syntax.OptUnset && p.GlobSubst == syntax.OptUnset && p.RcExpand == syntax.OptUnset &&
		p.NestedParam == nil && p.Index == nil && len(p.Modifiers) == 0 && p.Slice == nil &&
		p.Repl == nil && p.Names == 0 && p.Exp == nil
}

func (s *state) value(p *syntax.ParamExp) (string, bool) {
	// ${d:?} and ${d?} expand to $d whenever they expand at all, so a known non-empty d stands in for them
	if p.Exp != nil && strings.Contains(p.Exp.Op.String(), "?") {
		bare := *p
		bare.Exp = nil
		if v, ok := s.value(&bare); ok && v != "" {
			return v, true
		}
		return "", false
	}
	if !plainParam(p) {
		return "", false
	}
	v := s.vars[p.Param.Value]
	return v.value, v.known
}

var escaped = regexp.MustCompile(`\\(.)`)

// word is the literal text of w with known variables filled in. any other parameter reads as $name and any other expansion as $(...)
func (s *state) word(w *syntax.Word) string {
	if w == nil {
		return ""
	}
	var b strings.Builder
	for _, p := range w.Parts {
		b.WriteString(s.part(p))
	}
	return b.String()
}

// scratchMark names the folder the guard stands in for a fresh scratch directory. the exact name does not
// matter: it only has to resolve to an untracked path, so the write under it clears the checks
const scratchMark = "agent-guard-fresh"

// scratchSubst is the fresh directory a command substitution makes, when it runs new-scratch.sh.
// such a directory is new and untracked, so a write under it is safe. the guard stands a concrete path in for it,
// which the resolver and the other checks then read like any absolute path, so an escape with .. is still caught
func (s *state) scratchSubst(cs *syntax.CmdSubst) (string, bool) {
	if len(cs.Stmts) != 1 || cs.Stmts[0].Cmd == nil {
		return "", false
	}
	ce, ok := cs.Stmts[0].Cmd.(*syntax.CallExpr)
	if !ok || len(ce.Args) == 0 || base(s.word(ce.Args[0])) != "new-scratch.sh" {
		return "", false
	}
	root := os.Getenv("HOME")
	if s.dir != "" {
		if top := gitOut(s.dir, "rev-parse", "--show-toplevel"); top != "" {
			root = top
		}
	}
	return filepath.Join(root, ".eric/scratch", scratchMark), true
}

func (s *state) part(p syntax.WordPart) string {
	switch p := p.(type) {
	case *syntax.Lit:
		return escaped.ReplaceAllString(p.Value, "$1")
	case *syntax.SglQuoted:
		// $'...' decodes its escapes as printf does, so a literal % is doubled first
		if p.Dollar {
			if v, _, err := expand.Format(&expand.Config{}, strings.ReplaceAll(p.Value, "%", "%%"), nil); err == nil {
				v, _, _ = strings.Cut(v, "\x00")
				return v
			}
		}
		return p.Value
	case *syntax.DblQuoted:
		var b strings.Builder
		for _, q := range p.Parts {
			b.WriteString(s.part(q))
		}
		return b.String()
	case *syntax.ParamExp:
		if v, ok := s.value(p); ok {
			return v
		}
		if p.Param == nil {
			return "$"
		}
		// a variable this command set to a value the walk cannot see reads as a substitution, so the guard's own
		// environment never stands in for it
		if _, set := s.vars[p.Param.Value]; set {
			return "$(...)"
		}
		return "$" + p.Param.Value
	case *syntax.CmdSubst:
		if d, ok := s.scratchSubst(p); ok {
			return d
		}
	}
	return "$(...)"
}

// literal is w's value when every part of it is known
func (s *state) literal(w *syntax.Word) (string, bool) {
	if w == nil {
		return "", true
	}
	known := true
	syntax.Walk(w, func(n syntax.Node) bool {
		switch n := n.(type) {
		case *syntax.ParamExp:
			if _, ok := s.value(n); !ok {
				known = false
			}
			return false
		case *syntax.SglQuoted:
			known = known && !n.Dollar
		case *syntax.CmdSubst:
			// a fresh scratch directory stands in for a known path, so a variable set to it reads as that path
			if _, ok := s.scratchSubst(n); !ok {
				known = false
			}
			return false
		case *syntax.ProcSubst, *syntax.ArithmExp, *syntax.ExtGlob, *syntax.BraceExp:
			known = false
			return false
		}
		return true
	})
	return s.word(w), known
}

// dynamic marks a bare unquoted $var or $(...) that can expand to nothing. ${d:?} fails when empty instead
func (s *state) dynamic(w *syntax.Word) bool {
	if len(w.Parts) != 1 {
		return false
	}
	switch p := w.Parts[0].(type) {
	case *syntax.ParamExp:
		if v, ok := s.value(p); ok {
			return v == ""
		}
		return p.Exp == nil || !strings.Contains(p.Exp.Op.String(), "?")
	case *syntax.CmdSubst:
		return true
	}
	return false
}

var globChars = regexp.MustCompile(`[*?[{]`)

// opaque reports a command name the guard cannot read: one built from an unknown variable, a substitution,
// a glob or brace, or an escape in $'...'. $HOME and $PWD at the start still name a known directory
func (s *state) opaque(w *syntax.Word) bool {
	for i, p := range w.Parts {
		switch p := p.(type) {
		case *syntax.Lit:
			if v := p.Value; v != "[" && v != "[[" && globChars.MatchString(v) {
				return true
			}
		case *syntax.SglQuoted:
			if p.Dollar && strings.Contains(p.Value, `\`) {
				return true
			}
		case *syntax.DblQuoted:
			if s.opaque(&syntax.Word{Parts: p.Parts}) {
				return true
			}
		case *syntax.ParamExp:
			if _, ok := s.value(p); ok {
				continue
			}
			if i == 0 && p.Param != nil && (p.Param.Value == "HOME" || p.Param.Value == "PWD") && plainParam(p) {
				continue
			}
			return true
		default:
			return true
		}
	}
	return false
}
