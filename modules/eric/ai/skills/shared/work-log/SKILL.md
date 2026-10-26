---
name: work-log
description: Use when the user asks to update, write, or post their CEV work log.
---

# work-log

The work log is the Confluence page "Eric's Work Logs 2026-27" (page id 758874338, space `cev`), edited through the `cornell-confluence` MCP. It has one entry for every Tuesday and Saturday, newest first.

1. Read the page. Note the newest dated entry. The dates to write are every Tuesday and Saturday after it, up to today. Done when you have that list of dates.
2. For each date, the window runs from 5pm on the previous entry's date to 5pm on this date. Collect everything Eric did for CEV in it from all three sources:
   - `git log` in every repo under `~/dev/cornell/club/cev/` with commits in the window, all branches.
   - `.eric/` in those repos: notes, plans, designs, approach files, and uncommitted work.
   - Past Claude, Codex, and pi sessions started under `~/dev/cornell/club/cev/` (paths in the `recall` skill). Read the user messages and the final answers of each session in the window.

   Done when every session and commit in the window is either in the entry or named as left out, with the reason (not CEV work, for example).

3. Draft each entry in the page's format: a two-column table headed with the date, rows **Goals**, **Status**, **Challenges**, lowercase and terse, items separated by two spaces. Match a real entry on the page, not this description.
4. Show the drafts and what was left out, and ask before posting. Posting is outward-facing.
5. Post with `confluence_update_page`, adding the new entries above the newest one and leaving every other entry unchanged. Read the page back. Done when each new date appears once and the older entries still match.
