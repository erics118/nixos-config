---
name: fix-yourself
description: Diagnose a Claude failure and install a durable, general fix in the right layer (hook, CLAUDE.md, memory, skill).
argument-hint: "What went wrong?"
disable-model-invocation: true
---

I hit a failure worth fixing durably, not just correcting in-session. Work the steps in order; each ends with a check.

1. **Locate the divergence, not the symptom.** Quote the actual request and the actual behavior, and trace to the earliest moment the process left the request. It is usually where the request was translated into an internal artifact (plan, script, spec, assumption) and something was lost in translation.
   Done when: you can name the exact step where behavior diverged, and I agree it is the root.

2. **Find the instruction that should have fired.** Search global CLAUDE.md, project CLAUDE.md, memory, and the skill list for an existing rule covering this case. On a hit, the fix is rewording that rule so it fires next time - bind it to a checkable action at a specific moment - never adding a sibling rule.
   Done when: you can name the rule that failed, or state that none exists.

3. **Generalize.** Write the fix for the failure class, not the instance; no detail of the triggering incident may appear in the wording. Test it against two other plausible instances of the class.
   Done when: both hypotheticals would be caught by the wording.

4. **Choose the layer**, lowest layer that fits:
   - must always/never happen and is mechanically checkable: hook or settings via the update-config skill; harness enforcement beats prose
   - judgment behavior spanning projects: global CLAUDE.md
   - project-specific fact or constraint: project memory
   - repeatable multi-step process: new or amended skill, via writing-great-skills
     Done when: one layer is chosen and you can say why not the others.

5. **Propose, then install and prune.** Show me the exact wording, the layer, and everything the new rule supersedes; wait for my approval. Then install (realpath managed files first; edit lands in ~/nixos-config) and delete or merge every superseded duplicate so the meaning lives in exactly one place.
   Done when: I approved, the edit is verified on disk, and no duplicate remains.
