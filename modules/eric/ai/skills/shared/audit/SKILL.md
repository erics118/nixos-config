---
name: audit
description: Deep read-only survey of existing code for tech debt, non-idiomatic code, and structural/design problems, ranked by pain-to-effort, then applies the accepted fixes on confirm. Use to find and clean up what is worth improving across a codebase or area.
argument-hint: "[empty for whole repo | area | 'diff' for uncommitted changes] [+ 'debt', 'modernize', or 'structure' to narrow]"
---

Survey existing code deeply and report what is worth improving, then apply the accepted
fixes once confirmed. Solo personal project: skip enterprise theater (no dollar ROI,
sprints, or blanket coverage mandates). Read the actual code and config, never judge from
names. There is no quick mode: every audit is a full deep pass over its scope.

Scope: default to the entire repo. If the invocation names a path or area, focus there. If
it asks for the uncommitted changes ("diff", "uncommitted", "staged", "working"), use the
current working diff.

Lens: run all three lenses below by default. If the invocation names one ("debt",
"modernize"/"idioms", or "structure"/"simplify"), run only that lens.

## Survey the scope

You are the coordinator. Run until the whole scope is reviewed and the findings are
validated. Read-only throughout this phase: edit no files, run no fixes, change nothing.
Read-only inspection commands are fine.

Coverage contract: inventory every identifiable subsystem. Give each a stable ID and name,
an exact ownership boundary, its key files and major interfaces, and a status (queued, in
review, finding, skip). Keep one canonical scratchpad holding the inventory, confirmed
findings, explicit skips, cross-cutting patterns, duplicates, and priorities. A broad
catch-all row does not prove coverage.

Dispatch fresh read-only subagents in parallel, one distinct subsystem each with a
non-overlapping boundary. Under Claude use Explore or general-purpose agents via the Agent
tool; under Codex use its native subagents; only where no subagent mechanism exists, run
each subsystem review yourself in sequence. Keep every worker read-only, bound concurrency
to the lanes you can coordinate, wait on the batch together, and harvest each result. Brief
each worker to apply the lenses below within its boundary and return, per finding: what and
where (`file:line`), why it matters, the proposed fix, rough effort, regression risk, and
confidence. It may note cross-subsystem concerns but must not expand scope.

Validate every finding against the current code before accepting it. Reject or demote
findings that are vague, duplicate another, misread intentional semantics, or merely
relocate complexity. Deduplicate and assign each to one authoritative subsystem. Record
skips as completed coverage.

Audit the audit with fresh passes: repository coverage and missing boundaries; duplication
and ownership overlap; materiality and over-abstraction; priority ranking. A real omission
gets its own subsystem row, audited; do not hide it by broadening a finished boundary.

Done when every subsystem has a finding or explicit skip, each finding has complete
evidence / fix / effort / risk, duplicates and weak abstractions are removed, and the
repository is unchanged.

## Debt lens

Hunt for cost that is real here:

- Duplication and copy-paste that must be changed in lockstep.
- Overly complex or tangled code: deep nesting, long functions, unclear control flow.
- Fragile or footgun patterns, hacks, and workarounds left in place.
- Dead code, unused deps, stale config, leftover debug or commented-out blocks.
- Outdated or deprecated dependencies and APIs (flag, do not auto-upgrade).
- Missing tests only where a bug would actually bite (not blanket coverage goals).
- TODO/FIXME/HACK markers and what they imply.

## Modernization lens

Make code more idiomatic and current. First determine the standard or edition the project
targets from its build config (CMAKE_CXX_STANDARD or -std, Cargo edition, go directive,
tsconfig target, python_requires); prefer modern idioms within it, lean toward the newest
usable features, but never suggest what the toolchain cannot use. If the standard itself is
stale and cheap to bump, flag that. Detect which languages are actually present and apply
only the matching guidance; for a language not listed use its own idioms and linter (statix
for nix, luacheck for lua, shellcheck for shell, clippy for rust). Where the target standard
allows, prefer:

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

## Structure lens

Find materially useful simplifications in data structures, state representation, control
flow, and ownership:

- Scattered booleans or nullable fields that permit invalid combinations and want a state
  machine or discriminated union.
- Repeated assumptions about object shape that want a shared typed model.
- Duplicated branching a small map, registry, reducer, or command model would remove.
- Unclear ownership of state or behavior that a small module boundary would clarify.
- Repeated scans, transforms, or lookups where a better collection or index materially
  simplifies behavior.
- Lifecycle, concurrency, or async states whose representation permits stale or
  contradictory state.

Do not force an abstraction; prefer boring local code when it is already clear. Do not flag
stylistic consistency, hypothetical extensibility, minor line-count reduction, or merely
moving existing branching behind a new type.

## Rules

- Every item must earn its place with a concrete win: clearer, safer, less code, or fewer
  footguns. "Newer", "more standard", or "more abstract" alone is not a reason. Skip mere
  style or taste.
- KISS/YAGNI: add no abstraction, do not rewrite working code for fashion. If code is
  already fine, say so and move on.
- Leave formatting and whitespace to treefmt; do not flag those.
- This is quality and design, not correctness or security. Do not hunt for bugs, races, or
  vulnerabilities here; that is `code-review`, `adversarial-review`, and `security-review`.

## Report and apply on confirm

Rank findings by pain-to-effort, not by count: quick wins (high value, small effort) first
and most actionable, then worth-doing, then note-only (low value or risky to touch, say why
it can wait). Lead with the most important things worth doing now. For each: what and where
(`file:line`), why it matters, and rough fix and effort (small / medium / large).

Present the ranked list and change nothing yet. On confirmation, apply the accepted findings
in priority order, quick wins first. Every edit must trace to a listed finding; make no
change beyond the list, and leave note-only or risky items untouched unless explicitly
approved. After applying, re-run the relevant tests or checks.

Read-only until you confirm. Never auto-apply.
