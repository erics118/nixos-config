package main

import (
	"fmt"
	"slices"
)

// block a relative write after a cd the guard cannot follow, such as cd "$d". the write checks
// cannot tell which file it lands on, so a tracked file, a symlink, or a git config could be behind it
func blockUnresolvedWrite(h *hook) decision {
	for _, w := range h.written() {
		if w.unresolved && !w.creates {
			if w.fromCd {
				return deny(fmt.Sprintf("This command writes %s after a cd the guard cannot follow, so it cannot tell which file that is. Use an absolute path, or cd to a literal path.", w.word))
			}
			return deny(fmt.Sprintf("This command writes %s, a path built from a value the guard cannot resolve, so it cannot tell which file that is. Write to a literal path, such as one new-scratch.sh prints.", w.word))
		}
	}
	if slices.ContainsFunc(h.interpreterCalls(), func(c call) bool { return len(c.dirs()) == 0 && writesFiles(c) }) {
		return deny("This script writes files after a cd the guard cannot follow, so it cannot tell which files those are. cd to a literal path first.")
	}
	return decision{}
}
