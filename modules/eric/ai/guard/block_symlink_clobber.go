package main

import "strings"

// block Bash writes onto a path that is currently a symlink.
// mv and in-place sed/perl replace the link, detaching nix-managed config from its source.
// cp, tee, truncate, and redirects write through the link, outside the edit tool
func blockSymlinkClobber(h *hook) decision {
	for _, c := range h.calls {
		for _, w := range overwrites(c) {
			// fd dupes like 2>&1 and device sinks are not files we can clobber
			if strings.HasPrefix(w, "&") || strings.HasPrefix(w, "/dev/") {
				continue
			}
			for _, p := range h.paths(c, w) {
				if isLink(p) {
					return deny(p + " is a symlink (-> " + realpath(p) + "). mv or in-place sed/perl would replace the link itself, and cp, tee, truncate, or a redirect would write through it. Edit " + realpath(p) + " directly instead.")
				}
			}
		}
	}
	return decision{}
}

// overwrites lists the paths a call would overwrite: the destination of mv or cp, the files tee writes,
// the file of an in-place editor (sed -i, perl -i, truncate), and each > or >> target
func overwrites(c call) []string {
	out := c.writes()
	if dest, ok := c.copyDest(); ok {
		out = append(out, dest)
	}
	if c.inPlaceEdit() || c.tool() == "truncate" {
		out = append(out, c.argv[len(c.argv)-1])
	}
	return out
}
