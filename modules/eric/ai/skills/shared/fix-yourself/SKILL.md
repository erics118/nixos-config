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

2. **Find the instruction that should have fired.** Search the global AGENTS.md, the project instruction file, memory, and the skill list for an existing rule covering this case. On a hit, the fix is rewording that rule so it fires next time - bind it to a checkable action at a specific moment - never adding a sibling rule.
   Done when: you can name the rule that failed, or state that none exists.

3. **Generalize.** Write the fix for the failure class, not the instance; no detail of the triggering incident may appear in the wording. Test it against two other plausible instances of the class.
   Done when: both hypotheticals would be caught by the wording.

4. **Choose the layer**, lowest layer that fits:
   - must always/never happen and is mechanically checkable: a guard script in `~/nixos-config/modules/eric/ai/hooks/`. List it in `modules/eric/ai/claude/settings.json`, which pi reads too. For shell commands, also list it in `modules/eric/ai/codex/hooks.json`. For Codex, an ask-type guard goes in `modules/eric/ai/codex/rules/default.rules` instead. Add its tests to `modules/eric/ai/hooks/test.sh`: CI runs it and fails on any configured hook it does not test. Harness enforcement beats prose.
   - judgment behavior spanning projects: global AGENTS.md
   - project-specific fact or constraint: the project instruction file or its docs, never memory
   - repeatable multi-step process: new or amended skill, via writing-great-skills

   Done when: one layer is chosen and you can say why not the others.

5. **Propose, then install and prune.** Before proposing, check every capability, default, flag, or mechanism the rule's wording relies on. Check it against the source of truth: the code, config, or docs, never memory or inference. A durable rule built on an unchecked premise fails silently until something trips over it. Show me the exact wording, the layer, and everything the new rule supersedes. Wait for my approval. Then install. Delete or merge every superseded duplicate so the meaning lives in exactly one place. Prefer deleting or tightening a rule over adding one.
   Done when: the rule's premises are checked, I approved, the edit is verified on disk, and no duplicate remains.
