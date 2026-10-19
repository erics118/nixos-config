package main

// block Write over an existing git-tracked file.
// a whole-file write regenerates every line and can silently change lines outside the request.
// Edit touches only the matched text
func blockWriteTracked(h *hook) decision {
	f := h.str("file_path")
	if f == "" || !tracked(f) {
		return decision{}
	}
	return deny(f + " is tracked by git. Use Edit so lines outside the change stay untouched. Write is for new files.")
}
