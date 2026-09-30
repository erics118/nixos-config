---
name: remaining
description: List everything left to do in this session, including threads that were raised and never closed
disable-model-invocation: true
disallowed-tools: Edit, Write, NotebookEdit
---

List what is left before this session can end. Change no files.

1. Scan the whole session, not only the last few turns. Collect every item that is still open:
   - work that was agreed but not done
   - a question to the user that got no answer
   - a `Not checked:` line, or a check promised and never run
   - a topic dropped when the conversation moved on
2. Check each item against the files, `git status`, and running tasks. Drop any item that is already done.
3. Name what ending now would lose: uncommitted changes, decisions that live only in this chat, and background tasks still running.
4. Reply with one line per item and what closes it. If nothing is open, say `Nothing left` in one line. Never pad the list to look thorough.
