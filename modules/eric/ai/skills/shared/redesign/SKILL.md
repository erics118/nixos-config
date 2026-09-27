---
name: redesign
description: Survey how the platform, standard tools, and this repo already do a job, then give one verdict before any code changes
argument-hint: "<the job in one line> [--adversary]"
disable-model-invocation: true
effort: high
---

Decide how a job should be done before any code changes. The current design gets no credit for existing. It is one candidate among the others.

1. Job. Restate the job in one line as an outcome. Name no current mechanism (the script, service, or tool that does the job today), but do name the inputs it must honor.
2. Survey. Fill every slot with its source: a doc or man page you read, `path:line`, or a command and its output. Write `none` for an empty slot and say where you looked.
   - Platform: what the OS, init system, language, or framework already provides for this job
   - Standard tools: the usual tool for this job outside this repo
   - Repo: what this repo already does for it. Search by the job, not the current names, and search basenames and paths built from variables before calling anything unused
   - Zero-code: delete it, or leave it as is
   - Project rules: any rule in the project instructions that constrains the answer
3. Candidates. List the ones that fully do the job, simplest first, each with its cost and what it breaks. Don't pad the list.
4. Strongest objection. Write the best case against your pick as the user would put it, and the fact that answers it.
5. Verdict. `Verdict: <pick> - <the deciding fact>` and `Would change if: <a fact, not a preference>`. When the evidence doesn't settle it, write `Verdict: hold - <what to check>`.
6. Save the survey to `.eric/design/YYYY-MM-DD-<topic>.md` at the repo root. Reply with the verdict line first, then the survey.

Change no project files. If the user approves, the next step is a direct edit for a small change or `writing-plans` for a larger one.

With `--adversary`, give only the job line to the other model through `consulting-codex` or `consulting-claude` before writing the verdict, and quote its answer verbatim.
