package main

import (
	"regexp"
	"slices"
	"strings"
)

var (
	tmuxKill = regexp.MustCompile(`^kill-|^kill[pw]$`)
	// respawn kills the process running in the pane or window when given -k
	tmuxRespawn = regexp.MustCompile(`^respawn(-pane|-window|p|w)$`)
	// the user's tmux sockets live in a tmux-<uid> folder
	userSocket = regexp.MustCompile(`(^|/)tmux-[0-9]+/`)
	// matches pane.close, client.tab.close, session.close, confirm_close, and confirm_close_tab
	rexCloseAction = regexp.MustCompile(`(^|[._])close(_tab)?$`)
	// api methods that destroy, close, or stop
	rexAPIKill = regexp.MustCompile(`\.(destroy|kill|stop|close\w*)$`)
	rexLuaKill = regexp.MustCompile(`(?i)destroy|close|stop|kill`)
)

// block kills on the user's tmux or rex server. a private tmux -L or -S server, or a rex server on a
// socket of the agent's own, stays the agent's to kill
func blockMuxKill(h *hook) decision {
	// kill $(pgrep tmux) and pgrep tmux | xargs kill reach the server through its pids
	pids := h.anyCall(func(c call) bool { return (c.tool() == "pgrep" || c.tool() == "pidof") && killsMux(c) })
	if (pids && h.has("kill")) || h.anyCall(func(c call) bool {
		a := c.args()
		switch c.tool() {
		case "tmux":
			return !tmuxPrivate(c.argv) && (slices.ContainsFunc(a, tmuxKill.MatchString) ||
				(slices.ContainsFunc(a, tmuxRespawn.MatchString) && slices.Contains(a, "-k")))
		case "rex":
			return rexKills(a)
		case "pkill", "killall":
			return killsMux(c)
		}
		return false
	}) {
		return deny("Agents never kill sessions, close tabs or panes, or stop the server on the user's tmux or rex. Label what you create agent-test-<name> (rex new agent-test-x, rex split --label agent-test-x) and close it by that label, run your own server (tmux -L <name>), or tell the user what to close.")
	}
	return decision{}
}

// rexKills reports a rex call that kills a session, closes a tab or pane, or stops the server.
// a server named by a socket path stays the agent's, unless it is the user's own socket
func rexKills(a []string) bool {
	p := parseArgs("rex", a)
	if server, ok := p.value("-S", "--server"); ok && rexPrivateServer(server) {
		return false
	}
	words := p.operands
	switch at(words, 0) {
	case "kill":
		return !agentTargets(words[1:])
	case "session":
		return at(words, 1) == "kill" && !agentTargets(words[2:])
	case "window", "block":
		return at(words, 1) == "close" && !agentTargets(words[2:])
	case "server":
		return at(words, 1) == "stop"
	case "api":
		return at(words, 1) == "call" && rexAPIKill.MatchString(at(words, 2))
	// do runs an action, Lua given with -e, or a Lua file or - for standard input, which the guard does not read
	case "do":
		if lua, ok := p.value("-e", "--eval"); ok {
			return rexLuaKill.MatchString(lua)
		}
		act := at(words, 1)
		return act == "-" || strings.Contains(act, "/") || strings.HasSuffix(act, ".lua") || rexCloseAction.MatchString(act)
	}
	return false
}

// agents label what they create agent-test-<name>, and rex resolves a target by its label.
// an id could name anything, so only labels with the prefix are the agent's to close
func agentTargets(targets []string) bool {
	return len(targets) > 0 && !slices.ContainsFunc(targets, func(t string) bool { return !strings.HasPrefix(t, agentTest) })
}

// a host label or a network address can be the user's, and the default socket is
func rexPrivateServer(s string) bool {
	return (strings.HasPrefix(s, "unix://") || strings.HasPrefix(s, "/")) && !strings.Contains(s, "rex/server.sock")
}

// tmuxPrivate reports a tmux server of the agent's own: -L with a name other than default,
// or -S with a socket outside the user's tmux folder and not named by a variable
func tmuxPrivate(a []string) bool {
	global := leadingArgs("tmux", a[1:])
	if name, ok := global.value("-L"); ok {
		return name != "default"
	}
	if socket, ok := global.value("-S"); ok {
		return !strings.Contains(socket, "$") && !userSocket.MatchString(socket)
	}
	return false
}

// killsMux reports a pkill, killall, or pgrep whose patterns match tmux or rex
func killsMux(c call) bool {
	return slices.ContainsFunc(c.parsed().operands, func(p string) bool { return killsName(p, "tmux") || killsName(p, "rex") })
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
