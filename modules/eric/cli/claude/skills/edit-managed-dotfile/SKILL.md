---
name: edit-managed-dotfile
description: Use when reading, editing, or locating any nix/home-manager-managed dotfile (~/.claude, ~/.config, ~/.flake) or its repo source (e.g. modules/**/claude, ~/nixos-config). Resolve the path with realpath and operate on the real repo file -- Write/Edit refuse to write through symlinks and their read/write tracking desyncs on them; bash (sed -i, >, tee) silently clobbers the link.
---

# Reading or editing a nix-managed dotfile

**Resolve with realpath, then operate on the real path -- for Read, Edit, and bash alike.** ~/.claude, ~/.config, ~/.flake files are symlinks (often multi-hop, through the nix store) into a repo. Run `realpath <path>`, then act on the result; never the ~/ symlink path.

- **Read/Edit:** the tools refuse to write through a symlink, and their state tracking desyncs on symlink paths (spurious "not read yet" / "modified since read"). Read and edit the realpath instead.
- **Bash (sed -i, >, tee, mv, cp):** these do NOT error on a symlink -- they silently replace it with a regular file, splitting ~/.claude from the repo. Always target `$(realpath path)`.

**realpath, not plain readlink**: plain readlink stops at the first nix-store hop; realpath resolves all the way to the repo.
