package main

import (
	"regexp"
	"slices"
	"strings"
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
	// script is what a shell -c, eval, env -S, flock -c, nix-shell --run, or here-string runs
	script *string
	// stdin marks a shell that reads its script from standard input
	stdin bool
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
	// opaque marks a command name the guard cannot read, such as $(...) or a glob
	opaque bool
}

type redir struct {
	op, word string
	hdoc     *string
}

// callsOf is c as written and, behind a wrapper, again as the command it wraps
func callsOf(c call) []call {
	out := []call{c}
	if n := wrapperLen(c.argv); n > 0 {
		out[0].wrapper = true
		inner := c
		inner.argv, inner.dyn, inner.prefix = c.argv[n:], c.dyn[n:], c.argv[:n]
		if d, moved := wrapperDir(c.argv, c.dir); moved {
			inner.dir, inner.moved = d, true
			if d != "" {
				inner.maybe = nil
			}
		}
		out = append(out, inner)
	}
	for i := range out {
		out[i].setScript()
	}
	return out
}

func base(s string) string { return s[strings.LastIndex(s, "/")+1:] }

// at is a[i], or "" past the end
func at(a []string, i int) string {
	if i < len(a) {
		return a[i]
	}
	return ""
}

var assignment = regexp.MustCompile(`^-|^[A-Za-z_][A-Za-z0-9_]*=`)

// optsEnd is the index of the first word after a wrapper's options. vals lists the options that take a value,
// which a cluster such as -vC also takes when it ends in one
func optsEnd(a []string, vals ...string) int {
	i := 1
	for i < len(a) {
		w := a[i]
		switch {
		case w == "--":
			return i + 1
		case !assignment.MatchString(w):
			return i
		case slices.Contains(vals, w) ||
			(!strings.HasPrefix(w, "--") && !strings.Contains(w, "=") && len(w) > 2 && slices.Contains(vals, "-"+w[len(w)-1:])):
			i += 2
		default:
			i++
		}
	}
	return i
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

// optValue is the value of the last of names in opts. a short name may be attached (-Csub) or end a cluster (-vC sub),
// and a long one may take = (--chdir=sub)
func optValue(opts []string, names ...string) (string, bool) {
	value, found := "", false
	for i := 0; i < len(opts); i++ {
		o := opts[i]
		for _, n := range names {
			long := strings.HasPrefix(n, "--")
			switch {
			case o == n || (!long && len(o) > 2 && !strings.HasPrefix(o, "--") && strings.HasSuffix(o, n[1:]) && !strings.Contains(o, "=")):
				value, found = at(opts, i+1), i+1 < len(opts)
				i++
			case long && strings.HasPrefix(o, n+"="):
				value, found = o[len(n)+1:], true
			case !long && strings.HasPrefix(o, n) && len(o) > len(n) && !strings.HasPrefix(o, "--"):
				value, found = o[len(n):], true
			default:
				continue
			}
			break
		}
	}
	return value, found
}

// installable is the index of the installable `nix run` starts, or 0. it runs as a command named after the part past the #
func installable(a []string) int {
	i := 2
	for i < len(a) {
		switch {
		case slices.Contains([]string{"--override-input", "--option", "--arg", "--argstr"}, a[i]):
			i += 3
		case slices.Contains([]string{"-I", "--include", "--expr", "-f", "--file", "--inputs-from"}, a[i]):
			i += 2
		case strings.HasPrefix(a[i], "-"):
			i++
		default:
			return i
		}
	}
	return 0
}

// wrapperLen is how many leading words are wrappers around the real command
func wrapperLen(a []string) int {
	if n := wrapperStep(a); n > 0 && n < len(a) {
		return n + wrapperLen(a[n:])
	}
	return 0
}

// wrapperDir is where a wrapper chain runs its command, and whether a wrapper moved it:
// env -C and sudo -D move it, and find -execdir makes it unknown
func wrapperDir(a []string, dir string) (string, bool) {
	moved := false
	for {
		n := wrapperStep(a)
		if n <= 0 || n >= len(a) {
			return dir, moved
		}
		opts := a[1:n]
		switch base(a[0]) {
		case "env":
			if v, ok := optValue(opts, "-C", "--chdir"); ok {
				dir, moved = resolveIn(dir, v), true
			}
		case "sudo":
			if v, ok := optValue(opts, "-D", "--chdir"); ok {
				dir, moved = resolveIn(dir, v), true
			}
		case "find":
			if slices.Contains(opts, "-execdir") || slices.Contains(opts, "-okdir") {
				return "", true
			}
		}
		a = a[n:]
	}
}

// wrapperStep is how many leading words the first wrapper and its options take, or 0
func wrapperStep(a []string) int {
	if len(a) == 0 {
		return 0
	}
	n := 0
	switch c := base(a[0]); {
	case c == "env":
		n = optsEnd(a, "-u", "-C", "-S", "--unset", "--chdir", "--split-string")
	case c == "command" && slices.ContainsFunc(a[1:], func(w string) bool { return w == "-v" || w == "-V" }):
	case c == "exec":
		n = optsEnd(a, "-a")
	case slices.Contains([]string{"command", "builtin", "nohup", "time", "noglob", "nocorrect", "chronic", "unbuffer", "coproc"}, c):
		n = optsEnd(a)
	case c == "doas":
		n = optsEnd(a, "-u", "-C")
	case c == "ionice":
		n = optsEnd(a, "-c", "-n", "-p", "-P", "-u", "--class", "--classdata", "--pid", "--pgid", "--uid")
	case c == "caffeinate":
		n = optsEnd(a, "-w", "-t")
	case c == "stdbuf":
		n = optsEnd(a, "-i", "-o", "-e", "--input", "--output", "--error")
	case c == "xcrun":
		n = optsEnd(a, "--sdk", "--toolchain", "-sdk")
	case c == "flock":
		n = optsEnd(a, "-w", "-E", "--timeout", "--wait", "--conflict-exit-code") + 1
	case c == "sudo":
		n = optsEnd(a, "-u", "-g", "-p", "-C", "-D", "-h", "-R", "-T", "-U", "--user", "--group", "--prompt",
			"--close-from", "--chdir", "--host", "--role", "--type", "--other-user", "--command-timeout")
	case c == "nice":
		n = optsEnd(a, "-n", "--adjustment")
	case c == "timeout" || c == "gtimeout":
		n = optsEnd(a, "-s", "-k", "--signal", "--kill-after") + 1
	case c == "xargs":
		n = optsEnd(a, "-I", "-n", "-P", "-L", "-d", "-E", "-s", "-a", "--max-args", "--max-lines", "--max-procs",
			"--delimiter", "--max-chars", "--arg-file", "--process-slot-var")
	case c == "direnv" && at(a, 1) == "exec":
		n = 3
	case c == "nix" && (at(a, 1) == "develop" || at(a, 1) == "shell"):
		n = afterWord(a, "-c", "--command")
	case c == "nix" && at(a, 1) == "run":
		n = installable(a)
	case c == "find":
		n = afterWord(a, "-exec", "-execdir", "-ok", "-okdir")
	}
	return n
}

var shells = []string{"sh", "bash", "zsh", "dash"}

var shellC = regexp.MustCompile(`^-[A-Za-z]*c[A-Za-z]*$`)

func scriptOf(a []string) (string, bool) {
	switch c := base(at(a, 0)); {
	case c == "eval":
		return strings.Join(a[1:], " "), true
	// watch joins its words into a script for sh -c
	case c == "watch":
		return strings.Join(a[min(optsEnd(a, "-n", "--interval", "-q", "--equexit"), len(a)):], " "), true
	case c == "script":
		for i := 1; i < len(a); i++ {
			if shellC.MatchString(a[i]) || a[i] == "--command" {
				return at(a, i+1), i+1 < len(a)
			}
		}
	case c == "env":
		return optValue(a[1:min(optsEnd(a, "-u", "-C", "-S", "--unset", "--chdir", "--split-string"), len(a))], "-S", "--split-string")
	case c == "flock":
		return optValue(a[1:], "-c", "--command")
	case c == "nix-shell":
		return optValue(a[1:], "--run", "--command")
	case slices.Contains(shells, c):
		for i := 1; i < len(a); i++ {
			if shellC.MatchString(a[i]) {
				return at(a, i+1), i+1 < len(a)
			}
		}
	}
	return "", false
}

// a shell with no -c and no script file, or with -s, reads its script from standard input
func stdinShell(a []string) bool {
	if !slices.Contains(shells, base(at(a, 0))) {
		return false
	}
	if slices.ContainsFunc(a[1:], func(w string) bool { return w == "--version" || w == "--help" }) {
		return false
	}
	return slices.Contains(a, "-s") ||
		!slices.ContainsFunc(a[1:], func(w string) bool { return !strings.HasPrefix(w, "-") && !strings.HasPrefix(w, "+") })
}

// a here-string or heredoc is checked as the script. a pipe hides it
func (c *call) setScript() {
	if s, ok := scriptOf(c.argv); ok {
		c.script = &s
		return
	}
	if !stdinShell(c.argv) {
		return
	}
	var in []*string
	for _, r := range c.redirs {
		if r.op == "<<<" {
			in = append(in, &r.word)
		}
	}
	for _, r := range c.redirs {
		if r.op == "<<" || r.op == "<<-" {
			in = append(in, r.hdoc)
		}
	}
	if len(in) > 0 && in[0] != nil {
		c.script = in[0]
	} else {
		c.stdin = true
	}
}
