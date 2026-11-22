---
name: work-log
description: Use when the user asks to update, write, or post their CEV work log.
---

# work-log

Never do the work log without Eric's explicit approval.

The work log is the Confluence page "Eric's Work Logs 2026-27" (page id 758874338, space `cev`), edited through the `cornell-confluence` MCP. It has one entry for every Tuesday and Saturday, newest first.

1. Read the page. Note the newest dated entry. The dates to write are every Tuesday and Saturday after it, up to today. Done when you have that list of dates.
2. For each date, the window runs from 5pm on the previous entry's date to 5pm on this date. Collect everything Eric did for CEV in it from all of these sources:
   - `git log` in every repo under `~/dev/cornell/club/cev/` with commits in the window, all branches.
   - GitHub, since local clones can be stale: `gh search commits --author erics118 --owner cornellev`, `gh search prs --author erics118 --owner cornellev`, and `gh search prs --commenter erics118 --owner cornellev`, each limited to the window.
   - `.eric/` in those repos: notes, plans, designs, approach files, and uncommitted work.
   - Past Claude, Codex, and pi sessions started under `~/dev/cornell/club/cev/` (paths in the `recall` skill). Read every user message and the final answers of each session in the window yourself, including long sessions. A subagent's summary of a session is a lead, not a source.

   Done when every session and commit in the window is either in the entry or named as left out, with the reason (not CEV work, for example).

3. Draft each entry in the page's format: a two-column table headed with the date, rows **Goals**, **Status**, **Challenges**, lowercase and terse, each Status and Challenges item its own `<p>` in the cell. Match a real entry on the page, not this description. Read it with `convert_to_markdown: false`, since the markdown view joins the `<p>` items with two spaces.
4. Show the drafts as bullets, one item per line, never as a table, plus what was left out. Ask before posting. Posting is outward-facing.
5. Post with `confluence_update_page` in `storage` format, adding the new entries above the newest one and leaving every other entry unchanged. Check with `confluence_get_page_diff` from the old version to the new one. Done when the diff shows only the new entries added and each new date appears once.
