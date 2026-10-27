package main

import (
	"os"
	"strings"
)

// steer the agent to the real repo path of a nix-managed dotfile symlink.
// a silent rewrite would desync Claude's read tracking, since Read stays on the link and Write moves to the target
func denySymlinkPath(h *hook) decision {
	f := h.str("file_path")
	if f == "" || !isLink(f) {
		return decision{}
	}
	real := realpath(f)
	if real == "" || real == f {
		return decision{}
	}
	// only steer when the symlink resolves back into a managed repo location
	home := os.Getenv("HOME")
	for _, root := range []string{home + "/nixos-config/", home + "/nixos-config-private/", home + "/.config/"} {
		if strings.HasPrefix(real, root) {
			return deny("That path is a symlink into a nix-managed repo. Read and edit the real path instead: " + real)
		}
	}
	return decision{}
}
