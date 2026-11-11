package main

import "regexp"

var (
	hooksPathKey = regexp.MustCompile(`^core\.hookspath$`)
	// .git/hooks, including worktree and submodule variants (.git/worktrees/<id>/hooks, .git/modules/<p>/hooks)
	gitHooksPath = regexp.MustCompile(`(?:^|[/=])\.git/(?:[^/\s]+/)*hooks/`)
	gitHooksName = regexp.MustCompile(`(?:^|[^\w.])(\.git/(?:[^/\s,()]+/)*hooks/[^\s,()]+)`)
	// .git/info/attributes holds the agent-verbatim and agent-generated opt-outs, so only the user edits it
	gitInfoAttrPath = regexp.MustCompile(`(?:^|[/=])\.git/(?:[^/\s]+/)*info/attributes$`)
)

const gitHookReason = "is under .git/hooks. Agents never add or change git hooks; the user owns them, and they run on commit and push."

var (
	isGitHook     = pathIs(gitHooksPath)
	isGitInfoAttr = pathIs(gitInfoAttrPath)
)

// block the ways an agent could bypass or repoint git's hooks: setting core.hooksPath, a write onto
// a hook under .git/hooks, or skipping the hooks git runs with --no-verify or commit -n
func blockHookBypass(h *hook) decision {
	for _, c := range h.calls {
		g := c.gitArgs()
		// setting core.hooksPath moves where git looks for hooks
		if setsConfigKey(g, hooksPathKey) {
			return deny("Only the user sets core.hooksPath. Repointing it moves git's hooks and bypasses the repo's pre-commit, commit-msg, and pre-push hooks.")
		}
		if skipsHooks(g) {
			return deny("Agents never skip git hooks with --no-verify or commit -n. The repo's pre-commit, commit-msg, pre-merge-commit, and pre-push hooks enforce its policy.")
		}
	}
	// a write landing on a file under .git/hooks is a new or changed hook
	if w, ok := writeOnto(h, isGitHook); ok {
		return deny(w.report(isGitHook) + " " + gitHookReason)
	}
	if _, ok := writeOnto(h, isGitInfoAttr); ok {
		return deny("Only the user edits .git/info/attributes; it holds the agent-verbatim and agent-generated opt-outs.")
	}
	if name, ok := namedByNonReader(h, gitHooksName, isGitHook); ok {
		return deny(name + " " + gitHookReason)
	}
	if scriptNames(h, gitHooksName) {
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
