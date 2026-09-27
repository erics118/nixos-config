---
name: recall
description: Use when the user refers to an earlier session, a past decision, or work already done ("last time", "we decided", "you did this before"), to find it in past Claude, Codex, and pi transcripts
---

Search past transcripts before asking the user to repeat themselves or guessing. Each agent stores sessions as JSONL:

- Claude Code: `~/.claude/projects/<dir>/*.jsonl`, where `<dir>` is the directory the session started in with `/` replaced by `-` (for example `-Users-eric-dev-foo`), so sessions started in subdirectories have their own folders. Find them with `ls ~/.claude/projects | rg <repo-name>`. User messages: `jq -r 'select(.type=="user" and (.message.content|type)=="string") | .message.content' FILE`
- Codex: `~/.codex/sessions/YYYY/MM/DD/*.jsonl`. The directory comes from `jq -r 'select(.type=="session_meta") | .payload.cwd' FILE`. User messages: `jq -r 'select(.type=="response_item" and .payload.type=="message" and .payload.role=="user") | .payload.content[].text // empty' FILE`. Skip injected blocks that start with `<` or `# AGENTS.md`
- pi: `~/.pi/agent/sessions/<dir>/*.jsonl`, where `<dir>` is the directory the session started in with `/` replaced by `-` and one extra `-` on each end (for example `--Users-eric-dev-foo--`). Find them with `ls ~/.pi/agent/sessions | rg <repo-name>`. User messages: `jq -r 'select(.type=="message" and .message.role=="user") | .message.content | if type=="string" then . else (map(select(.type=="text").text) | join("\n")) end' FILE`

Start with the sessions for the current repo, newest first (`ls -t`). Search user messages with `rg` before reading whole transcripts, since they are large. Quote what you found with the file path and date.
