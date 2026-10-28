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
	// each config command naming an eric-agent key, an alias, or an include must itself be a read
	for _, c := range h.calls {
		g := c.gitArgs()
		if at(g, 0) != "config" {
			continue
		}
		names := slices.ContainsFunc(g, func(w string) bool { return agentConfigKey.MatchString(strings.ToLower(w)) })
		reads := slices.ContainsFunc(g, func(w string) bool { return slices.Contains(configReads, w) }) ||
			at(g, 1) == "get" || at(g, 1) == "list"
		if names && !reads {
			return deny("Only the user sets eric-agent keys, git aliases, and git includes, since an alias or include can wrap push or commit.")
		}
	}
	// each write, as written or as the call's directory resolves it
	for _, w := range h.written() {
		if isGitConfig(w.word) || slices.ContainsFunc(w.paths, isGitConfig) {
			return deny(w.word + " " + gitConfigReason)
		}
	}
	// any other command naming a git config file, unless it only reads it. git config is the way to change one
	for _, c := range h.calls {
		if c.wrapper || c.tool() == "git" || slices.Contains(readers, c.tool()) {
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
	if slices.ContainsFunc(h.interpreterCalls(), func(c call) bool { return lineMatch(gitConfigName, strings.ToLower(c.scriptText())) }) {
		return deny("This script names a git config file. Change git config with `git config`, and read it with Read or `git config --list --show-origin`.")
	}
	return decision{}
}
