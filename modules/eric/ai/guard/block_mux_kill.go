package main

import (
	"regexp"
	"slices"
	"strings"
)

var (
	privateServer = regexp.MustCompile(`^-[LS]`)
	tmuxKill      = regexp.MustCompile(`^kill-|^kill[pw]$`)
	// matches pane.close, client.tab.close, session.close, confirm_close, and confirm_close_tab
	rexCloseAction = regexp.MustCompile(`(^|[._])close(_tab)?$`)
)

// block kills on the user's tmux or rex server. a private tmux -L or -S server, or a rex server on a
// socket of the agent's own, stays the agent's to kill
func blockMuxKill(h *hook) decision {
	if h.anyCall(func(c call) bool {
		a := c.args()
		switch c.tool() {
		case "tmux":
			// -L default names the user's own server
			private := slices.ContainsFunc(a, privateServer.MatchString) && !slices.Contains(a, "-Ldefault") &&
				!(slices.Contains(a, "-L") && at(a, slices.Index(a, "-L")+1) == "default")
			return !private && slices.ContainsFunc(a, tmuxKill.MatchString)
		case "rex":
			return rexKills(a)
		case "pkill", "killall":
			return slices.ContainsFunc(killPatterns(c), func(p string) bool { return killsName(p, "tmux") || killsName(p, "rex") })
		}
		return false
	}) {
		return deny("Agents never kill sessions, close tabs or panes, or stop the server on the user's tmux or rex. Label what you create agent-test-<name> (rex new agent-test-x, rex split --label agent-test-x) and close it by that label, run your own server (tmux -L <name>), or tell the user what to close.")
	}
	return decision{}
}

// rex options that take a value, so the value is not a subcommand or an action name
var rexValueOpts = []string{"-S", "--server", "-C", "--client", "--timeout", "--color", "-s", "--session", "-b", "--block",
	"--origin", "--args", "-e", "--eval", "-a", "--action", "--for"}

// rexKills reports a rex call that kills a session, closes a tab or pane, or stops the server.
// a server named by a socket path stays the agent's, unless it is the user's own socket
func rexKills(a []string) bool {
	var words []string
	for i := 0; i < len(a); i++ {
		switch {
		case slices.Contains(rexValueOpts, a[i]):
			if a[i] == "-S" || a[i] == "--server" {
				if rexPrivateServer(at(a, i+1)) {
					return false
				}
			}
			i++
		case strings.HasPrefix(a[i], "--server="):
			if rexPrivateServer(strings.TrimPrefix(a[i], "--server=")) {
				return false
			}
		case strings.HasPrefix(a[i], "-S"):
			if rexPrivateServer(strings.TrimPrefix(a[i], "-S")) {
				return false
			}
		case !strings.HasPrefix(a[i], "-"):
			words = append(words, a[i])
		}
	}
	switch at(words, 0) {
	case "kill":
		return !agentTargets(words[1:])
	case "session":
		return at(words, 1) == "kill" && !agentTargets(words[2:])
	case "window", "block":
		return at(words, 1) == "close" && !agentTargets(words[2:])
	case "server":
		return at(words, 1) == "stop"
	case "do":
		return rexCloseAction.MatchString(at(words, 1))
	}
	return false
}

// agents label what they create agent-test-<name>, and rex resolves a target by its label.
// an id could name anything, so only labels with the prefix are the agent's to close
func agentTargets(targets []string) bool {
	return len(targets) > 0 && !slices.ContainsFunc(targets, func(t string) bool { return !strings.HasPrefix(t, "agent-test-") })
}

// a host label or a network address can be the user's, and the default socket is
func rexPrivateServer(s string) bool {
	return (strings.HasPrefix(s, "unix://") || strings.HasPrefix(s, "/")) && !strings.Contains(s, "rex/server.sock")
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

// killsName reports a pattern that matches name: pkill and killall -r or -m read it as a regex,
// and pkill -f matches it anywhere in a command line such as "tmux new -s x", so a plain mention counts too.
// the mention is checked in any case, since the rex app runs as "Rex Beta"
func killsName(p, name string) bool {
	if strings.Contains(strings.ToLower(p), name) {
		return true
	}
	re, err := regexp.Compile(p)
	return err == nil && re.MatchString(name)
}
