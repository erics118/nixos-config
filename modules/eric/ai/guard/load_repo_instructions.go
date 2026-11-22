package main

import (
	"bytes"
	"cmp"
	"os"
	"path/filepath"
	"strings"
)

// Claude Code loads instruction files only from the session's folder and the folders above it.
// the first Read in another repo carries its AGENTS.md as context, and the first Write or Edit is denied with it.
// the marker in the transcript means it was shown already
func loadRepoInstructions(h *hook) decision {
	f := h.str("file_path")
	if f == "" || h.harness != "claude" || h.transcript == "" {
		return decision{}
	}
	f = cmp.Or(throughLink(f), filepath.Clean(f))
	inst := instructionsFor(filepath.Dir(f))
	if inst == "" {
		return decision{}
	}
	cwd := cmp.Or(realpath(h.cwd), h.cwd)
	if dir := filepath.Dir(inst); cwd == dir || strings.HasPrefix(cwd, dir+"/") {
		return decision{}
	}
	marker := "Project instructions from " + inst
	if seen, err := os.ReadFile(h.transcript); err == nil && bytes.Contains(seen, []byte(marker)) {
		return decision{}
	}
	text, err := os.ReadFile(inst)
	if err != nil {
		return decision{}
	}
	if len(text) > 9000 {
		text = append(text[:9000], "\n[cut at 9000 bytes, Read the file for the rest]"...)
	}
	msg := f + " is in a repo whose instructions were not loaded at session start. " + marker + ":\n\n" + string(text)
	if h.toolName == "Read" {
		return decision{context: []string{msg}}
	}
	return deny(msg + "\n\nFollow these instructions, then retry the change.")
}

// instructionsFor is the AGENTS.md or CLAUDE.md in dir or the nearest folder above it, below home, or "".
// ~/.claude holds the user-level CLAUDE.md, which every session loads
func instructionsFor(dir string) string {
	home := os.Getenv("HOME")
	home = cmp.Or(realpath(home), home)
	for ; dir != home && dir != filepath.Dir(dir); dir = filepath.Dir(dir) {
		if dir == home+"/.claude" {
			return ""
		}
		for _, name := range []string{"AGENTS.md", "CLAUDE.md"} {
			if p := filepath.Join(dir, name); isFile(p) {
				return p
			}
		}
	}
	return ""
}
