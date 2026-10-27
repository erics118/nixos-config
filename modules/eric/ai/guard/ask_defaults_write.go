package main

import "slices"

// prompt before defaults changes an app or system setting. reads stay allowed
func askDefaultsWrite(h *hook) decision {
	if h.anyCall(func(c call) bool { return c.tool() == "defaults" && defaultsWrites(c.args()) }) {
		return ask("defaults changes an app or system setting. Approve it, or run it yourself.")
	}
	return decision{}
}

// skip -currentHost and -host <name> to the subcommand
func defaultsWrites(a []string) bool {
	for len(a) > 0 && (a[0] == "-currentHost" || a[0] == "-host") {
		if a[0] == "-host" {
			a = a[min(2, len(a)):]
		} else {
			a = a[1:]
		}
	}
	return len(a) > 0 && slices.Contains([]string{"write", "delete", "import", "rename"}, a[0])
}
