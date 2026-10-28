package main

import (
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
)

// the entries the global instructions allow directly under a .eric folder
var ericEntries = []string{"scratch", "worktrees", "notes", "handoffs", "plans", "approach", "reminders.md"}

// ericStray is the entry a write to p makes directly under a .eric folder, when nothing allows it.
// the AGENTS.md beside that .eric folder can allow more by naming .eric/<entry>
func ericStray(p string) string {
	// the innermost .eric folder, so one inside a worktree under another .eric is checked too
	p = filepath.Clean(p)
	i := strings.LastIndex(p, "/.eric/")
	if i < 0 {
		return ""
	}
	root, rest := p[:i], p[i+len("/.eric/"):]
	entry, _, _ := strings.Cut(rest, "/")
	if slices.Contains(ericEntries, entry) {
		return ""
	}
	named := regexp.MustCompile(`\.eric/` + regexp.QuoteMeta(entry) + `([^\w.-]|$)`)
	if doc, err := os.ReadFile(filepath.Join(root, "AGENTS.md")); err == nil && named.Match(doc) {
		return ""
	}
	return entry
}

func ericDeny(entry string) decision {
	return deny(".eric/" + entry + " is not an entry the global instructions allow at the top of .eric/. Put task files under .eric/scratch/<YYYY-MM-DD>-<topic>/ instead.")
}

// block a write into a file or folder directly under ~/.eric/ or a repo's .eric/
// other than the entries the global instructions name
func blockEricTop(h *hook) decision {
	for _, w := range h.written() {
		for _, p := range w.paths {
			if e := ericStray(p); e != "" {
				return ericDeny(e)
			}
		}
	}
	return decision{}
}
