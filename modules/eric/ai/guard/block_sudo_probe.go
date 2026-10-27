package main

import (
	"os/exec"
	"regexp"
	"strings"
)

var (
	sudoValueFlag = regexp.MustCompile(`^-[ugpCDhRTU]$`)
	sudoNFlag     = regexp.MustCompile(`^-.*n`)
)

// block sudo -n on macOS. it never prompts, so it reports sudo as unavailable even though
// Touch ID would approve a plain sudo. elsewhere sudo -n is the right non-hanging check
func blockSudoProbe(h *hook) decision {
	if !h.anyCall(func(c call) bool { return c.tool() == "sudo" && sudoProbe(c.args()) }) {
		return decision{}
	}
	// uname, not the build's GOOS, so a stub on PATH can stand in for macOS
	if out, err := exec.Command("uname").Output(); err != nil || strings.TrimSpace(string(out)) != "Darwin" {
		return decision{}
	}
	return deny("sudo -n never prompts, so it gives a false negative. Run plain sudo and let Touch ID prompt.")
}

// walk sudo's options up to the command it runs. -u, -g, -p, and the like take a value as the next word
func sudoProbe(a []string) bool {
	for len(a) > 0 {
		w := a[0]
		switch {
		case w == "--non-interactive":
			return true
		case strings.HasPrefix(w, "--"):
			a = a[1:]
		case sudoValueFlag.MatchString(w):
			a = a[min(2, len(a)):]
		case sudoNFlag.MatchString(w):
			return true
		case strings.HasPrefix(w, "-"):
			a = a[1:]
		default:
			return false
		}
	}
	return false
}
