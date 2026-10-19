package main

import (
	"regexp"
	"strings"
)

// a trailer goes from its keyword, after any indent or robot emoji, to the end of its line or quote,
// so a message on the same line stays
const trailerLead = `(?i)[ \t]*(\x{1F916}[ \t]*)?`

var (
	attribution = regexp.MustCompile(`(?i)(co-authored-by|assisted-by):.*(claude|anthropic)|generated with.*claude|claude-session:`)
	trailers    = []*regexp.Regexp{
		regexp.MustCompile(trailerLead + `(co-authored-by|assisted-by):[^\n"']*(claude|anthropic)[^\n"']*\n?`),
		regexp.MustCompile(trailerLead + `generated with[^\n"']*claude[^\n"']*\n?`),
		regexp.MustCompile(trailerLead + `claude-session:[^\n"']*\n?`),
	}
)

// strip claude attribution trailers from git commit commands before they run.
// the system prompt hardcodes Co-Authored-By and settings do not reliably remove it (anthropics/claude-code#4287, #7543)
func stripClaudeAttribution(h *hook) decision {
	if !h.anyCall(func(c call) bool { g := c.gitArgs(); return g != nil && g[0] == "commit" }) || !attribution.MatchString(h.command) {
		return decision{}
	}
	s := h.command
	for _, re := range trailers {
		s = re.ReplaceAllString(s, "")
	}
	s = strings.TrimRight(s, "\n")
	return decision{command: &s}
}
