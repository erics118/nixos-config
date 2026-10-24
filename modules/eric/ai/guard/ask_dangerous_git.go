package main

import (
	"regexp"
	"slices"
	"strings"
)

// prompt before git commands that rewrite history or discard uncommitted work.
// asks rather than denies, so anything genuinely wanted is one confirmation away
func askDangerousGit(h *hook) decision {
	for _, c := range h.calls {
		// gh pr checkout --force runs git reset --hard onto the pr head
		forcedCheckout := c.tool() == "gh" && at(c.argv, 1) == "pr" && at(c.argv, 2) == "checkout" &&
			slices.ContainsFunc(c.argv[3:], func(a string) bool { return forceFlag.MatchString(a) || a == "--force" })
		if g, shell := h.gitCommand(c); shell || forcedCheckout || (g != nil && dangerousGit(g)) {
			return ask("This git command rewrites history or discards uncommitted work. Approve it, or run it yourself.")
		}
	}
	return decision{}
}

var (
	forceFlag    = regexp.MustCompile(`^-[a-zA-Z]*f`)
	stagedFlag   = regexp.MustCompile(`^-[a-zA-Z]*S`)
	restoreWFlag = regexp.MustCompile(`^-[a-zA-Z]*W`)
)

func dangerousGit(g []string) bool {
	args := g[1:]
	has := func(xs ...string) bool {
		return slices.ContainsFunc(args, func(a string) bool { return slices.Contains(xs, a) })
	}
	switch g[0] {
	case "filter-branch":
		return true
	case "rebase":
		return !has("--continue", "--abort", "--quit")
	case "reset":
		// a reset that only unstages, with no args or with paths after --, moves no branch
		return has("--hard", "--merge", "--keep", "--soft") ||
			(!slices.Contains(g, "--") && slices.ContainsFunc(args, func(a string) bool { return !strings.HasPrefix(a, "-") }))
	case "reflog":
		return at(g, 1) == "expire"
	case "clean":
		return slices.ContainsFunc(args, func(a string) bool { return forceFlag.MatchString(a) || a == "--force" })
	case "stash":
		return at(g, 1) == "drop" || at(g, 1) == "clear"
	case "checkout":
		i := slices.Index(args, "--")
		return has("-f", "-B", "--force", ".") || (i >= 0 && i < len(args)-1)
	case "switch":
		return has("-f", "-C", "--force", "--force-create", "--discard-changes")
	case "worktree":
		return at(g, 1) == "remove" && has("-f", "--force")
	case "branch":
		return has("-D") || (has("-d", "--delete") && has("-f", "--force"))
	case "restore":
		// restore discards worktree changes unless it only unstages with --staged and no --worktree
		staged := slices.ContainsFunc(args, func(a string) bool { return a == "--staged" || stagedFlag.MatchString(a) })
		worktree := slices.ContainsFunc(args, func(a string) bool { return a == "--worktree" || restoreWFlag.MatchString(a) })
		return !staged || worktree
	}
	return false
}
