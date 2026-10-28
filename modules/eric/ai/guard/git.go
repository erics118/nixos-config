package main

import (
	"cmp"
	"maps"
	"regexp"
	"slices"
	"strings"

	"mvdan.cc/sh/v3/syntax"
)

// gitGlobals is git's global options, before its subcommand
func (c call) gitGlobals() args {
	if c.tool() != "git" {
		return args{}
	}
	return leadingArgs("git", c.args())
}

// gitArgs is the git subcommand and its words after the global options, or nil for any other call
func (c call) gitArgs() []string {
	if g := c.gitGlobals().operands; len(g) > 0 {
		return g
	}
	return nil
}

// a gitSetting is one -c or --config-env setting before git's subcommand. fromEnv marks --config-env,
// whose value names a variable to read
type gitSetting struct {
	key, value string
	fromEnv    bool
}

func (c call) gitSettings() []gitSetting {
	var out []gitSetting
	for _, o := range c.gitGlobals().opts {
		if (o.name == "-c" || o.name == "--config-env") && len(o.values) > 0 {
			key, value, _ := strings.Cut(o.values[0], "=")
			out = append(out, gitSetting{strings.ToLower(key), value, o.name == "--config-env"})
		}
	}
	return out
}

// repo is the directory git runs in: the call's dir, then each -C in turn, as git applies them. "" when unknown
func (c call) repo() string {
	d := c.dir
	for _, o := range c.gitGlobals().opts {
		if o.name == "-C" && len(o.values) > 0 {
			d = resolveIn(d, o.values[0])
		}
	}
	return d
}

// expandAlias rewrites a git call whose subcommand is an alias in the call's repo into the command it stands for.
// it returns any shell code that runs and where: a shell alias's code at the top of the repo,
// or the script the expanded command runs, such as difftool -x's
func (h *hook) expandAlias(c *call) (script, dir string) {
	dir = c.repo()
	if g := c.gitArgs(); dir == "" && g != nil && !h.gitCommand(g[0]) {
		c.hidden = hiddenAlias
		return "", ""
	}
	expanded := false
	for rounds := 0; ; rounds++ {
		g := c.gitArgs()
		if g == nil || dir == "" {
			break
		}
		key := dir + "\x00" + g[0]
		def, ok := h.aliases[key]
		if !ok {
			def = gitOut(dir, "config", "--get", "alias."+g[0])
			h.aliases[key] = def
		}
		if def == "" {
			break
		}
		// an alias can name another, and a chain longer than this is not followed
		if rounds == maxAliases {
			c.hidden = hiddenAlias
			return "", ""
		}
		if body, ok := strings.CutPrefix(def, "!"); ok {
			quoted := []string{body}
			for _, w := range g[1:] {
				quoted = append(quoted, shellQuote(w))
			}
			return strings.Join(quoted, " "), cmp.Or(gitOut(dir, "rev-parse", "--show-toplevel"), dir)
		}
		words, ok := aliasWords(def)
		if !ok {
			c.hidden = hiddenAlias
			return "", ""
		}
		globals := c.argv[:len(c.argv)-len(g)]
		c.argv = slices.Concat(globals, words, g[1:])
		c.dyn = make([]bool, len(c.argv))
		c.spans = nil
		expanded = true
	}
	if s, ok := scriptOf(c.argv); ok && expanded {
		return s, dir
	}
	return "", ""
}

// gitCommand reports a git subcommand that is a command, built in or a git-* program, rather than an alias
func (h *hook) gitCommand(name string) bool {
	if h.gitCommands == nil {
		h.gitCommands = strings.Fields(gitOut(h.cwd, "--list-cmds=main,others"))
	}
	return slices.Contains(h.gitCommands, name)
}

// aliasWords splits an alias's text into words as git does, with shell quoting.
// text that is more than one plain command, or has a value the guard cannot know, does not split
func aliasWords(def string) ([]string, bool) {
	f, err := parser.Parse(strings.NewReader(def), "")
	if err != nil || len(f.Stmts) != 1 {
		return nil, false
	}
	ce, ok := f.Stmts[0].Cmd.(*syntax.CallExpr)
	if !ok || len(ce.Assigns) > 0 || len(f.Stmts[0].Redirs) > 0 {
		return nil, false
	}
	st := newState("")
	var out []string
	for _, a := range ce.Args {
		if st.dynamic(a) {
			return nil, false
		}
		out = append(out, st.fields(a)...)
	}
	return out, true
}

const maxAliases = 5

func shellQuote(s string) string { return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'" }

var (
	aliasKey = regexp.MustCompile(`^(alias|include|includeif)\.`)
	// variables that point git at another repo, index, object store, or config
	gitEnv = regexp.MustCompile(`^GIT_(CONFIG[A-Z0-9_]*|DIR|WORK_TREE|COMMON_DIR|INDEX_FILE|OBJECT_DIRECTORY|ALTERNATE_OBJECT_DIRECTORIES|NAMESPACE)$`)
)

// inlineAlias reports an alias, or an include that can define one, set with -c or --config-env
func (c call) inlineAlias() bool {
	return slices.ContainsFunc(c.gitSettings(), func(s gitSetting) bool { return aliasKey.MatchString(s.key) })
}

// configOverride denies what can point git at a repo or config the gates do not read: an inline alias or include,
// or an assignment anywhere in the command to a gitEnv variable, or to XDG_CONFIG_HOME or HOME in a command that runs git
func (h *hook) configOverride() decision {
	if h.anyCall(call.inlineAlias) {
		return deny("Agents never define git aliases or includes with -c or --config-env, since an alias can wrap push or commit.")
	}
	if h.anyCall(func(c call) bool {
		return slices.ContainsFunc(c.env, func(kv string) bool {
			name, _, _ := strings.Cut(kv, "=")
			return gitEnv.MatchString(name) || ((name == "XDG_CONFIG_HOME" || name == "HOME") && h.has("git"))
		})
	}) {
		return deny("Agents never set GIT_DIR, GIT_WORK_TREE, GIT_COMMON_DIR, GIT_INDEX_FILE, GIT_CONFIG*, XDG_CONFIG_HOME, or HOME around git. Name the repo with git -C, and pass a config value with git -c key=value.")
	}
	return decision{}
}

// gitElsewhere reports a repo git finds some way repo cannot follow:
// --git-dir, --work-tree, core.worktree, or find -execdir, which runs once per match
func (c call) gitElsewhere() bool {
	return c.gitGlobals().has("--git-dir", "--work-tree") ||
		slices.ContainsFunc(c.gitSettings(), func(s gitSetting) bool { return s.key == "core.worktree" }) ||
		slices.Contains(c.prefix, "-execdir") || slices.Contains(c.prefix, "-okdir")
}

// gitDryRun reports a --dry-run, or push -n, that git reads as an option.
// after -- it is a path, and after an option that takes a value it is that value, such as a -m message
func gitDryRun(g []string) bool {
	p := parseArgs("git "+g[0], g[1:])
	return p.has("--dry-run") || (g[0] == "push" && p.has("-n"))
}

// agents name their throwaway branches, sessions, and panes with this prefix
const agentTest = "agent-test-"

// gate reads eric-agent.<key> in each repo: on allows, ask asks for approval, and modes decides any other setting,
// such as branch for commits. a setting modes does not know, unset or off included, denies with off
func gate(key string, repos map[string][][]string, modes map[string]func(dir string, cmds [][]string) decision, off, approve string) decision {
	asks := false
	for _, dir := range slices.Sorted(maps.Keys(repos)) {
		switch mode := gitOut(dir, "config", "--get", "eric-agent."+key); mode {
		case "on":
		case "ask":
			asks = true
		default:
			decide, ok := modes[mode]
			if !ok {
				return deny(off)
			}
			if d := decide(dir, repos[dir]); d.kind != "" {
				return d
			}
		}
	}
	if asks {
		return ask(approve)
	}
	return decision{}
}

// gateRepos maps each repo where a git command meeting match runs to those commands.
// it denies when it cannot tell a repo, since the gate then cannot read that repo's setting
func (h *hook) gateRepos(match func([]string) bool) (map[string][][]string, decision) {
	repos := map[string][][]string{}
	for _, c := range h.calls {
		g := c.gitArgs()
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
		repos[d] = append(repos[d], g)
	}
	return repos, decision{}
}
