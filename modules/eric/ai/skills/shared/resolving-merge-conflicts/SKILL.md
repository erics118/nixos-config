---
name: resolving-merge-conflicts
description: "Use when you need to resolve an in-progress git merge/rebase conflict."
---

1. **See the current state** of the merge/rebase. Run `git status` and `git log --merge --oneline`, and list the conflicting files.

2. **Find the primary sources** for each conflict. Understand deeply why each change was made, and what the original intent was. Read the commit messages, check the PRs, check original issues/tickets.

3. **Resolve each hunk.** Preserve both intents where possible. Where incompatible, pick the one matching the goal in the merge or rebase commit message, or the user's request, and note the trade-off. Do **not** invent new behaviour. Always resolve; never `--abort`.

4. Discover the project's **automated checks** and run them: typically typecheck, then tests, then format. Fix anything the merge broke.

5. **Finish.** `git add` only the files you resolved. If `git config --get eric-agent.commit` prints `on`, or `branch` and the current branch is not `main` or `master` (a detached HEAD, as mid-rebase, counts as `main`), or `ask` and you are not Codex, run `git merge --continue` or `git rebase --continue` until done. `git rebase --continue` triggers the rebase approval prompt in every agent, so expect one prompt per step. Otherwise stop and tell the user the conflicts are resolved and staged, so they continue it.
