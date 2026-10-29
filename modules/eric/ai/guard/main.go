package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"slices"
	"strings"
)

func main() {
	os.Exit(run(os.Args[1:], os.Stdin, os.Stdout, os.Stderr))
}

// a decision with no kind, no command, and no context lets the call through
type decision struct {
	kind    string
	reason  string
	command *string
	// updated overrides fields of the tool input (updatedInput), such as a Write's content normalized to ASCII
	updated map[string]json.RawMessage
	// context is additionalContext added to the model's context alongside the tool result: a non-blocking
	// warning that lets the call run. several checks' contexts accumulate
	context []string
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
	if len(args) == 2 && args[0] == "tools" && (args[1] == "pre" || args[1] == "post") {
		tools := toolsOf(preChecks)
		if args[1] == "post" {
			tools = toolsOf(postChecks)
		}
		for _, t := range tools {
			fmt.Fprintln(stdout, t)
		}
		return 0
	}
	if len(args) < 2 || (args[0] != "pre" && args[0] != "post") {
		fmt.Fprintln(stderr, "usage: agent-guard pre|post claude|codex|pi [check...], agent-guard checks, or agent-guard tools pre|post")
		return 2
	}
	event, harness, names := args[0], args[1], args[2:]
	if !slices.Contains([]string{"claude", "codex", "pi"}, harness) {
		return failClosed(event, stdout, stderr, fmt.Sprintf("The guard does not know the harness %q, so the call was not checked.", harness))
	}
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
	if d.kind == "" && d.command == nil && len(d.updated) == 0 && len(d.context) == 0 {
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
		var err error
		if panicked := safely(func() { err = h.parse() }); panicked != nil {
			err = panicked
		}
		if err != nil {
			return deny(fmt.Sprintf("The guard hooks could not parse this command, so they could not check it: %v. Rewrite it in plain bash syntax.", err))
		}
		if i := slices.IndexFunc(h.calls, func(c call) bool { return c.hidden != "" }); i >= 0 {
			return deny(h.calls[i].hidden)
		}
	}
	var out decision
	for _, c := range checks {
		name := c.name
		var d decision
		if err := safely(func() { d = c.run(h) }); err != nil {
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
		for k, v := range d.updated {
			if out.updated == nil {
				out.updated = map[string]json.RawMessage{}
			}
			out.updated[k] = v
		}
		out.context = append(out.context, d.context...)
	}
	// codex runs an ask as allow and applies a rewrite only with an allow
	if h.harness == "codex" {
		if out.kind == "ask" {
			return deny(out.reason + " Codex cannot ask for approval, so this was denied. Tell the user what to run.")
		}
		out.command, out.updated = nil, nil
	}
	return out
}

// safely runs f and turns a panic into an error, so one broken check fails closed instead of crashing the hook
func safely(f func()) (err error) {
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("%v", r)
		}
	}()
	f()
	return nil
}

// a post check warns the model with stderr and exit 2. the tool already ran, so nothing blocks
func runPost(h *hook, checks []postCheck, stderr io.Writer) int {
	rc := 0
	for _, c := range checks {
		var msg string
		var code int
		if err := safely(func() { msg, code = c.run(h) }); err != nil {
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
		AdditionalContext        string                     `json:"additionalContext,omitempty"`
	}
	s := specific{HookEventName: "PreToolUse", PermissionDecision: d.kind, PermissionDecisionReason: d.reason}
	if len(d.context) > 0 {
		s.AdditionalContext = strings.Join(d.context, "\n")
	}
	if (d.command != nil || len(d.updated) > 0) && h != nil {
		s.UpdatedInput = map[string]json.RawMessage{}
		for k, v := range h.toolInput {
			s.UpdatedInput[k] = v
		}
		if d.command != nil {
			cmd, _ := json.Marshal(*d.command)
			s.UpdatedInput["command"] = cmd
		}
		for k, v := range d.updated {
			s.UpdatedInput[k] = v
		}
	}
	enc := json.NewEncoder(w)
	enc.SetEscapeHTML(false)
	_ = enc.Encode(struct {
		HookSpecificOutput specific `json:"hookSpecificOutput"`
	}{s})
}
