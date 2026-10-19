package main

import (
	"fmt"
	"os"
	"regexp"
	"strings"
)

var (
	hashBang    = regexp.MustCompile(`^[[:space:]]*#!`)
	hashComment = regexp.MustCompile(`^[[:space:]]*#`)
	dashComment = regexp.MustCompile(`^[[:space:]]*--`)
	slashLine   = regexp.MustCompile(`^[[:space:]]*//`)
	blockOpen   = regexp.MustCompile(`^[[:space:]]*/\*`)
	shebangLine = regexp.MustCompile(`^#!`)
)

// the comment syntax each file extension uses
var commentModes = map[string][]string{
	"slash": {".c", ".cc", ".cpp", ".cxx", ".h", ".hpp", ".hh", ".js", ".jsx", ".ts", ".tsx", ".go", ".rs", ".java", ".kt", ".swift",
		".cs", ".scala", ".php", ".json", ".jsonc", ".json5"},
	"block": {".css", ".scss", ".less"},
	"hash":  {".sh", ".bash", ".zsh", ".py", ".nix", ".yaml", ".yml", ".toml", ".rb", ".pl"},
	"dash":  {".lua"},
}

// flag comment blocks longer than 3 lines in the text an edit introduced.
// scans only newly written text, so pre-existing blocks in an edited file stay quiet
func warnCommentBlock(h *hook) (string, int) {
	f := h.str("file_path")
	if f == "" || !isFile(f) {
		return "", 0
	}
	mode := ""
	for m, exts := range commentModes {
		for _, ext := range exts {
			if strings.HasSuffix(f, ext) {
				mode = m
			}
		}
	}
	if mode == "" {
		return "", 0
	}
	// only the text this tool call wrote: Write content, Edit new_string, MultiEdit each new_string
	e := h.edit()
	var added string
	switch {
	case e.Content != nil:
		added = *e.Content
	case e.NewString != nil:
		added = *e.NewString
	case e.Edits != nil:
		var parts []string
		for _, ed := range e.Edits {
			if ed.NewString != nil {
				parts = append(parts, *ed.NewString)
			} else {
				parts = append(parts, "")
			}
		}
		added = strings.Join(parts, "\n")
	}
	if added == "" {
		return "", 0
	}
	file, err := os.ReadFile(f)
	if err != nil {
		return "", 0
	}
	// a block that opens the file is a header (license, userscript metadata), not an essay
	lines := strings.Split(added, "\n")
	atTop := strings.SplitN(string(file), "\n", 2)[0] == lines[0]

	longest, streak, end := 0, 0, ""
	inBlock, header := false, false
	for i, line := range lines {
		c := false
		switch mode {
		case "hash":
			c = !hashBang.MatchString(line) && hashComment.MatchString(line)
		case "dash":
			c = dashComment.MatchString(line)
		default:
			switch {
			case inBlock:
				c = true
				inBlock = !strings.Contains(line, "*/")
			case mode == "slash" && slashLine.MatchString(line):
				c = true
			case blockOpen.MatchString(line):
				c = true
				inBlock = !strings.Contains(line, "*/")
			}
		}
		if c && streak == 0 {
			header = atTop && (i == 0 || (i == 1 && shebangLine.MatchString(lines[0])))
		}
		if !c {
			streak = 0
			continue
		}
		streak++
		if !header && streak > longest {
			longest, end = streak, line
		}
	}
	if longest < 4 {
		return "", 0
	}
	// locate the added block in the file for a real line number, else name the file alone
	loc := f
	for i, line := range strings.Split(string(file), "\n") {
		if strings.Contains(line, end) {
			loc = fmt.Sprintf("%s:%d", f, i+1)
			break
		}
	}
	return fmt.Sprintf("comment block of %d lines ending at %s. AGENTS.md: one line is best, two or three max, never a rationale/essay block. cut it to the durable fact or delete it.\n", longest, loc), 2
}
