package main

import (
	"cmp"
	"os/exec"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
)

var nixWord = regexp.MustCompile(`(^|\W)(nix|nh|darwin-rebuild|nixos-rebuild|home-manager)(\W|$)`)

// block flake-evaluating commands when untracked files exist: flakes only see git-tracked files,
// so a new module, config file, or skill is silently invisible and the change appears to do nothing
func gitAddBeforeNix(h *hook) decision {
	checked := map[string]bool{}
	for _, c := range h.calls {
		// a cd the guard cannot follow leaves no repo to check. the check only warns, so it lets the call run
		if c.moved && len(c.dirs()) == 0 {
			continue
		}
		for _, dir := range h.paths(c, ".") {
			if !evaluatesFlake(c, dir) {
				continue
			}
			for _, f := range flakePaths(c) {
				// a path that is no folder, such as a misread option value, is checked as the call's own directory
				flake := resolveIn(dir, f)
				if !isDir(flake) {
					flake = dir
				}
				if checked[flake] {
					continue
				}
				checked[flake] = true
				root := gitOut(flake, "rev-parse", "--show-toplevel")
				if root == "" || !isFile(filepath.Join(root, "flake.nix")) {
					continue
				}
				if untracked := gitOut(root, "ls-files", "--others", "--exclude-standard"); untracked != "" {
					return deny("Untracked files are invisible to flake eval. git add them first: " + strings.ReplaceAll(untracked, "\n", " "))
				}
			}
		}
	}
	return decision{}
}

// flakePaths is where the local flakes a call evaluates live: each installable's or --flake's path, before any #,
// or . when it names none. a remote flake such as nixpkgs#jq has no local files. options that read local files,
// such as --inputs-from or --file, count too, and any other option's value counts as local, so a misread denies
func flakePaths(c call) []string {
	var out []string
	named := false
	add := func(w string) {
		named = true
		if remoteFlake.MatchString(w) {
			return
		}
		p, _, _ := strings.Cut(w, "#")
		out = append(out, cmp.Or(strings.TrimPrefix(strings.TrimPrefix(p, "path:"), "git+file://"), "."))
	}
	switch c.tool() {
	case "nix":
		sub := nixCommand(c.argv)
		start := 1
		if at(sub, 0) == "flake" {
			start = 2
		}
		// the program and its arguments after --command, -c, or -- are not installables
		words := sub[min(start, len(sub)):]
		if i := slices.IndexFunc(words, func(w string) bool { return w == "--command" || w == "-c" || w == "--" }); i >= 0 {
			words = words[:i]
		}
		p := parseArgs("nix", words)
		for _, w := range p.operands {
			add(w)
		}
		for _, o := range p.opts {
			switch {
			case (o.name == "--inputs-from" || o.name == "--override-input") && len(o.values) > 0:
				add(o.values[len(o.values)-1])
			case slices.Contains([]string{"--expr", "--file", "-f", "--reference-lock-file"}, o.name):
				add(".")
			}
		}
	case "darwin-rebuild", "nixos-rebuild", "home-manager":
		if f, ok := c.parsed().value("--flake"); ok {
			add(f)
		}
	}
	if !named {
		return []string{"."}
	}
	return out
}

var remoteFlake = regexp.MustCompile(`^(nixpkgs([/#]|$)|(github|gitlab|sourcehut):|(git\+)?(https?|ssh)://|tarball\+)`)

// evaluatesFlake reports a call that evaluates the flake in dir.
// a just recipe counts only when its dry run calls nix, since many repos with a flake use just for other builds.
// a dry run that fails falls back to the recipe name, so an unreadable justfile still blocks
func evaluatesFlake(c call, dir string) bool {
	a, t := c.argv, c.tool()
	switch {
	case t == "nix":
		sub := nixCommand(a)
		return slices.Contains([]string{"build", "eval", "run", "shell", "bundle", "copy", "develop", "fmt", "repl"}, at(sub, 0)) ||
			(at(sub, 0) == "flake" && slices.Contains([]string{"check", "show", "metadata"}, at(sub, 1)))
	case t == "nh":
		return (at(a, 1) == "darwin" || at(a, 1) == "os" || at(a, 1) == "home") && (at(a, 2) == "build" || at(a, 2) == "switch")
	case t == "just":
		if args, ok := justDryRunArgs(c.args()); ok {
			cmd := exec.Command("just", append([]string{"--dry-run"}, args...)...)
			cmd.Dir = dir
			if out, err := cmd.CombinedOutput(); err == nil {
				return lineMatch(nixWord, string(out))
			}
		}
		return slices.ContainsFunc(c.args(), func(w string) bool { return slices.Contains([]string{"build", "switch", "check", "dev"}, w) })
	}
	return slices.Contains([]string{"darwin-rebuild", "nixos-rebuild", "home-manager"}, t)
}

// justDryRunArgs is what the dry run may pass on: -f and -d with their values, and the recipes.
// any other option, such as --command, --init, or --edit, would run or change something, so it gets no dry run
func justDryRunArgs(a []string) ([]string, bool) {
	var out []string
	for i := 0; i < len(a); i++ {
		switch w := a[i]; {
		case w == "-f" || w == "--justfile" || w == "-d" || w == "--working-directory":
			out = append(out, w, at(a, i+1))
			i++
		case strings.HasPrefix(w, "--justfile=") || strings.HasPrefix(w, "--working-directory="):
			out = append(out, w)
		case strings.HasPrefix(w, "-"):
			return nil, false
		default:
			out = append(out, w)
		}
	}
	return out, true
}
