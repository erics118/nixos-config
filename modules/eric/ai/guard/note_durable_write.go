package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
)

// a claim written into memory, notes, or a handoff outlives the session, so a premise without a source spreads from there.
// the first such write in a session gets a note on sourcing; the marker in the transcript means it was shown already
const durableMarker = "This file is durable"

func noteDurableWrite(h *hook) decision {
	f := h.str("file_path")
	if f == "" || h.harness != "claude" || h.transcript == "" || !durablePath(filepath.Clean(f)) {
		return decision{}
	}
	if seen, err := os.ReadFile(h.transcript); err == nil && bytes.Contains(seen, []byte(durableMarker)) {
		return decision{}
	}
	return decision{context: []string{durableMarker + ": later sessions will read it as fact. Each claim in it needs a source opened this session, or a guess mark. Keep any hedge you said in chat. A summary, a memory note, or your own earlier words is not a source."}}
}

// durablePath is a Claude memory file or a file under .eric/notes or .eric/handoffs
func durablePath(p string) bool {
	return (strings.Contains(p, "/.claude/projects/") && strings.Contains(p, "/memory/")) ||
		strings.Contains(p, "/.eric/notes/") || strings.Contains(p, "/.eric/handoffs/")
}
