---
description: Update flake inputs, rebuild, and summarize what changed or broke
argument-hint: [input-name]
---

Update this project's flake dependencies and assess the damage. Steps:

1. If $1 given: `nix flake update $1`. Otherwise `nix flake update`.
2. Summarize the flake.lock diff: which inputs moved, old -> new rev/date (use `git diff flake.lock` and condense; do not paste the raw diff).
3. Rebuild: use `just build` if a justfile exists, else `nix flake check` then `nix build` of the default output or devShell.
4. If the build fails: diagnose the breakage (which input caused it, what API/option changed), propose the minimal fix, and ask before pinning back or applying nontrivial changes.
5. If it succeeds: report inputs updated + build clean. Do NOT commit, do NOT switch the system - building only.
