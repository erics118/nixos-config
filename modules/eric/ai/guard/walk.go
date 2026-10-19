package main

import (
	"fmt"
	"maps"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strings"

	"mvdan.cc/sh/v3/syntax"
)

var parser = syntax.NewParser(syntax.Variant(syntax.LangZsh))

// nested scripts and function calls are followed this many levels deep. deeper ones deny
const maxDepth = 16

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
	// prev is the directory before the last cd, for cd -
	prev  string
	stack []string
	// stackLost marks a pushd stack a branch may have changed
	stackLost bool
	vars      map[string]shellVar
	funcs     map[string]*syntax.Stmt
}

func newState(dir string) *state {
	return &state{dir: dir, vars: map[string]shellVar{}, funcs: map[string]*syntax.Stmt{}}
}

func (s *state) clone() *state {
	c := *s
	c.maybe = slices.Clone(s.maybe)
	c.stack = slices.Clone(s.stack)
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

// cdTo moves to p, relative to every directory the shell may be in
func (s *state) cdTo(p string) {
	if s.dir != "" || len(s.maybe) == 0 {
		s.setDir(resolveIn(s.dir, p))
		return
	}
	var maybe []string
	for _, d := range s.maybe {
		if r := resolveIn(d, p); r != "" {
			maybe = append(maybe, r)
		}
	}
	s.setDir("")
	s.maybe = maybe
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
	if strings.Contains(p, "$") {
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
	case "read", "mapfile", "readarray", "getopts", "printf", "vared", "zparseopts":
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
}

// walker collects every simple command with the state the shell is in when it runs
type walker struct {
	calls   []call
	visited map[*syntax.CallExpr]bool
	// missed counts the calls only the fallback reached
	missed int
}

func parseCalls(src, cwd string) ([]call, error) {
	w := walker{visited: map[*syntax.CallExpr]bool{}}
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
	// a background job runs in a subshell
	if s.Background || s.Coprocess || s.Disown {
		st = st.clone()
	}
	if _, ok := s.Cmd.(*syntax.CallExpr); !ok {
		// a compound command's redirects, or a bare one that zsh runs as cat, still write
		if len(s.Redirs) > 0 {
			w.calls = append(w.calls, call{redirs: st.redirs(s.Redirs), dir: st.dir, maybe: slices.Clone(st.maybe), moved: st.moved})
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
	if err := w.stmt(c.X, st.clone(), depth); err != nil {
		return err
	}
	y := st.clone()
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
			err = w.stmts(n.Stmts, st.clone(), depth)
			return false
		}
		return true
	})
	return err
}

func (s *state) redirs(rs []*syntax.Redirect) []redir {
	var out []redir
	for _, r := range rs {
		rd := redir{op: r.Op.String(), word: s.word(r.Word)}
		if r.Hdoc != nil {
			h := s.word(r.Hdoc)
			rd.hdoc = &h
		}
		out = append(out, rd)
	}
	return out
}

func (w *walker) call(ce *syntax.CallExpr, rs []*syntax.Redirect, st *state, depth int) error {
	w.visited[ce] = true
	c := call{dir: st.dir, maybe: slices.Clone(st.maybe), moved: st.moved, mayBeHome: st.mayBeHome, redirs: st.redirs(rs)}
	for _, a := range ce.Args {
		c.argv = append(c.argv, st.word(a))
		c.dyn = append(c.dyn, st.dynamic(a))
	}
	if len(ce.Args) > 0 {
		c.opaque = st.opaque(ce.Args[0])
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
		return nil
	}
	real := out[len(out)-1]
	// a function call runs its body in this shell, where the definition left it
	if body, ok := st.funcs[real.tool()]; ok && len(real.prefix) == 0 {
		return w.inlined(body, st, depth+1)
	}
	for _, oc := range out {
		if oc.script == nil {
			continue
		}
		// eval runs its script in this shell, so the script's cds and assignments stay
		if base(at(oc.argv, 0)) == "eval" {
			return w.file(*oc.script, st, depth+1)
		}
		child := st.child(oc.dir)
		for _, a := range ce.Assigns {
			child.assign(a, true)
		}
		if err := w.file(*oc.script, child, depth+1); err != nil {
			return err
		}
	}
	st.apply(real)
	return nil
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

func (s *state) part(p syntax.WordPart) string {
	switch p := p.(type) {
	case *syntax.Lit:
		return escaped.ReplaceAllString(p.Value, "$1")
	case *syntax.SglQuoted:
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
		return "$" + p.Param.Value
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
		case *syntax.CmdSubst, *syntax.ProcSubst, *syntax.ArithmExp, *syntax.ExtGlob, *syntax.BraceExp:
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
