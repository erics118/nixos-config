package main

import (
	"regexp"
	"slices"
	"strings"
)

// tool is the command's name, without its directory or a nix run flake prefix
func (c call) tool() string {
	t := base(at(c.argv, 0))
	return t[strings.LastIndex(t, "#")+1:]
}

func (c call) args() []string {
	if len(c.argv) == 0 {
		return nil
	}
	return c.argv[1:]
}

var fdNumber = regexp.MustCompile(`^([0-9]+|-)$`)

// writes lists the files a redirect or tee writes. >& to a number or - duplicates a descriptor instead
func (c call) writes() []string {
	var out []string
	for _, r := range c.redirs {
		if slices.Contains([]string{">", ">>", ">|", "&>", "&>>", "<>"}, r.op) || (r.op == ">&" && !fdNumber.MatchString(r.word)) {
			out = append(out, r.word)
		}
	}
	if c.tool() == "tee" {
		for _, w := range c.args() {
			if !strings.HasPrefix(w, "-") {
				out = append(out, w)
			}
		}
	}
	return out
}

// the destination of a cp or mv, which needs a source before it
func (c call) copyDest() (string, bool) {
	if t := c.tool(); (t == "mv" || t == "cp") && len(c.argv) > 2 {
		return c.argv[len(c.argv)-1], true
	}
	return "", false
}

var inPlaceFlag = regexp.MustCompile(`^-[a-zA-Z]*i|^--in-place`)

// inPlaceEdit reports sed or perl editing its files in place
func (c call) inPlaceEdit() bool {
	t := c.tool()
	return (t == "sed" || t == "perl") && slices.ContainsFunc(c.args(), inPlaceFlag.MatchString)
}

var scriptFlag = regexp.MustCompile(`^-[a-zA-Z]*[ef]$|^--(expression|file)$`)

// inPlaceFiles is what an in-place sed or perl edits: its operands, past the script,
// which -e or -f names or which sed otherwise takes as its first operand
func (c call) inPlaceFiles() []string {
	var files []string
	scripted := false
	a := c.args()
	for i := 0; i < len(a); i++ {
		switch {
		case scriptFlag.MatchString(a[i]):
			scripted = true
			i++
		case !strings.HasPrefix(a[i], "-"):
			files = append(files, a[i])
		}
	}
	if c.tool() == "sed" && !scripted && len(files) > 0 {
		files = files[1:]
	}
	return files
}

// dirs is where the call may run: its dir when known, else what a branch could have left. empty when unknown
func (c call) dirs() []string {
	if c.dir != "" {
		return []string{c.dir}
	}
	return c.maybe
}
