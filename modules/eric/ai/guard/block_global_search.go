package main

import (
	"regexp"
	"slices"
	"strings"
)

// a filesystem-wide root: / , /nix, /nix/store, /nix/var(/nix), whole $HOME / ~ / /home/<user>, or a huge or
// hang-prone system root. bounded subpaths (. , /home/eric/dev , ~/proj, /nix/store/<hash>-name) pass
var searchRoot = regexp.MustCompile(`^(/|~/?|\$HOME/?|/nix(/(store|var(/nix)?))?/?\*?|/(home|Users)(/[^/]+)?/?|/(usr|var|proc|sys|System|Library|private|Volumes)/?)$`)

var searchTools = []string{"find", "fd", "rg", "grep", "egrep", "fgrep", "ugrep", "ag", "ack"}

func absolute(p string) bool {
	return strings.HasPrefix(p, "/") || strings.HasPrefix(p, "~") || strings.HasPrefix(p, "$HOME")
}

// atRoot reports a path that names a filesystem-wide root, as written or once cleaned, so /. and /tmp/.. count
func atRoot(p string) bool {
	return searchRoot.MatchString(p) || (absolute(p) && searchRoot.MatchString(resolveIn("/", p)))
}

// block `find`, `fd`, `rg`, and `grep` commands rooted at / (or other filesystem-wide roots): scanning the
// whole filesystem is slow, can hang on network/special mounts, and is never what's needed.
// a relative path counts from where the search runs, after any cd in the command
func blockGlobalSearch(h *hook) decision {
	for _, c := range h.calls {
		if !slices.Contains(searchTools, c.tool()) {
			continue
		}
		paths := searchPaths(c)
		var relative []string
		for _, p := range paths {
			if !absolute(p) {
				relative = append(relative, p)
			}
		}
		if len(paths) == 0 && searchesHere(c) {
			relative = []string{"."}
		}
		root := slices.ContainsFunc(paths, atRoot)
		// a cd's own target counts, not the harness cwd, so a session started in ~ can still search .
		if c.moved {
			for _, d := range c.dirs() {
				root = root || slices.ContainsFunc(relative, func(p string) bool { return atRoot(resolveIn(d, p)) })
			}
		}
		if root {
			return deny("find, fd, rg, or grep rooted at a filesystem-wide directory (/, /nix, ~, $HOME, /home/<user>, /Users/<user>, or a system root) scans far too much and can hang on special mounts. Search from a specific directory instead (e.g. `fd <pattern> .` or `fd <pattern> /path/to/project`).")
		}
		if c.mayBeHome && len(relative) > 0 {
			return deny("a relative search after an unquoted `cd $var` / `cd $(...)`: if the expansion is empty, cd goes to $HOME and the search scans all of it. Guard it: `cd -- \"${var:?}\"`.")
		}
	}
	return decision{}
}

// searchesHere reports a search that scans the current directory when it names no path
func searchesHere(c call) bool {
	if c.tool() != "grep" {
		return true
	}
	return slices.ContainsFunc(c.args(), func(w string) bool {
		return w == "--recursive" || w == "--dereference-recursive" || (!strings.HasPrefix(w, "--") && strings.ContainsAny(w, "rR") && strings.HasPrefix(w, "-"))
	})
}

var findLeading = regexp.MustCompile(`^-([HLPEXdsx]|O[0-9]*)$`)

// find takes its roots before the first expression word, after options like -H, -L, -P, -O3, or -D debug.
// fd, rg, and grep take the pattern first and paths after it, unless --files, -e, -f, or a path flag names them
func searchPaths(c call) []string {
	a := c.args()
	var out []string
	if c.tool() == "find" {
		for len(a) > 0 {
			switch {
			case findLeading.MatchString(a[0]):
				a = a[1:]
				continue
			case a[0] == "-D":
				a = a[min(2, len(a)):]
				continue
			case a[0] == "-f" && len(a) > 1:
				out = append(out, a[1])
				a = a[2:]
				continue
			}
			break
		}
		for _, w := range a {
			if w != "" && strings.ContainsAny(w[:1], "-(!") {
				break
			}
			out = append(out, w)
		}
		return out
	}
	// after -- every word is a pattern or a path, even one that starts with -
	for i, w := range a {
		if w == "--" {
			out = append(out, a[i+1:]...)
			break
		}
		if !strings.HasPrefix(w, "-") {
			out = append(out, w)
		}
	}
	patternFlag := slices.ContainsFunc(a, func(w string) bool {
		return w == "-e" || w == "-f" || strings.HasPrefix(w, "--regexp") || strings.HasPrefix(w, "--file")
	})
	if !slices.Contains(a, "--files") && !patternFlag && len(out) > 0 {
		out = out[1:]
	}
	for i, w := range a {
		switch {
		case strings.HasPrefix(w, "--base-directory=") || strings.HasPrefix(w, "--search-path="):
			out = append(out, w[strings.Index(w, "=")+1:])
		case w == "--base-directory" || w == "--search-path":
			if i+1 < len(a) {
				out = append(out, a[i+1])
			}
		}
	}
	return out
}
