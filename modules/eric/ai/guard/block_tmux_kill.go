package main

import (
	"regexp"
	"slices"
	"strings"
)

var (
	privateServer = regexp.MustCompile(`^-[LS]`)
	tmuxKill      = regexp.MustCompile(`^kill-|^kill[pw]$`)
)

// block kills on the user's tmux server. a private -L or -S server stays the agent's to kill
func blockTmuxKill(h *hook) decision {
	if h.anyCall(func(c call) bool {
		a := c.args()
		switch c.tool() {
		case "tmux":
			// -L default names the user's own server
			private := slices.ContainsFunc(a, privateServer.MatchString) && !slices.Contains(a, "-Ldefault") &&
				!(slices.Contains(a, "-L") && at(a, slices.Index(a, "-L")+1) == "default")
			return !private && slices.ContainsFunc(a, tmuxKill.MatchString)
		case "pkill", "killall":
			return slices.ContainsFunc(killPatterns(c), killsTmux)
		}
		return false
	}) {
		return deny("Agents never kill sessions, windows, panes, or the server on the user's tmux. Run your own server with tmux -L <name>, or tell the user what to kill.")
	}
	return decision{}
}

// options of pkill and killall that take a value, so the value is not a process pattern
var killValueOpts = []string{"-F", "-G", "-g", "-P", "-s", "-t", "-U", "-u", "-L", "-c", "--signal", "--older-than", "--younger-than"}

// killPatterns is the process names or patterns a pkill or killall call matches
func killPatterns(c call) []string {
	var out []string
	a := c.args()
	for i := 0; i < len(a); i++ {
		switch {
		case slices.Contains(killValueOpts, a[i]):
			i++
		case !strings.HasPrefix(a[i], "-"):
			out = append(out, a[i])
		}
	}
	return out
}

// killsTmux reports a pattern that matches tmux: pkill and killall -r or -m read it as a regex,
// and pkill -f matches it anywhere in a command line such as "tmux new -s x", so a plain mention counts too
func killsTmux(p string) bool {
	if strings.Contains(p, "tmux") {
		return true
	}
	re, err := regexp.Compile(p)
	return err == nil && re.MatchString("tmux")
}
