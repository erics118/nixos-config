---
name: fix-yourself
description: Diagnose an agent failure and install a durable, general fix in the right layer (hook, AGENTS.md, project instructions, skill).
argument-hint: "What went wrong?"
disable-model-invocation: true
effort: high
---

I hit a failure worth fixing durably, not just correcting in-session. Work the steps in order; each ends with a check.

0. **Sweep for the class.** List every other instance of the same failure class in this session, and in past sessions via the recall skill.
   Done when: the list is in the reply, even if it has one item.

1. **Locate the divergence, not the symptom.** Quote the actual request and the actual behavior, and trace to the earliest moment the process left the request. It is usually where the request was translated into an internal artifact (plan, script, spec, assumption) and something was lost in translation.
   Done when: you can name the exact step where behavior diverged. Stop and wait until I agree it is the root.

2. **Find the instruction that should have fired.** Search the global AGENTS.md, the project instruction file, memory, and the skill bodies (not just their names) for an existing rule covering this case. A hit means the rule existed and did not change behavior, so rewording it is only one option. Also weigh deleting it, when it never changed behavior or caused the failure, and moving the job to a lower layer in step 4. A reworded rule binds to a checkable action at a specific moment. Never add a sibling rule.
   Done when: you can name the rule that failed, or state that none exists.

3. **Generalize.** Write the fix for the failure class, not the instance; no detail of the triggering incident may appear in the wording. Name two other plausible instances of the class, and one case where the current behavior is right and must stay right.
   Done when: the two instances and the right case are written down; step 5 tests the fix on them.

4. **Choose the layer**, lowest layer that fits:
   - must always/never happen and is mechanically checkable: a check in the Go guard at `~/nixos-config/modules/eric/ai/guard/`, one file per check. Add its row, with the tools it runs on, to the table in `guard/checks.go`, which Claude, Codex, and pi all run. Add its tests to `modules/eric/ai/hooks/test.sh`: CI runs it and fails on any check it does not test. It goes live with `just switch`. Harness enforcement beats prose.
   - judgment behavior one skill's task needs: that skill
   - judgment behavior spanning projects and tasks: global AGENTS.md
   - project-specific fact or constraint: the project instruction file or its docs, never memory
   - repeatable multi-step process: new or amended skill, via writing-great-skills

   Done when: one layer is chosen and you can say why not the others.

5. **Show the fix changes behavior.** Reading the wording proves nothing about behavior. Replay the failing turn, the two instances, and the right case from step 3, with and without the fix, at least 3 runs each, and grade each reply against a pass/fail test written before the run. The method and scripts are in `~/nixos-config/.eric/notes/2026-11-14-rules-benchmark.md` and the folder beside it. When the failure needs tools or spans many turns, a replay can't show it: measure it live per failure mode against labeled past corrections, or choose a guard or hook in step 4. A fix that moves nothing, or breaks the right case, is not installed; record it in the notes instead.
   Done when: you have pass counts with and without the fix, or the reason only live measurement can show the effect and how it will be measured.

6. **Propose, then install and prune.** Before proposing, check every capability, default, flag, or mechanism the rule's wording relies on. Check it against the source of truth: the code, config, or docs, never memory or inference. A durable rule built on an unchecked premise fails silently until something trips over it. Show me the exact wording, the layer, the step 5 results, and everything the new rule supersedes. Wait for my approval. Then install. Delete or merge every superseded duplicate so the meaning lives in exactly one place. Prefer deleting or tightening a rule over adding one. A line stays only on evidence that it changes behavior, or because it states a fact the agent can't work out itself. Meaning alone does not keep it.
   Done when: the rule's premises are checked, I approved, the edit is verified on disk, and no duplicate remains.
