package main

import "slices"

// block shell edits of git-tracked files: anything written, a script's writes included, onto a tracked file
// skips the edit tool, so the change never shows as a diff and /rewind cannot undo it.
// binary files, which the edit tool cannot change either, are exempt
func blockShellEdit(h *hook) decision {
	for _, w := range h.written() {
		if !w.creates && slices.ContainsFunc(w.paths, func(p string) bool { return tracked(p) && !binary(p) }) {
			return deny(w.word + " is tracked by git. Use the edit tool so the change shows as a diff and /rewind can undo it.")
		}
	}
	return decision{}
}
