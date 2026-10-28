package main

import (
	"encoding/json"
	"fmt"
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
	// gitCommands caches the names git runs as commands, not aliases
	gitCommands []string
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

// edit is the text a Write or an Edit carries. pi sends its edits as a list
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

// added is each text the call writes: a Write's content, an Edit's new_string, or each of pi's edits
func (e edit) added() []string {
	out := deref(e.Content, e.NewString)
	for _, ed := range e.Edits {
		out = append(out, deref(ed.NewString)...)
	}
	return out
}

// removed is each text the call replaces
func (e edit) removed() []string {
	out := deref(e.OldString)
	for _, ed := range e.Edits {
		out = append(out, deref(ed.OldString)...)
	}
	return out
}

func deref(ps ...*string) []string {
	var out []string
	for _, p := range ps {
		if p != nil {
			out = append(out, *p)
		}
	}
	return out
}

// parse reads the command's calls and the tools they run
func (h *hook) parse() error {
	calls, err := parseCalls(h.command, h.cwd)
	if err != nil {
		return err
	}
	// git aliases expand here, once, so every check reads the command an alias stands for.
	// a shell alias's code is walked as a script, and an alias that keeps calling one is cut off as a deep script is
	scripts := 0
	for i := 0; i < len(calls); i++ {
		s, dir := h.expandAlias(&calls[i])
		if s == "" {
			continue
		}
		if scripts++; scripts > maxDepth {
			return fmt.Errorf("git aliases run more than %d shell commands", maxDepth)
		}
		more, err := parseScript(s, dir)
		if err != nil {
			return err
		}
		calls = append(calls, more...)
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

func absolute(p string) bool {
	return strings.HasPrefix(p, "/") || strings.HasPrefix(p, "~") || strings.HasPrefix(p, "$HOME")
}

// a write is a target resolved to where it may land
type write struct {
	target
	// paths is everywhere the target may land. a copy into a folder lands under each source's name
	paths []string
	// unresolved marks a target the guard cannot place: a relative path after a cd it cannot follow,
	// or a path built from a value it cannot know
	unresolved bool
}

// written lists what every call writes, or the file a Write or Edit writes. fd duplicates and devices are not files
func (h *hook) written() []write {
	if f := h.str("file_path"); f != "" {
		return []write{{target: target{word: f}, paths: []string{f}}}
	}
	var out []write
	for _, c := range h.calls {
		for _, t := range c.targets() {
			if t.word == "" || strings.HasPrefix(t.word, "/dev/") || strings.HasPrefix(t.word, "&") {
				continue
			}
			w := write{target: t, unresolved: len(c.dirs()) == 0 && !absolute(t.word)}
			for _, p := range h.paths(c, t.word) {
				if len(t.into) == 0 || !(t.folder || isDir(p) || strings.HasSuffix(t.word, "/")) {
					w.paths = append(w.paths, p)
					continue
				}
				for _, s := range t.into {
					for _, name := range h.sourceNames(c, s) {
						w.paths = append(w.paths, filepath.Join(p, name))
					}
				}
			}
			w.unresolved = w.unresolved || len(w.paths) == 0
			out = append(out, w)
		}
	}
	return out
}

// sourceNames is the name each file a copy source names lands under: its own, or each match of a glob
func (h *hook) sourceNames(c call, s string) []string {
	s = strings.TrimRight(s, "/")
	var out []string
	if strings.ContainsAny(s, "*?[") {
		for _, p := range h.paths(c, s) {
			matches, _ := filepath.Glob(p)
			for _, m := range matches {
				out = append(out, filepath.Base(m))
			}
		}
	}
	if len(out) == 0 {
		out = []string{base(s)}
	}
	return out
}

// interpreterCalls is each call that runs python, node, ruby, or perl, as its command or behind a runner like uv run
func (h *hook) interpreterCalls() []call {
	return slices.DeleteFunc(slices.Clone(h.calls), func(c call) bool { return interpreter(c.tool()) == "" })
}

func isFile(p string) bool {
	st, err := os.Stat(p)
	return err == nil && st.Mode().IsRegular()
}

func exists(p string) bool {
	_, err := os.Lstat(p)
	return err == nil
}

func isDir(p string) bool {
	st, err := os.Stat(p)
	return err == nil && st.IsDir()
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

// tracked reports whether f is an existing file that git tracks. where git ignores case, as on macOS,
// the filesystem finds the file under any case, so git's match ignores case too
func tracked(f string) bool {
	if !isFile(f) {
		return false
	}
	dir, name := filepath.Dir(f), filepath.Base(f)
	return gitOK(dir, "ls-files", "--error-unmatch", "--", name) ||
		(gitOut(dir, "config", "--get", "core.ignorecase") == "true" && gitOut(dir, "ls-files", "--", ":(icase)"+name) != "")
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
