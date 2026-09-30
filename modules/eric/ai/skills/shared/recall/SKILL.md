---
name: recall
description: Last resort for an earlier session, past decision, or work already done ("last time", "we decided", "you did this before") that memory, project notes, and git history don't settle. Searches past Claude, Codex, and pi transcripts
---

Transcripts are the last resort. First check the written record: loaded memory, the repo's notes and docs (plans, designs, a personal notes dir such as `.eric/`), and `git log`. Search transcripts only if those don't settle it, and before asking the user to repeat themselves. Say which records you checked.

Each agent stores sessions as JSONL:

- Claude Code:
  - Path: `~/.claude/projects/<dir>/*.jsonl`. `<dir>` is the directory the session started in, with both `/` and `.` replaced by `-`. For example, `/Users/eric/dev/foo` becomes `-Users-eric-dev-foo` and `/Users/eric/.local/bin` becomes `-Users-eric--local-bin`. Sessions started in subdirectories have their own folders.
  - Find: `ls ~/.claude/projects | rg <repo-name>`
  - User messages: `jq -r 'select(.type=="user" and (.message.content|type)=="string") | .message.content' FILE`. Skip injected blocks that start with `<`, such as `<command-message>` wrappers.
- Codex:
  - Path: `~/.codex/sessions/YYYY/MM/DD/*.jsonl`. The directory comes from `jq -r 'select(.type=="session_meta") | .payload.cwd' FILE`.
  - Find: `rg -l '"cwd":"<repo-path>"' ~/.codex/sessions`
  - User messages: `jq -r 'select(.type=="response_item" and .payload.type=="message" and .payload.role=="user") | .payload.content[].text // empty' FILE`. Skip injected blocks that start with `<` or `# AGENTS.md`.
- pi:
  - Path: `~/.pi/agent/sessions/<dir>/*.jsonl`. `<dir>` is the directory the session started in, with `/` replaced by `-` and one extra `-` on each end. For example, `/Users/eric/dev/foo` becomes `--Users-eric-dev-foo--`. Unlike Claude Code, pi keeps `.` as is.
  - Find: `ls ~/.pi/agent/sessions | rg <repo-name>`
  - User messages: `jq -r 'select(.type=="message" and .message.role=="user") | .message.content | if type=="string" then . else (map(select(.type=="text").text) | join("\n")) end' FILE`

Start with the sessions for the current repo, newest first (`ls -t`). Search user messages with `rg` before reading whole transcripts, since they are large. Quote what you found with the file path and date.
