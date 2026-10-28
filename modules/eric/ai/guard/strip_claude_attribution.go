package main

import (
	"cmp"
	"regexp"
	"slices"
	"strings"
)

// a trailer goes from its keyword, after any indent or robot emoji, to the end of its line or quote.
// Co-Authored-By may follow a message on its line, and the others start one
const trailerLead = `(?i)[ \t]*(\x{1F916}[ \t]*)?`

var (
	attribution = regexp.MustCompile(`(?i)(co-authored-by|assisted-by):.*(claude|anthropic)|generated with.*claude|claude-session:`)
	trailers    = []*regexp.Regexp{
		regexp.MustCompile(trailerLead + `(co-authored-by|assisted-by):[^\n"']*(claude|anthropic)[^\n"']*\n?`),
		regexp.MustCompile(`(?m)^` + trailerLead + `generated with[^\n"']*claude[^\n"']*\n?`),
		regexp.MustCompile(`(?m)^` + trailerLead + `claude-session:[^\n"']*\n?`),
	}
)

// strip claude attribution trailers from the messages of git commit commands before they run.
// the system prompt hardcodes Co-Authored-By and settings do not reliably remove it (anthropics/claude-code#4287, #7543)
func stripClaudeAttribution(h *hook) decision {
	if !h.anyCall(func(c call) bool { return at(c.gitArgs(), 0) == "commit" }) || !attribution.MatchString(h.command) {
		return decision{}
	}
	s := h.command
	spans := h.commitMessages()
	for i := len(spans) - 1; i >= 0; i-- {
		lo, hi := spans[i][0], spans[i][1]
		msg := s[lo:hi]
		for _, re := range trailers {
			msg = re.ReplaceAllString(msg, "")
		}
		s = s[:lo] + msg + s[hi:]
	}
	if s == h.command {
		return decision{}
	}
	s = strings.TrimRight(s, "\n")
	return decision{command: &s}
}

// commitMessages is the byte ranges in the command of each git commit's message: the word that holds a -m
// or --message value, and the heredoc that -F - reads. only top-level calls keep their positions,
// so a commit in a bash -c script or behind an alias is left alone
func (h *hook) commitMessages() [][2]int {
	var spans [][2]int
	for _, c := range h.calls {
		g := c.gitArgs()
		if c.spans == nil || at(g, 0) != "commit" {
			continue
		}
		// option words count from the one after commit
		base := len(c.argv) - len(g) + 1
		for _, o := range parseArgs("git commit", g[1:]).opts {
			switch o.name {
			case "-m", "--message":
				spans = append(spans, c.spans[base+o.word])
			case "-F", "--file":
				if slices.Equal(o.values, []string{"-"}) {
					for _, r := range c.redirs {
						if r.hdocSpan != nil {
							spans = append(spans, *r.hdocSpan)
						}
					}
				}
			}
		}
	}
	// a word that splits into several fields gives each the same range
	slices.SortFunc(spans, func(a, b [2]int) int { return cmp.Compare(a[0], b[0]) })
	return slices.Compact(spans)
}
