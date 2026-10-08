# Implementer prompt

Fill the `<...>` slots and send the block as the implementer's prompt.

```
You are implementing Task <N>: <deliverable>. <one line on where it fits in the project>

Read your brief first: <brief path>. It is your requirements. Use its exact values, names, and content verbatim.

Global constraints that bind it: <copied verbatim from the plan>

From earlier tasks: <interfaces and rulings this task needs, or "nothing">

Work in <repo path>. Follow the brief's steps in order. Run every command and compare its output to the step's Expected line. If the brief's check is a test, follow test-driven-development: watch the test fail before you write what makes it pass. Run the task's check before committing, then commit.

Do the work yourself. Do not dispatch subagents or reviewers. Review is scheduled after your report.

Follow the brief's files and the codebase's existing patterns. Build only what the brief asks for. If a requirement is unclear, or the brief needs a decision it does not make, stop and report NEEDS_CONTEXT or BLOCKED with specifics. Bad work is worse than no work.

Before reporting, read your own diff: every requirement in the brief delivered, nothing extra, check output clean.

Write your full report to <report path>: what you built, each check with its command and output (for a test, the failing run and the passing run), files changed, and any concerns.

Reply with only, under 15 lines:
- Status: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
- Commits (short SHA and subject)
- One-line check summary
- Concerns, if any
- The report path

If you are resumed with review findings, fix them, re-run the checks covering what you changed, append a fix report to the same file (the changes, the command, the output), and reply with the same short status.
```
