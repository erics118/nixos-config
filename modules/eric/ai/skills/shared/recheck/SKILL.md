---
name: recheck
description: Use when the user doubts or pushes back on claims in the last reply, to re-check them against sources before acting.
argument-hint: "[claim, file, or empty for the last reply]"
effort: high
---

Re-check claims instead of defending them. Change no files.

Edit and Write are disabled only for this turn; they return with the user's next message.

1. Restate. Turn each factual claim in the last reply, or in the target given, into a neutral question: "Is it true that X?". Include claims that something exists, is unused, works, is done, or has no alternative. For each recommendation, add the fact it rests on as a claim.
2. Table, one row per claim: claim | how it was known (ran: command, read: `path:line`, searched: which forms, memory, or none).
3. Re-check every row not backed by a run or a file read this session. Then add two columns: re-check done | holds, wrong, or unsettled. An absence claim holds only after searching the basename and any path built from variables.
4. For each wrong claim, name what rested on it.
5. If an answer changes and the user offered no new fact, say plainly that the first answer was not based on analysis.
