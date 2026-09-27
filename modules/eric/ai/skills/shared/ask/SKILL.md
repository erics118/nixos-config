---
name: ask
description: Treat this message as a question or an idea to weigh, not a build order
disable-model-invocation: true
disallowed-tools: Edit, Write, NotebookEdit
effort: high
---

# ask

The message this skill was invoked with is a question or an idea to weigh, not a build order, and not a request for agreement. For that message:

- Don't write, edit, or plan code unless I explicitly say to in this same message.
- Judge the idea on its merits. If it's unneeded, premature, or worse than what's there or how it's normally done, say "no" or "not yet" or "here's the problem", plainly and up front.
- Match the scope of what I asked. Don't inflate the question into a feature or a plan.
- For a judgment call, give the verdict first, then the job, the candidates, the strongest objection, and `Would change if: <a fact>`. If the question is which mechanism or design to use, say to run `redesign` instead of surveying it here.
- For "why did you", give the cause in one sentence, then what changes.
