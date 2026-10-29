package main

import (
	"slices"
	"strings"
)

// en and em dash, curly quotes, and ellipsis
var smartPunct = []rune{0x2013, 0x2014, 0x2018, 0x2019, 0x201C, 0x201D, 0x2026}

const smartPunctMsg = `smart punctuation (dash, curly quote, ellipsis) is blocked. use ASCII instead: "-", straight quotes, "...". ` +
	`only if code must match or produce the exact character (e.g. normalizing scraped text), escape it: ` +
	`\u{2019} in js, ts, rust, lua, swift; \N{RIGHT SINGLE QUOTATION MARK} or chr(0x2019) in python. ` +
	`never in prose, comments, docs, or messages. a four-digit backslash-u escape arrives as the character and is blocked too.`

// block newly introduced smart punctuation in written content, since AGENTS.md wants plain ASCII.
// an edit only denies when it adds more smart chars than it removes, so edits that merely
// preserve existing ones are not blocked. a git commit message is written content too, even on the shell
func blockSmartPunct(h *hook) decision {
	e := h.edit()
	added := strings.Join(e.added(), "\n")
	if added != "" && smartCount(added) > smartCount(strings.Join(e.removed(), "\n")) {
		return deny(smartPunctMsg)
	}
	for _, span := range h.commitMessages() {
		if smartCount(h.command[span[0]:span[1]]) > 0 {
			return deny(smartPunctMsg)
		}
	}
	return decision{}
}

func smartCount(s string) int {
	n := 0
	for _, r := range s {
		if slices.Contains(smartPunct, r) {
			n++
		}
	}
	return n
}
