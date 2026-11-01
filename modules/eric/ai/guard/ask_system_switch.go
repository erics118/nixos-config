package main

// prompt before a command that activates the system configuration, so a switch runs only when the user wants it live.
// asks rather than denies, so a switch the user asked for is one confirmation away
func askSystemSwitch(h *hook) decision {
	for _, c := range h.calls {
		for _, dir := range h.paths(c, ".") {
			if isSwitch(c, dir) {
				return ask("This activates the system configuration. Approve it, or run it yourself.")
			}
		}
	}
	return decision{}
}
