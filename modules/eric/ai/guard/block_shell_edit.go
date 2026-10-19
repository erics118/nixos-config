package main

import (
	"regexp"
	"slices"
	"strings"
)

var (
	// a write call in python, node, ruby, or perl
	scriptWrite = regexp.MustCompile(`write_text|write_bytes|writeFileSync|appendFileSync|writeFile\b|createWriteStream|` +
		`File\.(write|open|new)|IO\.write|open\([^)]*['"][wa]\+?['"]|open\s*\(?[^,]*,\s*['"]\s*\+?>`)
	pathWrite    = regexp.MustCompile(`Path\(\s*['"]([^'"]+)['"]\s*\)\.write_(?:text|bytes)`)
	openWrite    = regexp.MustCompile(`open\(\s*['"]([^'"]+)['"]\s*,\s*['"][wa]`)
	nodeWrite    = regexp.MustCompile(`(?:writeFileSync|appendFileSync)\(\s*['"]([^'"]+)['"]`)
	singleQuoted = regexp.MustCompile(`'([^'\s]+)'`)
	doubleQuoted = regexp.MustCompile(`"([^"\s]+)"`)
)

const trackedSuffix = " is tracked by git. Use the edit tool so the change shows as a diff and /rewind can undo it."

// block shell edits of git-tracked files: sed/perl in place, scripts that write files, and
// redirects, tee, cp, or mv onto a tracked file. these skip the edit tool, so the change never
// shows as a diff and /rewind cannot undo it
func blockShellEdit(h *hook) decision {
	// sed or perl in place: check that command's operands
	for _, c := range h.calls {
		if !c.inPlaceEdit() {
			continue
		}
		for _, w := range c.inPlaceFiles() {
			if slices.ContainsFunc(h.paths(c, w), tracked) {
				return deny(w + trackedSuffix)
			}
		}
	}

	// a script that writes files: check the literal path each write names. when a write
	// targets a variable instead, check every quoted path the script names
	if in, ok := h.interpreter(); ok && lineMatch(scriptWrite, h.scriptText()) {
		text := h.scriptText()
		var literal []string
		for _, re := range []*regexp.Regexp{pathWrite, openWrite, nodeWrite} {
			literal = append(literal, lineSubmatches(re, text)...)
		}
		candidates := literal
		if len(literal) == 0 || len(literal) < len(scriptWrite.FindAllString(text, -1)) {
			candidates = append(lineSubmatches(singleQuoted, text), lineSubmatches(doubleQuoted, text)...)
		}
		for _, p := range candidates {
			// perl opens with the mode in front of the path, as ">file"
			p = strings.TrimLeft(p, "+<> ")
			if slices.ContainsFunc(h.paths(in, p), tracked) {
				return deny(p + trackedSuffix)
			}
		}
	}

	// ... > file, ... >> file, tee file, or the destination of cp or mv
	for _, c := range h.calls {
		targets := c.writes()
		if dest, ok := c.copyDest(); ok {
			targets = append(targets, dest)
		}
		for _, f := range targets {
			if f == "" || strings.HasPrefix(f, "/dev/") {
				continue
			}
			if slices.ContainsFunc(h.paths(c, f), func(p string) bool { return tracked(p) && !binary(p) }) {
				return deny(f + trackedSuffix)
			}
		}
	}
	return decision{}
}
