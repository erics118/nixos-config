package main

import (
	"path/filepath"
	"regexp"
	"slices"
	"strings"
)

var (
	hooksPathKey = regexp.MustCompile(`^core\.hookspath$`)
	// .git/hooks, including worktree and submodule variants (.git/worktrees/<id>/hooks, .git/modules/<p>/hooks)
	gitHooksPath = regexp.MustCompile(`(?:^|[/=])\.git/(?:[^/\s]+/)*hooks/`)
	gitHooksName = regexp.MustCompile(`(?:^|[^\w.])(\.git/(?:[^/\s,()]+/)*hooks/[^\s,()]+)`)
	// .git/info/attributes holds the agent-verbatim and agent-generated opt-outs, so only the user edits it
	gitInfoAttrPath = regexp.MustCompile(`(?:^|[/=])\.git/(?:[^/\s]+/)*info/attributes$`)
)

const gitHookReason = "is under .git/hooks. Agents never add or change git hooks; the user owns them, and they run on commit and push."

func isGitHook(p string) bool {
	return p != "" && lineMatch(gitHooksPath, strings.ToLower(filepath.Clean(p)))
}

func isGitInfoAttr(p string) bool {
	return p != "" && lineMatch(gitInfoAttrPath, strings.ToLower(filepath.Clean(p)))
}

// block the ways an agent could bypass or repoint git's hooks: setting core.hooksPath, a write onto
// a hook under .git/hooks, or skipping the hooks git runs with --no-verify or commit -n
func blockHookBypass(h *hook) decision {
	for _, c := range h.calls {
		g := c.gitArgs()
		// setting core.hooksPath moves where git looks for hooks. a read with --get, get, or list is fine
		if at(g, 0) == "config" {
			names := slices.ContainsFunc(g, func(w string) bool { return hooksPathKey.MatchString(strings.ToLower(w)) })
			reads := slices.ContainsFunc(g, func(w string) bool { return slices.Contains(configReads, w) }) ||
				at(g, 1) == "get" || at(g, 1) == "list"
			if names && !reads {
				return deny("Only the user sets core.hooksPath. Repointing it moves git's hooks and bypasses the repo's pre-commit, commit-msg, and pre-push hooks.")
			}
		}
		if skipsHooks(g) {
			return deny("Agents never skip git hooks with --no-verify or commit -n. The repo's pre-commit, commit-msg, pre-merge-commit, and pre-push hooks enforce its policy.")
		}
	}
	// a write landing on a file under .git/hooks is a new or changed hook
	for _, w := range h.written() {
		if isGitHook(w.word) || slices.ContainsFunc(w.paths, isGitHook) {
			return deny(w.report(isGitHook) + " " + gitHookReason)
		}
		if isGitInfoAttr(w.word) || slices.ContainsFunc(w.paths, isGitInfoAttr) {
			return deny("Only the user edits .git/info/attributes; it holds the agent-verbatim and agent-generated opt-outs.")
		}
	}
	// any other tool that names a hook path, unless it only reads it. a reader's writes are caught above
	for _, c := range h.calls {
		if c.wrapper || c.tool() == "git" || slices.Contains(readers, c.tool()) {
			continue
		}
		for _, w := range c.args() {
			if m := gitHooksName.FindStringSubmatch(strings.ToLower(w)); m != nil {
				return deny(m[1] + " " + gitHookReason)
			}
			if slices.ContainsFunc(h.paths(c, w), isGitHook) {
				return deny(w + " " + gitHookReason)
			}
		}
	}
	// a script, including a heredoc body, that writes under .git/hooks
	if slices.ContainsFunc(h.interpreterCalls(), func(c call) bool { return lineMatch(gitHooksName, strings.ToLower(c.scriptText())) }) {
		return deny("This script writes under .git/hooks. Agents never add or change git hooks.")
	}
	return decision{}
}

// skipsHooks reports a git command that skips the hooks git would run: --no-verify on commit, merge,
// pull, or push, and -n on commit, where it means --no-verify (-n is dry-run or no-stat elsewhere)
func skipsHooks(g []string) bool {
	switch at(g, 0) {
	case "commit":
		return parseArgs("git commit", g[1:]).has("--no-verify", "-n")
	case "merge", "pull", "push":
		return parseArgs("git "+g[0], g[1:]).has("--no-verify")
	}
	return false
}
