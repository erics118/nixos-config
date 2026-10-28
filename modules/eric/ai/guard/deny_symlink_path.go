package main

import (
	"cmp"
	"os"
	"path/filepath"
	"slices"
	"strings"
)

// steer the agent to the real repo path of a nix-managed dotfile symlink, and block a write through a link
// anywhere along the path that lands outside the approved roots.
// a silent rewrite would desync Claude's read tracking, since Read stays on the link and Write moves to the target
func denySymlinkPath(h *hook) decision {
	f := h.str("file_path")
	if f == "" {
		return decision{}
	}
	if real := realpath(f); isLink(f) && real != "" && real != f && underAny(real, approvedRoots()) {
		return deny("That path is a symlink into a nix-managed repo. Read and edit the real path instead: " + real)
	}
	if h.toolName == "Read" {
		return decision{}
	}
	if real := leavesManaged(f); real != "" {
		return deny(leavesReason(real))
	}
	return decision{}
}

// approvedRoots are where nix-managed links point, under home with its own links resolved
func approvedRoots() []string {
	home := os.Getenv("HOME")
	home = cmp.Or(realpath(home), home)
	return []string{home + "/nixos-config", home + "/nixos-config-private", home + "/.config"}
}

// leavesManaged is where p lands when a link along it leads outside the approved roots, or ""
func leavesManaged(p string) string {
	if real := throughLink(p); real != "" && !underAny(real, approvedRoots()) {
		return real
	}
	return ""
}

func leavesReason(real string) string {
	return "This write goes through a symlink to " + real + ", outside the nix-managed roots, so it would change a file the path does not name. Write the real path, or ask the user."
}

func underAny(p string, roots []string) bool {
	return slices.ContainsFunc(roots, func(r string) bool { return p == r || strings.HasPrefix(p, r+"/") })
}

// root-owned macOS system links, trusted as if written by their real path
var systemAliases = []string{"/tmp", "/var", "/etc"}

// throughLink is where p lands when a link along its existing part leads elsewhere, or "" when none does
func throughLink(p string) string {
	lexical := filepath.Clean(p)
	for _, a := range systemAliases {
		if real := realpath(a); real != "" && (lexical == a || strings.HasPrefix(lexical, a+"/")) {
			lexical = real + lexical[len(a):]
		}
	}
	existing, rest := lexical, ""
	for !exists(existing) {
		parent := filepath.Dir(existing)
		if parent == existing {
			return ""
		}
		existing, rest = parent, filepath.Join(filepath.Base(existing), rest)
	}
	resolved := filepath.Join(realpath(existing), rest)
	if resolved == lexical {
		return ""
	}
	return resolved
}
