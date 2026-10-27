package main

import (
	"regexp"
	"slices"
	"strings"
)

var (
	agentConfigKey = regexp.MustCompile(`eric-agent|^(alias|include|includeif)\.|^(-e|--edit|edit)$`)
	configReads    = []string{"--get", "--get-all", "--get-regexp", "--get-urlmatch", "-l", "--list"}
)

// gate agent commits on `git config eric-agent.commit`: off (default), ask, branch (not main or master), or on.
// only the user sets eric-agent keys, so agents may not write them
func blockAgentCommit(h *hook) decision {
	// each config command naming an eric-agent key, an alias, or an include must itself be a read
	for _, c := range h.calls {
		g := c.gitArgs()
		if g == nil || g[0] != "config" {
			continue
		}
		names := slices.ContainsFunc(g, func(w string) bool { return agentConfigKey.MatchString(strings.ToLower(w)) })
		reads := slices.ContainsFunc(g, func(w string) bool { return slices.Contains(configReads, w) }) ||
			at(g, 1) == "get" || at(g, 1) == "list"
		if names && !reads {
			return deny("Only the user sets eric-agent keys, git aliases, and git includes, since an alias or include can wrap push or commit.")
		}
	}
	if d := h.configOverride(); d.kind != "" {
		return d
	}

	// pull commits unless it only fast-forwards. --abort and --quit only back out, and a rebase's
	// --edit-todo and --show-current-patch only look. update-ref moves a branch onto any commit
	dirs, d := h.gateDirs(func(g []string) bool {
		commits := slices.Contains([]string{"commit", "commit-tree", "update-ref", "merge", "revert", "cherry-pick", "am", "rebase", "subtree"}, g[0]) ||
			(g[0] == "pull" && !slices.Contains(g, "--ff-only"))
		backsOut := slices.Contains([]string{"merge", "revert", "cherry-pick", "am", "rebase"}, g[0]) &&
			slices.ContainsFunc(g, func(w string) bool {
				return w == "--abort" || w == "--quit" || w == "--edit-todo" || w == "--show-current-patch"
			})
		return commits && !backsOut && !(g[0] == "commit" && gitDryRun(g))
	})
	if d.kind != "" {
		return d
	}
	asks := false
	for _, dir := range dirs {
		switch gitOut(dir, "config", "--get", "eric-agent.commit") {
		case "on":
		case "branch":
			switch gitOut(dir, "symbolic-ref", "--short", "-q", "HEAD") {
			case "main", "master", "":
				return deny("Agent commits are allowed only on a feature branch in this repo. Create one, or tell the user the work is ready.")
			}
		case "ask":
			asks = true
		default:
			return deny("Agent commits are off in this repo. Tell the user the work is ready so they commit it.")
		}
	}
	if asks {
		return ask("Agent commits need approval in this repo. Approve this commit, or deny it and commit yourself.")
	}
	return decision{}
}
