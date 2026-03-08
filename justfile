set shell := ["zsh", "-uc"]

# list all commands
[private]
default:
    @just --list --unsorted

# ── Flake ─────────────────────────────────────────────────────────────────────

# update all flake inputs
[group('flake')]
update-all:
    nix flake update

# update a single flake input
[group('flake')]
update input:
    nix flake update {{input}}

# format nix files
[group('flake')]
fmt:
    nix fmt

# check flake outputs
[group('flake')]
check:
    nix flake check

# open nix repl with flake loaded
[group('flake')]
repl:
    nix repl .#

# ── System ────────────────────────────────────────────────────────────────────

# switch the system configuration
[group('system')]
switch:
    {{ if os() == "macos" { "nh darwin switch" } else { "nh os switch" } }}

# build the system configuration
[group('system')]
build:
    {{ if os() == "macos" { "nh darwin build" } else { "nh os build" } }}

# test the NixOS configuration (Linux only)
[group('system')]
[linux]
test:
    nh os test

# switch home-manager configuration
[group('system')]
home:
    nh home switch

# garbage collect unused nix store entries
[group('system')]
gc:
    nh clean all --keep-since 14d
