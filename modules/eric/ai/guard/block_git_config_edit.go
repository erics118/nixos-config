package main

import "regexp"

// .git/config, config or config.worktree under .git/worktrees or .git/modules, the global ~/.gitconfig,
// and git/config under any XDG config dir. paths are matched cleaned and lowercased, since macOS ignores case
var (
	gitConfigPath = regexp.MustCompile(`(?:^|[/=])(?:\.git/(?:[^/\s]+/)*config(?:\.worktree)?|\.gitconfig|git/config)$`)
	gitConfigName = regexp.MustCompile(`(?:^|[^\w.])(\.git/(?:[^/\s,()]+/)*config(?:\.worktree)?|\.gitconfig|\.config/git/config)\b`)
)

const gitConfigReason = "is a git config file. Change git config with `git config`, and read it with Read or `git config --list --show-origin`."

var isGitConfig = pathIs(gitConfigPath)

// readers write only what written() sees, such as a redirect or awk's print > "file". any other tool that names
// a git config file is denied, so an unknown writer is too
var readers = []string{"rg", "grep", "echo", "printf", "cat", "head", "tail", "less", "bat", "wc", "diff", "ls", "file", "sed", "awk",
	"fd", "find", "stat", "jq"}

var (
	agentConfigKey = regexp.MustCompile(`eric-agent|^(alias|include|includeif)\.|^(-e|--edit|edit)$`)
	configReads    = []string{"--get", "--get-all", "--get-regexp", "--get-urlmatch", "-l", "--list"}
)

// block direct writes to a repo's git config files, so config changes go through `git config`,
// and keep git config itself from setting eric-agent keys, aliases, or includes, which only the user sets
func blockGitConfigEdit(h *hook) decision {
	for _, c := range h.calls {
		if setsConfigKey(c.gitArgs(), agentConfigKey) {
			return deny("Only the user sets eric-agent keys, git aliases, and git includes, since an alias or include can wrap push or commit.")
		}
	}
	if w, ok := writeOnto(h, isGitConfig); ok {
		return deny(w.report(isGitConfig) + " " + gitConfigReason)
	}
	// git config is the way to change one
	if name, ok := namedByNonReader(h, gitConfigName, isGitConfig); ok {
		return deny(name + " " + gitConfigReason)
	}
	if scriptNames(h, gitConfigName) {
		return deny("This script names a git config file. Change git config with `git config`, and read it with Read or `git config --list --show-origin`.")
	}
	return decision{}
}
