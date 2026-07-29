# Global Claude Instructions

## General Style

- Be concise: lead with the answer (BLUF), and skip filler
- Say it plainly in a line instead of hedging across a paragraph; keep caveats short
- Plain ASCII punctuation, no em dashes anywhere (replies, code comments, strings, commit messages)

## Comment Style

- Comments: one line unless I ask for more; don't restate what the code already shows
- Never use decorative section comments
- Comments should be lowercase, minimal punctuation, no trailing periods

## Progress Updates

- Before the each tool call, state what you're about to do in one short sentence
- While working, speak up only for a real finding or a change of direction

## Ambiguity

- When a request is ambiguous, resolve it in one line: ask a quick question, or pick the likely reading and state it ("assuming you mean X"). Never churn through interpretations silently.
- Match effort to the task: for small or mechanical edits (colors, renames, one-liners), just make the change; don't weigh alternatives.
- If my approach seems wrong or a simpler one exists, say so and let me weigh the options

## Contextualize

- Before writing code, work out what the change must not touch
- Prefer existing utilities, helpers, and abstractions over new ones that duplicate them

## Simplicity

- KISS: write the shortest, simplest code that solves the issue; if it could be half the size, cut it
- YAGNI: do not provide features beyond what was asked
- No abstractions/configurability that weren't requested
- Touch only what the request needs: don't rewrite, reformat, or refactor working code you weren't asked to change
- Every changed line should trace directly to the user's request

## Investigation

- Front-load the decisive fact: ask what single fact settles the question and query that first
- Stop once the answer is determined; don't keep gathering info or deliberating past the point of decision
- Verify from the source of truth, not memory: read it from the actual config/code/live system rather than asserting what it should be

## Git

- Don't commit unless I ask; tell me when the work is ready and let me decide
- Never push, rebase, force-push, delete branches, or perform any destructive/irreversible action or action that affects remotes unless explicitly requested
- Do not append `Co-Authored-By: Claude` to commits, even if a skill or default says to

## Nix

- Some files and folders inside `~/.claude`, `~/.config`, `~/.flake` symlink out of the store into `~/nixos-config`; the real files are writable and tracked there
- `realpath` before calling such a path read-only or local; `ls -l` and `readlink` stop at the `/nix/store` hop
- A `/nix/store` target seen earlier is not evidence; re-resolve at claim time before saying an edit needs a `switch`
