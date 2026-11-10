package main

import (
	"path/filepath"
	"slices"
	"strings"
)

// worktrees follow the global instructions: new-worktree.sh makes them under the main repo's .eric/worktrees, and a remove
// takes --force only for submodules, so git's own refusal of a dirty or locked worktree stands
func blockWorktree(h *hook) decision {
	for _, c := range h.calls {
		g := c.gitArgs()
		if at(g, 0) != "worktree" {
			continue
		}
		p := parseArgs("git worktree "+at(g, 1), g[2:])
		target := at(p.operands, 0)
		if target == "" {
			continue
		}
		paths := h.paths(c, target)
		switch at(g, 1) {
		case "add":
			if !slices.ContainsFunc(paths, inEricWorktrees) {
				return deny("Make a worktree with ~/.agents/bin/new-worktree.sh <branch> [base], which puts it under the main repo's .eric/worktrees/, then enter it with EnterWorktree.")
			}
		case "remove":
			if p.has("-f", "--force") && !slices.ContainsFunc(paths, func(d string) bool { return exists(filepath.Join(d, ".gitmodules")) }) {
				return deny("Remove a worktree with plain git worktree remove, which refuses a dirty or locked one. --force is only for a worktree with submodules. Tell the user what blocks the remove.")
			}
		}
	}
	return decision{}
}

func inEricWorktrees(p string) bool {
	return strings.Contains(filepath.Clean(p)+"/", "/.eric/worktrees/")
}

// claude's own worktree isolation puts an agent under .claude/worktrees, outside the .eric rules
func blockAgentWorktree(h *hook) decision {
	if h.str("isolation") == "worktree" {
		return deny("Agents never use isolation: worktree. Make the worktree with ~/.agents/bin/new-worktree.sh and give the agent its path in the prompt.")
	}
	return decision{}
}
