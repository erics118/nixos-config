---
name: edit-managed-dotfile
description: Use when reading, editing, or locating any nix/home-manager-managed dotfile (~/.claude, ~/.config, ~/.flake) or its repo source (e.g. modules/**/claude, ~/nixos-config) -- including before hunting for the "real" file or grepping the nix wiring. Read/edit the ~/ path directly; a hook redirects edits. Also covers raw-Bash ops that could clobber the symlink.
---

# Reading or editing a nix-managed dotfile

**Locating: don't.** ~/.claude, ~/.config, ~/.flake files are symlinks that resolve back into a repo, and a PreToolUse hook (resolve-symlink-path.sh) rewrites Write/Edit to that source. Read and edit the ~/ path directly. Never open the repo copy or grep the home-manager wiring to find the "real" file first.

**Edit/Write:** just edit the ~/ path; the hook resolves the symlink.

**Raw Bash (mv/cp/redirect/tee/sed -i):** hook does NOT cover these. If `[ -L path ]`, `realpath path` and operate on that -- never write onto the symlink path, it clobbers the link.

**Clobbered symlink** (regular file where a symlink should be): diff against wherever `realpath` used to point, merge lost edits back in.
