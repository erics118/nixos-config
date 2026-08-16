---
name: new-project
description: Scaffold a new dev project from ~/dev/templates (flake + direnv + language init). Use when the user wants to start or create a new project.
argument-hint: "<name> [language]"
---

Treat the first value supplied with the invocation as the project name and an optional
second value as the language; infer the language from the name or context if omitted.
Create the project under `~/dev` using this templates-first workflow:

1. Check ~/dev/templates/ for a matching language template (it is a flake-templates repo: cpp, go, latex, node, ocaml, python, rust, ...). Read the chosen template's flake.nix before using it.
2. If a template exists: create `~/dev/<name>`, enter it, run `git init`, then run
   `nix flake init -t ~/dev/templates#<language>` with the values determined above.
3. If NO template exists for the language: create one in ~/dev/templates/<lang>/ FIRST, using flake-parts for multi-arch scaffolding (register it in the templates repo's flake.nix `flake.templates`, matching the style of the existing ones), git add it there, then use it via step 2. The template gets the nix layer only - see next point.
4. Templates carry the NIX layer only (flake.nix, maybe justfile). Source scaffolding comes from the language's own init tool, run inside the devShell:
   - go: `go mod init` - ocaml: `dune init` - node: the suitable framework init (`npm create vite`, `npm init`, etc.)
   - cpp is the exception: cpp doesn't have a super nice tooling framework so its template ships CMakeLists/src/tests directly
5. Write .envrc with `use flake` if the template didn't provide one; `direnv allow`.
6. git add nix files BEFORE any nix command (flakes ignore untracked files).
7. Run the language init tool (step 4) inside the devShell, then verify: `nix flake check` (or `nix develop -c <build cmd>`) passes.
8. If the template's flake lacks a treefmt wrapper in the devShell packages, add `config.treefmt.build.wrapper` (needed for the global format-on-edit hook) - and offer to upstream that fix to the template itself.
9. Do NOT git commit (neither in the new project nor in templates). Report: template used or created, init tool run, verify results.
