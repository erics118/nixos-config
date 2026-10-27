package main

import (
	"regexp"
	"slices"
	"sort"
	"strings"
)

var gitValueOpts = []string{"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--config-env"}

// gitOpts yields the words from each git global option on, since commit -C names a commit
func (c call) gitOpts() [][]string {
	var out [][]string
	a := c.args()
	for len(a) > 0 && strings.HasPrefix(a[0], "-") {
		out = append(out, a)
		a = skipGitOpt(a)
	}
	return out
}

func skipGitOpt(a []string) []string {
	if slices.Contains(gitValueOpts, a[0]) {
		return a[min(2, len(a)):]
	}
	return a[1:]
}

// gitArgs is the git subcommand and its words after the global options, or nil for any other call
func (c call) gitArgs() []string {
	if c.tool() != "git" {
		return nil
	}
	a := c.args()
	for len(a) > 0 && strings.HasPrefix(a[0], "-") {
		a = skipGitOpt(a)
	}
	if len(a) == 0 {
		return nil
	}
	return a
}

// repo is the directory git runs in: the call's dir, then each -C in turn, as git applies them. "" when unknown
func (c call) repo() string {
	d := c.dir
	for _, o := range c.gitOpts() {
		if o[0] == "-C" && len(o) > 1 {
			d = resolveIn(d, o[1])
		}
	}
	return d
}

// gitCommand is the git subcommand with a configured alias expanded, read from the call's repo.
// shell marks an alias that runs a shell command, which no check can see into
func (h *hook) gitCommand(c call) (g []string, shell bool) {
	g = c.gitArgs()
	dir := c.repo()
	if dir == "" {
		dir = h.cwd
	}
	// an alias can name another, but git refuses a loop, so a few rounds suffice
	for range 5 {
		if g == nil {
			return nil, false
		}
		key := dir + "\x00" + g[0]
		def, ok := h.aliases[key]
		if !ok {
			def = gitOut(dir, "config", "--get", "alias."+g[0])
			h.aliases[key] = def
		}
		if def == "" {
			return g, false
		}
		if strings.HasPrefix(def, "!") {
			return g, true
		}
		g = append(strings.Fields(def), g[1:]...)
	}
	return g, false
}

var (
	aliasKey  = regexp.MustCompile(`^(alias|include|includeif)\.`)
	aliasFlag = regexp.MustCompile(`^(-c|--config-env=)(alias|include|includeif)\.`)
	gitEnv    = regexp.MustCompile(`(^|[^A-Za-z0-9_])GIT_(CONFIG[A-Z0-9_]*|DIR|WORK_TREE)=`)
	configDir = regexp.MustCompile(`(^|[^A-Za-z0-9_])(XDG_CONFIG_HOME|HOME)=`)
)

// inlineAlias reports an alias, or an include that can define one, set with -c or --config-env
func (c call) inlineAlias() bool {
	if c.tool() != "git" {
		return false
	}
	a := c.argv
	for i := 1; i < len(a); i++ {
		if (a[i] == "-c" || a[i] == "--config-env") && aliasKey.MatchString(strings.ToLower(at(a, i+1))) {
			return true
		}
		if aliasFlag.MatchString(strings.ToLower(a[i])) {
			return true
		}
	}
	return false
}

// configOverride denies what can point git at a config the gates do not read: an inline alias or include,
// or a GIT_DIR, GIT_WORK_TREE, GIT_CONFIG*, XDG_CONFIG_HOME, or HOME assignment
func (h *hook) configOverride() decision {
	if h.anyCall(call.inlineAlias) {
		return deny("Agents never define git aliases or includes with -c or --config-env, since an alias can wrap push or commit.")
	}
	// XDG_CONFIG_HOME and HOME move git's config only in a command that runs git
	if gitEnv.MatchString(h.command) || (h.has("git") && configDir.MatchString(h.command)) {
		return deny("Agents never set GIT_DIR, GIT_WORK_TREE, GIT_CONFIG*, XDG_CONFIG_HOME, or HOME around git. Name the repo with git -C, and pass a config value with git -c key=value.")
	}
	return decision{}
}

var (
	gitDirFlag   = regexp.MustCompile(`^--(git-dir|work-tree)(=|$)`)
	worktreeFlag = regexp.MustCompile(`^(-c|--config-env=)core\.worktree`)
)

// gitElsewhere reports a repo git finds some way repo cannot follow:
// --git-dir, --work-tree, core.worktree, or find -execdir, which runs once per match
func (c call) gitElsewhere() bool {
	if c.tool() != "git" {
		return false
	}
	for _, o := range c.gitOpts() {
		if gitDirFlag.MatchString(o[0]) || worktreeFlag.MatchString(strings.ToLower(o[0])) ||
			((o[0] == "-c" || o[0] == "--config-env") && strings.HasPrefix(strings.ToLower(at(o, 1)), "core.worktree")) {
			return true
		}
	}
	return slices.Contains(c.prefix, "-execdir") || slices.Contains(c.prefix, "-okdir")
}

var gitValueFlags = []string{"-m", "-F", "-C", "-c", "-t", "-o", "--message", "--file", "--reuse-message", "--reedit-message",
	"--author", "--date", "--template", "--cleanup", "--fixup", "--squash", "--trailer", "--push-option", "--repo", "--receive-pack", "--exec"}

// gitDryRun reports a --dry-run, or push -n, that git reads as an option.
// after -- it is a path, and after an option that takes a value it is that value, such as a -m message
func gitDryRun(g []string) bool {
	end := slices.Index(g, "--")
	if end < 0 {
		end = len(g)
	}
	for i := 1; i < end; i++ {
		if (g[i] == "--dry-run" || (g[0] == "push" && g[i] == "-n")) && !slices.Contains(gitValueFlags, g[i-1]) {
			return true
		}
	}
	return false
}

// gateDirs returns the repos, sorted, where a git command meeting match runs, with aliases expanded.
// it denies when it cannot tell a repo, since the gate then cannot read that repo's setting
func (h *hook) gateDirs(match func([]string) bool) ([]string, decision) {
	seen := map[string]bool{}
	var dirs []string
	for _, c := range h.calls {
		g, shell := h.gitCommand(c)
		if shell {
			return nil, deny("A git alias here runs a shell command, which the guard cannot check. Run the command the alias stands for.")
		}
		if g == nil || !match(g) {
			continue
		}
		if c.gitElsewhere() {
			return nil, deny("A git commit or push here names its repo with --git-dir, --work-tree, core.worktree, or find -execdir, which the guard does not follow. Name the repo with git -C or cd.")
		}
		d := c.repo()
		if d == "" {
			return nil, deny("A git commit or push here runs in a repo the guard cannot tell, from a shell variable, a command substitution, or a cd in a branch, so it cannot read that repo's setting. Name the repo with a literal path in git -C or cd.")
		}
		if !seen[d] {
			seen[d] = true
			dirs = append(dirs, d)
		}
	}
	sort.Strings(dirs)
	return dirs, decision{}
}
