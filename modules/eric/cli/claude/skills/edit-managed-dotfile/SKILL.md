---
name: edit-managed-dotfile
description: Use before editing any file under ~/.claude/, ~/.config/, or another home directory dotfile location that might be a home-manager symlink (e.g. settings.json, hooks). Prevents mv/cp/redirect from silently destroying the symlink.
---

# Editing a possibly nix-managed dotfile

Use the Edit/Write tool -- a hook auto-resolves symlinks for it.

If you must use raw Bash instead: check `[ -L path ]`, and if true, `realpath path` and operate on that instead. Never `mv`/`cp`/redirect/`tee` onto the symlink path itself; it will clobber the link.

If a symlink already got clobbered (now a regular file where a symlink should be): diff it against wherever `realpath` used to point, merge any lost edits back in.
