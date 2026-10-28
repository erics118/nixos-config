package main

import (
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
)

// a filesystem-wide root: / , /nix, /nix/store, /nix/var(/nix), whole $HOME / ~ / /home/<user>, or a huge or
// hang-prone system root. bounded subpaths (. , /home/eric/dev , ~/proj, /nix/store/<hash>-name) pass
var searchRoot = regexp.MustCompile(`^(/|~/?|\$HOME/?|/nix(/(store|var(/nix)?))?/?|/(home|Users)(/[^/]+)?/?|/(usr|var|proc|sys|System|Library|private|Volumes)/?)\*?$`)

var searchTools = []string{"find", "fd", "rg", "grep", "egrep", "fgrep", "ugrep", "ag", "ack"}

// atRoot reports a path that names a filesystem-wide root, as written or once cleaned, so /. and /tmp/.. count
func atRoot(p string) bool {
	if searchRoot.MatchString(p) {
		return true
	}
	clean := resolveIn("/", p)
	return absolute(p) && (searchRoot.MatchString(clean) || clean == filepath.Clean(os.Getenv("HOME")))
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
		// a cd's own target counts. without one, . stays allowed, so a session started in ~ can still search it,
		// but a path such as .. climbs from the harness cwd
		dirs := c.dirs()
		if !c.moved {
			dirs = []string{h.cwd}
			relative = slices.DeleteFunc(relative, func(p string) bool { return p == "." || p == "./" })
		}
		for _, d := range dirs {
			root = root || slices.ContainsFunc(relative, func(p string) bool { return atRoot(resolveIn(d, p)) })
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
	return c.tool() != "grep" || c.parsed().has("-r", "-R", "--recursive", "--dereference-recursive")
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
	p := c.parsed()
	out = p.operands
	// fd takes no pattern option, and rg and grep take no pattern word once -e or -f names one
	patternFlag := c.tool() != "fd" && p.has("-e", "-f", "--regexp", "--file")
	if !p.has("--files") && !patternFlag && len(out) > 0 {
		out = out[1:]
	}
	for _, name := range []string{"--base-directory", "--search-path"} {
		if dir, ok := p.value(name); ok {
			out = append(out, dir)
		}
	}
	return out
}
