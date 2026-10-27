package main

import (
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
			if checked[dir] || !evaluatesFlake(c, dir) {
				continue
			}
			checked[dir] = true
			root := gitOut(dir, "rev-parse", "--show-toplevel")
			if root == "" || !isFile(filepath.Join(root, "flake.nix")) {
				continue
			}
			if untracked := gitOut(root, "ls-files", "--others", "--exclude-standard"); untracked != "" {
				return deny("Untracked files are invisible to flake eval. git add them first: " + strings.ReplaceAll(untracked, "\n", " "))
			}
		}
	}
	return decision{}
}

// nix options that take a value, which can come before the subcommand
var nixValueOpts = map[string]int{"--option": 2, "--override-input": 2, "-I": 1, "--include": 1, "--extra-experimental-features": 1,
	"--experimental-features": 1, "--log-format": 1, "--store": 1, "--eval-store": 1, "--max-jobs": 1, "-j": 1, "--cores": 1}

// nixCommand is the nix subcommand and the words after it, past any global options
func nixCommand(a []string) []string {
	for i := 1; i < len(a); i++ {
		if !strings.HasPrefix(a[i], "-") {
			return a[i:]
		}
		i += nixValueOpts[a[i]]
	}
	return nil
}

var remoteFlake = regexp.MustCompile(`^(nixpkgs([/#]|$)|(github|gitlab|sourcehut):|(git\+)?(https?|ssh)://|tarball\+)`)

// remoteOnly reports nix arguments that name at least one installable and only remote flakes.
// the program and its arguments after --command, -c, or -- are not installables.
// any other word, such as an option's value, counts as local, so a misread denies
func remoteOnly(args []string) bool {
	n := 0
	for _, w := range args {
		if w == "--command" || w == "-c" || w == "--" {
			break
		}
		if strings.HasPrefix(w, "-") {
			if slices.Contains([]string{"--inputs-from", "--override-input", "--expr", "--file", "-f", "--reference-lock-file"}, w) {
				return false
			}
			continue
		}
		if !remoteFlake.MatchString(w) {
			return false
		}
		n++
	}
	return n > 0
}

// evaluatesFlake reports a call that evaluates the flake in dir.
// a just recipe counts only when its dry run calls nix, since many repos with a flake use just for other builds.
// a dry run that fails falls back to the recipe name, so an unreadable justfile still blocks
func evaluatesFlake(c call, dir string) bool {
	a, t := c.argv, c.tool()
	switch {
	case t == "nix":
		sub := nixCommand(a)
		if slices.Contains([]string{"build", "eval", "run", "shell", "bundle", "copy"}, at(sub, 0)) {
			return !remoteOnly(sub[1:])
		}
		return slices.Contains([]string{"develop", "fmt", "repl"}, at(sub, 0)) ||
			(at(sub, 0) == "flake" && slices.Contains([]string{"check", "show", "metadata"}, at(sub, 1)))
	case t == "nh":
		return (at(a, 1) == "darwin" || at(a, 1) == "os" || at(a, 1) == "home") && (at(a, 2) == "build" || at(a, 2) == "switch")
	case t == "just":
		// the dry run gets the call's own options too, such as -f justfile
		cmd := exec.Command("just", append([]string{"--dry-run"}, c.args()...)...)
		cmd.Dir = dir
		if out, err := cmd.CombinedOutput(); err == nil {
			return lineMatch(nixWord, string(out))
		}
		return slices.ContainsFunc(c.args(), func(w string) bool { return slices.Contains([]string{"build", "switch", "check", "dev"}, w) })
	}
	return slices.Contains([]string{"darwin-rebuild", "nixos-rebuild", "home-manager"}, t)
}
