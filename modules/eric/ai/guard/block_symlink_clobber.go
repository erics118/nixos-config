package main

// block Bash writes onto a path that is currently a symlink.
// mv, ln, and in-place sed/perl replace the link, detaching nix-managed config from its source.
// cp, tee, truncate, and redirects write through the link, outside the edit tool
func blockSymlinkClobber(h *hook) decision {
	for _, w := range h.written() {
		if w.creates {
			continue
		}
		for _, p := range w.paths {
			if isLink(p) {
				return deny(p + " is a symlink (-> " + realpath(p) + "). mv, ln, or in-place sed/perl would replace the link itself, and cp, tee, truncate, or a redirect would write through it. Edit " + realpath(p) + " directly instead.")
			}
			if real := leavesManaged(p); real != "" {
				return deny(leavesReason(real))
			}
		}
	}
	return decision{}
}
