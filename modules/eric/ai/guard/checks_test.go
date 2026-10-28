package main

import (
	"bytes"
	"cmp"
	"encoding/json"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"testing"
	"time"
)

// fixture is a repo laid out the way the checks' cases expect
type fixture struct {
	t *testing.T
	// repo is the repo root as the harness reports it, real is it with symlinks resolved
	repo, real, home string
}

func newFixture(t *testing.T) *fixture {
	repo := t.TempDir()
	real, err := filepath.EvalSymlinks(repo)
	if err != nil {
		t.Fatal(err)
	}
	// deny-symlink-path only denies links that resolve under its approved roots, such as $HOME/nixos-config
	f := &fixture{t: t, repo: repo, real: real, home: real + "/home"}
	f.write("tracked.txt", "tracked\n")
	f.write("blob.png", "a\x00b")
	f.git(".", "init", "-q")
	f.git(".", "add", "tracked.txt", "blob.png")
	f.git(".", "-c", "commit.gpgsign=false", "-c", "user.name=test", "-c", "user.email=test@example.invalid", "commit", "-qm", "initial")
	f.write("flake.nix", "flake\n")
	f.write("untracked.nix", "module\n")
	f.write("comments.ts", "code\n// one\n// two\n// three\n// four\n")
	f.write("comments.lua", "code\n-- one\n-- two\n-- three\n-- four\n")
	f.write("header.sh", "#!/usr/bin/env bash\n# one\n# two\n# three\n# four\ncode\n")
	f.write("home/nixos-config/managed.txt", "managed\n")
	f.link("managed-link")
	// block-sudo-probe only acts on macOS, so this shim keeps its cases live on linux
	f.write("bin/uname", "#!/bin/sh\necho Darwin\n")
	// jb's recipes are judged by what their dry run calls, not by their names
	f.write("jb/flake.nix", "flake\n")
	f.write("jb/justfile", "build:\n    latexmk -pdf resume.tex\n\nswitch: build\n    nix build .\n")
	f.git("jb", "init", "-q")
	f.git("jb", "add", "flake.nix", "justfile")
	f.write("jb/new.tex", "new\n")
	f.write("sub/flake.nix", "flake\n")
	f.git("sub", "init", "-q")
	f.git("sub", "add", "flake.nix")
	f.write("sub/new.lua", "new\n")
	return f
}

func (f *fixture) write(rel, content string) {
	f.t.Helper()
	path := filepath.Join(f.repo, rel)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		f.t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o755); err != nil {
		f.t.Fatal(err)
	}
}

// link points rel at the managed file in the fake home
func (f *fixture) link(rel string) {
	f.t.Helper()
	if err := os.Symlink(f.home+"/nixos-config/managed.txt", filepath.Join(f.repo, rel)); err != nil {
		f.t.Fatal(err)
	}
}

func (f *fixture) git(dir string, args ...string) {
	f.t.Helper()
	if out, err := exec.Command("git", append([]string{"-C", filepath.Join(f.repo, dir)}, args...)...).CombinedOutput(); err != nil {
		f.t.Fatalf("git %v: %v\n%s", args, err, out)
	}
}

func (f *fixture) expand(s string) string {
	return strings.NewReplacer("{repo}", f.repo, "{home}", f.home, "{real}", f.real, "{path}", os.Getenv("PATH")).Replace(s)
}

type outcome struct {
	empty   bool
	kind    string
	reason  string
	command *string
}

func runPreHook(t *testing.T, harness string, input any, checks ...string) outcome {
	t.Helper()
	raw, _ := json.Marshal(input)
	var out bytes.Buffer
	if code := run(append([]string{"pre", harness}, checks...), bytes.NewReader(raw), &out, io.Discard); code != 0 {
		t.Fatalf("%v: exit %d", checks, code)
	}
	if out.Len() == 0 {
		return outcome{empty: true}
	}
	var d struct {
		HookSpecificOutput struct {
			PermissionDecision       string `json:"permissionDecision"`
			PermissionDecisionReason string `json:"permissionDecisionReason"`
			UpdatedInput             struct {
				Command *string `json:"command"`
			} `json:"updatedInput"`
		} `json:"hookSpecificOutput"`
	}
	if err := json.Unmarshal(out.Bytes(), &d); err != nil {
		t.Fatalf("output %q: %v", out.String(), err)
	}
	o := d.HookSpecificOutput
	return outcome{kind: o.PermissionDecision, reason: o.PermissionDecisionReason, command: o.UpdatedInput.Command}
}

func cmdInput(dir, cmd string) map[string]any {
	return map[string]any{"cwd": dir, "tool_input": map[string]any{"command": cmd}}
}

// group is commands or files that one check judges the same way in one fixture state
type group struct {
	// setup changes the fresh fixture first, such as setting eric-agent keys
	setup   func(f *fixture)
	env     map[string]string
	harness string
	// dir is where the commands run, relative to the repo
	dir string
	// want is deny, ask, or allow for a pre check, where allow means it printed nothing,
	// and warn or quiet for a post check
	want string
	// reason is text the decision's reason must hold
	reason string
	cmds   []string
	// files are paths a Write sends with content, or an Edit sends with edits
	files   []string
	content string
	edits   string
}

// groups run one at a time, since the walk's parser is shared
func (g group) run(t *testing.T, check string, post bool) {
	f := newFixture(t)
	for k, v := range g.env {
		t.Setenv(k, f.expand(v))
	}
	if g.setup != nil {
		g.setup(f)
	}
	harness := cmp.Or(g.harness, "claude")
	var inputs []any
	for _, c := range g.cmds {
		in := cmdInput(filepath.Join(f.repo, g.dir), f.expand(c))
		in["tool_name"] = "Bash"
		inputs = append(inputs, in)
	}
	for _, p := range g.files {
		tool, in := "Write", map[string]any{"command": "", "file_path": filepath.Join(f.repo, f.expand(p)), "content": g.content}
		if g.edits != "" {
			tool, in = "Edit", map[string]any{"file_path": in["file_path"], "edits": []any{map[string]any{"new_string": g.edits}}}
		}
		inputs = append(inputs, map[string]any{"cwd": f.repo, "tool_name": tool, "tool_input": in})
	}
	// the cases name the check, which skips routing, so each tool must also route to it
	for _, in := range inputs {
		tool := in.(map[string]any)["tool_name"].(string)
		ok := routes(preChecks, tool, check)
		if post {
			ok = routes(postChecks, tool, check)
		}
		if !ok {
			t.Errorf("%s does not run on %s", check, tool)
		}
	}
	for _, in := range inputs {
		name, _ := json.Marshal(in.(map[string]any)["tool_input"])
		if post {
			raw, _ := json.Marshal(in)
			var stdout, stderr bytes.Buffer
			code := run([]string{"post", harness, check}, bytes.NewReader(raw), &stdout, &stderr)
			got := "quiet"
			if code == 2 && stderr.Len() > 0 {
				got = "warn"
			} else if code != 0 || stdout.Len() > 0 {
				got = "failed"
			}
			if got != g.want {
				t.Errorf("%s: got %s (exit %d, %q), want %s", name, got, code, stderr.String(), g.want)
			}
			continue
		}
		o := runPreHook(t, harness, in, check)
		got := o.kind
		if o.empty {
			got = "allow"
		}
		if got != g.want || !strings.Contains(o.reason, g.reason) {
			t.Errorf("%s: got %s (%s), want %s with %q", name, got, o.reason, g.want, g.reason)
		}
	}
}

func routes[C interface{ info() meta }](checks []C, tool, name string) bool {
	picked, _ := pick(checks, tool, nil)
	return slices.ContainsFunc(picked, func(c C) bool { return c.info().name == name })
}

func config(dir string, kv ...string) func(f *fixture) {
	return func(f *fixture) {
		for i := 0; i < len(kv); i += 2 {
			f.git(dir, "config", kv[i], kv[i+1])
		}
	}
}

// midRebase leaves the repo as an interrupted rebase of branch leaves it: HEAD detached, and head-name naming branch
func midRebase(branch string) func(f *fixture) {
	return func(f *fixture) {
		f.git(".", "checkout", "-q", "-b", branch)
		f.git(".", "checkout", "-q", "--detach")
		f.write(".git/rebase-merge/head-name", "refs/heads/"+branch+"\n")
	}
}

// awayLinks links into away, a folder outside the approved roots, and into the approved nixos-config
func awayLinks(f *fixture) {
	f.write("away/file.txt", "x\n")
	f.write("home/.config/.keep", "")
	for link, target := range map[string]string{"linkdir": "away", "home/.config/link": "away", "filelink": "away/file.txt",
		"home/cfglink": "home/nixos-config"} {
		if err := os.Symlink(filepath.Join(f.repo, target), filepath.Join(f.repo, link)); err != nil {
			f.t.Fatal(err)
		}
	}
}

// a read through a link elsewhere is no write, so only the path itself being a managed link steers it
func TestSymlinkPathAllowsReads(t *testing.T) {
	f := newFixture(t)
	awayLinks(f)
	t.Setenv("HOME", f.home)
	in := map[string]any{"cwd": f.repo, "tool_name": "Read", "tool_input": map[string]any{"file_path": filepath.Join(f.repo, "linkdir/file.txt")}}
	if o := runPreHook(t, "claude", in, "deny-symlink-path"); !o.empty {
		t.Errorf("got %s (%s), want allow", o.kind, o.reason)
	}
}

// a script nested deeper than any fixed limit
func nestedRm() string {
	s := "rm f"
	for range 5 {
		s = "bash -c " + shellQuote(s)
	}
	return s
}

var cases = map[string][]group{
	"deny-symlink-path": {
		{env: map[string]string{"HOME": "{home}"}, want: "deny", files: []string{"managed-link"}},
		{env: map[string]string{"HOME": "{home}"}, want: "allow", files: []string{"tracked.txt"}},
		// a write through a link anywhere along the path must land under an approved root
		{env: map[string]string{"HOME": "{home}"}, setup: awayLinks, want: "deny",
			files: []string{"linkdir/new.txt", "linkdir/file.txt", "home/.config/link/new.txt", "filelink"}},
		{env: map[string]string{"HOME": "{home}"}, setup: awayLinks, want: "allow",
			files: []string{"away/new.txt", "home/cfglink/new.txt", "new.txt"}},
	},
	"block-smart-punct": {
		{want: "deny", files: []string{"new.txt"}, content: "em dash: " + string(rune(0x2014))},
		{want: "allow", files: []string{"new.txt"}, content: `dash: - quotes: "x"`},
		{want: "allow", files: []string{"new.ts"}, content: `const q = /[\u{2018}\u{2019}]/gu, d = "\\u2014", p = "\N{EM DASH}"`},
	},
	"block-git-config-edit": {
		{want: "deny", files: []string{".git/config", "{home}/.gitconfig"}},
		{want: "allow", files: []string{"config"}},
		{want: "deny", cmds: []string{"echo x > .git/config", "cp /tmp/x .git/config", "sudo cp /tmp/x .git/config",
			"printf x > ~/.gitconfig", "cp /tmp/x ~/.config/git/config",
			"{ echo x; } >> .git/config", "(echo x) > .git/config", ">> .git/config <<< x", "echo x 1<> .git/config",
			"echo x >& .git/config", "echo x > .git//config", "echo x > .GIT/config", "cd .git && echo x >> config",
			"echo x > /tmp/x/git/config", `awk 'BEGIN { print "[eric-agent]" >> ".git/config" }'`, "sed -i s/a/b/ .git/config",
			`yq -i '.a = 1' .git/config`}},
		{want: "allow", cmds: []string{"cat .git/config", "sudo cat .git/config", "cat ~/.gitconfig", "rg -n python ~/.gitconfig", "jq . ~/.gitconfig"}},
		// only the user sets eric-agent keys, git aliases, and includes, which git config is the one way to change
		{want: "deny", cmds: []string{"git config eric-agent.commit on", "git config alias.c commit", "git config include.path /tmp/x",
			"git config --edit", "git config set eric-agent.commit list", "git config include.path get"}},
		{want: "allow", cmds: []string{"git config --get eric-agent.commit", "git config -l", "git config get --all eric-agent.commit",
			"git config user.name x"}},
	},
	"block-eric-top": {
		{want: "deny", files: []string{".eric/x.txt", ".eric/tmp/x.txt"}},
		{want: "allow", files: []string{".eric/scratch/2026-01-01-x/x.txt", ".eric/notes/2026-01-01-x.md", ".eric/reminders.md", "x/.eric.txt"}},
		{env: map[string]string{"HOME": "{home}"}, want: "deny", cmds: []string{"echo x > .eric/x.txt", `zsh -c 'log foo' 2>"$HOME/.eric/err.txt"`,
			"touch ~/.eric/x", "mkdir -p .eric/tmp", "cp /tmp/x .eric/", "mv /tmp/x ~/.eric/y", "echo x | tee .eric/x", "cd .eric && echo x > y",
			"cp -t .eric/ /tmp/x", "ln -s /tmp/x .eric/foo", "install -d .eric/foo", "git worktree add .eric/wt", "rsync -a /tmp/x .eric/",
			"install -dm755 .eric/foo", "sed -n 'w .eric/stray' f", `python3 -c "open('.eric/x.txt', 'w')"`}},
		{env: map[string]string{"HOME": "{home}"}, want: "allow", cmds: []string{"echo x > .eric/scratch/2026-01-01-x/x.txt", "mkdir -p ~/.eric/scratch/2026-01-01-x",
			"cp /tmp/x .eric/notes/", "cat .eric/x.txt", "ls ~/.eric"}},
		{setup: func(f *fixture) { f.write("AGENTS.md", "keep the catalog in `.eric/catalog/`\n") }, want: "allow", cmds: []string{"echo x > .eric/catalog/a.txt"}},
		// the entry an AGENTS.md names is a whole name, not a prefix
		{setup: func(f *fixture) { f.write("AGENTS.md", "keep the catalog in `.eric/catalog/`\n") }, want: "deny", cmds: []string{"echo x > .eric/cat"}},
		// a .eric folder inside another one is checked too
		{want: "deny", files: []string{".eric/scratch/2026-01-01-x/wt/.eric/stray.txt"}},
	},
	"block-write-tracked": {
		{want: "deny", files: []string{"tracked.txt"}},
		{want: "allow", files: []string{"untracked.nix", "new.txt"}},
	},
	"git-add-before-nix": {
		{want: "deny", cmds: []string{"nix build", "sudo darwin-rebuild switch --flake .", "just switch", "nh darwin switch",
			"nix flake check", "nix -L build", "nix --print-build-logs build", "nix shell .#hello", "nix develop", "nix fmt",
			"nix shell nixpkgs#jq .#hello", "nix eval --raw --inputs-from . nixpkgs#hello.version", "nix build -o result nixpkgs#hello"}},
		{want: "allow", cmds: []string{"nix shell nixpkgs#jq --command jq .", "nix eval --raw nixpkgs#hello.version",
			"nix run github:o/r -- .", "nix build --no-link nixpkgs#hello nixpkgs/nixos-unstable#jq", "nix shell nixpkgs#jq -c jq ."}},
		{want: "allow", cmds: []string{"git status", "rg -n home-manager modules", "ls ~/.local/state/home-manager /tmp",
			// the dry run and the untracked check use the directory a later cd moves to
			"git status && cd jb && just build",
			`cd "$d" && nix build`}},
		{dir: "jb", want: "allow", cmds: []string{"just build"}},
		{dir: "jb", want: "deny", cmds: []string{"just switch", "just -f justfile switch"}},
		{dir: "sub", want: "deny", cmds: []string{"darwin-rebuild switch --flake ."}},
		{dir: "sub", setup: func(f *fixture) { f.git("sub", "add", "new.lua") }, want: "allow", cmds: []string{"nix build"}},
		// the repo checked is the flake the command names, and a remote flake has no local files
		{setup: func(f *fixture) { f.git("sub", "add", "new.lua") }, want: "allow", cmds: []string{"nix develop ./sub --command true",
			"nix build ./sub#x", "nix develop nixpkgs#go --command true", "darwin-rebuild switch --flake ./sub"}},
		{dir: "sub", setup: func(f *fixture) { f.git("sub", "add", "new.lua") }, want: "deny", cmds: []string{"nix build ../jb#x",
			"nix develop {repo}/jb -c true", "darwin-rebuild switch --flake ../jb#host"}},
	},
	"strip-claude-attribution": {
		{want: "allow", cmds: []string{"git commit -m 'x'"}},
		{harness: "codex", want: "allow", cmds: []string{"git commit -m 'x\n\nCo-Authored-By: Claude <noreply@anthropic.com>'"}},
	},
	"block-global-search": {
		// a real home path, since the nix build sandbox sets HOME to /homeless-shelter
		{env: map[string]string{"HOME": "/home/user"}, want: "deny", cmds: []string{"find / -name nope", "rg x /nix", "rg x /nix/store/", "fd x /nix/store/*", "grep -r x /nix/var/nix",
			"rg x $HOME", "rg --files /", "sudo find / -name x", "cd -- $d && rg x .",
			"d=$(fd -t d gitsigns . | head -1); cd $d && rg -l GitSignsUpdate .", "cd ${d:-}\nrg x .",
			// a relative search after a cd into a filesystem-wide root scans that root
			"cd / && rg x .", "cd ~ && fd x", "cd /nix/store; find . -name x",
			"env -C / rg x .", "sudo -D / fd x", "cd /; true || cd /tmp; rg x .", "cd /; if false; then cd /tmp; else rg x .; fi",
			"cd /; cd /tmp; cd -; rg x .", "cd /tmp && cd -LP / && rg x .", "rg x /.", "rg x //", "find /. -name x", "rg x ~/.",
			"rg x /tmp/..", "find -O3 / -name x", "find -x / -name x", "rg -- -foo /", "egrep -r x /", "rg -e foo /",
			// a glob or cdpath can land a cd somewhere the literal path does not name
			"cd /ni? && rg foo .", "cdpath=(/); cd nix && rg foo .",
			// an option's value is not the pattern, and a glob of a root scans that root
			"cd ~ && rg -t nix foo", "cd ~ && rg -g '*.nix' foo", "cd ~ && fd -e nix foo", "rg x /*", "fd x ~/*", "rg x $HOME/*"}},
		// .. from a repo in home climbs to home itself
		{env: map[string]string{"HOME": "{repo}/.."}, want: "deny", cmds: []string{"rg x ..", "fd x ..", "find .. -name x"}},
		{want: "allow", cmds: []string{`cd "${d:?}" && rg -l GitSignsUpdate .`, `cd "$d" && rg x .`, "cd $dir/sub && rg x .", "cd $d && ls",
			`echo "cd $d && rg x ."`, "cd ${d:?} && rg x .", "rg foo .", "fd x .", "find . -name x", "rg foo {repo}",
			"grep -n x /nix/store/abc-etc-zshenv", "rg / src", `echo "rg x /"`, "cat <<EOF\nrg x /\nEOF", "echo ${(f)x}",
			"d=/tmp; cd $d && rg x .", "cd $d && rg x /tmp", "cd / & rg x ."}},
	},
	"block-symlink-clobber": {
		{want: "deny", cmds: []string{"echo x > managed-link", "mv /tmp/x managed-link && echo ok", "cp /tmp/x managed-link; ls",
			"cp /tmp/x managed-link 2>/dev/null", "printf x | tee managed-link >/dev/null", "cp a b; cp /tmp/x managed-link",
			"echo x &> managed-link", "echo x >| managed-link", "sed -i s/a/b/ managed-link", "truncate -s 0 managed-link",
			"{ echo x; } > managed-link", "sed -i s/a/b/ managed-link other", "truncate -s 0 managed-link other",
			"cp /tmp/x/managed-link .", "ln -sf /tmp/x managed-link", "install /tmp/x managed-link",
			`python3 -c "open('managed-link', 'w').write('x')"`, `awk '{ print > "managed-link" }' f`}},
		// a shell write through a linked folder that leads outside the managed roots, as a file tool write is denied
		{env: map[string]string{"HOME": "{home}"}, setup: awayLinks, want: "deny", cmds: []string{"echo x > linkdir/new.txt"}},
		{env: map[string]string{"HOME": "{home}"}, setup: awayLinks, want: "allow", cmds: []string{"echo x > home/cfglink/new.txt"}},
		// a relative path after a leading cd names a file in that directory
		{setup: func(f *fixture) { f.link("sub/link") }, want: "deny", cmds: []string{"cd sub && cp /tmp/x link"}},
		{want: "allow", cmds: []string{"cp /tmp/x other 2>/dev/null"}},
	},
	"ask-dangerous-git": {
		{want: "ask", cmds: []string{"git reset --hard", "direnv exec . git reset --hard", `bash -c "git reset --hard"`, "git clean -x -f",
			"git stash drop", "git stash clear", "git checkout -f main", "git switch --discard-changes main", "git worktree remove --force x",
			"git clean --force", "git clean -d --force", `bash -c "echo \"a b\" && git reset --hard"`, "git checkout -- f",
			"git checkout feature -- src", "git restore f", "git restore -W f", "git restore -S -W .", "git restore --source=HEAD f",
			"git switch -C main", "git checkout -B main", "git rebase main", "git reflog expire --all", "git filter-branch",
			"git branch -D x", "git branch -d -f x", "git rebase --skip", "git reset HEAD~1", "git reset --soft HEAD~1",
			"git reset --keep HEAD~1", "git reset --merge", "gh pr checkout -f 1", "gh pr checkout 1 --force",
			// checkout of an existing path discards its changes, with or without --
			"git checkout tracked.txt", "git checkout HEAD tracked.txt", "git replace HEAD main",
			"git checkout -qf main", "git branch -qD foo", "git switch -qC main",
			// clean deletes without -f when clean.requireForce is off, or in its interactive mode
			"git -c clean.requireForce=false clean -d", "git clean -i"}},
		{want: "allow", cmds: []string{"git checkout -b sub", "git reset tracked.txt", "git switch -c sub"}},
		{want: "allow", cmds: []string{"git stash list", "git clean -n", "git checkout main", "git switch -c feat", "git worktree remove x",
			"git restore --staged f", "git restore -S f", "git branch -d x", "git rebase --continue", "git rebase --abort",
			"git rebase --quit", "git reset", "git reset -q", "git reset -- f", "git reset HEAD -- f", "gh pr checkout 1"}},
	},
	"block-agent-commit": {
		{want: "deny", cmds: []string{"git status --short\ngit commit -m x", "direnv exec . git commit -m x", `bash -c "git commit -m x"`,
			"git -c 'alias.c=commit -m x' c", "git -calias.c=commit c", "bash -c 'echo \"a\nb\"\ngit commit -m x'", "git pull",
			"git pull --rebase", "git subtree add --prefix=x r main", "git -c include.path=/tmp/x c",
			"git --config-env=alias.c=X c", "git --config-env alias.c=X c",
			"GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=alias.c GIT_CONFIG_VALUE_0=commit git c", "env GIT_DIR=sub/.git git commit -m x",
			"export GIT_CONFIG_GLOBAL=/tmp/x",
			"git commit -m --abort", "git commit -m --dry-run", "git commit -- --dry-run", "git commit --author --dry-run -m x",
			"git rebase main", "git rebase --continue", "XDG_CONFIG_HOME=/tmp/x git status",
			// these move a branch too
			"git branch -f main feat", "git branch -M x", "git fetch . feat:main", "git fetch origin +main:refs/heads/main", "git fast-import"}},
		{want: "allow", cmds: []string{"git branch x", "git branch -d x", "git fetch origin", "git fetch origin main",
			"git fetch origin +refs/heads/*:refs/remotes/origin/*", `echo "docs mention GIT_DIR=x"`}},
		// a setting git reads from the environment moves the repo or config the gate reads, wherever it is set
		{setup: config(".", "eric-agent.commit", "on"), want: "deny", reason: "Agents never set",
			cmds: []string{"GIT_COMMON_DIR=x git commit -m x", "GIT_INDEX_FILE=x git commit -m x", "export GIT_DIR=x"}},
		{setup: config(".", "eric-agent.commit", "on"), want: "allow", cmds: []string{`git commit -m "handle GIT_DIR= in the guard"`}},
		// branch mode allows only commands that move the checked-out branch
		{setup: func(f *fixture) {
			config(".", "eric-agent.commit", "branch")(f)
			f.git(".", "checkout", "-q", "-b", "feat")
		}, want: "deny", cmds: []string{"git update-ref refs/heads/main HEAD", "git branch -f main HEAD", "git fetch . feat:main"}},
		// wrappers that run git as a later word, and shells that read their script from a here-string or heredoc
		{want: "deny", cmds: []string{"caffeinate git commit -m x", "noglob git commit -m x", "stdbuf -o0 git commit -m x",
			"flock /tmp/l git commit -m x", "flock /tmp/l -c 'git commit -m x'", "env --frob x git commit -m x", "xcrun git commit -m x", "env -S 'git commit -m x'",
			"bash <<<'git commit -m x'", "bash <<'EOF'\ngit commit -m x\nEOF", "nix run nixpkgs#git -- commit -m x",
			"nix-shell -p git --run 'git commit -m x'", "git update-ref refs/heads/main HEAD"}},
		// a shell reading its script from a pipe hides it from every guard
		{want: "deny", reason: "standard input", cmds: []string{"echo 'git status' | bash"}},
		// a nested parse error names the script
		{want: "deny", reason: `nested script: echo "x`, cmds: []string{`echo hi; bash -c 'echo "x'`}},
		{want: "allow", cmds: []string{
			// a -c script with a newline inside quotes parses whole, so a later line is still checked
			"bash -c 'echo \"a\nb\"\ngit status'",
			"bash ./run.sh", "caffeinate -i sleep 1", "flock /tmp/l true", "command -v bash", "command -V zsh", "bash --version | head -1",
			"/bin/bash --help", "git merge --abort", "git cherry-pick --quit", "git pull --ff-only", "git config --get alias.lg",
			"git commit --dry-run --short -- a b", "git commit -m x --dry-run", "git rebase --abort", "git rebase --edit-todo",
			// commit-tree only writes an object, so a trial merge needs no setting
			"git commit-tree HEAD^{tree} -m x", "git merge-tree --write-tree main feat",
			"git config --get eric-agent.commit", "git -C . config --show-origin --get-all eric-agent.commit",
			"git config --show-scope --list", "git config -l", "git config get --all eric-agent.commit", "git config list --show-origin"}},
		{setup: config(".", "eric-agent.commit", "on"), want: "allow", cmds: []string{"git commit -m x", "git pull",
			"git commit-tree HEAD^{tree} -m x", "git subtree add --prefix=x r main", "git commit -C HEAD", "direnv exec . git commit -C HEAD",
			"env FOO=1 git commit -m x", "git -C {repo} commit -m x; cd sub", "T={repo}; git -C $T commit -m x"}},
		// a repo named by a shell expansion cannot be resolved, so the denial says that, not that commits are off
		{setup: config(".", "eric-agent.commit", "on"), want: "deny", reason: "shell variable",
			cmds: []string{"cd $T && git commit -m x", `git -C "$(pwd)" commit -m x`, "T=$(pwd); git -C $T commit -m x"}},
		// every repo a command commits in must allow it, in either order. sub is off, so a cd or -C there denies,
		// and --git-dir, --work-tree, core.worktree, and find -execdir deny since the guard does not follow them
		{setup: config(".", "eric-agent.commit", "on"), want: "deny", cmds: []string{"git commit -m x; git -C sub commit -m x",
			"git -C sub commit -m x; git commit -m x", "git status && cd sub && git commit -m x", "git --git-dir=sub/.git commit -m x",
			"git --work-tree=sub commit -m x", "pushd sub && git commit -m x", "cd -P sub && git commit -m x",
			"git -C . -C sub commit -m x", "git -c core.worktree=sub commit -m x", "env -C sub git commit -m x",
			"env --chdir=sub git commit -m x", "sudo -D sub git commit -m x", `find sub/flake.nix -execdir git commit -m x \;`,
			"(cd sub) && git -C sub commit -m x",
			// a cd in a branch that may not run, or a function called after a cd, still reaches the commit gate
			"false && cd sub; git commit -m x", "f() { git commit -m x; }; cd sub; f"}},
		// the guard follows each cd, pushd, -C, env -C, sudo -D, and literal variable to the repo a commit lands in
		{setup: func(f *fixture) {
			config(".", "eric-agent.commit", "on")(f)
			config("sub", "eric-agent.commit", "on")(f)
		}, want: "allow", cmds: []string{"git status && cd sub && git commit -m x", "pushd sub && git commit -m x",
			"R=sub; git -C $R commit -m x", "env -C sub git commit -m x", "sudo -D sub git commit -m x",
			"(cd sub && git commit -m x) && git commit -m y", "git -C . -C sub commit -m x", "pushd sub && popd && git commit -m x",
			"cd sub; cd ..; git commit -m x"}},
		{setup: func(f *fixture) {
			config(".", "eric-agent.commit", "branch")(f)
			f.git(".", "checkout", "-q", "-b", "feat")
		}, want: "allow", cmds: []string{"git commit -m x", "git pull"}},
		{setup: config(".", "eric-agent.commit", "branch"), want: "deny", cmds: []string{"git commit -m x", "git pull",
			"git subtree add --prefix=x r main"}},
		// an agent-test- branch is the agent's own, so a command that moves only it needs no setting,
		// but one that can move another branch still does
		{setup: func(f *fixture) { f.git(".", "checkout", "-q", "-b", "agent-test-x") }, want: "allow", cmds: []string{
			"git commit -m x", "git commit --amend -m x", "git merge feat", "git cherry-pick abc", "git revert abc", "git pull",
			"git rebase main", "git rebase -i main", "git rebase --onto main a", "git rebase -X theirs main"}},
		{setup: func(f *fixture) { f.git(".", "checkout", "-q", "-b", "agent-test-x") }, want: "deny", cmds: []string{
			"git update-ref refs/heads/main HEAD", "git rebase main feat", "git rebase --onto main a feat",
			"git subtree add --prefix=x r main", "git commit -m x; git -C sub commit -m x", "git pull . feat:main"}},
		// the prefix must start the branch name
		{setup: func(f *fixture) { f.git(".", "checkout", "-q", "-b", "my-agent-test-x") }, want: "deny", cmds: []string{"git commit -m x"}},
		// mid-rebase HEAD is detached, so the branch being rebased names whose branch it is
		{setup: midRebase("agent-test-x"), want: "allow", cmds: []string{"git rebase --continue", "git commit -m x"}},
		{setup: midRebase("feat"), want: "deny", cmds: []string{"git rebase --continue"}},
		{setup: config(".", "eric-agent.commit", "ask"), want: "ask", cmds: []string{"git commit -m x"}},
		{setup: func(f *fixture) {
			config(".", "eric-agent.commit", "ask")(f)
			config("sub", "eric-agent.commit", "on")(f)
		}, want: "ask", cmds: []string{"git -C sub commit -m x; git commit -m x"}},
		{setup: config(".", "eric-agent.commit", "ask"), harness: "codex", want: "deny", cmds: []string{"git commit -m x"}},
		// a configured alias is expanded, and one that runs a shell command is checked as that command
		{setup: config(".", "alias.ci", "commit", "alias.sh", "!git commit"), want: "deny", cmds: []string{"git ci -m x", "git sh"}},
		{setup: config(".", "alias.lines", "!wc -l"), want: "allow", cmds: []string{"git lines f"}},
	},
	"block-agent-push": {
		{setup: config(".", "eric-agent.push", "ask"), want: "ask", cmds: []string{"git push"}},
		{setup: config(".", "eric-agent.push", "ask"), harness: "codex", want: "deny", cmds: []string{"git push"}},
		{want: "deny", cmds: []string{"git push", "caffeinate git push", "noglob git push", "nix run nixpkgs#git -- push",
			"bash <<<'git push'", "git send-pack origin main", "git subtree push --prefix=x origin main", "git lfs push origin main",
			"GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=alias.p GIT_CONFIG_VALUE_0=push git p", "git --config-env=alias.p=X p",
			"git push -o --dry-run origin main", "git push origin -- -n",
			"direnv exec . git push", "nix develop -c git push", "xargs git push", `find . -exec git push \;`, "timeout 10 git push",
			`bash -c "git push origin main"`, "bash -l -c 'git push'",
			"bash -ec 'git push'", "sh -xc 'git push'", `bash -c "echo \"a\"; git push"`, "env -i git push", "command -p git push",
			"sudo git push", "nice git push", "nohup git push", "time git push", "eval git push", "git -P push",
			"git -c 'alias.p=!git push' p", "git -c alias.p=push p", "git --attr-source HEAD push"}},
		{want: "allow", cmds: []string{"git push --dry-run", "git push -n origin main", "direnv exec . git status",
			"nix develop -c git status", `bash -c "echo hi"`, "bash -c 'echo hi'", `echo "git push"`, `rg -n "bash -c 'git push'" docs`,
			`echo "a; git push"`, "cat <<EOF\ngit push\nEOF"}},
		// -C names the repo whose eric-agent.push applies, and every repo a command pushes from must allow it
		{setup: config("sub", "eric-agent.push", "on"), want: "allow", cmds: []string{"git -C sub push"}},
		{setup: config("sub", "eric-agent.push", "on"), want: "deny", cmds: []string{"git -C sub push; git push"}},
		{setup: config(".", "eric-agent.push", "on"), want: "allow", cmds: []string{"git push", "git send-pack origin main",
			"git subtree push --prefix=x origin main", "git lfs push origin main", "git push origin main -o agent-test-note"}},
		// agent-test- branches never leave the machine, even where pushes are on
		{setup: config(".", "eric-agent.push", "on"), want: "deny", reason: "throwaway",
			cmds: []string{"git push origin agent-test-x", "git push origin HEAD:agent-test-x", "git push -u origin agent-test-x:main",
				"git push --repo=origin agent-test-x"}},
		// an alias chain longer than the guard follows is unreadable
		{setup: config(".", "alias.a1", "a2", "alias.a2", "a3", "alias.a3", "a4", "alias.a4", "a5", "alias.a5", "a6", "alias.a6", "push"),
			want: "deny", cmds: []string{"git a1"}},
		{setup: func(f *fixture) {
			config(".", "eric-agent.push", "on")(f)
			f.git(".", "checkout", "-q", "-b", "agent-test-x")
		}, want: "deny", reason: "throwaway", cmds: []string{"git push", "git push origin main"}},
		{setup: func(f *fixture) {
			config(".", "eric-agent.push", "on")(f)
			midRebase("agent-test-x")(f)
		}, want: "deny", reason: "throwaway", cmds: []string{"git push"}},
	},
	"block-gh-write": {
		{want: "deny", cmds: []string{"direnv exec . gh pr create", `bash -c "gh pr create"`}},
		{want: "allow", cmds: []string{"gh pr view 1", "gh pr list", "gh pr diff 1", "gh run view 1", "gh run watch 1",
			"gh api repos/o/r/pulls", "gh search code x", "gh api -X GET search/code -f q='repo:o/r x' --jq '.items[].path'",
			"gh api --method=get search/code -F q=x", "gh api -XGET search/code -fq=x",
			`gh api graphql -f query='{search(query:"repo:o/r x", type:DISCUSSION, first:10){nodes{... on Discussion{number}}}}' --jq '.data'`,
			"gh api graphql -f query='query { viewer { login } }'", "gh --version", "gh version", "gh help pr", "gh pr comment --help",
			"gh repo read-file f", "gh repo autolink list", "gh repo deploy-key list", "gh repo license view mit", "gh ruleset check",
			"gh variable get X", "gh project item-list 1", "gh attestation verify f", "gh licenses", "gh run download 1", "gh pr checkout 1"}},
		{want: "deny", cmds: []string{"gh pr merge 1", "gh api -X DELETE repos/o/r", "gh api repos/o/r/issues -f title=x",
			"gh auth status --show-token", "gh api repos/o/r/issues -ftitle=x", "gh api repos/o/r/issues -Ftitle=x", "gh api -XPOST repos/o/r",
			"gh api --method=PATCH repos/o/r", "gh api -X GET -X POST repos/o/r -f x=1", "gh api --method PUT repos/o/r",
			"gh api -X post repos/o/r", "gh api graphql -f query='mutation { x }'", "gh api graphql -f query='{ a } mutation { x }'",
			"gh api graphql -F query=@q.graphql", "gh api graphql -f query='{ a }' --input q.json", `gh api graphql -f query="$Q"`,
			`gh api graphql -f query="{ $(cat q) }"`, "gh api graphql -f query='query($o: String!) { a(o: $o) }' -f o=x",
			"gh api graphql -f query='{ a }' -f query='mutation { x }'", "gh api repos/o/r/issues -f query='{ a }' -f title=x",
			"gh api -X POST graphql -f query='{ a }'", "gh pr comment 1 --body --help --edit-last", "gh repo deploy-key add k",
			"gh repo autolink create x y", "gh variable set X", "gh project item-add 1", "gh auth token", "gh browse"}},
	},
	"block-shell-edit": {
		// a shell alias runs at the top of the repo, wherever git starts
		{setup: config(".", "alias.w", "!echo x > tracked.txt"), dir: "bin", want: "deny", cmds: []string{"git w"}},
		{want: "deny", cmds: []string{"sed -i s/tracked/changed/ tracked.txt", "echo x > tracked.txt", "printf x | tee -a tracked.txt",
			`python3 -c "open('tracked.txt', 'w').write('x')"`, "perl -pi -e s/a/b/ tracked.txt", "printf x | tee new.txt tracked.txt",
			"cd sub && sed -i s/a/b/ flake.nix", `echo x > "$PWD/tracked.txt"`, "echo x > ${PWD}/tracked.txt", "cp /tmp/x tracked.txt",
			"mv /tmp/x tracked.txt", "cp -f /tmp/x /tmp/y tracked.txt", "git status && cd sub && echo x > flake.nix",
			"(cd sub) && echo x > tracked.txt", "F=tracked.txt; echo x > $F",
			// a runner that starts the interpreter still counts as a script
			`uv run python -c "open('tracked.txt', 'w').write('x')"`,
			"{ echo x; } > tracked.txt", `perl -e 'open(F, ">tracked.txt")'`, `ruby -e "File.write('tracked.txt', 'x')"`,
			`node -e "require('fs').appendFileSync('tracked.txt', 'x')"`, `python3 -c "open(\"tracked.txt\", \"w\")"`,
			`d=sub; cd -- "${d:?}" && echo x > flake.nix`, `python3 -c "p='tracked.txt'; open(o, 'w').write(open(p).read())"`}},
		{env: map[string]string{"HOME": "{repo}"}, want: "deny", cmds: []string{`echo x > "$HOME/tracked.txt"`, "echo x > ${HOME}/tracked.txt"}},
		// a copy into a folder writes the source's name there, and these tools overwrite their destination too
		{want: "deny", cmds: []string{"cp /tmp/x/tracked.txt .", "cp /tmp/x/tracked.txt ./", "cp -t . /tmp/x/tracked.txt",
			"mv /tmp/x/flake.nix sub", "truncate -s 0 tracked.txt", "install /tmp/x tracked.txt", "dd if=/tmp/x of=tracked.txt",
			"rsync /tmp/x tracked.txt", "ln -sf /tmp/x tracked.txt", "sed -i s/a/b/ new.txt tracked.txt",
			"echo x >>| tracked.txt", "echo x &>| tracked.txt", "uv run sed -i s/a/b/ tracked.txt", `awk '{ print > "tracked.txt" }' f`,
			"sed -n 'w tracked.txt' f", "sort -o tracked.txt f", "git diff --output=tracked.txt"}},
		// a glob copy into a folder writes each match's name there
		{setup: func(f *fixture) { f.write("rep/tracked.txt", "x\n") }, want: "deny", cmds: []string{"cp rep/* .", "cp rep/t*.txt ./"}},
		{want: "allow", cmds: []string{"mv -t sub tracked.txt", "truncate -s 0 new.txt", "dd if=tracked.txt of=/tmp/x", "mkdir -p sub/x",
			"touch tracked.txt", "cp -r /tmp/x/dir ."}},
		{want: "allow", cmds: []string{"sed -n p tracked.txt", "sed -i s/a/b/ untracked.nix", "echo x > new.txt",
			"cat tracked.txt > /dev/null", "cp tracked.txt /tmp/x", "mv tracked.txt", "cp /tmp/x.png blob.png", "mv new.png blob.png",
			`echo "python: open('tracked.txt', 'w')"`, `python3 -c "p='blob.png'; open(o, 'w').write(open(p, 'rb').read())"`,
			// a write pattern in another call's words is a search, not a script
			`node --version && rg -n "writeFileSync" tracked.txt`, "python3 scripts/check.py && rg -n 'write_text' 'tracked.txt'"}},
	},
	"ask-defaults-write": {
		{want: "ask", cmds: []string{"defaults write com.x k -bool false", "sudo defaults write /Library/Preferences/com.x k -int 1",
			"/usr/bin/defaults delete com.x k", "defaults -currentHost write com.x k 1", "defaults -host h import com.x f.plist",
			"defaults rename com.x a b", `bash -c "defaults write com.x k 1"`}},
		{want: "allow", cmds: []string{"defaults read com.x", "defaults read-type com.x k", "defaults domains", "defaults find x",
			"defaults export com.x -", "defaults -currentHost read com.x", `echo "defaults write com.x k 1"`}},
	},
	"block-sudo-probe": {
		{env: map[string]string{"PATH": "{repo}/bin:{path}"}, want: "deny",
			cmds: []string{"sudo -n true", "sudo --non-interactive true", "sudo -u root -n true", "sudo -nv"}},
		{env: map[string]string{"PATH": "{repo}/bin:{path}"}, want: "deny", cmds: []string{"sudo -nu root true"}},
		{env: map[string]string{"PATH": "{repo}/bin:{path}"}, want: "allow", cmds: []string{"sudo true", "sudo -u nobody true", "sudo -unobody true"}},
	},
	"block-rm": {
		// every check reads what a git alias runs, as a git command or as shell code
		{setup: config(".", "alias.zap", "!rm f", "alias.dt", "difftool -x 'rm f'"), want: "deny", cmds: []string{"git zap", "git dt"}},
		{setup: config(".", "alias.dt", "difftool -x 'echo f'"), want: "allow", cmds: []string{"git dt"}},
		// an alias in a repo the guard cannot tell is unreadable, and so is one that is more than a plain command
		{setup: config(".", "alias.x", "commit; rm f"), want: "deny", reason: "git alias", cmds: []string{`cd "$d"; git zz`, "git x"}},
		{want: "allow", cmds: []string{`cd "$d"; git status`}},
		{want: "deny", cmds: []string{"rm f", "rm -rf /tmp/x", "/bin/rm f", "command rm f", "fd -0 . | xargs -0 rm", `bash -c "rm f"`,
			"sudo rm f", "doas rm f", "doas -u root rm f", "ionice -c 3 rm f", "chronic rm f", "unbuffer rm f", "watch rm f",
			"watch -n 1 'rm f'", "script -qc 'rm f' /dev/null", "coproc rm f", nestedRm(),
			// commands only the walk's control flow, wrapper options, or command-name rules reveal
			`builtin eval "rm f"`, `command eval "rm f"`, "c=" + shellQuote("rm -f nothing-here;") + "; eval $c$c$c$c$c$c",
			"sudo --user root rm f", "timeout --signal KILL 5 rm f", "nice --adjustment 5 rm f", "xargs --max-args 1 rm",
			"env -vC . rm f", `env -iS "rm f"`, "exec -a x rm f", `$'\x72m' f`, "/bin/r[m] f", "$(printf rm) f", "R=rm; $R f",
			"f() { rm x; }; f", "cd sub & rm f"}},
		// scripts hidden behind -c options, other shells, $'...' escapes, a pipe named as a file, a runner's command string,
		// a variable the walk wrongly thinks it knows, or a wrapper the walk did not unwrap
		{want: "deny", cmds: []string{`bash -c -- "rm f"`, `bash -c -e "rm f"`, `zsh -c -x "rm f"`, `bash -c -o pipefail "rm f"`,
			"command rm -v f", `ksh -c "rm f"`, `mksh -c "rm f"`, `fish -c "rm f"`, `tcsh -c "rm f"`, `csh -c "rm f"`,
			`bash -c $'rm\x20f'`, `eval $'rm\x20f'`, `bash /dev/stdin <<<"rm f"`, "bash <(echo rm f)", `source /dev/stdin <<<"rm f"`,
			". <(echo rm f)", "echo rm f | bash /dev/stdin",
			`git -c core.fsmonitor="rm f" status`, `git -c diff.external="rm f" diff`, `GIT_PAGER="rm f" git log`,
			`env GIT_PAGER="rm f" git log`, `export GIT_PAGER="rm f"`, "git submodule foreach 'rm f'", "git bisect run rm f",
			`tmux -L x new-session -d "rm f"`, "tmux -L x split-window -t a 'rm f'", `tmux -L x if-shell true 'run-shell "rm f"'`,
			`trap "rm f" EXIT`,
			`BASH_ENV=/dev/stdin bash -c true <<<"rm f"`, "echo *(e:'rm f':)", "x='$(rm f)'; echo ${(e)x}",
			"x=; : ${x:=rm}; $x f", "x=ls; print -v x rm; $x f", "export x=ls; env x=rm sh -c '$x f'", `x="rm f"; $x`,
			"/usr/bin/env -P /bin rm f", "arch -arm64 rm f", `sandbox-exec -p "(version 1)" rm f`, "script -q /dev/null rm f",
			"- rm f", `nix run nixpkgs#bash -- -c "rm f"`, "echo rm f | xargs env", "echo rm f | xargs -I@ sh -c @",
			"echo 'rm f' | sudo -s", "echo 'rm f' | nix develop", "just --command rm f", "just -c rm f",
			// options read the way the program reads them: clusters, values, and options it takes after -c
			`echo "rm f" | bash -es x`, `echo "rm f" | bash --rcfile x`, `echo "print(1)" | python3 -E`, `echo "print(1)" | python3 -W ignore`,
			`printf "rm f" | xargs -0I{} sh -c "{}"`, "env -a harmless rm f", `tcsh -V -c "rm f"`,
			// runners, a git command option, and awk or sed code that runs a command
			"uv run rm f", "npx rm f", "pnpm exec rm f", "poetry run rm f", "uvx rm f", `git difftool -y -x "rm f" HEAD`,
			`awk 'BEGIN { system("rm f") }'`, `awk '{ print | "sh" }' f`, "sed 'e rm f' x"}},
		{want: "allow", cmds: []string{"script -q out.log", "trap - EXIT", "trap '' INT", "GIT_EDITOR=true git rebase --continue",
			"GIT_PAGER=cat git log", "tmux -L x new-session -d nvim", "xargs -I@ echo @", "bash -c 'echo hi' arg0", "command -v rm",
			`x="a b"; echo $x`, "git -c user.name=x status", "ksh --version", "nix develop -c true", "echo x | sudo tee f",
			"python3 <<'EOF'\nprint(1)\nEOF", "python3 script.py", "python3 -c 'print(1)'", "node --version", "perl -ne 'print' f",
			"python3 -m json.tool f", "awk '{print $1}' f", "sed -n p f", "env -i git status", "uv run pytest"}},
		// an interpreter reading its program from a pipe or a terminal hides it, as Codex can type into one later
		{want: "deny", cmds: []string{"echo 'import os' | python3", "node", "cat x.js | node -"}},
		// the default lists run under pi as under claude
		{harness: "pi", want: "deny", cmds: []string{"rm f"}},
		// a command the guard cannot parse is denied before any check runs
		{want: "deny", reason: "could not parse", cmds: []string{`echo "unterminated`}},
		{want: "allow", cmds: []string{"trash f", "git rm f", "echo rm", "watch -n 1 ls", "chronic ls", "[ -f x ] && echo y",
			`"$HOME/bin/tool" x`, "f() { echo; }; f"}},
	},
	"block-mux-kill": {
		{want: "deny", cmds: []string{"tmux kill-server", "tmux kill-session -t main", "tmux killp -t 1", "TMUX_TMPDIR=/tmp/x tmux kill-server",
			"pkill tmux", "killall tmux", `bash -c "tmux kill-server"`, "tmux -L default kill-server", "pkill tm[u]x",
			"pkill -f 'tmux.*'", "killall -m tmu."}},
		// the user's default socket, a variable socket, a kill of tmux's pids, a respawn that kills the pane's process,
		// and a kill inside a command tmux runs
		{want: "deny", cmds: []string{"tmux -S /private/tmp/tmux-501/default kill-server", `tmux -S "${TMUX%%,*}" kill-session -t main`,
			"kill $(pgrep tmux)", "pgrep tmux | xargs kill", "tmux respawn-pane -k -t main", "tmux run-shell 'tmux kill-server'",
			"tmux if-shell true '' kill-server"}},
		{want: "allow", cmds: []string{"tmux -L agent kill-server", "tmux -Lagent kill-session -t main", "tmux -S /tmp/s kill-server",
			"tmux ls", "pkill node", "pkill -u eric node", "pgrep tmux", "tmux -L agent respawn-pane -k -t x", "kill $(pgrep node)"}},
		{want: "deny", cmds: []string{"rex kill main", "rex session kill main", "rex -S narwhal kill main", "rex --timeout 5s kill x",
			`rex block close -s "$REX_SESSION" block:1`, "rex window close window:1", "rex server stop", "rex do pane.close",
			"rex -C studio do client.tab.close", "rex do session.close", "rex do confirm_close_tab", "rex do -b block:1 pane.close",
			"rex -S 'unix:///Users/eric/Library/Application%20Support/rex/server.sock' kill x", "pkill rex", "killall 'Rex Beta'",
			"pkill -f 're[x]'", "rex kill agent-test-a main", "rex kill agent-x", "rex block close session:1",
			"rex session kill agent-test", "rex kill",
			// rex api and Lua reach the same actions
			"rex api call -s main session.destroy", `rex api call block.close '{"block_id":"block:1"}'`, "rex api call server.stop",
			"rex api call session.close_window", `rex do -e 'rex.call("session.destroy", {session_id="x"})'`, "rex do - < kill.lua"}},
		{want: "allow", cmds: []string{"rex ls", "rex new x", "rex split --split=right", "rex do popup_closed", "rex do session.select",
			"rex do -e 'return 1'", "rex -S unix:///tmp/agent.sock kill x", "rex --server=/tmp/agent.sock block close block:1",
			"rex block inspect block:1", "rex capture -b block:1", "rex kill agent-test-popup", "rex kill agent-test-a agent-test-b",
			"rex session kill agent-test-x", `rex block close -s "$REX_SESSION" agent-test-codex`, "rex window close agent-test-w",
			"rex api ls", "rex api call session.list", `rex do -e 'return rex.call("session.list")'`}},
	},
	"block-pipe-head-tail": {
		{want: "deny", cmds: []string{"ssh turtle 'ls ~/.ssh' | tail -6", "nix build . 2>&1 | tail -n 20", "rg x . | head", "a | b | head -1",
			"git log | head -c 100", `bash -c "ls | tail"`, "ls | tee /dev/null | tail -3", "ls | sudo tail -2", "cat log | tail -", "ls |& head",
			// a process substitution or a here-string of command output is a pipe too, and a tee saves only its own pipeline
			"head -n 5 <(nix build .)", "tail -n 20 < <(nix build . 2>&1)", "nix build . 2>&1 > >(tail -n 5)", `head -c 10 <<< "$(git log)"`,
			"echo hi | tee out.log; git log | head", "git log | head -5 | tee out.log",
			// - reads the pipe beside a file, and a tee into a substitution saves nothing
			"git log | head -n 5 - f", "git log | tee >(cat) | head"}},
		{want: "allow", cmds: []string{"tail -n 20 out.log", "head -c 100 /dev/urandom", "nix build . 2>&1 | tee out.log | tail -n 5",
			"tail -f log | rg error", "ls | rg x", "cat f | head -n 5 f", `echo "ls | head"`, "ls > out.log; tail out.log"}},
	},
	"block-exec-flags": {
		{want: "deny", cmds: []string{"fd . -x rm", "fd -e png -X convert", "fd --exec rm", "fd --exec-batch=rm", "rg --pre sh x .",
			"rg --pre=./p x", "sort -o out in", "sort -oout in", "sort --output=out in", "sort --output out in", "tree -o out",
			"git diff --output=/tmp/x", "git log --output /tmp/x", "git -C . show --output=/tmp/x", "command fd -x rm", "fd -Hx echo",
			"sort -S 1K --compress-program=./c in", "sort --compress-program ./c in", "rg --hostname-bin=./p --hyperlink-format=default x .",
			"rg --hostname-bin ./p x", "sort -mo out a b", "fd -1x echo", "tree -fo out", "uniq in out"}},
		{want: "allow", cmds: []string{"fd -e nix .", "fd -t x .", "fd -tx .", "rg -n foo .", "rg --pretty foo", "sort -u in", "tree -L 2",
			"git diff --stat", "git log --oneline", "git diff -- --output", "sort -m a b", "rg --hyperlink-format=default x .", "uniq -c in",
			"sort -k1,1 in"}},
	},
	// a relative write after a cd the guard cannot follow could land on any file, so it denies
	"block-unresolved-write": {
		{want: "deny", cmds: []string{`cd "$d" && echo x > f`, "cd $dir/sub && sed -i s/a/b/ f", `cd "$d"; cp /tmp/x out`,
			`cd "$d" && python3 -c "open(\"f\", \"w\")"`, `cd -- "${d:?}" && echo x > f`, `cd "$d" && truncate -s 0 a /tmp/b`,
			`cd "$d" && cp -t . /tmp/x`, `cd "$d" && dd if=/tmp/x of=f`,
			// a path built from a value the guard cannot know names no file it can check
			"r=$(pwd); echo x > $r/tracked.txt", `echo x > "$(git rev-parse --show-toplevel)/f"`}},
		{want: "allow", cmds: []string{`cd "$d" && echo x > /tmp/abs`, `cd "$d" && rg x .`, `cd "$d" && make 2>/dev/null`,
			`cd "$d" && make 2>&1`, "cd sub && echo x > f", `cd "$d" && sed -i s/a/b/ /tmp/abs`,
			`d=sub; cd -- "${d:?}" && echo x > f`, `d=sub; cd "${d?}" && echo x > f`,
			`cd "$d" && python3 --version; rg -n 'write_text' /abs/src`, "echo x > $HOME/f"}},
	},
	"treefmt-on-edit": {
		{want: "quiet", files: []string{"tracked.txt"}},
	},
	"warn-comment-block": {
		{want: "warn", files: []string{"comments.ts"}, edits: "// one\n// two\n// three\n// four"},
		{want: "warn", files: []string{"comments.lua"}, edits: "-- one\n-- two\n-- three\n-- four"},
		{want: "quiet", files: []string{"comments.lua"}, edits: "-- one\n-- two\nlocal x = 1"},
		{want: "quiet", files: []string{"comments.ts"}, edits: "// one\n// two\ncode"},
		{want: "quiet", files: []string{"header.sh"}, content: "#!/usr/bin/env bash\n# one\n# two\n# three\n# four\ncode"},
		{want: "warn", files: []string{"header.sh"}, content: "#!/usr/bin/env bash\n# one\n# two\n# three\n# four\ncode\n# a\n# b\n# c\n# d"},
	},
}

func TestChecks(t *testing.T) {
	for check, groups := range cases {
		post := slices.ContainsFunc(postChecks, func(c postCheck) bool { return c.name == check })
		t.Run(check, func(t *testing.T) {
			for i, g := range groups {
				t.Run(strconv.Itoa(i), func(t *testing.T) { g.run(t, check, post) })
			}
		})
	}
}

func TestEveryCheckHasCases(t *testing.T) {
	var names []string
	for _, c := range preChecks {
		names = append(names, c.name)
	}
	for _, c := range postChecks {
		names = append(names, c.name)
	}
	for _, n := range names {
		if len(cases[n]) == 0 {
			t.Errorf("no cases for the check %s", n)
		}
	}
	for n := range cases {
		if !slices.Contains(names, n) {
			t.Errorf("cases name %s, which is not a check", n)
		}
	}
}

// the trailer goes and the message stays, in a -m with real newlines, inline, and in a heredoc
func TestStripAttributionRewrites(t *testing.T) {
	robot := string(rune(0x1F916))
	for _, tc := range []struct{ cmd, keeps string }{
		{"git commit -m 'subject\n\nCo-Authored-By: Claude <noreply@anthropic.com>'", "git commit -m 'subject"},
		{`git commit -m "fix parser. Co-Authored-By: Claude"`, "fix parser."},
		{"git commit -F - <<'EOF'\nadd the thing\n\nbody line\n\n" + robot + " Generated with [Claude Code](https://claude.com/claude-code)\n\nCo-Authored-By: Claude <noreply@anthropic.com>\nEOF",
			"add the thing\n\nbody line"},
		// -m in a cluster, and a message from a cat heredoc inside -m
		{"git commit -am 'fix\n\nCo-Authored-By: Claude <noreply@anthropic.com>'", "git commit -am 'fix"},
		{"git commit -m \"$(cat <<'EOF'\nsubject\n\nCo-Authored-By: Claude <noreply@anthropic.com>\nEOF\n)\"", "subject"},
	} {
		o := runPreHook(t, "claude", cmdInput(t.TempDir(), tc.cmd), "strip-claude-attribution")
		if o.command == nil || !strings.Contains(*o.command, tc.keeps) ||
			slices.ContainsFunc([]string{"co-authored-by", "generated with", robot}, func(s string) bool { return strings.Contains(strings.ToLower(*o.command), s) }) {
			t.Errorf("%q rewrote to %v", tc.cmd, o.command)
		}
	}
}

// the dry run that judges a just recipe passes only the justfile and the recipes, so the agent's own options never run
func TestJustDryRunRunsNothing(t *testing.T) {
	if _, err := exec.LookPath("just"); err != nil {
		t.Skip("just is not on PATH")
	}
	f := newFixture(t)
	for _, cmd := range []string{"just --command touch {real}/ran", "just -c touch {real}/ran", "just --init", "just --edit"} {
		runPreHook(t, "claude", cmdInput(filepath.Join(f.repo, "jb"), f.expand(cmd)), "git-add-before-nix")
	}
	if exists(filepath.Join(f.real, "ran")) {
		t.Error("the check ran the agent's just --command")
	}
	if got, _ := os.ReadFile(filepath.Join(f.real, "jb/justfile")); !strings.Contains(string(got), "latexmk") {
		t.Errorf("the justfile changed: %q", got)
	}
}

// trailer words outside a commit message, or mid-line in one, are text, not a trailer
func TestStripAttributionLeavesText(t *testing.T) {
	for _, cmd := range []string{
		`git commit -m "guard: handle Claude-Session: trailers"`,
		"rg -n 'generated with claude' a.txt; git commit -m y",
		`git commit -m "strip-claude-attribution: also match 'Generated with Claude'"`,
	} {
		if o := runPreHook(t, "claude", cmdInput(t.TempDir(), cmd), "strip-claude-attribution"); o.command != nil {
			t.Errorf("%q rewrote to %q", cmd, *o.command)
		}
	}
}

// pi sends each edit's new text, and two short comments in two edits are not one long block
func TestWarnCommentBlockEdits(t *testing.T) {
	dir := t.TempDir()
	f := filepath.Join(dir, "m.ts")
	if err := os.WriteFile(f, []byte("code\n// a\n// b\ncode\n// c\n// d\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	in := map[string]any{"cwd": dir, "tool_input": map[string]any{"file_path": f, "edits": []any{
		map[string]any{"new_string": "// a\n// b"}, map[string]any{"new_string": "// c\n// d"}}}}
	raw, _ := json.Marshal(in)
	var stderr bytes.Buffer
	if code := run([]string{"post", "pi", "warn-comment-block"}, bytes.NewReader(raw), io.Discard, &stderr); code != 0 {
		t.Errorf("exit %d: %s", code, stderr.String())
	}
}

// the warning names the line the added block ends on, even when a short line like # appears earlier
func TestWarnCommentBlockLocation(t *testing.T) {
	dir := t.TempDir()
	f := filepath.Join(dir, "loc.sh")
	block := "# one\n# two\n# three\n#"
	if err := os.WriteFile(f, []byte("#\ncode\n"+block+"\ncode\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	raw, _ := json.Marshal(map[string]any{"cwd": dir, "tool_input": map[string]any{"file_path": f, "new_string": block}})
	var stderr bytes.Buffer
	run([]string{"post", "claude", "warn-comment-block"}, bytes.NewReader(raw), io.Discard, &stderr)
	if !strings.Contains(stderr.String(), f+":6") {
		t.Errorf("got %q, want the block's last line, %s:6", stderr.String(), f)
	}
}

// a treefmt that hangs is given up on, so the edit's other post checks still report
func TestTreefmtOnEditGivesUp(t *testing.T) {
	if _, err := exec.LookPath("direnv"); err != nil {
		t.Skip("direnv is not on PATH")
	}
	dir, err := filepath.EvalSymlinks(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	for path, content := range map[string]string{".envrc": "PATH_add bin\n", "bin/treefmt": "#!/bin/sh\nsleep 30\n", "file.txt": "raw\n"} {
		_ = os.MkdirAll(filepath.Dir(filepath.Join(dir, path)), 0o755)
		if err := os.WriteFile(filepath.Join(dir, path), []byte(content), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv("XDG_DATA_HOME", dir+"/xdg")
	t.Setenv("XDG_CONFIG_HOME", dir+"/xdg")
	if out, err := exec.Command("direnv", "allow", dir).CombinedOutput(); err != nil {
		t.Fatalf("direnv allow: %v\n%s", err, out)
	}
	saved := treefmtTimeout
	defer func() { treefmtTimeout = saved }()
	treefmtTimeout = 2 * time.Second
	raw, _ := json.Marshal(map[string]any{"cwd": dir, "tool_input": map[string]any{"file_path": dir + "/file.txt", "content": ""}})
	start := time.Now()
	run([]string{"post", "claude", "treefmt-on-edit"}, bytes.NewReader(raw), io.Discard, io.Discard)
	if took := time.Since(start); took > 10*time.Second {
		t.Errorf("treefmt-on-edit took %v", took)
	}
}

// on a filesystem that ignores case, a tracked file written under another case is still that file
func TestTrackedIgnoresCase(t *testing.T) {
	f := newFixture(t)
	upper := filepath.Join(f.repo, "TRACKED.txt")
	if !exists(upper) {
		t.Skip("the filesystem tells case apart")
	}
	if !tracked(upper) {
		t.Error("TRACKED.txt does not count as tracked.txt")
	}
}

// a push that is allowed or asked for does not let a gh write through
func TestPushDoesNotSkipGh(t *testing.T) {
	for _, mode := range []string{"on", "ask"} {
		f := newFixture(t)
		config(".", "eric-agent.push", mode)(f)
		if o := runPreHook(t, "claude", cmdInput(f.repo, "git push; gh pr merge 1"), "block-agent-push", "block-gh-write"); o.kind != "deny" || !strings.Contains(o.reason, "gh") {
			t.Errorf("push %s: got %q %q, want gh's deny", mode, o.kind, o.reason)
		}
	}
}

// the attribution rewrite comes with an ask in an ask repo
func TestAskKeepsRewrite(t *testing.T) {
	f := newFixture(t)
	config(".", "eric-agent.commit", "ask")(f)
	in := cmdInput(f.repo, "git commit -m 'x\n\nCo-Authored-By: Claude <noreply@anthropic.com>'")
	if o := runPreHook(t, "claude", in, "block-agent-commit", "strip-claude-attribution"); o.kind != "ask" || o.command == nil || strings.Contains(*o.command, "Co-Authored-By") {
		t.Errorf("got %s with %v", o.kind, o.command)
	}
}

// the default lists run for Monitor as for Bash
func TestMonitorRunsShellChecks(t *testing.T) {
	in := map[string]any{"cwd": t.TempDir(), "tool_name": "Monitor", "tool_input": map[string]any{"command": "rm f"}}
	if o := runPreHook(t, "claude", in); o.kind != "deny" {
		t.Errorf("got %q, want deny", o.kind)
	}
}

// a stub treefmt that rewrites the file and fails shows the hook ran it and still exits silently
func TestTreefmtOnEditRunsTreefmt(t *testing.T) {
	if _, err := exec.LookPath("direnv"); err != nil {
		t.Skip("direnv is not on PATH")
	}
	// direnv exec does not match an allow made through a symlinked path like /tmp
	dir, err := filepath.EvalSymlinks(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	for path, content := range map[string]string{
		".envrc":      "PATH_add bin\n",
		"bin/treefmt": "#!/bin/sh\nprintf \"formatted\\n\" >\"$1\"\nexit 1\n",
		"file.txt":    "raw\n",
	} {
		_ = os.MkdirAll(filepath.Dir(filepath.Join(dir, path)), 0o755)
		if err := os.WriteFile(filepath.Join(dir, path), []byte(content), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	// a private direnv allow list and config keep the user's direnv state out of the test
	t.Setenv("XDG_DATA_HOME", dir+"/xdg")
	t.Setenv("XDG_CONFIG_HOME", dir+"/xdg")
	if out, err := exec.Command("direnv", "allow", dir).CombinedOutput(); err != nil {
		t.Fatalf("direnv allow: %v\n%s", err, out)
	}
	raw, _ := json.Marshal(map[string]any{"cwd": dir, "tool_input": map[string]any{"command": "", "file_path": dir + "/file.txt", "content": ""}})
	var stdout bytes.Buffer
	if code := run([]string{"post", "claude", "treefmt-on-edit"}, bytes.NewReader(raw), &stdout, io.Discard); code != 0 || stdout.Len() > 0 {
		t.Errorf("exit %d, output %q", code, stdout.String())
	}
	if got, _ := os.ReadFile(dir + "/file.txt"); string(got) != "formatted\n" {
		t.Errorf("treefmt did not run: file holds %q", got)
	}
}
