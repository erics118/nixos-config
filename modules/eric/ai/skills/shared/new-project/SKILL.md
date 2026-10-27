---
name: new-project
description: Scaffold a new dev project from ~/dev/templates (flake + direnv + language init)
argument-hint: "<name> [language]"
disable-model-invocation: true
---

Treat the first value supplied with the invocation as the project name and an optional
second value as the language; infer the language from the name or context if omitted.
Create the project under `~/dev` using this templates-first workflow:

1. Check ~/dev/templates/ for a matching language template (it is a flake-templates repo: cpp, go, latex, node, ocaml, python, rust, ...). Read the chosen template's flake.nix before using it.
2. If a template exists: create `~/dev/<name>`, then run `git init` and
   `nix flake init -t ~/dev/templates#<language>` in it, using absolute paths and the values determined above.
3. If NO template exists for the language: create one in `~/dev/templates/<language>/` first, using flake-parts for multi-arch scaffolding. Register it in `flake.templates` in `~/dev/templates/flake.nix`, matching the existing entries. `git add` it there, then use it via step 2.
4. Most templates carry only the nix layer (flake.nix, maybe justfile). Source scaffolding comes from the language's init tool, which step 7 runs inside the devShell:
   - go: `go mod init`
   - ocaml: `dune init`
   - node: the suitable framework init (`npm create vite`, `npm init`, etc.)
   - python: `uv init`
   - rust: `cargo init`

   Two templates ship source and skip the init tool:
   - cpp: cpp doesn't have a super nice tooling framework, so its template ships CMakeLists.txt, src/ and tests/
   - latex: its template ships main.tex and .latexmkrc

5. `git add` the nix files before any nix command, because flakes ignore untracked files. Then run `nix flake update` so the project starts on current inputs, not the template's pins. `git add` the updated `flake.lock`.
6. Write `.envrc` containing `use flake` (no template ships one), then run `direnv allow`.
7. Run the language init tool (step 4) inside the devShell, then verify: `nix flake check` (or `nix develop -c <build cmd>`) passes.
8. Report: template used or created, init tool run, verify results.
