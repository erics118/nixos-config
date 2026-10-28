package main

import (
	"os/exec"
	"strings"
)

// block sudo -n on macOS. it never prompts, so it reports sudo as unavailable even though
// Touch ID would approve a plain sudo. elsewhere sudo -n is the right non-hanging check
func blockSudoProbe(h *hook) decision {
	if !h.anyCall(func(c call) bool {
		return c.tool() == "sudo" && leadingArgs("sudo", c.args()).has("-n", "--non-interactive")
	}) {
		return decision{}
	}
	// uname, not the build's GOOS, so a stub on PATH can stand in for macOS
	if out, err := exec.Command("uname").Output(); err != nil || strings.TrimSpace(string(out)) != "Darwin" {
		return decision{}
	}
	return deny("sudo -n never prompts, so it gives a false negative. Run plain sudo and let Touch ID prompt.")
}
