---
name: audit
description: Complete read-only sweep of existing code across every lens -- correctness, robustness, concurrency, and security as much as tech debt, idioms, and structure -- reported by what to fix first, then applies the accepted fixes on confirm. Use to find everything a senior would call improper across a codebase or area, or narrow to one lens or the working diff.
argument-hint: "[empty for whole repo | area | 'diff' for uncommitted changes] [+ a lens to narrow: debt|modernize|structure|correctness|robustness|concurrency|security|contract|performance|tests|operability|docs]"
---

Survey existing code and report what is worth fixing, then apply the accepted fixes once
confirmed. Read the actual code and config, never judge from names. These are personal or
small-group / student-club projects, never enterprise: skip enterprise theater -- no dollar
ROI, sprints, or blanket coverage mandates.

Scope: default to the entire codebase -- all of it, long-committed code included, not just
what changed recently or sits uncommitted in the working tree. Narrow only on an explicit ask:
an area or path, or the uncommitted changes ("diff", "uncommitted", "staged", "working"). Absent
that ask, an audit reads everything.

By default the sweep is complete: hunt everything a careful senior would flag as improper in
any way. The lenses below are a checklist to force that breadth, not a fence -- a genuine
problem that fits no named lens still counts. Reach for the list to check you have missed no
dimension, never to bound what you look for. Narrow to a single lens, or to `cleanup` /
`quality` for the debt+structure+modernize group, only when the ask names one.

Match depth to the ask too. A light ask -- "surface", "quick", "cleanup", "tidy", or a small
named target -- is a single direct pass for the obvious, high-confidence wins: read, report,
apply, and skip the coordinated apparatus below. A wide ask -- the whole repo, or "thorough" /
"deep" / "everything" -- earns the full sweep in Survey the scope.

## Survey the scope (wide audits)

The full coordinated sweep, for a wide ask; a light or single-target ask skips it for the
direct pass above.

You are the coordinator. Run until the whole scope is reviewed and the findings are validated.
Read-only throughout: edit no files, run no fixes, change nothing. Read-only inspection commands
are fine.

Coverage contract: inventory every identifiable subsystem. Give each a stable ID and name,
an exact ownership boundary, its key files and major interfaces, and a status (queued, in
review, finding, skip). Keep one canonical scratchpad holding the inventory, confirmed
findings, explicit skips, cross-cutting patterns, duplicates, and priorities. A broad
catch-all row does not prove coverage. Do not skip the unglamorous corners: scripts, CLIs,
build and deploy config, and vendored assets are subsystems too.

Dispatch fresh read-only subagents in parallel, one distinct subsystem each with a
non-overlapping boundary. Under Claude use Explore or general-purpose agents via the Agent
tool; under Codex use its native subagents; only where no subagent mechanism exists, run
each subsystem review yourself in sequence. Keep every worker read-only, bound concurrency
to the lanes you can coordinate, wait on the batch together, and harvest each result. Brief
each worker to apply every lens (or the single focused lens) within its boundary and return,
per finding: what and where (`file:line`), severity or effort, why it matters with a concrete
failure scenario, the proposed fix, regression risk, and confidence. It may note
cross-subsystem concerns but must not expand scope.

Validate every finding against the current code before accepting it. Reject or demote
findings that are vague, duplicate another, misread intentional semantics, or merely relocate
complexity. A wrong "bug" or "bypass" claim costs more than a missed nitpick, so verify the
decisive line before believing the worker. Deduplicate and assign each to one authoritative
subsystem. Record skips as completed coverage.

Audit the audit with fresh passes: repository coverage and missing boundaries; duplication
and ownership overlap; materiality and over-abstraction; severity and priority ranking. A real
omission gets its own subsystem row, audited; do not hide it by broadening a finished
boundary.

Done when every subsystem has a finding or explicit skip, each finding has complete evidence /
fix / severity / risk, duplicates and weak claims are removed, and the repository is unchanged.

## Lenses

Apply only the lenses that fit the code in front of you -- a lens with nothing to say is a
clean pass, not a reason to invent findings.

Quality and design

- **debt** -- duplication that must change in lockstep; tangled or deeply nested control flow;
  dead code, unused deps, stale config, leftover debug; deprecated deps and APIs (flag, never
  auto-upgrade); TODO/FIXME/HACK and what they imply.
- **modernize** -- non-idiomatic or deprecated-but-working code the project's target standard
  has a cleaner form for. Read the standard from build config (tsconfig target, Cargo edition,
  -std, go directive, python_requires) and stay within it; flag the standard itself only if it
  is stale and cheap to bump. Match the language actually present and its linter (statix,
  luacheck, shellcheck, clippy). Reach for the newest usable idiom, never novelty for its own
  sake.
- **structure** -- invalid states made representable (scattered booleans or nullables that want
  a state machine or discriminated union); repeated shape assumptions that want a shared type;
  duplicated branching a small map, registry, or reducer removes; unclear ownership a module
  boundary clarifies. Never force an abstraction where boring local code is already clear.

Correctness and robustness

- **correctness** -- boundary and off-by-one errors; encoding and normalization (utf-8 vs
  utf-16 length, percent-encoding, unicode NFC/NFD, case, null bytes); validation gaps, and
  rules that disagree between the write path and the read path; wrong or inconsistent error
  taxonomy (status codes, error shape).
- **robustness** -- unhandled failures and silently swallowed errors; partial-write and cleanup
  gaps; behavior when a dependency is down (fail-open vs fail-closed); retries and idempotency.
- **concurrency** -- races and TOCTOU (check-then-act); multi-step writes that are not atomic
  and orphan or duplicate on interruption; lifecycle or async states whose representation
  permits stale or contradictory values.

Security and contract

- **security** -- authn/authz on every path; CSRF and origin checks; XSS and injection, with
  escaping correct for the context it lands in, not just some context; sandbox and CSP; secret
  handling and exposure; info leakage in errors; SSRF and open-redirect; supply-chain
  (vendored, pinned, integrity-checked). For a deeper dedicated pass, `security-review` and
  `adversarial-review` go further; this lens is the broad net that finds where to aim them.
- **contract** -- http/api semantics (status codes, headers, conditional and range requests,
  redirects and their cache stickiness); caching and invalidation (stale-on-mutate, and
  read-your-write on an eventually-consistent store); platform and runtime limits (memory, cpu,
  subrequest count, size caps); data-model invariants and namespace consistency;
  backward/forward compatibility of the contract.

Cross-cutting

- **performance** -- needless work, repeated scans or per-call allocations, N+1 access,
  payload or bundle weight, cold-start cost -- only where it is real here, not microbenchmark
  theater.
- **tests** -- whether tests assert the load-bearing invariants rather than incidental strings
  or a mock's own shape; high-value gaps where a bug would bite right next to a tested path;
  isolation footguns (shared state, order dependence, flaky timers). Not blanket coverage.
- **operability** -- logging, telemetry, and an audit trail for state changes; deploy, rollback,
  and migration safety; config drift across environments.
- **docs** -- a comment that misstates the code (worse than none); a missing load-bearing
  invariant or onboarding fact; a misleading name.

## Rules

- Every item earns its place with a concrete win: a real defect, or clearer / safer / less
  code / fewer footguns. "Newer", "more standard", or "more abstract" alone is not a reason;
  skip mere taste.
- KISS/YAGNI: add no abstraction and rewrite no working code for fashion. If the code is
  already right, say so and move on.
- Leave formatting and whitespace to the formatter; do not flag those.
- A fix that would break a deliberate, tested behavior is not a fix. When a finding collides
  with an existing decision the code or tests encode, surface the collision instead of
  applying it blindly.

## Report and apply on confirm

Rank by what to fix first: correctness, security, and robustness defects by severity; quality
items by pain-to-effort. Lead with the highest-impact. For each: what and where (`file:line`),
why it matters (a concrete failure scenario for a defect), and the fix with rough effort
(small / medium / large). Group note-only items -- low value, or a design decision rather than
a bug -- at the end with why they can wait.

Present the ranked list and change nothing yet. On confirmation, apply the accepted findings
in priority order, highest-impact first. Every edit traces to a listed finding; make no change
beyond the list, and leave note-only or risky items untouched unless explicitly approved. After
applying, re-run the relevant tests or checks.

Read-only until you confirm. Never auto-apply.
