package main

import (
	"path/filepath"
	"regexp"
	"slices"
	"strings"
)

// .git/config, config or config.worktree under .git/worktrees or .git/modules, the global ~/.gitconfig,
// and git/config under any XDG config dir. paths are matched cleaned and lowercased, since macOS ignores case
var (
	gitConfigPath = regexp.MustCompile(`(?:^|[/=])(?:\.git/(?:[^/\s]+/)*config(?:\.worktree)?|\.gitconfig|git/config)$`)
	gitConfigName = regexp.MustCompile(`(?:^|[^\w.])(\.git/(?:[^/\s,()]+/)*config(?:\.worktree)?|\.gitconfig|\.config/git/config)\b`)
)

const gitConfigReason = "is a git config file. Change git config with `git config`, and read it with Read or `git config --list --show-origin`."

func isGitConfig(p string) bool {
	return p != "" && lineMatch(gitConfigPath, strings.ToLower(filepath.Clean(p)))
}

// block direct writes to a repo's git config files, so config changes go through `git config`,
// where block-agent-commit keeps agents from setting the eric-agent keys
func blockGitConfigEdit(h *hook) decision {
	if f := h.str("file_path"); f != "" {
		if isGitConfig(f) {
			return deny(f + " " + gitConfigReason)
		}
		return decision{}
	}
	if h.command == "" {
		return decision{}
	}
	// ... > file, ... >> file, or tee file, as written or as the call's directory resolves it
	for _, c := range h.calls {
		for _, w := range c.writes() {
			if isGitConfig(w) || slices.ContainsFunc(h.paths(c, w), isGitConfig) {
				return deny(w + " " + gitConfigReason)
			}
		}
	}
	// any other command naming a git config file, unless it only reads it. git config is the way to change one
	for _, c := range h.calls {
		if c.wrapper || c.tool() == "git" || (slices.Contains(textTools, c.tool()) && !c.inPlaceEdit()) {
			continue
		}
		for _, w := range c.args() {
			if m := gitConfigName.FindStringSubmatch(strings.ToLower(w)); m != nil {
				return deny(m[1] + " " + gitConfigReason)
			}
			if slices.ContainsFunc(h.paths(c, w), isGitConfig) {
				return deny(w + " " + gitConfigReason)
			}
		}
	}
	// a script, including a heredoc body, that names a git config file
	if _, ok := h.interpreter(); ok && lineMatch(gitConfigName, strings.ToLower(h.scriptText())) {
		return deny("This script names a git config file. Change git config with `git config`, and read it with Read or `git config --list --show-origin`.")
	}
	return decision{}
}
