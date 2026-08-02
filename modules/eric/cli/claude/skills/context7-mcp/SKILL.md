---
name: context7-mcp
description: Use when a question is about a library, framework, SDK, API, or CLI tool - setup, syntax, configuration, version migration, or library-specific debugging.
---

Fetch the docs rather than answering from training data, even for libraries you know well.

`resolve-library-id` first, unless the user gave an exact `/org/project` ID. Choose between results by name match, then benchmark score, then snippet count, then source reputation. If nothing looks right, rephrase or try alternate names (`next.js`, not `nextjs`). Prefer a version-specific ID when the user names a version.

Then `query-docs`, **one concept per call**. A question spanning routing and auth and caching is three calls against the same library ID - combined queries dilute ranking and return shallow results for each. The exception is a question about how those concepts interact, which is one call.
