package main

import "slices"

// prompt before git commands that rewrite history or discard uncommitted work.
// asks rather than denies, so anything genuinely wanted is one confirmation away
func askDangerousGit(h *hook) decision {
	for _, c := range h.calls {
		// gh pr checkout --force runs git reset --hard onto the pr head
		forcedCheckout := c.tool() == "gh" && at(c.argv, 1) == "pr" && at(c.argv, 2) == "checkout" &&
			parseArgs("gh pr checkout", c.argv[3:]).has("-f", "--force")
		isPath := func(w string) bool { return slices.ContainsFunc(h.paths(c, w), exists) }
		if g := c.gitArgs(); forcedCheckout || (g != nil && dangerousGit(g, isPath)) {
			return ask("This git command rewrites history or discards uncommitted work. Approve it, or run it yourself.")
		}
	}
	return decision{}
}

// dangerousGit reports a git command that rewrites history or discards work. isPath tells a path from a commit or branch
func dangerousGit(g []string, isPath func(string) bool) bool {
	p := parseArgs("git "+g[0], g[1:])
	notPath := func(w string) bool { return !isPath(w) }
	switch g[0] {
	case "filter-branch":
		return true
	// replace makes history read as other commits, and -d takes that back
	case "replace":
		return !p.has("-l", "--list")
	case "rebase":
		return !p.has("--continue", "--abort", "--quit")
	// a reset moves the branch when it names a commit. one that only unstages names paths, or nothing
	case "reset":
		return p.has("--hard", "--merge", "--keep", "--soft") || (len(p.pathspecs) == 0 && slices.ContainsFunc(p.operands, notPath))
	case "reflog":
		return at(g, 1) == "expire"
	// clean deletes without -f where clean.requireForce is off, and -i deletes what the user picks
	case "clean":
		return !p.has("-n", "--dry-run")
	case "stash":
		return at(g, 1) == "drop" || at(g, 1) == "clear"
	// a checkout of a path, named after -- or existing, discards its changes
	case "checkout":
		return p.has("-f", "-B", "--force") || len(p.pathspecs) > 0 || slices.ContainsFunc(p.operands, isPath)
	case "switch":
		return p.has("-f", "-C", "--force", "--force-create", "--discard-changes")
	case "worktree":
		return at(g, 1) == "remove" && p.has("-f", "--force")
	case "branch":
		return p.has("-D") || (p.has("-d", "--delete") && p.has("-f", "--force"))
	// restore discards worktree changes unless it only unstages with --staged and no --worktree
	case "restore":
		return !p.has("-S", "--staged") || p.has("-W", "--worktree")
	}
	return false
}
