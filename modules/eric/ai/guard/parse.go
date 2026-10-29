package main

import (
	"regexp"
	"slices"
	"strings"

	"mvdan.cc/sh/v3/syntax"
)

// call is one simple command. a command behind a wrapper like env or sudo yields a second call without the wrapper
type call struct {
	argv []string
	// dyn marks a bare unquoted $var or $(...), which can expand to nothing
	dyn    []bool
	redirs []redir
	// wrapper marks the call as written, when a stripped copy follows it
	wrapper bool
	// prefix holds the wrapper words a stripped call ran behind
	prefix []string
	// scripts is the shell code the call runs: a shell's -c script or here-string, eval's words, a runner's command string
	// such as tmux new-session's, or a command a git setting or an environment variable like GIT_PAGER names
	scripts []string
	// env is the NAME=value assignments the call runs with, from the shell or a wrapper like env
	env []string
	// dir is where the call runs, or "" when the guard cannot tell
	dir string
	// maybe lists the directories the call may run in, when dir is ""
	maybe []string
	// moved marks a dir that a cd, env -C, or sudo -D in the command changed
	moved bool
	// mayBeHome marks a call after a cd that lands in $HOME when its variable is empty
	mayBeHome bool
	// piped marks a call that reads the output of the command before it in a pipe
	piped bool
	// pipe numbers the pipeline the call is part of, or is 0 outside one
	pipe int
	// hidden says why the guard cannot see what this call runs, such as a name from $(...) or a script read from a pipe
	hidden string
	// spans is each argv word's byte range in the command, for a top-level call whose words are as written
	spans [][2]int
}

const (
	hiddenName  = "The guard cannot tell which program this command runs, since its name comes from a variable, a substitution, a glob, or an escape, so it cannot check it. Write the program name literally."
	hiddenStdin = "A shell here reads its script from standard input, so the guard hooks cannot check it. Pass the script with bash -c, a here-string, or a heredoc."
	hiddenShell = "This command runs a csh, tcsh, or fish script, whose syntax the guard cannot parse. Use bash or zsh."
	hiddenInput = "xargs here builds a command or a script from its input, which the guard cannot see. Loop over the input in the shell instead."
	hiddenSetup = "This command sets BASH_ENV or ZDOTDIR, or a git setting such as core.hooksPath or --config-env, which runs code the guard cannot see."
	hiddenZsh   = "zsh's (e) expansion flag or an e or + glob qualifier runs code the guard cannot see. Write the command out."
	hiddenProg  = "An interpreter here reads its program from standard input, so the guard cannot check it. Pass the program with -c or -e, a here-string, or a heredoc."
	hiddenText  = "This awk or sed program runs a command, or writes to a file it names by an expression, which the guard cannot see. Write the output with a shell redirect instead."
	hiddenAlias = "The guard cannot read this git alias, since it runs in a repo the guard cannot tell, its text is more than one plain command, or it names a long chain of aliases. Run the git command it stands for."
)

type redir struct {
	op   syntax.RedirOperator
	word string
	// alt is the target rendered with maybeEmpty vars empty (the cd-failed world), when that differs from
	// word. a write check resolves it too, so an empty expansion that lands on a protected path is caught
	alt  string
	hdoc *string
	// hdocSpan is the heredoc body's byte range in the command, when the call is top level
	hdocSpan *[2]int
}

// callsOf is c as written and, behind a wrapper, again as the command it wraps. a wrapper option the table
// does not list may take a value, so the command a greedy reading finds is checked too, before the real one
func callsOf(c call) []call {
	out := []call{c}
	if n := wrapperLen(c.argv, false); n > 0 {
		out[0].wrapper = true
		inner := c.behind(n)
		if d, moved := wrapperDir(c.argv, c.dir); moved {
			inner.dir, inner.moved = d, true
			if d != "" {
				inner.maybe = nil
			}
		}
		if g := wrapperLen(c.argv, true); g > 0 && g != n {
			alt := c.behind(g)
			alt.dir, alt.maybe, alt.moved = inner.dir, inner.maybe, inner.moved
			out = append(out, alt)
		}
		out = append(out, inner)
	}
	if xargsHides(c.argv) {
		out[0].hidden = hiddenInput
	}
	for i := range out {
		out[i].setScripts()
	}
	return out
}

// behind is the call the first n words wrap, with the wrappers' NAME=value words in its env
func (c call) behind(n int) call {
	inner := c
	inner.argv, inner.dyn, inner.prefix = c.argv[n:], c.dyn[n:], c.argv[:n]
	if c.spans != nil {
		inner.spans = c.spans[n:]
	}
	inner.env = slices.Concat(c.env, slices.DeleteFunc(slices.Clone(c.argv[1:n]), func(w string) bool { return !envWord.MatchString(w) }))
	return inner.nixRunArgs()
}

// nixRunArgs drops the -- that ends nix run's own options, which nix keeps from the installable it runs
func (c call) nixRunArgs() call {
	i := len(c.prefix) - 1
	for i >= 0 && base(c.prefix[i]) != "nix" {
		i--
	}
	k := slices.Index(c.argv, "--")
	// the nix run must be the last wrapper, the one that runs this call
	if i < 0 || at(nixCommand(c.prefix[i:]), 0) != "run" || wrapperStep(slices.Concat(c.prefix[i:], c.argv[:1]), false) != len(c.prefix)-i || k < 1 {
		return c
	}
	c.argv, c.dyn = slices.Delete(slices.Clone(c.argv), k, k+1), slices.Delete(slices.Clone(c.dyn), k, k+1)
	if c.spans != nil {
		c.spans = slices.Delete(slices.Clone(c.spans), k, k+1)
	}
	return c
}

var envWord = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*=`)

// xargsHides reports an xargs whose input becomes code: the command a bare wrapper or eval takes from the input,
// or a -I replace string in the program name or a script
func xargsHides(a []string) bool {
	if base(at(a, 0)) != "xargs" {
		return false
	}
	n := wrapperStep(a, false)
	inner := a[min(n, len(a)):]
	if n == 0 || len(inner) == 0 {
		return false
	}
	if m := wrapperStep(inner, false); m >= len(inner) || (program(inner[0]) == "eval" && len(inner) == 1) {
		return true
	}
	replace, ok := leadingArgs("xargs", a[1:n]).value("-I", "-J", "--replace")
	if !ok || replace == "" {
		return false
	}
	s, _ := scriptOf(inner)
	return strings.Contains(inner[0], replace) || strings.Contains(s, replace)
}

func base(s string) string { return s[strings.LastIndex(s, "/")+1:] }

// at is a[i], or "" past the end
func at(a []string, i int) string {
	if i < len(a) {
		return a[i]
	}
	return ""
}

// afterWord is the index after the first of words in a, or 0
func afterWord(a []string, words ...string) int {
	for i, w := range a {
		if slices.Contains(words, w) {
			return i + 1
		}
	}
	return 0
}

// nixCommand is the nix subcommand and the words after it, past any global options
func nixCommand(a []string) []string {
	return leadingArgs("nix", a[min(1, len(a)):]).operands
}

// wrapperLen is how many leading words are wrappers around the real command
func wrapperLen(a []string, greedy bool) int {
	if n := wrapperStep(a, greedy); n > 0 && n < len(a) {
		return n + wrapperLen(a[n:], greedy)
	}
	return 0
}

// wrapperDir is where a wrapper chain runs its command, and whether a wrapper moved it:
// env -C and sudo -D move it, and find -execdir makes it unknown
func wrapperDir(a []string, dir string) (string, bool) {
	moved := false
	for {
		n := wrapperStep(a, false)
		if n <= 0 || n >= len(a) {
			return dir, moved
		}
		lead := leadingArgs(base(a[0]), a[1:n])
		switch base(a[0]) {
		case "env":
			if v, ok := lead.value("-C", "--chdir"); ok {
				dir, moved = resolveIn(dir, v), true
			}
		case "sudo":
			if v, ok := lead.value("-D", "--chdir"); ok {
				dir, moved = resolveIn(dir, v), true
			}
		case "find":
			if slices.Contains(a[1:n], "-execdir") || slices.Contains(a[1:n], "-okdir") {
				return "", true
			}
		}
		a = a[n:]
	}
}

// wrapperStep is how many leading words the first wrapper and its options take, or 0.
// greedy reads a wrapper option the table does not list as one that takes a value
func wrapperStep(a []string, greedy bool) int {
	if len(a) == 0 {
		return 0
	}
	c := base(a[0])
	lead := readArgs(c, a[1:], true, greedy)
	end := 1 + lead.end
	switch {
	case c == "command" && lead.has("-v", "-V"):
	case slices.Contains(wrappers, c):
		return end
	// a lock file or a duration comes before the command
	case c == "flock" || c == "timeout" || c == "gtimeout":
		return end + 1
	// BSD script runs its command after the output file. script -c takes it as a script instead
	case c == "script" && !parseArgs("script", a[1:]).has("-c", "--command"):
		return end + 1
	// zsh's - runs its command as a login shell would
	case c == "-":
		return 1
	case c == "direnv" && at(a, 1) == "exec":
		return 3
	case c == "just":
		return afterWord(a, "-c", "--command")
	case slices.Contains(subcommandRunners, c+" "+at(a, 1)):
		return 2 + readArgs(c+" "+a[1], a[2:], true, greedy).end
	case c == "nix":
		sub := nixCommand(a)
		k := len(a) - len(sub)
		switch at(sub, 0) {
		case "develop", "shell":
			if j := afterWord(sub, "-c", "--command"); j > 0 {
				return k + j
			}
		// the installable runs as a command named after the part past the #
		case "run":
			if j := 1 + leadingArgs("nix", sub[1:]).end; j < len(sub) {
				return k + j
			}
		}
	case c == "find":
		return afterWord(a, "-exec", "-execdir", "-ok", "-okdir")
	}
	return 0
}

// wrappers run the command after their options, as in sudo -u root cmd
var wrappers = []string{"env", "exec", "doas", "ionice", "caffeinate", "stdbuf", "xcrun", "sudo", "nice", "xargs", "arch", "sandbox-exec",
	"command", "builtin", "nohup", "time", "noglob", "nocorrect", "chronic", "unbuffer", "coproc", "uvx", "npx", "bunx"}

// subcommandRunners run the command after a subcommand and its options, as in uv run pytest
var subcommandRunners = []string{"uv run", "poetry run", "pnpm exec", "pnpm dlx", "yarn dlx", "bun x"}

var shells = []string{"sh", "bash", "zsh", "dash", "ksh", "mksh", "oksh", "yash"}

// these shells take a syntax the parser cannot read
var foreignShells = []string{"csh", "tcsh", "fish"}

func scriptOf(a []string) (string, bool) {
	words := a[min(1, len(a)):]
	switch c := program(at(a, 0)); {
	case c == "eval":
		return strings.Join(words, " "), true
	// watch joins its words into a script for sh -c
	case c == "watch":
		return strings.Join(leadingArgs("watch", words).operands, " "), true
	case c == "script" || c == "flock" || c == "nix-shell" || c == "npx":
		return parseArgs(c, words).value("-c", "--command", "--run", "--call")
	case c == "env":
		return leadingArgs("env", words).value("-S", "--split-string")
	// trap - resets a signal, and trap with only -l or -p prints
	case c == "trap":
		ops := parseArgs("trap", words).operands
		return at(ops, 0), len(ops) > 0 && ops[0] != "-"
	case c == "git":
		g := call{argv: a}.gitArgs()
		switch {
		case at(g, 0) == "submodule" && slices.Contains(g, "foreach"):
			return strings.Join(leadingArgs("git submodule foreach", g[slices.Index(g, "foreach")+1:]).operands, " "), true
		case at(g, 0) == "bisect" && at(g, 1) == "run":
			return strings.Join(g[2:], " "), true
		case at(g, 0) == "difftool":
			return parseArgs("git difftool", g[1:]).value("-x", "--extcmd")
		}
	// a shell reads its options up to the first operand, -c among them, and takes that operand as the script
	case slices.Contains(shells, c):
		if lead := leadingArgs(c, words); lead.has("-c") {
			return at(lead.operands, 0), len(lead.operands) > 0
		}
	}
	return "", false
}

func info(a []string) bool {
	return slices.ContainsFunc(a[min(1, len(a)):], func(w string) bool { return w == "--version" || w == "--help" })
}

// pipeFile names a pipe, so a shell that runs it as a script file reads hidden input
func pipeFile(w string) bool {
	return w == "/dev/stdin" || strings.HasPrefix(w, "/dev/fd/") || strings.HasPrefix(w, "/proc/self/fd/") || w == "$(...)"
}

// readsScript reports a shell that reads its script from standard input or a pipe it names: a shell with -s,
// no script file, or /dev/stdin or <(...) as one, source or . of a pipe, sudo -s or -i with no command,
// and a nix or nix-shell shell with no command
func readsScript(a []string) bool {
	words := a[min(1, len(a)):]
	switch c := program(at(a, 0)); {
	case info(a):
		return false
	case slices.Contains(shells, c):
		lead := leadingArgs(c, words)
		// -n parses the script but runs nothing, so where the script comes from does not matter
		if lead.has("-n") {
			return false
		}
		return lead.has("-s") || len(lead.operands) == 0 || pipeFile(lead.operands[0])
	case c == "source" || c == ".":
		return pipeFile(at(parseArgs(c, words).operands, 0))
	case c == "sudo":
		lead := leadingArgs("sudo", words)
		return len(lead.operands) == 0 && lead.has("-s", "-i", "--shell", "--login")
	case c == "nix":
		sub := nixCommand(a)
		return (at(sub, 0) == "develop" || at(sub, 0) == "shell") && afterWord(sub, "-c", "--command") == 0
	case c == "nix-shell":
		return !parseArgs("nix-shell", words).has("--run", "--command")
	}
	return false
}

// the options that give an interpreter its program, or make it print and exit
var programOpts = map[string][]string{
	"python": {"-c", "-m", "-V", "-h"},
	"node":   {"-e", "-p", "--eval", "--print", "-v", "-h", "--check"},
	"ruby":   {"-e", "-v", "-h"},
	"perl":   {"-e", "-E", "-v", "-V", "-h"},
}

// readsProgram reports an interpreter given no program file, or -, and no option that gives it one,
// which reads its program from standard input
func readsProgram(a []string) bool {
	g := interpreter(program(at(a, 0)))
	if g == "" || info(a) {
		return false
	}
	p := parseArgs(g, a[1:])
	return (len(p.operands) == 0 || p.operands[0] == "-") && !p.has(programOpts[g]...)
}

// interpreter is the grammar of a python, node, ruby, or perl program name, or ""
func interpreter(name string) string {
	if !interpreters.MatchString(name) {
		return ""
	}
	if strings.HasPrefix(name, "python") {
		return "python"
	}
	return name
}

// hereText is the text a here-string or heredoc gives the call, the first one in its redirects
func (c call) hereText() (string, bool) {
	for _, r := range c.redirs {
		if r.op == syntax.WordHdoc {
			return r.word, true
		}
		if (r.op == syntax.Hdoc || r.op == syntax.DashHdoc) && r.hdoc != nil {
			return *r.hdoc, true
		}
	}
	return "", false
}

// variables whose value is a command that a program runs through a shell
var commandVars = []string{"GIT_PAGER", "GIT_EDITOR", "GIT_SEQUENCE_EDITOR", "GIT_EXTERNAL_DIFF", "GIT_SSH_COMMAND", "GIT_SSH",
	"GIT_ASKPASS", "SSH_ASKPASS", "PAGER", "EDITOR", "VISUAL"}

// variables that name a startup file a shell reads before its script
var startupVars = []string{"BASH_ENV", "ZDOTDIR"}

// setScripts records the shell code a call runs and anything it runs that the guard cannot see
func (c *call) setScripts() {
	a := c.argv
	if slices.Contains(foreignShells, program(at(a, 0))) && !info(a) {
		c.hidden = hiddenShell
		return
	}
	if s, ok := scriptOf(a); ok {
		c.scripts = append(c.scripts, s)
	} else if readsScript(a) {
		if s, ok := c.hereText(); ok {
			c.scripts = append(c.scripts, s)
		} else {
			c.hidden = hiddenStdin
		}
	} else if _, ok := c.hereText(); !ok && readsProgram(a) {
		c.hidden = hiddenProg
	} else if t := c.tool(); (t == "awk" || t == "sed") && programWrites(*c).runs {
		c.hidden = hiddenText
	}
	c.scripts = append(c.scripts, tmuxScripts(a)...)
	for _, kv := range c.env {
		name, value, _ := strings.Cut(kv, "=")
		switch {
		case slices.Contains(commandVars, name):
			c.scripts = append(c.scripts, value)
		case slices.Contains(startupVars, name):
			c.hidden = hiddenSetup
		}
	}
	scripts, hides := c.gitConfigScripts()
	c.scripts = append(c.scripts, scripts...)
	if hides {
		c.hidden = hiddenSetup
	}
}

// git settings whose value is a command git runs
var gitCommandKey = regexp.MustCompile(`^(core\.(fsmonitor|pager|editor|sshcommand|askpass|alternaterefscommand)|diff\.external|` +
	`sequence\.editor|credential\.(.+\.)?helper|gpg\.(.+\.)?program|pager\..+|(diff|merge|filter)\..+\.(textconv|command|driver|clean|smudge|process))$`)

// gitConfigScripts is the commands a git call's -c settings run. core.hooksPath, or a command setting
// read from the environment with --config-env, hides what runs
func (c call) gitConfigScripts() (scripts []string, hides bool) {
	for _, s := range c.gitSettings() {
		switch {
		case s.key == "core.hookspath" || (gitCommandKey.MatchString(s.key) && s.fromEnv):
			hides = true
		case gitCommandKey.MatchString(s.key):
			scripts = append(scripts, strings.TrimPrefix(s.value, "!"))
		}
	}
	return scripts, hides
}

// tmux subcommands that run a shell command, by their short names too
var tmuxRunners = map[string]string{"new-session": "new-session", "new": "new-session", "new-window": "new-window", "neww": "new-window",
	"split-window": "split-window", "splitw": "split-window", "respawn-pane": "respawn-pane", "respawnp": "respawn-pane",
	"respawn-window": "respawn-window", "respawnw": "respawn-window", "run-shell": "run-shell", "run": "run-shell",
	"display-popup": "display-popup", "popup": "display-popup", "pipe-pane": "pipe-pane", "pipep": "pipe-pane", "if-shell": "if-shell", "if": "if-shell"}

// tmuxScripts is the shell commands a tmux call runs: its -c command, and the command string of each
// new-session, split-window, run-shell, and the like, in a chain split by ;
func tmuxScripts(a []string) []string {
	if program(at(a, 0)) != "tmux" {
		return nil
	}
	var out []string
	lead := leadingArgs("tmux", a[1:])
	if s, ok := lead.value("-c"); ok {
		out = append(out, s)
	}
	for rest := lead.operands; len(rest) > 0; {
		cmd := rest
		if j := slices.Index(rest, ";"); j >= 0 {
			cmd, rest = rest[:j], rest[j+1:]
		} else {
			rest = nil
		}
		name, ok := tmuxRunners[at(cmd, 0)]
		if !ok {
			continue
		}
		ops := parseArgs("tmux "+name, cmd[1:]).operands
		// if-shell runs its condition as shell code, and its then and else commands as tmux commands
		if name == "if-shell" {
			for _, s := range ops[min(1, len(ops)):] {
				out = append(out, "tmux "+s)
			}
			ops = ops[:min(1, len(ops))]
		}
		if len(ops) > 0 {
			out = append(out, strings.Join(ops, " "))
		}
	}
	return out
}
