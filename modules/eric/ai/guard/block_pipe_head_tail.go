package main

import (
	"slices"
	"strings"

	"mvdan.cc/sh/v3/syntax"
)

// block piping output into head or tail, which drops lines before anyone has seen them.
// a tee to a file earlier in the same pipeline saves the full output, and head or tail on a file reads what was saved
func blockPipeHeadTail(h *hook) decision {
	// calls come in walk order, left to right, so a tee before the head in its pipeline has been seen by then
	saved := map[int]bool{}
	for _, c := range h.calls {
		if t := c.tool(); (t == "head" || t == "tail") && readsOutput(c) && !saved[c.pipe] && !tailToEnd(c) {
			return deny("Piping output into head or tail drops lines before you've seen them. Save the full output to a file in the scratch directory (`cmd > <scratch>/out.log 2>&1`, or `cmd | tee <scratch>/out.log`), then read or search that file. To get one value, use the command's own option (`git log -n 1`, `nix build --print-out-paths`).")
		}
		// a tee feeding head saves the output only if it keeps writing after head closes the pipe (-p or
		// --output-error=warn); a plain tee exits on the broken pipe (GNU default) and truncates the file too
		if c.tool() == "tee" && c.pipe != 0 && teeKeepsWriting(c) && slices.ContainsFunc(c.streams(), func(w string) bool {
			return !strings.HasPrefix(w, "/dev/") && !strings.Contains(w, "$(...)")
		}) {
			saved[c.pipe] = true
		}
	}
	return decision{}
}

// tailToEnd reports tail -n +N (or --lines +N), which prints from a line to the end, dropping nothing unseen
func tailToEnd(c call) bool {
	if c.tool() != "tail" {
		return false
	}
	v, ok := c.parsed().value("-n", "--lines")
	return ok && strings.HasPrefix(v, "+")
}

// teeKeepsWriting reports a tee that keeps writing its file after a downstream reader closes the pipe:
// -p, or --output-error set to warn or warn-nopipe. a plain tee exits on the broken pipe and truncates
func teeKeepsWriting(c call) bool {
	p := c.parsed()
	if p.has("-p") {
		return true
	}
	v, ok := p.value("--output-error")
	return ok && (v == "warn" || v == "warn-nopipe")
}

// readsOutput reports a head or tail that reads another command's output: from a pipe, a <(...) operand,
// or a < or <<< of a substitution. a file operand reads that file instead, and - names the pipe
func readsOutput(c call) bool {
	ops := c.parsed().operands
	if c.piped && slices.Contains(ops, "-") {
		return true
	}
	if slices.ContainsFunc(ops, func(w string) bool { return w != "-" && w != "$(...)" }) {
		return false
	}
	return c.piped || slices.Contains(ops, "$(...)") || slices.ContainsFunc(c.redirs, func(r redir) bool {
		return (r.op == syntax.RdrIn || r.op == syntax.WordHdoc) && strings.Contains(r.word, "$(...)")
	})
}
