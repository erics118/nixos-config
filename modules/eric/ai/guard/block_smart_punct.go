package main

import (
	"slices"
	"strings"
)

// en and em dash, curly quotes, and ellipsis
var smartPunct = []rune{0x2013, 0x2014, 0x2018, 0x2019, 0x201C, 0x201D, 0x2026}

// block newly introduced smart punctuation in written content, since AGENTS.md wants plain ASCII.
// only denies when an edit adds more smart chars than it removes, so edits that merely
// preserve existing ones are not blocked
func blockSmartPunct(h *hook) decision {
	e := h.edit()
	var news, olds []string
	for _, s := range []*string{e.Content, e.NewString} {
		if s != nil {
			news = append(news, *s)
		}
	}
	if e.OldString != nil {
		olds = append(olds, *e.OldString)
	}
	for _, ed := range e.Edits {
		if ed.NewString != nil {
			news = append(news, *ed.NewString)
		}
		if ed.OldString != nil {
			olds = append(olds, *ed.OldString)
		}
	}
	added := strings.Join(news, "\n")
	if added == "" {
		return decision{}
	}
	if smartCount(added) > smartCount(strings.Join(olds, "\n")) {
		return deny("this write introduces smart punctuation (em/en dash, curly quotes, ellipsis). use plain ASCII: -, straight quotes, ... instead. rewrite and retry.")
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
