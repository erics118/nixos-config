---
name: audit
description: Read-only survey of existing code for tech debt and modernization, prioritized by pain-to-effort
argument-hint: [empty for entire repo | area | "diff" for uncommitted changes ] [+ "debt" or "idioms" to narrow]
---

Survey existing code and report what is worth improving. Read-only audit, solo personal
project: skip enterprise theater (no dollar ROI, sprints, or blanket coverage mandates).
Read the actual code and config, never judge from names.

Scope: default to the entire repo. If $ARGUMENTS names a path or area, focus there. If it
asks for the uncommitted changes ("diff", "uncommitted", "staged", "working"), use the
current working diff.

Lens: run both lenses below by default. If $ARGUMENTS says "debt" run only the debt lens;
if it says "idioms" or "modernize" run only the modernization lens.

Debt lens, hunt for cost that is real here:

- Duplication and copy-paste that must be changed in lockstep.
- Overly complex or tangled code: deep nesting, long functions, unclear control flow.
- Fragile or footgun patterns, hacks, and workarounds left in place.
- Dead code, unused deps, stale config, leftover debug or commented-out blocks.
- Outdated or deprecated dependencies and APIs (flag, do not auto-upgrade).
- Missing tests only where a bug would actually bite (not blanket coverage goals).
- TODO/FIXME/HACK markers and what they imply.

Modernization lens, make code more idiomatic and current. First determine the standard or
edition the project targets from its build config (CMAKE_CXX_STANDARD or -std, Cargo
edition, go directive, tsconfig target, python_requires); prefer modern idioms within it,
lean toward the newest usable features, but never suggest what the toolchain cannot use.
If the standard itself is stale and cheap to bump, flag that. Detect which languages are
actually present and apply only the matching guidance, ignore the rest; for a language not
listed use its own idioms and linter (statix for nix, luacheck for lua, shellcheck for
shell, clippy for rust). Where the target standard allows, prefer:

- C++: modern C++20/23/26 over legacy C++ (ranges, concepts, std::span, std::expected,
  std::print/format, constexpr, structured bindings, RAII and smart pointers over raw
  new/delete and owning pointers, <=> where it fits). Push to the newest std usable.
- Rust: current-edition idioms, iterator chains over manual loops, ? over match-on-error,
  derive/std traits over hand-rolled.
- Go: stdlib generics and slices/maps helpers, errors.Is/As over string checks.
- Python: modern typing, f-strings, pathlib, dataclasses where they fit.

Look for: non-idiomatic patterns, deprecated-but-working APIs with a current replacement,
older features where a newer one is clearer or safer, verbose manual code a stdlib or
existing helper does better.

Rules:

- Every item must earn its place with a concrete win: clearer, safer, less code, or fewer
  footguns. "Newer" or "more standard" alone is not a reason. Skip mere style or taste.
- KISS/YAGNI: add no abstraction, do not rewrite working code for fashion. If code is
  already fine, say so and move on.
- Leave formatting and whitespace to treefmt; do not flag those.
- Stay out of /simplify's lane: this reports idiom and debt, not general simplification.

For each item: what and where (`file:line`), why it matters (the pain or risk for debt,
the concrete win for idioms), and rough fix and effort (small / medium / large).

Prioritize by pain-to-effort, not by count: quick wins (high value, small effort) first
and most actionable, then worth-doing, then note-only (low value or risky to touch, say
why it can wait). Lead with the most important things worth doing now.

Read-only: change no code, run no fixes. Ask before any remediation.
