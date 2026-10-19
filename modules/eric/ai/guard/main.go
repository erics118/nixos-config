package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"slices"
)

func main() {
	os.Exit(run(os.Args[1:], os.Stdin, os.Stdout, os.Stderr))
}

// a decision with no kind and no command lets the call through
type decision struct {
	kind    string
	reason  string
	command *string
}

func deny(reason string) decision { return decision{kind: "deny", reason: reason} }
func ask(reason string) decision  { return decision{kind: "ask", reason: reason} }

func run(args []string, stdin io.Reader, stdout, stderr io.Writer) int {
	if len(args) == 1 && args[0] == "checks" {
		for _, c := range preChecks {
			fmt.Fprintln(stdout, c.name)
		}
		for _, c := range postChecks {
			fmt.Fprintln(stdout, c.name)
		}
		return 0
	}
	if len(args) < 2 || (args[0] != "pre" && args[0] != "post") {
		fmt.Fprintln(stderr, "usage: agent-guard pre|post claude|codex|pi [check...]")
		return 2
	}
	event, harness, names := args[0], args[1], args[2:]
	raw, err := io.ReadAll(stdin)
	if err != nil {
		return failClosed(event, stdout, stderr, fmt.Sprintf("The guard could not read the hook event: %v, so the call was not checked.", err))
	}
	h, err := newHook(harness, raw)
	if err != nil {
		return failClosed(event, stdout, stderr, fmt.Sprintf("The guard could not parse the hook event: %v, so the call was not checked.", err))
	}
	if event == "post" {
		checks, missing := pick(postChecks, h.toolName, names)
		if missing != "" {
			fmt.Fprintf(stderr, "The guard check %s does not exist.\n", missing)
			return 1
		}
		return runPost(h, checks, stderr)
	}
	checks, missing := pick(preChecks, h.toolName, names)
	if missing != "" {
		writeDecision(stdout, h, deny(fmt.Sprintf("The guard check %s does not exist, so the command was not checked.", missing)))
		return 0
	}
	if len(checks) == 0 {
		return 0
	}
	d := runPre(h, checks)
	if d.kind == "" && d.command == nil {
		return 0
	}
	writeDecision(stdout, h, d)
	return 0
}

// a pre hook denies. a post hook already ran its tool, so it only reports
func failClosed(event string, stdout, stderr io.Writer, reason string) int {
	if event == "post" {
		fmt.Fprintln(stderr, reason)
		return 1
	}
	writeDecision(stdout, nil, deny(reason))
	return 0
}

// runPre combines the checks. a deny wins at once, the first ask wins over later ones, and the last rewrite wins
func runPre(h *hook, checks []preCheck) decision {
	if h.command != "" {
		if err := h.parse(); err != nil {
			return deny(fmt.Sprintf("The guard hooks could not parse this command, so they could not check it: %v. Rewrite it in plain bash syntax.", err))
		}
		if slices.ContainsFunc(h.calls, func(c call) bool { return c.stdin }) {
			return deny("A shell here reads its script from standard input, so the guard hooks cannot check it. Pass the script with bash -c, a here-string, or a heredoc.")
		}
		if slices.ContainsFunc(h.calls, func(c call) bool { return c.opaque }) {
			return deny("The guard cannot tell which program this command runs, since its name comes from a variable, a substitution, a glob, or an escape, so it cannot check it. Write the program name literally.")
		}
	}
	var out decision
	for _, c := range checks {
		name := c.name
		d, err := safely(func() decision { return c.run(h) })
		if err != nil {
			return deny(fmt.Sprintf("The guard check %s failed: %v, so the command was not checked.", name, err))
		}
		switch d.kind {
		case "deny":
			if d.reason == "" {
				d.reason = name + " blocked this."
			}
			return d
		case "ask":
			if out.kind == "" {
				out.kind, out.reason = "ask", d.reason
				if out.reason == "" {
					out.reason = name + " asks for approval."
				}
			}
		}
		if d.command != nil {
			out.command = d.command
		}
	}
	// codex runs an ask as allow and applies a rewrite only with an allow
	if h.harness == "codex" {
		if out.kind == "ask" {
			return deny(out.reason + " Codex cannot ask for approval, so this was denied. Tell the user what to run.")
		}
		out.command = nil
	}
	return out
}

func safely(f func() decision) (d decision, err error) {
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("%v", r)
		}
	}()
	return f(), nil
}

// a post check warns the model with stderr and exit 2. the tool already ran, so nothing blocks
func runPost(h *hook, checks []postCheck, stderr io.Writer) int {
	rc := 0
	for _, c := range checks {
		var msg string
		var code int
		_, err := safely(func() decision { msg, code = c.run(h); return decision{} })
		if err != nil {
			fmt.Fprintf(stderr, "The guard check %s failed: %v.\n", c.name, err)
			rc = 1
			continue
		}
		if msg != "" {
			fmt.Fprint(stderr, msg)
		}
		if code != 0 {
			rc = code
		}
	}
	return rc
}

func writeDecision(w io.Writer, h *hook, d decision) {
	type specific struct {
		HookEventName            string                     `json:"hookEventName"`
		PermissionDecision       string                     `json:"permissionDecision,omitempty"`
		PermissionDecisionReason string                     `json:"permissionDecisionReason,omitempty"`
		UpdatedInput             map[string]json.RawMessage `json:"updatedInput,omitempty"`
	}
	s := specific{HookEventName: "PreToolUse", PermissionDecision: d.kind, PermissionDecisionReason: d.reason}
	if d.command != nil && h != nil {
		s.UpdatedInput = map[string]json.RawMessage{}
		for k, v := range h.toolInput {
			s.UpdatedInput[k] = v
		}
		cmd, _ := json.Marshal(*d.command)
		s.UpdatedInput["command"] = cmd
	}
	enc := json.NewEncoder(w)
	enc.SetEscapeHTML(false)
	_ = enc.Encode(struct {
		HookSpecificOutput specific `json:"hookSpecificOutput"`
	}{s})
}
