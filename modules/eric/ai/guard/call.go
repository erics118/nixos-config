package main

import (
	"regexp"
	"slices"
	"strings"

	"mvdan.cc/sh/v3/syntax"
)

// tool is the command's name, without its directory or a nix run flake prefix
func (c call) tool() string { return program(at(c.argv, 0)) }

func program(w string) string {
	t := base(w)
	return t[strings.LastIndex(t, "#")+1:]
}

func (c call) args() []string {
	if len(c.argv) == 0 {
		return nil
	}
	return c.argv[1:]
}

// parsed is the call's words read by its own program's options
func (c call) parsed() args { return parseArgs(c.tool(), c.args()) }

var fdNumber = regexp.MustCompile(`^([0-9]+|-)$`)

// the redirects that write their word. >& writes it unless it names a descriptor
var writeRedirs = []syntax.RedirOperator{syntax.RdrOut, syntax.AppOut, syntax.RdrClob, syntax.AppClob, syntax.RdrAll,
	syntax.RdrAllClob, syntax.AppAll, syntax.AppAllClob, syntax.RdrInOut}

// streams lists the files a redirect or tee writes
func (c call) streams() []string {
	var out []string
	for _, r := range c.redirs {
		if slices.Contains(writeRedirs, r.op) || (r.op == syntax.DplOut && !fdNumber.MatchString(r.word)) {
			out = append(out, r.word)
		}
	}
	if c.tool() == "tee" {
		out = append(out, c.parsed().operands...)
	}
	return out
}

// a target is a path a call writes
type target struct {
	// word is the path as written
	word string
	// alt is a redirect target's empty-var (cd-failed) rendering, checked alongside word; "" when there is none
	alt string
	// into lists the sources a copy writes into word under their own names, when word is a folder
	into []string
	// folder marks a word the call always treats as a folder, as cp -t does
	folder bool
	// creates marks a new file or folder, as mkdir or touch makes, rather than an overwrite
	creates bool
}

var copiers = []string{"cp", "mv", "install", "rsync", "ln"}

// targets lists the paths the call writes: redirects and tee, the destination of cp, mv, install, rsync, or ln,
// dd's of=, the output option of sort, tree, uniq, or git diff and log, the files an in-place sed or perl or truncate
// changes, the files an awk, sed, or interpreter script writes, and what mkdir, touch, install -d, or git worktree add creates
func (c call) targets() []target {
	var out []target
	add := func(creates bool, words ...string) {
		for _, w := range words {
			out = append(out, target{word: w, creates: creates})
		}
	}
	// redirect targets carry alt (the empty-var world); tee's file operands do not
	for _, r := range c.redirs {
		if slices.Contains(writeRedirs, r.op) || (r.op == syntax.DplOut && !fdNumber.MatchString(r.word)) {
			out = append(out, target{word: r.word, alt: r.alt})
		}
	}
	if c.tool() == "tee" {
		add(false, c.parsed().operands...)
	}
	p := c.parsed()
	switch t := c.tool(); {
	case c.inPlaceEdit():
		add(false, c.inPlaceFiles()...)
	case t == "truncate":
		add(false, p.operands...)
	case t == "mkdir" || t == "touch" || (t == "install" && p.has("-d", "--directory")):
		add(true, p.operands...)
	case slices.Contains(copiers, t):
		// rsync's -t keeps times, so only the others name a target folder with it
		if dir, ok := p.value("-t", "--target-directory"); ok && t != "rsync" {
			out = append(out, target{word: dir, into: p.operands, folder: true})
		} else if t == "ln" && len(p.operands) == 1 {
			out = append(out, target{word: ".", into: p.operands, folder: true})
		} else if len(p.operands) > 1 {
			out = append(out, target{word: p.operands[len(p.operands)-1], into: p.operands[:len(p.operands)-1]})
		}
	case t == "dd":
		for _, a := range c.args() {
			if f, ok := strings.CutPrefix(a, "of="); ok {
				add(false, f)
			}
		}
	case t == "sort" || t == "tree":
		if f, ok := p.value("-o", "--output"); ok {
			add(false, f)
		}
	case t == "uniq" && len(p.operands) > 1:
		add(false, p.operands[1])
	case t == "awk" || t == "sed":
		add(false, programWrites(c).files...)
	case interpreter(t) != "":
		add(false, scriptWrites(c.scriptText())...)
	}
	if g := c.gitArgs(); at(g, 0) == "worktree" && at(g, 1) == "add" {
		add(true, at(parseArgs("git worktree add", g[2:]).operands, 0))
	} else if slices.Contains([]string{"diff", "log", "show", "whatchanged"}, at(g, 0)) {
		if f, ok := parseArgs("git "+g[0], g[1:]).value("--output"); ok {
			add(false, f)
		}
	}
	return out
}

// interpreters run a script given as a word, which can write files the shell never names
var interpreters = regexp.MustCompile(`^(python(3(\.[0-9]+)?)?|node|ruby|perl)$`)

// scriptText is the words a call passes, unquoted, and the here-string or heredoc it reads,
// so a script given as python3 -c "open(\"f\", \"w\")" reads without its escapes
func (c call) scriptText() string {
	parts := slices.Clone(c.argv)
	if s, ok := c.hereText(); ok {
		parts = append(parts, s)
	}
	return strings.Join(parts, "\n")
}

// writesFiles reports a script with a write call in python, node, ruby, or perl
func writesFiles(c call) bool { return lineMatch(scriptWrite, c.scriptText()) }

// inPlaceEdit reports sed or perl editing its files in place
func (c call) inPlaceEdit() bool {
	t := c.tool()
	return (t == "sed" || t == "perl") && c.parsed().has("-i", "--in-place")
}

// inPlaceFiles is what an in-place sed or perl edits: its operands, past the script,
// which -e or -f names or which sed otherwise takes as its first operand
func (c call) inPlaceFiles() []string {
	p := c.parsed()
	files := p.operands
	if c.tool() == "sed" && !p.has("-e", "-f", "--expression", "--file") && len(files) > 0 {
		files = files[1:]
	}
	return files
}

// program is the awk or sed program text: what -e gives, else the first operand. a program from a file with -f
// is not read, as no script file is
func (c call) program() string {
	p := c.parsed()
	if e, ok := p.value("-e", "--expression"); ok {
		return e
	}
	if p.has("-f", "--file") {
		return ""
	}
	return at(p.operands, 0)
}

var (
	// awk's print and printf write to a file after > or >>, and run a command after | or |&
	awkOutput = regexp.MustCompile(`\bprintf?\b[^;{}\n]*?(>>|>|\|&|\|)\s*("([^"]*)"|[^\s;}]+)`)
	awkRuns   = regexp.MustCompile(`\bsystem\s*\(|\|\s*getline`)
	// an awk string literal, so its contents can be masked before the output and run regexes read the program
	awkStr = regexp.MustCompile(`"(?:\\.|[^"\\])*"`)
	// sed's w and W commands and the w flag of s write the file named to the end of the line, and e runs a command
	sedWrite = regexp.MustCompile(`(?m)(?:^|[;{}])\s*(?:[0-9$]+|/[^/]*/)?\s*[wW]\s+([^;}\n]+)|s/(?:\\.|[^\\/])*/(?:\\.|[^\\/])*/[gpiImM0-9]*w\s*([^;}\n]+)`)
	sedRuns  = regexp.MustCompile(`(?m)(?:^|[;{}])\s*(?:[0-9$]+|/[^/]*/)?\s*e(\s|;|$)|s/(?:\\.|[^\\/])*/(?:\\.|[^\\/])*/[gpiImM0-9]*e`)
)

// a programWrite is what an awk or sed program writes. runs marks one that runs a command or writes to a file
// it names by an expression, which the guard cannot see
type programWrite struct {
	files []string
	runs  bool
}

func programWrites(c call) programWrite {
	text := c.program()
	var w programWrite
	switch c.tool() {
	case "awk":
		text = maskAwkStrings(text)
		w.runs = awkRuns.MatchString(text)
		for _, m := range awkOutput.FindAllStringSubmatch(text, -1) {
			if strings.HasPrefix(m[1], "|") || !strings.HasPrefix(m[2], `"`) {
				w.runs = true
			} else {
				w.files = append(w.files, m[3])
			}
		}
	case "sed":
		w.runs = sedRuns.MatchString(text)
		for _, m := range sedWrite.FindAllStringSubmatch(text, -1) {
			w.files = append(w.files, strings.TrimSpace(m[1]+m[2]))
		}
	}
	return w
}

// maskAwkStrings blanks the characters the output and run regexes key on inside awk string literals,
// so a >, |, or system( in a printf format is read as text while a real redirect to a quoted file still parses
func maskAwkStrings(text string) string {
	b := []byte(text)
	for _, span := range awkStr.FindAllStringIndex(text, -1) {
		for i := span[0] + 1; i < span[1]-1; i++ {
			if strings.IndexByte(">|&;{}(", b[i]) >= 0 {
				b[i] = '_'
			}
		}
	}
	return string(b)
}

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

// scriptWrites is the paths an interpreter script writes: the literal path each write names. when a write
// targets a variable instead, every quoted path the script names counts, so a write the guard cannot place still checks
func scriptWrites(text string) []string {
	if !lineMatch(scriptWrite, text) {
		return nil
	}
	var literal []string
	for _, re := range []*regexp.Regexp{pathWrite, openWrite, nodeWrite} {
		literal = append(literal, lineSubmatches(re, text)...)
	}
	paths := literal
	if len(literal) == 0 || len(literal) < len(scriptWrite.FindAllString(text, -1)) {
		paths = append(lineSubmatches(singleQuoted, text), lineSubmatches(doubleQuoted, text)...)
	}
	// perl opens with the mode in front of the path, as ">file"
	for i, p := range paths {
		paths[i] = strings.TrimLeft(p, "+<> ")
	}
	return paths
}

// dirs is where the call may run: its dir when known, else what a branch could have left. empty when unknown
func (c call) dirs() []string {
	if c.dir != "" {
		return []string{c.dir}
	}
	return c.maybe
}
