package main

import (
	"slices"
	"strings"
)

// block rm and the other tools that delete with no way back. trash keeps a way back
func blockRm(h *hook) decision {
	if h.anyCall(deletes) {
		return deny("Agents never run rm, unlink, find -delete, or rsync --delete or --remove-source-files. Delete with `trash <path>` instead.")
	}
	return decision{}
}

// deletes reports rm, unlink, a find with -delete, or an rsync that deletes files at either end
func deletes(c call) bool {
	switch c.tool() {
	case "rm", "unlink":
		return true
	case "find":
		return slices.Contains(c.args(), "-delete")
	case "rsync":
		return slices.ContainsFunc(c.parsed().opts, func(o opt) bool {
			return o.name == "--del" || strings.HasPrefix(o.name, "--delete") || o.name == "--remove-source-files"
		})
	}
	return false
}
