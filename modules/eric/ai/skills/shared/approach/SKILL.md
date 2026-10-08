---
name: approach
description: Survey how the platform, standard tools, and this repo already do a job, new or existing, then give one verdict before any code changes
argument-hint: "<the job in one line> [--adversary]"
disable-model-invocation: true
effort: high
---

Decide how a job should be done before any code changes.

1. Work steps 1-5 of [survey.md](survey.md), which `writing-plans` also uses.
2. Save the survey to `.eric/approach/YYYY-MM-DD-<topic>.md` at the repo root. Reply with the verdict line first, then the survey.

Write nothing but the survey file. Once the user asks for the change, make a direct edit for a small change or run `writing-plans` for a larger one.

With `--adversary`, give only the job line to the other model through `consulting-codex` from Claude, or `consulting-claude` from Codex or pi, before writing the verdict, and quote its answer verbatim.
