package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"slices"
)

// format the edited file with the project's own treefmt, reached through the direnv devShell
// (nix-direnv cached, no flake eval). silently no-ops for non-direnv projects or shells without treefmt
func treefmtOnEdit(h *hook) (string, int) {
	f := h.str("file_path")
	if f == "" || !isFile(f) {
		return "", 0
	}
	if _, err := exec.LookPath("direnv"); err != nil {
		return "", 0
	}
	// walk up to the project root, the dir holding .envrc
	d := filepath.Dir(f)
	for d != "/" && !isFile(filepath.Join(d, ".envrc")) {
		up := filepath.Dir(d)
		if up == d {
			break
		}
		d = up
	}
	if !isFile(filepath.Join(d, ".envrc")) {
		return "", 0
	}
	// direnv tracks allowed .envrc files by resolved path, so a symlinked root reads as blocked
	d = realpath(d)
	home := os.Getenv("HOME")
	// roots whose .envrc should not trigger formatting
	if d == "" || slices.Contains([]string{home, home + "/dev", home + "/dev/other"}, d) {
		return "", 0
	}
	cmd := exec.Command("direnv", "exec", d, "treefmt", f)
	cmd.Dir = d
	_ = cmd.Run()
	return "", 0
}
