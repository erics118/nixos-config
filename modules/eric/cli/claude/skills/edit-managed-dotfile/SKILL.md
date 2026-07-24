---
name: edit-managed-dotfile
description: Use before a raw Bash mv/cp/redirect/tee/sed-i onto a possibly home-manager-symlinked dotfile under ~/.claude/, ~/.config/, etc. Not for Edit/Write -- a hook resolves symlinks there, so just edit.
---

# Editing a possibly nix-managed dotfile

Edit/Write: just edit, a hook resolves symlinks. This skill is only for raw Bash file ops.

Raw Bash: if `[ -L path ]`, `realpath path` and operate on that. Never `mv`/`cp`/redirect/`tee` onto the symlink path; it clobbers the link.

If a symlink already got clobbered (now a regular file where a symlink should be): diff it against wherever `realpath` used to point, merge any lost edits back in.
