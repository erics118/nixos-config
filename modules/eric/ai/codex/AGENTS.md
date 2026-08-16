# Global Instructions

## General Style

- Be concise. Lead with the answer (BLUF) and skip filler
- Say it plainly in a line instead of hedging across a paragraph
- Keep caveats short
- Plain ASCII punctuation, no em dashes anywhere (replies, code comments, strings, commit messages)

## Comment Style

- Comment only durable state the code cannot show, and default to none. Never the process or conversation that produced it (no "we decided", "the user asked", "as discussed", "temporary until"). It must read the same to someone who never saw this session.
- One line is best, but two or three are fine when the point needs it
- Never over-explain
- One comment line states one thought. When you need two thoughts, use two lines. Never merge separate thoughts with a semicolon or comma splice. Trimming a comment means fewer words, not cramming more thoughts onto one line.
- No summary or rationale block atop a file, function, namespace, or section
- Put a comment on its own line, not trailing after code
- Comments should be lowercase, minimal punctuation, no trailing periods

## Working

- Before each tool call, say what you are about to do in one sentence. Otherwise speak up only for a real finding or a change of direction.
- Resolve ambiguity in one line: ask, or state the likely reading. Match effort to the task; just make small mechanical edits.
- If my approach seems wrong or a simpler one exists, say so.

## Code

- Work out what the change must not touch first. Prefer existing utilities over new duplicates. Copy a real neighboring instance, not a summary of one.
- KISS/YAGNI: shortest code that solves it, no unrequested features or abstractions. Touch only what the request needs; do not reformat or refactor working code.
- Check finished work against the request, not your restatement of it.

## Investigation

- Front-load the decisive fact and stop once the answer is determined.
- Verify from the source of truth, never memory. When a file or tool output contradicts a prior, the evidence wins; re-read and match it.
- Read a tool's docs to learn what it can do. Say "I couldn't find X", not "X doesn't exist".
- Fan out parallel subagents for the same operation across many independent targets, or for bulky research with a small conclusion.

## Git

- Don't commit unless I ask. Tell me when the work is ready and let me decide
- Never push, rebase, force-push, delete branches, or perform any destructive or irreversible action or action that affects remotes unless explicitly requested

## Managed dotfiles

- Parts of `~/.claude`, `~/.config`, `~/.flake` are symlinks into `~/nixos-config`. Everything else there is runtime state
- To resolve a managed file's real path, `realpath` it. `ls -l` stops at a `/nix/store` hop that is itself a symlink to the repo
- Editing a managed file takes effect immediately, with NO `just switch`: the `/nix/store` hop is a symlink back to the repo file (not a compiled copy), so editing the `realpath`ed repo file changes the live file directly. `just switch` is only for ADDING a new managed file (to create its symlink) or changing what nix generates. Do not assume the generic home-manager "edit source, rebuild" model here; edit the real path and it is live.
