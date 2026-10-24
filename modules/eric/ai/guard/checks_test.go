package main

import (
	"bytes"
	"encoding/json"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"testing"
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
	harness := cmp(g.harness, "claude")
	var inputs []any
	for _, c := range g.cmds {
		inputs = append(inputs, cmdInput(filepath.Join(f.repo, g.dir), f.expand(c)))
	}
	for _, p := range g.files {
		in := map[string]any{"command": "", "file_path": filepath.Join(f.repo, f.expand(p)), "content": g.content}
		if g.edits != "" {
			in = map[string]any{"file_path": in["file_path"], "edits": []any{map[string]any{"new_string": g.edits}}}
		}
		inputs = append(inputs, map[string]any{"cwd": f.repo, "tool_input": in})
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

func cmp(s, fallback string) string {
	if s == "" {
		return fallback
	}
	return s
}

func config(dir string, kv ...string) func(f *fixture) {
	return func(f *fixture) {
		for i := 0; i < len(kv); i += 2 {
			f.git(dir, "config", kv[i], kv[i+1])
		}
	}
}

func shellQuote(s string) string { return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'" }

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
	},
	"block-smart-punct": {
		{want: "deny", files: []string{"new.txt"}, content: "em dash: " + string(rune(0x2014))},
		{want: "allow", files: []string{"new.txt"}, content: `dash: - quotes: "x"`},
	},
	"block-git-config-edit": {
		{want: "deny", files: []string{".git/config", "{home}/.gitconfig"}},
		{want: "allow", files: []string{"config"}},
		{want: "deny", cmds: []string{"echo x > .git/config", "cp /tmp/x .git/config", "sudo cp /tmp/x .git/config",
			"printf x > ~/.gitconfig", "cp /tmp/x ~/.config/git/config",
			"{ echo x; } >> .git/config", "(echo x) > .git/config", ">> .git/config <<< x", "echo x 1<> .git/config",
			"echo x >& .git/config", "echo x > .git//config", "echo x > .GIT/config", "cd .git && echo x >> config",
			"echo x > /tmp/x/git/config"}},
		{want: "allow", cmds: []string{"cat .git/config", "sudo cat .git/config", "cat ~/.gitconfig", "rg -n python ~/.gitconfig"}},
	},
	"block-eric-top": {
		{want: "deny", files: []string{".eric/x.txt", ".eric/tmp/x.txt"}},
		{want: "allow", files: []string{".eric/scratch/2026-01-01-x/x.txt", ".eric/notes/2026-01-01-x.md", ".eric/reminders.md", "x/.eric.txt"}},
		{env: map[string]string{"HOME": "{home}"}, want: "deny", cmds: []string{"echo x > .eric/x.txt", `zsh -c 'log foo' 2>"$HOME/.eric/err.txt"`,
			"touch ~/.eric/x", "mkdir -p .eric/tmp", "cp /tmp/x .eric/", "mv /tmp/x ~/.eric/y", "echo x | tee .eric/x", "cd .eric && echo x > y"}},
		{env: map[string]string{"HOME": "{home}"}, want: "allow", cmds: []string{"echo x > .eric/scratch/2026-01-01-x/x.txt", "mkdir -p ~/.eric/scratch/2026-01-01-x",
			"cp /tmp/x .eric/notes/", "cat .eric/x.txt", "ls ~/.eric"}},
		{setup: func(f *fixture) { f.write("AGENTS.md", "keep the catalog in `.eric/catalog/`\n") }, want: "allow", cmds: []string{"echo x > .eric/catalog/a.txt"}},
	},
	"block-write-tracked": {
		{want: "deny", files: []string{"tracked.txt"}},
		{want: "allow", files: []string{"untracked.nix", "new.txt"}},
	},
	"git-add-before-nix": {
		{want: "deny", cmds: []string{"nix build", "sudo darwin-rebuild switch --flake .", "just switch", "nh darwin switch",
			"nix flake check", "nix -L build", "nix --print-build-logs build", "nix shell .#hello"}},
		{want: "allow", cmds: []string{"git status", "rg -n home-manager modules", "ls ~/.local/state/home-manager /tmp",
			// the dry run and the untracked check use the directory a later cd moves to
			"git status && cd jb && just build",
			`cd "$d" && nix build`}},
		{dir: "jb", want: "allow", cmds: []string{"just build"}},
		{dir: "jb", want: "deny", cmds: []string{"just switch", "just -f justfile switch"}},
		{dir: "sub", want: "deny", cmds: []string{"darwin-rebuild switch --flake ."}},
		{dir: "sub", setup: func(f *fixture) { f.git("sub", "add", "new.lua") }, want: "allow", cmds: []string{"nix build"}},
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
			"rg x /tmp/..", "find -O3 / -name x", "find -x / -name x", "rg -- -foo /", "egrep -r x /", "rg -e foo /"}},
		{want: "allow", cmds: []string{`cd "${d:?}" && rg -l GitSignsUpdate .`, `cd "$d" && rg x .`, "cd $dir/sub && rg x .", "cd $d && ls",
			`echo "cd $d && rg x ."`, "cd ${d:?} && rg x .", "rg foo .", "fd x .", "find . -name x", "rg foo {repo}",
			"grep -n x /nix/store/abc-etc-zshenv", "rg / src", `echo "rg x /"`, "cat <<EOF\nrg x /\nEOF", "echo ${(f)x}",
			"d=/tmp; cd $d && rg x .", "cd $d && rg x /tmp", "cd / & rg x ."}},
	},
	"block-symlink-clobber": {
		{want: "deny", cmds: []string{"echo x > managed-link", "mv /tmp/x managed-link && echo ok", "cp /tmp/x managed-link; ls",
			"cp /tmp/x managed-link 2>/dev/null", "printf x | tee managed-link >/dev/null", "cp a b; cp /tmp/x managed-link",
			"echo x &> managed-link", "echo x >| managed-link", "sed -i s/a/b/ managed-link", "truncate -s 0 managed-link",
			"{ echo x; } > managed-link"}},
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
			"git reset --keep HEAD~1", "git reset --merge", "gh pr checkout -f 1", "gh pr checkout 1 --force"}},
		{want: "allow", cmds: []string{"git stash list", "git clean -n", "git checkout main", "git switch -c feat", "git worktree remove x",
			"git restore --staged f", "git restore -S f", "git branch -d x", "git rebase --continue", "git rebase --abort",
			"git rebase --quit", "git reset", "git reset -q", "git reset -- f", "git reset HEAD -- f", "gh pr checkout 1"}},
	},
	"block-agent-commit": {
		{want: "deny", cmds: []string{"git status --short\ngit commit -m x", "direnv exec . git commit -m x", `bash -c "git commit -m x"`,
			"git -c 'alias.c=commit -m x' c", "git -calias.c=commit c", "bash -c 'echo \"a\nb\"\ngit commit -m x'", "git pull",
			"git pull --rebase", "git commit-tree HEAD^{tree} -m x", "git subtree add --prefix=x r main", "git -c include.path=/tmp/x c",
			"git --config-env=alias.c=X c", "git --config-env alias.c=X c",
			"GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=alias.c GIT_CONFIG_VALUE_0=commit git c", "env GIT_DIR=sub/.git git commit -m x",
			"export GIT_CONFIG_GLOBAL=/tmp/x", "git config alias.c commit", "git config include.path /tmp/x", "git config --edit",
			"git commit -m --abort", "git commit -m --dry-run", "git commit -- --dry-run", "git commit --author --dry-run -m x",
			"git config include.path get", "git config set eric-agent.commit list", "git rebase main", "git rebase --continue",
			"git config eric-agent.commit on", "XDG_CONFIG_HOME=/tmp/x git status"}},
		// wrappers that run git as a later word, and shells that read their script from a here-string or heredoc
		{want: "deny", cmds: []string{"caffeinate git commit -m x", "noglob git commit -m x", "stdbuf -o0 git commit -m x",
			"flock /tmp/l git commit -m x", "flock /tmp/l -c 'git commit -m x'", "xcrun git commit -m x", "env -S 'git commit -m x'",
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
			"git commit-tree HEAD^{tree} -m x", "git subtree add --prefix=x r main"}},
		{setup: config(".", "eric-agent.commit", "ask"), want: "ask", cmds: []string{"git commit -m x"}},
		{setup: func(f *fixture) {
			config(".", "eric-agent.commit", "ask")(f)
			config("sub", "eric-agent.commit", "on")(f)
		}, want: "ask", cmds: []string{"git -C sub commit -m x; git commit -m x"}},
		{setup: config(".", "eric-agent.commit", "ask"), harness: "codex", want: "deny", cmds: []string{"git commit -m x"}},
		// a configured alias is expanded, and one that runs a shell command denies, since no check can see into it
		{setup: config(".", "alias.ci", "commit", "alias.sh", "!git commit"), want: "deny", cmds: []string{"git ci -m x", "git sh"}},
	},
	"block-agent-push": {
		{setup: config(".", "eric-agent.push", "ask"), want: "ask", cmds: []string{"git push"}},
		{setup: config(".", "eric-agent.push", "ask"), harness: "codex", want: "deny", cmds: []string{"git push"}},
		{setup: config(".", "eric-agent.push", "ask"), want: "deny", cmds: []string{"git push; gh pr merge 1"}},
		{want: "deny", cmds: []string{"git push", "caffeinate git push", "noglob git push", "nix run nixpkgs#git -- push",
			"bash <<<'git push'", "git send-pack origin main", "git subtree push --prefix=x origin main", "git lfs push origin main",
			"GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=alias.p GIT_CONFIG_VALUE_0=push git p", "git --config-env=alias.p=X p",
			"git push -o --dry-run origin main", "git push origin -- -n",
			"direnv exec . git push", "nix develop -c git push", "xargs git push", `find . -exec git push \;`, "timeout 10 git push",
			`bash -c "git push origin main"`, "direnv exec . gh pr create", `bash -c "gh pr create"`, "bash -l -c 'git push'",
			"bash -ec 'git push'", "sh -xc 'git push'", `bash -c "echo \"a\"; git push"`, "env -i git push", "command -p git push",
			"sudo git push", "nice git push", "nohup git push", "time git push", "eval git push", "git -P push",
			"git -c 'alias.p=!git push' p", "git -c alias.p=push p"}},
		{want: "allow", cmds: []string{"git push --dry-run", "git push -n origin main", "direnv exec . git status",
			"nix develop -c git status", `bash -c "echo hi"`, "bash -c 'echo hi'", `echo "git push"`, `rg -n "bash -c 'git push'" docs`,
			`echo "a; git push"`, "cat <<EOF\ngit push\nEOF"}},
		// -C names the repo whose eric-agent.push applies, and every repo a command pushes from must allow it
		{setup: config("sub", "eric-agent.push", "on"), want: "allow", cmds: []string{"git -C sub push"}},
		{setup: config("sub", "eric-agent.push", "on"), want: "deny", cmds: []string{"git -C sub push; git push"}},
		{setup: config(".", "eric-agent.push", "on"), want: "allow", cmds: []string{"git push", "git send-pack origin main",
			"git subtree push --prefix=x origin main", "git lfs push origin main"}},
		// an allowed push does not skip the gh checks
		{setup: config(".", "eric-agent.push", "on"), want: "deny", cmds: []string{"git push; gh pr merge 1"}},
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
		{want: "deny", cmds: []string{"sed -i s/tracked/changed/ tracked.txt", "echo x > tracked.txt", "printf x | tee -a tracked.txt",
			`python3 -c "open('tracked.txt', 'w').write('x')"`, "perl -pi -e s/a/b/ tracked.txt", "printf x | tee new.txt tracked.txt",
			"cd sub && sed -i s/a/b/ flake.nix", `echo x > "$PWD/tracked.txt"`, "echo x > ${PWD}/tracked.txt", "cp /tmp/x tracked.txt",
			"mv /tmp/x tracked.txt", "cp -f /tmp/x /tmp/y tracked.txt", "git status && cd sub && echo x > flake.nix",
			"(cd sub) && echo x > tracked.txt", "F=tracked.txt; echo x > $F",
			// a runner that starts the interpreter still counts as a script
			`uv run python -c "open('tracked.txt', 'w').write('x')"`,
			"{ echo x; } > tracked.txt", `perl -e 'open(F, ">tracked.txt")'`, `ruby -e "File.write('tracked.txt', 'x')"`,
			`node -e "require('fs').appendFileSync('tracked.txt', 'x')"`, `python3 -c "open(\"tracked.txt\", \"w\")"`}},
		{env: map[string]string{"HOME": "{repo}"}, want: "deny", cmds: []string{`echo x > "$HOME/tracked.txt"`, "echo x > ${HOME}/tracked.txt"}},
		{want: "allow", cmds: []string{"sed -n p tracked.txt", "sed -i s/a/b/ untracked.nix", "echo x > new.txt",
			"cat tracked.txt > /dev/null", "cp tracked.txt /tmp/x", "mv tracked.txt", "cp /tmp/x.png blob.png", "mv new.png blob.png",
			`echo "python: open('tracked.txt', 'w')"`}},
	},
	"block-sudo-probe": {
		{env: map[string]string{"PATH": "{repo}/bin:{path}"}, want: "deny",
			cmds: []string{"sudo -n true", "sudo --non-interactive true", "sudo -u root -n true", "sudo -nv"}},
		{env: map[string]string{"PATH": "{repo}/bin:{path}"}, want: "allow", cmds: []string{"sudo true", "sudo -u nobody true"}},
	},
	"block-rm": {
		{want: "deny", cmds: []string{"rm f", "rm -rf /tmp/x", "/bin/rm f", "command rm f", "fd -0 . | xargs -0 rm", `bash -c "rm f"`,
			"sudo rm f", "doas rm f", "doas -u root rm f", "ionice -c 3 rm f", "chronic rm f", "unbuffer rm f", "watch rm f",
			"watch -n 1 'rm f'", "script -qc 'rm f' /dev/null", "coproc rm f", nestedRm(),
			// commands only the walk's control flow, wrapper options, or command-name rules reveal
			`builtin eval "rm f"`, `command eval "rm f"`, "c=" + shellQuote("rm -f nothing-here;") + "; eval $c$c$c$c$c$c",
			"sudo --user root rm f", "timeout --signal KILL 5 rm f", "nice --adjustment 5 rm f", "xargs --max-args 1 rm",
			"env -vC . rm f", `env -iS "rm f"`, "exec -a x rm f", `$'\x72m' f`, "/bin/r[m] f", "$(printf rm) f", "R=rm; $R f",
			"f() { rm x; }; f", "cd sub & rm f"}},
		// the default lists run under pi as under claude
		{harness: "pi", want: "deny", cmds: []string{"rm f"}},
		// a command the guard cannot parse is denied before any check runs
		{want: "deny", reason: "could not parse", cmds: []string{`echo "unterminated`}},
		{want: "allow", cmds: []string{"trash f", "git rm f", "echo rm", "watch -n 1 ls", "chronic ls", "[ -f x ] && echo y",
			`"$HOME/bin/tool" x`, "f() { echo; }; f"}},
	},
	"block-tmux-kill": {
		{want: "deny", cmds: []string{"tmux kill-server", "tmux kill-session -t main", "tmux killp -t 1", "TMUX_TMPDIR=/tmp/x tmux kill-server",
			"pkill tmux", "killall tmux", `bash -c "tmux kill-server"`, "tmux -L default kill-server", "pkill tm[u]x",
			"pkill -f 'tmux.*'", "killall -m tmu."}},
		{want: "allow", cmds: []string{"tmux -L agent kill-server", "tmux -Lagent kill-session -t main", "tmux -S /tmp/s kill-server",
			"tmux ls", "pkill node", "pkill -u eric node"}},
	},
	"block-exec-flags": {
		{want: "deny", cmds: []string{"fd . -x rm", "fd -e png -X convert", "fd --exec rm", "fd --exec-batch=rm", "rg --pre sh x .",
			"rg --pre=./p x", "sort -o out in", "sort -oout in", "sort --output=out in", "sort --output out in", "tree -o out",
			"git diff --output=/tmp/x", "git log --output /tmp/x", "git -C . show --output=/tmp/x", "command fd -x rm", "fd -Hx echo"}},
		{want: "allow", cmds: []string{"fd -e nix .", "fd -t x .", "fd -tx .", "rg -n foo .", "rg --pretty foo", "sort -u in", "tree -L 2",
			"git diff --stat", "git log --oneline", "git diff -- --output"}},
	},
	// a relative write after a cd the guard cannot follow could land on any file, so it denies
	"block-unresolved-write": {
		{want: "deny", cmds: []string{`cd "$d" && echo x > f`, "cd $dir/sub && sed -i s/a/b/ f", `cd "$d"; cp /tmp/x out`,
			`cd "$d" && python3 -c "open(\"f\", \"w\")"`}},
		{want: "allow", cmds: []string{`cd "$d" && echo x > /tmp/abs`, `cd "$d" && rg x .`, `cd "$d" && make 2>/dev/null`,
			`cd "$d" && make 2>&1`, "cd sub && echo x > f", `cd "$d" && sed -i s/a/b/ /tmp/abs`}},
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
	} {
		o := runPreHook(t, "claude", cmdInput(t.TempDir(), tc.cmd), "strip-claude-attribution")
		if o.command == nil || !strings.Contains(*o.command, tc.keeps) ||
			slices.ContainsFunc([]string{"co-authored-by", "generated with", robot}, func(s string) bool { return strings.Contains(strings.ToLower(*o.command), s) }) {
			t.Errorf("%q rewrote to %v", tc.cmd, o.command)
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

// a nested parse error names the script, not the calls parsed before it
func TestNestedParseErrorNamesScript(t *testing.T) {
	if o := runPreHook(t, "claude", cmdInput(t.TempDir(), `echo hi; bash -c 'echo "x'`), "block-agent-commit"); strings.Contains(o.reason, "argv") {
		t.Errorf("reason %q names the parsed calls", o.reason)
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
