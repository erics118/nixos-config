package main

import (
	"path/filepath"
	"regexp"
	"slices"
	"strings"
)

// the shared steps of the checks that keep agents off files and git config keys only the user changes

// pathIs matches a path against re cleaned and lowercased, since macOS ignores case
func pathIs(re *regexp.Regexp) func(string) bool {
	return func(p string) bool { return p != "" && lineMatch(re, strings.ToLower(filepath.Clean(p))) }
}

// setsConfigKey reports a git config command that names a key matching key and does not only read it
func setsConfigKey(g []string, key *regexp.Regexp) bool {
	if at(g, 0) != "config" {
		return false
	}
	names := slices.ContainsFunc(g, func(w string) bool { return key.MatchString(strings.ToLower(w)) })
	reads := slices.ContainsFunc(g, func(w string) bool { return slices.Contains(configReads, w) }) ||
		at(g, 1) == "get" || at(g, 1) == "list"
	return names && !reads
}

// writeOnto is the first write that lands on a path is matches, as written or as the call's directory resolves it
func writeOnto(h *hook, is func(string) bool) (write, bool) {
	for _, w := range h.written() {
		if is(w.word) || slices.ContainsFunc(w.paths, is) {
			return w, true
		}
	}
	return write{}, false
}

// namedByNonReader is the first protected path a tool other than git or a reader names in its arguments.
// a reader's own writes are caught by writeOnto, so naming a path there is a read
func namedByNonReader(h *hook, name *regexp.Regexp, is func(string) bool) (string, bool) {
	for _, c := range h.calls {
		if c.wrapper || c.tool() == "git" || slices.Contains(readers, c.tool()) {
			continue
		}
		for _, w := range c.args() {
			if m := name.FindStringSubmatch(strings.ToLower(w)); m != nil {
				return m[1], true
			}
			if slices.ContainsFunc(h.paths(c, w), is) {
				return w, true
			}
		}
	}
	return "", false
}

// scriptNames reports a script, including a heredoc body, whose text names a path name matches
func scriptNames(h *hook, name *regexp.Regexp) bool {
	return slices.ContainsFunc(h.interpreterCalls(), func(c call) bool { return lineMatch(name, strings.ToLower(c.scriptText())) })
}
