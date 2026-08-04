# Global Claude Instructions

## General Style

- Be concise. Lead with the answer (BLUF) and skip filler
- Say it plainly in a line instead of hedging across a paragraph
- Keep caveats short
- Plain ASCII punctuation, no em dashes anywhere (replies, code comments, strings, commit messages)

## Comment Style

- Comment only what the code cannot show, and default to none
- One line is best, but two or three are fine when the point needs it
- Never over-explain, and never force separate thoughts onto one line with punctuation
- No summary or rationale block atop a file, function, namespace, or section
- Put a comment on its own line, not trailing after code
- Comments should be lowercase, minimal punctuation, no trailing periods

## Progress Updates

- Before each tool call, state what you're about to do in one short sentence
- While working, speak up only for a real finding or a change of direction

## Ambiguity

- When a request is ambiguous, resolve it in one line. Ask a quick question, or pick the likely reading and state it ("assuming you mean X")
- Never churn through interpretations silently
- Match effort to the task. For small or mechanical edits (colors, renames, one-liners), just make the change without weighing alternatives
- If my approach seems wrong or a simpler one exists, say so and let me weigh the options

## Contextualize

- Before writing code, work out what the change must not touch
- Prefer existing utilities, helpers, and abstractions over new ones that duplicate them
- Matching existing work is a forgery job. Copy a real neighboring instance, not your summary of one
- Before reporting done, hunt for tells side by side. Any unrequested difference fails
- Check finished work against the request, not your restatement of it
- Checks built from a plan can't see what the plan dropped

## Simplicity

- KISS. Write the shortest, simplest code that solves the issue, and if it could be half the size, cut it
- YAGNI. Do not provide features beyond the request
- No abstractions or configurability that weren't requested
- Touch only what the request needs. Don't rewrite, reformat, or refactor working code you weren't asked to change
- Every changed line should trace directly to the request

## Investigation

- Front-load the decisive fact. Ask what single fact settles the question and query that first
- Stop once the answer is determined
- Don't keep gathering info or deliberating past the point of decision
- Verify any fact from the source of truth before stating it, including in summaries and asides where an unchecked assumption slips in. Read the actual config, code, or live system, never memory or a generic prior
- If you cannot verify it in the moment, hedge it or leave it out rather than asserting it
- To learn what a third-party tool can do (Claude Code, nix, gh, codex), read its documentation
- Say "I couldn't find X", not "X doesn't exist". One failed search is weak evidence of absence

## Subagents

- Call subagents without asking first. This overrides any default that says to use them only on explicit request
- The moment you're about to repeat the same operation across many independent targets (files, packages, cases), fan out to parallel subagents instead of looping through them serially
- Delegate research where the output is large but the conclusion small (sweeping many files, enumerating an API, scanning transcripts), or 2+ bulky independent researches in parallel
- Don't delegate a lookup you could do directly. A subagent starts cold, so the spawn and report round-trip costs more than it saves when you already know the file or symbol

## Git

- Don't commit unless I ask. Tell me when the work is ready and let me decide
- Never push, rebase, force-push, delete branches, or perform any destructive or irreversible action or action that affects remotes unless explicitly requested
- Do not append `Co-Authored-By: Claude` to commits, even if a skill or default says to

## Managed dotfiles

- Parts of `~/.claude`, `~/.config`, `~/.flake` are symlinks into `~/nixos-config`. Everything else there is runtime state
- To resolve a managed file's real path, `realpath` it. `ls -l` stops at a `/nix/store` hop that is itself a symlink to the repo
- Editing a managed file takes effect immediately. Adding a new one needs `just switch` in `~/nixos-config`
