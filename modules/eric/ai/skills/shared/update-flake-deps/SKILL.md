---
name: update-flake-deps
description: Update flake inputs, rebuild, and summarize what changed or broke. Use when asked to update or bump dependencies or flake inputs.
argument-hint: "[input]"
disable-model-invocation: true
---

Update this project's flake dependencies and assess the damage. Steps:

1. If the invocation names an input, update only that input with
   `nix flake update <input>`; otherwise run `nix flake update`.
2. Summarize the flake.lock diff: which inputs moved, old -> new rev/date (use `git diff flake.lock` and condense; do not paste the raw diff).
3. Rebuild. If the justfile has a `build` recipe, run `just build`. Otherwise run `nix flake check`, then `nix build` (default package) or `nix build .#devShells.<system>.default` when there is no package.
4. If the build fails: diagnose the breakage (which input caused it, what API/option changed), propose the minimal fix, and ask before pinning back or applying nontrivial changes.
5. If it succeeds: report inputs updated + build clean. Do NOT commit, do NOT switch the system - building only.
