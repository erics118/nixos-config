package main

import (
	"fmt"
	"regexp"
	"slices"
	"strings"
)

// deny agent pushes by default. `eric-agent.push=ask` requests confirmation.
// `eric-agent.push=on` allows pushes. GitHub writes remain user-only
func blockAgentPush(h *hook) decision {
	if d := h.configOverride(); d.kind != "" {
		return d
	}
	dirs, d := h.gateDirs(func(g []string) bool {
		pushes := g[0] == "push" || g[0] == "send-pack" ||
			((g[0] == "subtree" || g[0] == "lfs") && slices.Contains(g[1:], "push"))
		return pushes && !(g[0] == "push" && gitDryRun(g))
	})
	if d.kind != "" {
		return d
	}
	asks := false
	for _, dir := range dirs {
		switch gitOut(dir, "config", "--get", "eric-agent.push") {
		case "on":
		case "ask":
			asks = true
		default:
			return deny("Agent pushes are off in this repo. Tell the user the work is ready so they push it.")
		}
	}

	// gh is read-only: allow only known reads, so new write commands are denied too
	for _, c := range h.calls {
		if c.tool() != "gh" || ghInfo(c.argv) {
			continue
		}
		for _, line := range strings.Split(at(c.argv, 1)+" "+at(c.argv, 2), "\n") {
			group, sub := readTwo(line)
			if group == "repo" && slices.Contains([]string{"autolink", "deploy-key", "gitignore", "license"}, sub) {
				group, sub = sub, at(c.argv, 3)
			}
			if !ghRead(group + " " + sub) {
				return deny(fmt.Sprintf("Agents use gh read-only, and gh %s %s is not a known read. Tell the user what to run.", group, sub))
			}
		}
	}
	if h.anyCall(func(c call) bool { return c.tool() == "gh" && slices.Contains(c.argv, "--show-token") }) {
		return deny("Agents never print the GitHub token.")
	}
	if h.anyCall(func(c call) bool { return c.tool() == "gh" && ghAPIWrite(c.argv) }) {
		return deny("Agents never write to GitHub through gh api. Use read-only gh api calls, or tell the user what to run. A graphql read must pass one literal query with -f query=..., with values inlined and no $ variables.")
	}
	if asks {
		return ask("Agent pushes need approval in this repo. Approve this push, or push it yourself.")
	}
	return decision{}
}

// readTwo splits a line into its first word and the rest, as the shell's `read -r a b` does
func readTwo(line string) (string, string) {
	line = strings.Trim(line, " \t")
	i := strings.IndexAny(line, " \t")
	if i < 0 {
		return line, ""
	}
	return line[:i], strings.Trim(line[i+1:], " \t")
}

// help and version only print. --help must come last, so a --body "--help" value can't pass a write
func ghInfo(a []string) bool {
	return a[len(a)-1] == "--help" || slices.Contains([]string{"--version", "version", "help"}, at(a, 1))
}

func ghRead(s string) bool {
	for _, p := range []string{"api ", "search "} {
		if strings.HasPrefix(s, p) {
			return true
		}
	}
	// downloads and checkouts write only local files. ask-dangerous-git asks before a forced pr checkout
	if slices.Contains([]string{"status ", "licenses ", "repo clone", "repo read-file", "repo read-dir", "run watch",
		"ruleset check", "variable get", "config get", "project field-list", "project item-list",
		"release verify", "release verify-asset", "attestation verify", "attestation trusted-root",
		"extension search", "skill search", "skill preview",
		"run download", "release download", "attestation download", "gist clone", "pr checkout"}, s) {
		return true
	}
	for _, p := range []string{" view", " list", " status", " diff", " checks"} {
		if strings.HasSuffix(s, p) {
			return true
		}
	}
	return false
}

var (
	methodFlag   = regexp.MustCompile(`^(-X|--METHOD=)(.+)`)
	fieldFlag    = regexp.MustCompile(`^-[fF]|^--(field|raw-field|input)(=|$)`)
	queryField   = regexp.MustCompile(`^(-[fF]|--field=|--raw-field=)(.+)`)
	graphqlQuery = regexp.MustCompile(`^\s*(query\b|\{)`)
	mutation     = regexp.MustCompile(`(?i)mutation`)
	inputFlag    = regexp.MustCompile(`^--input(=|$)`)
)

// gh api writes: a method other than GET or HEAD, or fields with no method, which make gh default to POST
func ghAPIWrite(a []string) bool {
	if at(a, 1) != "api" {
		return false
	}
	var methods []string
	for i := 2; i < len(a); i++ {
		up := strings.ToUpper(a[i])
		if up == "-X" || up == "--METHOD" {
			methods = append(methods, strings.ToUpper(at(a, i+1)))
		} else if m := methodFlag.FindStringSubmatch(up); m != nil {
			methods = append(methods, m[2])
		}
	}
	if slices.ContainsFunc(methods, func(m string) bool { return m != "GET" && m != "HEAD" }) {
		return true
	}
	return len(methods) == 0 && slices.ContainsFunc(a, fieldFlag.MatchString) && !graphqlRead(a)
}

// graphql always posts, so a literal query with no mutation reads.
// a $ is denied too, since a shell expansion and a graphql variable look the same here
func graphqlRead(a []string) bool {
	if at(a, 2) != "graphql" {
		return false
	}
	var queries []string
	for i := 3; i < len(a); i++ {
		var v string
		switch a[i] {
		case "-f", "-F", "--field", "--raw-field":
			v = at(a, i+1)
		default:
			m := queryField.FindStringSubmatch(a[i])
			if m == nil {
				continue
			}
			v = m[2]
		}
		if q, ok := strings.CutPrefix(v, "query="); ok {
			queries = append(queries, q)
		}
	}
	if len(queries) == 0 || slices.ContainsFunc(a, inputFlag.MatchString) {
		return false
	}
	return !slices.ContainsFunc(queries, func(q string) bool {
		return !graphqlQuery.MatchString(q) || strings.Contains(q, "$") || mutation.MatchString(q)
	})
}
