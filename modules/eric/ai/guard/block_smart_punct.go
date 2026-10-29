package main

import (
	"encoding/json"
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
	// a commit message is command text; normalizing a quote there could change shell quoting, so deny it
	for _, span := range h.commitMessages() {
		if smartCount(h.command[span[0]:span[1]]) > 0 {
			return deny(smartPunctMsg)
		}
	}
	e := h.edit()
	added := strings.Join(e.added(), "\n")
	if added == "" || smartCount(added) <= smartCount(strings.Join(e.removed(), "\n")) {
		return decision{}
	}
	// a file marked agent-verbatim keeps its bytes (a scraped-text fixture), so neither normalize nor deny
	if f := h.str("file_path"); hasGitAttr(f, "agent-verbatim") {
		return decision{}
	}
	// only Claude applies a content rewrite: codex drops rewrites, and pi reads only updatedInput.command,
	// so there the write is denied instead, as before
	if h.harness != "claude" {
		return deny(smartPunctMsg)
	}
	if updated := h.normalizeWrittenPunct(); updated != nil {
		return decision{updated: updated, context: []string{"Normalized smart punctuation to ASCII (en/em dash to -, curly quotes to straight, ellipsis to ...). If a literal smart character was intended (e.g. a scraped-text fixture), write it with a unicode escape in code, or mark the path agent-verbatim in .git/info/attributes."}}
	}
	return deny(smartPunctMsg)
}

// smartAscii maps the smart punctuation characters to ASCII; every dash becomes a single -
var smartAscii = strings.NewReplacer(
	"\U00002013", "-", "\U00002014", "-",
	"\U00002018", "'", "\U00002019", "'",
	"\U0000201C", `"`, "\U0000201D", `"`,
	"\U00002026", "...",
)

// normalizeWrittenPunct is the tool-input fields a Write or Edit should carry with smart punctuation
// normalized to ASCII: a Write's content, an Edit's new_string, or each new_string of an edits list
func (h *hook) normalizeWrittenPunct() map[string]json.RawMessage {
	out := map[string]json.RawMessage{}
	norm := func(raw json.RawMessage) (json.RawMessage, bool) {
		var s string
		if json.Unmarshal(raw, &s) != nil {
			return nil, false
		}
		b, _ := json.Marshal(smartAscii.Replace(s))
		return b, true
	}
	if raw, ok := h.toolInput["content"]; ok {
		if b, ok := norm(raw); ok {
			out["content"] = b
		}
	}
	if raw, ok := h.toolInput["new_string"]; ok {
		if b, ok := norm(raw); ok {
			out["new_string"] = b
		}
	}
	if raw, ok := h.toolInput["edits"]; ok {
		var edits []map[string]json.RawMessage
		if json.Unmarshal(raw, &edits) == nil {
			for i := range edits {
				if ns, ok := edits[i]["new_string"]; ok {
					if b, ok := norm(ns); ok {
						edits[i]["new_string"] = b
					}
				}
			}
			if b, err := json.Marshal(edits); err == nil {
				out["edits"] = b
			}
		}
	}
	if len(out) == 0 {
		return nil
	}
	return out
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
