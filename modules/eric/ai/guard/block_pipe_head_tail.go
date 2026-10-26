package main

import (
	"slices"
	"strings"
)

// head and tail options that take the next word as their value
var headTailValueOpts = []string{"-n", "-c", "--lines", "--bytes"}

// block piping output into head or tail, which drops lines before anyone has seen them.
// a tee to a file in the same command saves the full output, and head or tail on a file reads what was saved
func blockPipeHeadTail(h *hook) decision {
	saved := h.anyCall(func(c call) bool {
		return c.tool() == "tee" && slices.ContainsFunc(c.writes(), func(w string) bool { return !strings.HasPrefix(w, "/dev/") })
	})
	if !saved && h.anyCall(func(c call) bool {
		t := c.tool()
		return c.piped && (t == "head" || t == "tail") && !hasOperand(c)
	}) {
		return deny("Piping output into head or tail drops lines before you've seen them. Save the full output to a file in the scratch directory (`cmd > <scratch>/out.log 2>&1`, or `cmd | tee <scratch>/out.log`), then read or search that file. To get one value, use the command's own option (`git log -n 1`, `nix build --print-out-paths`).")
	}
	return decision{}
}

// hasOperand reports a head or tail that names a file to read, so it isn't reading its pipe
func hasOperand(c call) bool {
	a := c.args()
	for i := 0; i < len(a); i++ {
		switch {
		case slices.Contains(headTailValueOpts, a[i]):
			i++
		case !strings.HasPrefix(a[i], "-"):
			return true
		}
	}
	return false
}
