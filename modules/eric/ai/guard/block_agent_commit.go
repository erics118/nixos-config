package main

import (
	"os"
	"regexp"
	"slices"
	"strings"
)

// gate agent commits on `git config eric-agent.commit`: off (default), ask, branch (not main or master), or on.
// an agent-test- branch is the agent's own, so commits that move only it need no setting
func blockAgentCommit(h *hook) decision {
	if d := h.configOverride(); d.kind != "" {
		return d
	}
	repos, d := h.gateRepos(commits)
	if d.kind != "" {
		return d
	}
	// a command that moves only the checked-out branch needs no setting on an agent-test- branch,
	// the agent's own throwaway branch
	for dir, cmds := range repos {
		if !slices.ContainsFunc(cmds, movesOther) && onAgentTestBranch(dir) {
			delete(repos, dir)
		}
	}
	branchMode := func(dir string, cmds [][]string) decision {
		if slices.ContainsFunc(cmds, movesOther) {
			return deny("This command can move a branch other than the checked-out one, which agent commits on a feature branch do not allow in this repo. Tell the user what to run.")
		}
		switch gitOut(dir, "symbolic-ref", "--short", "-q", "HEAD") {
		case "main", "master", "":
			return deny("Agent commits are allowed only on a feature branch in this repo. Create one, or tell the user the work is ready.")
		}
		return decision{}
	}
	return gate("commit", repos, map[string]func(string, [][]string) decision{"branch": branchMode},
		"Agent commits are off in this repo. Tell the user the work is ready so they commit it.",
		"Agent commits need approval in this repo. Approve this commit, or deny it and commit yourself.")
}

// a refspec whose destination, after the colon, is a local branch: refs/heads/<name> or a bare name
var localRefspec = regexp.MustCompile(`:(refs/heads/|[^/]*$)`)

// movesLocalBranch reports a fetch or pull that writes a local branch through a refspec such as feat:main.
// the first operand is the remote, and the rest are refspecs
func movesLocalBranch(g []string) bool {
	ops := parseArgs("git "+g[0], g[1:]).operands
	return len(ops) > 1 && slices.ContainsFunc(ops[1:], localRefspec.MatchString)
}

// a branch command that force-moves, renames, or copies a branch, rather than creating or deleting one
func movesBranch(g []string) bool {
	p := parseArgs("git branch", g[1:])
	return g[0] == "branch" && !p.has("-d", "-D", "--delete") && p.has("-f", "--force", "-m", "-M", "--move", "-c", "-C", "--copy")
}

func movesOther(g []string) bool { return !headOnly(g) }

// commits reports a git command that makes a commit or moves a branch. pull commits unless it only fast-forwards,
// and commit-tree is left out, since it only writes an object that update-ref and the like must still move a branch onto
func commits(g []string) bool {
	makes := slices.Contains([]string{"commit", "update-ref", "merge", "revert", "cherry-pick", "am", "rebase", "subtree", "fast-import"}, g[0]) ||
		(g[0] == "pull" && !slices.Contains(g, "--ff-only")) || ((g[0] == "pull" || g[0] == "fetch") && movesLocalBranch(g)) || movesBranch(g)
	backsOut := slices.Contains([]string{"merge", "revert", "cherry-pick", "am", "rebase"}, g[0]) &&
		slices.ContainsFunc(g, func(w string) bool {
			return w == "--abort" || w == "--quit" || w == "--edit-todo" || w == "--show-current-patch"
		})
	return makes && !backsOut && !(g[0] == "commit" && gitDryRun(g))
}

// onAgentTestBranch reports a repo on an agent-test- branch.
// mid-rebase HEAD is detached, so the branch being rebased comes from the rebase's head-name file
func onAgentTestBranch(dir string) bool {
	branch := gitOut(dir, "symbolic-ref", "--short", "-q", "HEAD")
	for _, p := range []string{"rebase-merge/head-name", "rebase-apply/head-name"} {
		if branch != "" {
			break
		}
		if b, err := os.ReadFile(gitOut(dir, "rev-parse", "--path-format=absolute", "--git-path", p)); err == nil {
			branch = strings.TrimPrefix(strings.TrimSpace(string(b)), "refs/heads/")
		}
	}
	return strings.HasPrefix(branch, agentTest)
}

// headOnly reports a commit command that moves only the checked-out branch.
// a rebase moves another branch when it names one after the upstream
func headOnly(g []string) bool {
	switch g[0] {
	case "commit", "merge", "cherry-pick", "revert", "am":
		return true
	case "pull":
		return !movesLocalBranch(g)
	case "rebase":
		return len(parseArgs("git rebase", g[1:]).operands) <= 1
	}
	return false
}
