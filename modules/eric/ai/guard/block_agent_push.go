package main

import (
	"maps"
	"slices"
	"strings"
)

// gate agent pushes on `git config eric-agent.push`: off (default), ask, or on. agent-test- branches are never pushed
func blockAgentPush(h *hook) decision {
	if d := h.configOverride(); d.kind != "" {
		return d
	}
	repos, d := h.gateRepos(func(g []string) bool {
		pushes := g[0] == "push" || g[0] == "send-pack" ||
			((g[0] == "subtree" || g[0] == "lfs") && slices.Contains(g[1:], "push"))
		return pushes && !(g[0] == "push" && gitDryRun(g))
	})
	if d.kind != "" {
		return d
	}
	// agent-test- branches are throwaway, so they never leave the machine, whatever the setting.
	// a push names its remote, unless --repo does, then the refspecs it pushes
	pushesAgentTest := h.anyCall(func(c call) bool {
		g := c.gitArgs()
		if at(g, 0) != "push" {
			return false
		}
		p := parseArgs("git push", g[1:])
		refspecs := p.operands
		if !p.has("--repo") {
			refspecs = refspecs[min(1, len(refspecs)):]
		}
		return slices.ContainsFunc(refspecs, func(w string) bool { return strings.Contains(w, agentTest) })
	})
	if pushesAgentTest || slices.ContainsFunc(slices.Collect(maps.Keys(repos)), onAgentTestBranch) {
		return deny("agent-test- branches are throwaway and never pushed. Tell the user what to push from a real branch.")
	}
	return gate("push", repos, nil,
		"Agent pushes are off in this repo. Tell the user the work is ready so they push it.",
		"Agent pushes need approval in this repo. Approve this push, or push it yourself.")
}
