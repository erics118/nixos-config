package main

import (
	"os"
	"path/filepath"
	"slices"
	"strings"
)

// the entries the global instructions allow directly under a .eric folder
var ericEntries = []string{"scratch", "worktrees", "notes", "handoffs", "plans", "approach", "reminders.md"}

// ericStray is the entry a write to p makes directly under a .eric folder, when nothing allows it.
// the AGENTS.md beside that .eric folder can allow more by naming .eric/<entry>
func ericStray(p string) string {
	root, rest, ok := strings.Cut(filepath.Clean(p), "/.eric/")
	if !ok {
		return ""
	}
	entry, _, _ := strings.Cut(rest, "/")
	if slices.Contains(ericEntries, entry) {
		return ""
	}
	if doc, err := os.ReadFile(filepath.Join(root, "AGENTS.md")); err == nil && strings.Contains(string(doc), ".eric/"+entry) {
		return ""
	}
	return entry
}

func ericDeny(entry string) decision {
	return deny(".eric/" + entry + " is not an entry the global instructions allow at the top of .eric/. Put task files under .eric/scratch/<YYYY-MM-DD>-<topic>/ instead.")
}

// block a write that creates a file or folder directly under ~/.eric/ or a repo's .eric/
// other than the entries the global instructions name
func blockEricTop(h *hook) decision {
	if f := h.str("file_path"); f != "" {
		if e := ericStray(f); e != "" {
			return ericDeny(e)
		}
		return decision{}
	}
	for _, c := range h.calls {
		targets := c.writes()
		if dest, ok := c.copyDest(); ok {
			// a copy into the .eric folder itself lands under the source's name
			for _, p := range h.paths(c, dest) {
				if filepath.Base(p) == ".eric" {
					targets = append(targets, filepath.Join(p, base(c.argv[len(c.argv)-2])))
				}
			}
			targets = append(targets, dest)
		}
		if c.inPlaceEdit() {
			targets = append(targets, c.inPlaceFiles()...)
		}
		if t := c.tool(); t == "mkdir" || t == "touch" {
			for _, a := range c.args() {
				if !strings.HasPrefix(a, "-") {
					targets = append(targets, a)
				}
			}
		}
		for _, t := range targets {
			for _, p := range h.paths(c, t) {
				if e := ericStray(p); e != "" {
					return ericDeny(e)
				}
			}
		}
	}
	return decision{}
}
