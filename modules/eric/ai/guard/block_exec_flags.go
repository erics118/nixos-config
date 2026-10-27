package main

import (
	"regexp"
	"slices"
	"strings"
)

var (
	sortOutput = regexp.MustCompile(`^-[bdfghiMnRrsuVcCz]*o`)
	// fd's exec flag alone or after its boolean flags, as in -Hx. -tx is a type filter, since -t takes a value
	fdExec = regexp.MustCompile(`^-[HIsigFalLup0q]*[xX]$`)
)

// block the flags that turn an allowlisted read-only tool into a writer or a launcher.
// the agents approve fd, rg, sort, tree, git diff, and git log without asking, so these
// would run an arbitrary command or write a file with no prompt
func blockExecFlags(h *hook) decision {
	if h.anyCall(execFlag) {
		return deny("fd -x/--exec, rg --pre, sort -o, tree -o, and git diff/log/show --output run a command or write a file, which their read-only approval does not cover. Run the command or the write as its own step, such as a shell loop over the fd output.")
	}
	return decision{}
}

func execFlag(c call) bool {
	a := c.args()
	hasArg := func(f func(string) bool) bool { return slices.ContainsFunc(a, f) }
	switch c.tool() {
	case "fd":
		return hasArg(func(w string) bool { return fdExec.MatchString(w) || strings.HasPrefix(w, "--exec") })
	case "rg":
		return hasArg(func(w string) bool { return w == "--pre" || strings.HasPrefix(w, "--pre=") })
	case "sort":
		return hasArg(func(w string) bool {
			return sortOutput.MatchString(w) || w == "--output" || strings.HasPrefix(w, "--output=")
		})
	case "tree":
		return slices.Contains(a, "-o")
	}
	g := c.gitArgs()
	if g == nil || !slices.Contains([]string{"diff", "log", "show", "whatchanged"}, g[0]) {
		return false
	}
	end := slices.Index(g, "--")
	if end < 0 {
		end = len(g)
	}
	return slices.ContainsFunc(g[:end], func(w string) bool { return w == "--output" || strings.HasPrefix(w, "--output=") })
}
