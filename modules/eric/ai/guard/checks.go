package main

import "slices"

// meta names a check and the tool calls it runs on, by Claude Code's tool names, which pi and Codex calls arrive under too
type meta struct {
	name  string
	tools []string
}

func (m meta) info() meta { return m }

// a pre check runs before a tool call and returns a decision. a check that panics denies
type preCheck struct {
	meta
	run func(*hook) decision
}

// a post check runs after a tool call and returns its message for the model and its exit code
type postCheck struct {
	meta
	run func(*hook) (string, int)
}

var (
	shellTools = []string{"Bash", "Monitor"}
	fileTools  = []string{"Write", "Edit"}
)

// preChecks run in this order: a deny wins at once, the first ask wins over later ones, and the last rewrite wins
var preChecks = []preCheck{
	{meta{"deny-symlink-path", []string{"Read", "Write", "Edit"}}, denySymlinkPath},
	{meta{"git-add-before-nix", shellTools}, gitAddBeforeNix},
	{meta{"strip-claude-attribution", shellTools}, stripClaudeAttribution},
	{meta{"block-global-search", shellTools}, blockGlobalSearch},
	{meta{"block-unresolved-write", shellTools}, blockUnresolvedWrite},
	{meta{"block-symlink-clobber", shellTools}, blockSymlinkClobber},
	{meta{"ask-dangerous-git", shellTools}, askDangerousGit},
	{meta{"ask-defaults-write", shellTools}, askDefaultsWrite},
	{meta{"block-agent-commit", shellTools}, blockAgentCommit},
	{meta{"block-agent-push", shellTools}, blockAgentPush},
	{meta{"block-gh-write", shellTools}, blockGhWrite},
	{meta{"block-smart-punct", append(slices.Clone(shellTools), fileTools...)}, blockSmartPunct},
	{meta{"block-git-config-edit", append(slices.Clone(shellTools), fileTools...)}, blockGitConfigEdit},
	{meta{"block-hook-bypass", append(slices.Clone(shellTools), fileTools...)}, blockHookBypass},
	{meta{"block-eric-top", append(slices.Clone(shellTools), fileTools...)}, blockEricTop},
	{meta{"block-shell-edit", shellTools}, blockShellEdit},
	{meta{"block-sudo-probe", shellTools}, blockSudoProbe},
	{meta{"block-exec-flags", shellTools}, blockExecFlags},
	{meta{"block-rm", shellTools}, blockRm},
	{meta{"block-mux-kill", shellTools}, blockMuxKill},
	{meta{"block-pipe-head-tail", shellTools}, blockPipeHeadTail},
	{meta{"block-write-tracked", []string{"Write"}}, blockWriteTracked},
}

var postChecks = []postCheck{
	{meta{"treefmt-on-edit", fileTools}, treefmtOnEdit},
	{meta{"warn-comment-block", fileTools}, warnCommentBlock},
}

// toolsOf is every tool some check runs on, once each and sorted, which the hook matchers must name
func toolsOf[C interface{ info() meta }](checks []C) []string {
	var tools []string
	for _, c := range checks {
		tools = append(tools, c.info().tools...)
	}
	slices.Sort(tools)
	return slices.Compact(tools)
}

// pick returns the checks named, in that order, or every check that runs on tool when none are.
// missing is a name no check has
func pick[C interface{ info() meta }](checks []C, tool string, names []string) (picked []C, missing string) {
	if len(names) == 0 {
		for _, c := range checks {
			if slices.Contains(c.info().tools, tool) {
				picked = append(picked, c)
			}
		}
		return picked, ""
	}
	for _, n := range names {
		i := slices.IndexFunc(checks, func(c C) bool { return c.info().name == n })
		if i < 0 {
			return nil, n
		}
		picked = append(picked, checks[i])
	}
	return picked, ""
}
