package main

// block rm everywhere. trash keeps a way back, rm does not
func blockRm(h *hook) decision {
	if h.anyCall(func(c call) bool { return c.tool() == "rm" }) {
		return deny("Agents never run rm. Delete with `trash <path>` instead.")
	}
	return decision{}
}
