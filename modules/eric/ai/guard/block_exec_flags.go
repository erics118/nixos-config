package main

import "slices"

// the options, by tool, that run a command or write a file. a short one also counts inside a cluster, as -Hx or -mo
var execOpts = map[string][]string{
	"fd":   {"-x", "-X", "--exec", "--exec-batch"},
	"rg":   {"--pre", "--hostname-bin"},
	"sort": {"-o", "--output", "--compress-program"},
	"tree": {"-o"},
}

// block the flags that turn an allowlisted read-only tool into a writer or a launcher.
// the agents approve fd, rg, sort, tree, uniq, git diff, and git log without asking, so these
// would run an arbitrary command or write a file with no prompt
func blockExecFlags(h *hook) decision {
	if h.anyCall(execFlag) {
		return deny("fd -x/--exec, rg --pre or --hostname-bin, sort -o or --compress-program, tree -o, uniq with an output file, and git diff/log/show --output run a command or write a file, which their read-only approval does not cover. Run the command or the write as its own step, such as a shell loop over the fd output.")
	}
	return decision{}
}

func execFlag(c call) bool {
	t := c.tool()
	if t == "uniq" {
		return len(c.parsed().operands) > 1
	}
	if flags, ok := execOpts[t]; ok {
		return c.parsed().has(flags...)
	}
	g := c.gitArgs()
	return slices.Contains([]string{"diff", "log", "show", "whatchanged"}, at(g, 0)) && parseArgs("git "+g[0], g[1:]).has("--output")
}
