package main

import (
	"fmt"
	"strings"
)

// block a relative write after a cd the guard cannot follow, such as cd "$d". the write checks
// cannot tell which file it lands on, so a tracked file, a symlink, or a git config could be behind it
func blockUnresolvedWrite(h *hook) decision {
	for _, c := range h.calls {
		if len(c.dirs()) > 0 {
			continue
		}
		targets := c.writes()
		if dest, ok := c.copyDest(); ok {
			targets = append(targets, dest)
		}
		if c.inPlaceEdit() {
			targets = append(targets, c.inPlaceFiles()...)
		}
		if c.tool() == "truncate" {
			targets = append(targets, c.argv[len(c.argv)-1])
		}
		for _, t := range targets {
			if t == "" || absolute(t) || strings.HasPrefix(t, "&") {
				continue
			}
			return deny(fmt.Sprintf("This command writes %s after a cd the guard cannot follow, so it cannot tell which file that is. Use an absolute path, or cd to a literal path.", t))
		}
	}
	if in, ok := h.interpreter(); ok && len(in.dirs()) == 0 && lineMatch(scriptWrite, h.scriptText()) {
		return deny("This script writes files after a cd the guard cannot follow, so it cannot tell which files those are. cd to a literal path first.")
	}
	return decision{}
}
