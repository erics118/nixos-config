package main

import (
	"bytes"
	"encoding/json"
	"io"
	"slices"
	"strings"
	"testing"

	"mvdan.cc/sh/v3/syntax"
)

func decide(t *testing.T, args ...string) string {
	t.Helper()
	var out bytes.Buffer
	if code := run(args, strings.NewReader(`{"tool_input":{"command":"ls"}}`), &out, io.Discard); code != 0 {
		t.Fatalf("exit %d", code)
	}
	var d struct {
		HookSpecificOutput struct {
			PermissionDecision string `json:"permissionDecision"`
		} `json:"hookSpecificOutput"`
	}
	if err := json.Unmarshal(out.Bytes(), &d); err != nil {
		t.Fatalf("output %q: %v", out.String(), err)
	}
	return d.HookSpecificOutput.PermissionDecision
}

func TestPanickingCheckDenies(t *testing.T) {
	saved := preChecks
	defer func() { preChecks = saved }()
	preChecks = append(slices.Clone(saved), preCheck{meta{"test-panic", shellTools}, func(*hook) decision { panic("boom") }})
	if got := decide(t, "pre", "claude", "test-panic"); got != "deny" {
		t.Fatalf("got %q, want deny", got)
	}
}

func TestUnknownCheckDenies(t *testing.T) {
	if got := decide(t, "pre", "claude", "no-such-check"); got != "deny" {
		t.Fatalf("got %q, want deny", got)
	}
}

func TestCheckTable(t *testing.T) {
	known := []string{"Bash", "Monitor", "Read", "Write", "Edit"}
	seen := map[string]bool{}
	var all []meta
	for _, c := range preChecks {
		all = append(all, c.meta)
	}
	for _, c := range postChecks {
		all = append(all, c.meta)
	}
	for _, m := range all {
		if seen[m.name] {
			t.Errorf("two checks are named %s", m.name)
		}
		seen[m.name] = true
		if len(m.tools) == 0 {
			t.Errorf("no tool runs %s", m.name)
		}
		for _, tool := range m.tools {
			if !slices.Contains(known, tool) {
				t.Errorf("%s runs on %s, which no harness sends", m.name, tool)
			}
		}
	}
}

// the walk itself, not the fallback for calls it misses, must reach a call inside each construct
func TestWalkReachesEveryCall(t *testing.T) {
	for _, src := range []string{
		"if rm f; then rm f; elif rm f; then rm f; else rm f; fi",
		"while rm f; do rm f; done", "until rm f; do rm f; done",
		"for x in $(rm f); do rm f; done", "for ((i = 0; i < 1; i++)); do rm f; done",
		"case $(rm f) in a) rm f ;; esac", "f() { rm f; }", "time rm f", "! rm f", "rm f &",
		"[[ -n $(rm f) ]]", "(( $(rm f) ))", "coproc rm f", "{ rm f; } > out", "(rm f)",
		"rm f | cat", "cat | rm f", "x=$(rm f)", "local x=$(rm f)", "export x=$(rm f)",
		"echo <(rm f)", "echo $(rm f) > $(rm f)", "cat <<EOF\n$(rm f)\nEOF", "eval 'rm f'", "bash -c 'rm f'",
	} {
		w := walker{visited: map[*syntax.CallExpr]bool{}}
		if err := w.file(src, newState("/repo"), 0); err != nil {
			t.Errorf("%q: %v", src, err)
			continue
		}
		if w.missed > 0 {
			t.Errorf("%q: the walk missed %d calls", src, w.missed)
		}
		if !slices.ContainsFunc(w.calls, func(c call) bool { return c.tool() == "rm" }) {
			t.Errorf("%q: no rm call collected", src)
		}
	}
}

func TestWalkFollowsDirectories(t *testing.T) {
	for _, tc := range []struct{ src, want string }{
		{"cd sub && rm f", "/repo/sub"},
		{"cd sub; cd ..; rm f", "/repo"},
		{"(cd sub); rm f", "/repo"},
		{"pushd sub; popd; rm f", "/repo"},
		{"d=sub; cd $d; rm f", "/repo/sub"},
		{"cd $d; rm f", ""},
		{"true || cd sub; rm f", ""},
		{"if true; then cd sub; fi; rm f", ""},
		{"eval cd sub; rm f", "/repo/sub"},
		{"bash -c 'cd sub'; rm f", "/repo"},
		{"env -C sub rm f", "/repo/sub"},
		{"env -C a -C b rm f", "/repo/b"},
		{"cd /tmp && rm f", "/tmp"},
		{"false && cd sub; rm f", ""},
		{"git status && cd sub && rm f", "/repo/sub"},
		{"if false; then cd sub; else rm f; fi", "/repo"},
		{"f() { cd sub; }; f; rm f", "/repo/sub"},
		{"cd sub & rm f", "/repo"},
		{"cd /tmp; cd /; cd -; rm f", "/tmp"},
		{"cd -LP sub; rm f", "/repo/sub"},
		{"d=.; read d; cd $d; rm f", ""},
		{"pushd sub; false || pushd ..; popd; rm f", ""},
	} {
		calls, err := parseCalls(tc.src, "/repo")
		if err != nil {
			t.Fatalf("%q: %v", tc.src, err)
		}
		i := slices.IndexFunc(calls, func(c call) bool { return c.tool() == "rm" })
		if i < 0 {
			t.Fatalf("%q: no rm call", tc.src)
		}
		if got := calls[i].dir; got != tc.want {
			t.Errorf("%q: rm runs in %q, want %q", tc.src, got, tc.want)
		}
	}
}

func TestBadEventDenies(t *testing.T) {
	var out bytes.Buffer
	run([]string{"pre", "claude"}, strings.NewReader("not json"), &out, io.Discard)
	if !strings.Contains(out.String(), `"deny"`) {
		t.Fatalf("got %q, want a deny", out.String())
	}
	// a post hook cannot block a call that already ran, so it reports with a nonzero exit
	if code := run([]string{"post", "claude"}, strings.NewReader("not json"), io.Discard, io.Discard); code == 0 {
		t.Fatal("post hook exited 0 on a bad event")
	}
}

// a branch that may run leaves every directory it could have chosen, so a search can still see a root among them
func TestBranchKeepsPossibleDirs(t *testing.T) {
	calls, err := parseCalls("true || cd /; rm f", "/repo")
	if err != nil {
		t.Fatal(err)
	}
	i := slices.IndexFunc(calls, func(c call) bool { return c.tool() == "rm" })
	if got := calls[i].dirs(); !slices.Equal(got, []string{"/", "/repo"}) {
		t.Fatalf("rm may run in %q, want / and /repo", got)
	}
}
