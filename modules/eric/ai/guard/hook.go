package main

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
)

// hook is one tool call as the harness reports it
type hook struct {
	harness   string
	toolName  string
	toolInput map[string]json.RawMessage
	rawInput  json.RawMessage
	command   string
	calls     []call
	// cwd is where the harness runs the command
	cwd   string
	tools map[string]bool
	// aliases caches git alias lookups by repo and name
	aliases map[string]string
}

func newHook(harness string, raw []byte) (*hook, error) {
	var in struct {
		ToolName  string          `json:"tool_name"`
		Cwd       string          `json:"cwd"`
		ToolInput json.RawMessage `json:"tool_input"`
	}
	if err := json.Unmarshal(raw, &in); err != nil {
		return nil, err
	}
	h := &hook{harness: harness, toolName: in.ToolName, rawInput: in.ToolInput, cwd: in.Cwd, tools: map[string]bool{}, aliases: map[string]string{}}
	if len(in.ToolInput) > 0 && string(in.ToolInput) != "null" {
		if err := json.Unmarshal(in.ToolInput, &h.toolInput); err != nil {
			return nil, err
		}
	}
	h.command = h.str("command")
	if h.cwd == "" {
		h.cwd, _ = os.Getwd()
	}
	return h, nil
}

// str is a string field of tool_input, or ""
func (h *hook) str(key string) string {
	var s string
	_ = json.Unmarshal(h.toolInput[key], &s)
	return s
}

// edit is the text a Write, Edit, or MultiEdit carries
type edit struct {
	Content   *string `json:"content"`
	NewString *string `json:"new_string"`
	OldString *string `json:"old_string"`
	Edits     []struct {
		NewString *string `json:"new_string"`
		OldString *string `json:"old_string"`
	} `json:"edits"`
}

func (h *hook) edit() edit {
	var e edit
	_ = json.Unmarshal(h.rawInput, &e)
	return e
}

// parse reads the command's calls and the tools they run
func (h *hook) parse() error {
	calls, err := parseCalls(h.command, h.cwd)
	if err != nil {
		return err
	}
	h.calls = calls
	for _, c := range calls {
		h.tools[c.tool()] = true
	}
	return nil
}

func (h *hook) has(tools ...string) bool {
	return slices.ContainsFunc(tools, func(t string) bool { return h.tools[t] })
}

func (h *hook) anyCall(f func(call) bool) bool { return slices.ContainsFunc(h.calls, f) }

// paths is path p as call c may see it: from its dir, or each directory a branch could have left.
// a call whose dir the guard cannot tell at all falls back to the harness cwd
func (h *hook) paths(c call, p string) []string {
	dirs := c.dirs()
	if len(dirs) == 0 {
		dirs = []string{h.cwd}
	}
	var out []string
	for _, d := range dirs {
		if r := resolveIn(d, p); r != "" {
			out = append(out, r)
		}
	}
	return out
}

// scriptText is the command as written plus every word the shell passes, unquoted,
// so a script given as python3 -c "open(\"f\", \"w\")" reads without its escapes
func (h *hook) scriptText() string {
	parts := []string{h.command}
	for _, c := range h.calls {
		parts = append(parts, c.argv...)
	}
	return strings.Join(parts, "\n")
}

// text tools take patterns, files, or text as words, never a program to run
var textTools = []string{"rg", "grep", "echo", "printf", "cat", "head", "tail", "less", "bat", "wc", "diff", "ls", "file", "sed", "awk", "fd", "find", "stat"}

// interpreters run a script given as a word, which can write files the shell never names
var interpreters = regexp.MustCompile(`^(python(3(\.[0-9]+)?)?|node|ruby|perl)$`)

// interpreter is the first call that runs an interpreter, as its command or through a runner like uv run
func (h *hook) interpreter() (call, bool) {
	for _, c := range h.calls {
		if !slices.Contains(textTools, c.tool()) && slices.ContainsFunc(c.argv, func(w string) bool { return interpreters.MatchString(base(w)) }) {
			return c, true
		}
	}
	return call{}, false
}

func isFile(p string) bool {
	st, err := os.Stat(p)
	return err == nil && st.Mode().IsRegular()
}

func isLink(p string) bool {
	st, err := os.Lstat(p)
	return err == nil && st.Mode()&os.ModeSymlink != 0
}

// realpath is the absolute path with every symlink resolved, or "" when that fails
func realpath(p string) string {
	abs, err := filepath.Abs(p)
	if err != nil {
		return ""
	}
	real, err := filepath.EvalSymlinks(abs)
	if err != nil {
		return ""
	}
	return real
}

// gitOut runs git in dir and returns its output without trailing newlines, or "" when it fails
func gitOut(dir string, args ...string) string {
	out, err := exec.Command("git", append([]string{"-C", dir}, args...)...).Output()
	if err != nil {
		return ""
	}
	return strings.TrimRight(string(out), "\n")
}

func gitOK(dir string, args ...string) bool {
	return exec.Command("git", append([]string{"-C", dir}, args...)...).Run() == nil
}

// tracked reports whether f is an existing file that git tracks
func tracked(f string) bool {
	return isFile(f) && gitOK(filepath.Dir(f), "ls-files", "--error-unmatch", "--", filepath.Base(f))
}

// binary reports a file git stores as binary, which the edit tool cannot change either
func binary(f string) bool {
	return lineMatch(textlessInGit, gitOut(filepath.Dir(f), "ls-files", "--eol", "--", filepath.Base(f)))
}

var textlessInGit = regexp.MustCompile(`^i/-text`)

// lineMatch reports a match on any line of s, as rg and grep search
func lineMatch(re *regexp.Regexp, s string) bool {
	return slices.ContainsFunc(strings.Split(s, "\n"), re.MatchString)
}

// lineSubmatches is every match of re's first group, line by line, as rg -o -r '$1' prints them
func lineSubmatches(re *regexp.Regexp, s string) []string {
	var out []string
	for _, line := range strings.Split(s, "\n") {
		for _, m := range re.FindAllStringSubmatch(line, -1) {
			out = append(out, m[1])
		}
	}
	return out
}
