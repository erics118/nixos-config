# Global Claude Instructions

## General Style

- Be concise. Lead with the answer or result (BLUF), then the detail. Skip conversational filler and don't recap changes I can already see in the diff
- Plain ASCII punctuation. No em or en dashes anywhere: replies, comments in code, strings, commit messages. Use periods, commas, or parentheses
- When unsure, say so plainly in a line instead of hedging across a paragraph

## Comment Style

- Keep comments concise and simple
- Never use decorative section comments like `// ── Section ───────` or `# ── Section ────────`
- Comments should be generally lowercase, with minimal punctuation, no trailing periods

## Clarity

- State assumptions explicitly; if uncertain or ambiguous, ask rather than pick silently
- When you proceed under an assumption, state what you assumed
- If you feel the user's approach is incorrect, say so. Always let the user weigh the possible options
- If a simpler approach exists, say so. Push back when warranted

## Contextualize

- The goal is to produce code that looks like it was written by the same team, not code that is merely correct in isolation
- Before writing code, read the surrounding codebase: what the request touches, and what it must not
- Read files in the same module or layer as your change to understand naming, structure, and abstractions in use
- Prefer existing utilities, helpers, and abstractions over introducing new ones that duplicate them

## Simplicity

- KISS: write the shortest, simplest code that solves the issue; if it could be half the size, cut it
- YAGNI: do not provide features beyond what was asked
- No abstractions/configurability that weren't requested
- Only handle the errors that can actually occur; don't handle impossible cases

## Surgical Changes

- Minimal diff: touch only the code you need to
- Do not rewrite existing code, comments, or reformat other parts of the codebase
- Do not refactor things that aren't broken
- Every changed line should trace directly to the user's request

## Investigation

- Front-load the decisive fact. Before fanning out to gather breadth, ask "what single fact settles this question?" and query that first
- Stop investigating once the answer is determined. When a fact rules out the alternatives, commit and act. Don't keep gathering or deliberating past the point of decision
- Verify from the actual source of truth, don't recite from memory. For any factual claim (a value, version, default, state, behavior), read it from the actual config/code/live system rather than asserting what it "should" be

## Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification

## Git

- Never run `git commit` without explicit user request. Even when a task is complete, do not commit. Inform the user the work is ready and let them decide when to commit
- Never push, merge, rebase, force-push, delete branches, or perform any destructive action or action that affects remotes unless explicitly requested
- Do not append `Co-Authored-By: Claude` to commits, even if a skill or default says to

## Nix

- Some projects use Nix via direnv, which auto-loads the environment. Run commands normally; you do not need `direnv allow` or `direnv exec .`
