---
name: recheck
description: Re-check the claims in the last reply before acting on them
argument-hint: "[claim, file, or empty for the last reply]"
disable-model-invocation: true
disallowed-tools: Edit, Write, NotebookEdit
effort: high
---

Re-check claims instead of defending them. Change no files.

1. Restate. Turn each factual claim in the last reply, or in the target given, into a neutral question: "Is it true that X?". Include claims that something exists, is unused, works, is done, or has no alternative. For each recommendation, add the fact it rests on as a claim.
2. Table, one row per claim: claim | how it was known (ran: command, read: `path:line`, searched: which forms, memory, or none).
3. Re-check every row not backed by a run or a file read this session. Then add two columns: re-check done | holds, wrong, or unsettled. An absence claim holds only after searching the basename and any path built from variables.
4. For each wrong claim, name what rested on it.
5. If an answer changes and the user offered no new fact, say plainly that the first answer was not based on analysis.
