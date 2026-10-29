package main

import (
	"fmt"
	"regexp"
	"slices"
	"strings"
)

// ghWords is the gh subcommand and its arguments with leading global flags (and their values) removed,
// so -R/--repo or --hostname before the subcommand do not shift where the subcommand is read
func ghWords(argv []string) []string {
	return leadingArgs("gh", argv[min(1, len(argv)):]).operands
}

// agents use gh read-only: only known reads run, so a new write command is denied too
func blockGhWrite(h *hook) decision {
	for _, c := range h.calls {
		if c.tool() != "gh" {
			continue
		}
		if ghInfo(c.argv) {
			continue
		}
		g := ghWords(c.argv)
		group, sub := at(g, 0), at(g, 1)
		if group == "repo" && slices.Contains([]string{"autolink", "deploy-key", "gitignore", "license"}, sub) {
			group, sub = sub, at(g, 2)
		}
		if !ghRead(group + " " + sub) {
			return deny(fmt.Sprintf("Agents use gh read-only, and gh %s %s is not a known read. Tell the user what to run.", group, sub))
		}
	}
	if h.anyCall(func(c call) bool { return c.tool() == "gh" && slices.Contains(c.argv, "--show-token") }) {
		return deny("Agents never print the GitHub token.")
	}
	if h.anyCall(func(c call) bool { return c.tool() == "gh" && ghAPIWrite(ghWords(c.argv)) }) {
		return deny("Agents never write to GitHub through gh api. Use read-only gh api calls, or tell the user what to run. A graphql read must pass one literal query with -f query=..., with values inlined and no $ variables.")
	}
	return decision{}
}

// help and version only print. --help counts as the last word or a leading flag, so a --body "--help"
// value in the middle cannot pass a write off as help. version and help also count as the subcommand
func ghInfo(argv []string) bool {
	lead := leadingArgs("gh", argv[min(1, len(argv)):])
	g := lead.operands
	if len(g) > 0 && g[len(g)-1] == "--help" {
		return true
	}
	return lead.has("--version", "--help", "-h") || (len(g) > 0 && slices.Contains([]string{"version", "help"}, g[0]))
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
func ghAPIWrite(g []string) bool {
	if at(g, 0) != "api" {
		return false
	}
	var methods []string
	for i := 1; i < len(g); i++ {
		up := strings.ToUpper(g[i])
		if up == "-X" || up == "--METHOD" {
			methods = append(methods, strings.ToUpper(at(g, i+1)))
		} else if m := methodFlag.FindStringSubmatch(up); m != nil {
			methods = append(methods, m[2])
		}
	}
	if slices.ContainsFunc(methods, func(m string) bool { return m != "GET" && m != "HEAD" }) {
		return true
	}
	return len(methods) == 0 && slices.ContainsFunc(g, fieldFlag.MatchString) && !graphqlRead(g)
}

// graphql always posts, so a literal query with no mutation reads.
// a $ is denied too, since a shell expansion and a graphql variable look the same here
func graphqlRead(g []string) bool {
	if at(g, 1) != "graphql" {
		return false
	}
	var queries []string
	for i := 2; i < len(g); i++ {
		var v string
		switch g[i] {
		case "-f", "-F", "--field", "--raw-field":
			v = at(g, i+1)
		default:
			m := queryField.FindStringSubmatch(g[i])
			if m == nil {
				continue
			}
			v = m[2]
		}
		if q, ok := strings.CutPrefix(v, "query="); ok {
			queries = append(queries, q)
		}
	}
	if len(queries) == 0 || slices.ContainsFunc(g, inputFlag.MatchString) {
		return false
	}
	return !slices.ContainsFunc(queries, func(q string) bool {
		return !graphqlQuery.MatchString(q) || strings.Contains(q, "$") || mutation.MatchString(q)
	})
}
