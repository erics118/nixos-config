set shell := ["zsh", "-uc"]
system_target := if os() == "macos" { "darwin" } else { "os" }

# list all commands
[private]
default:
    @just --list --unsorted

# update all flake inputs
[group('flake')]
update-all:
    nix flake update

# update a single flake input
[group('flake')]
update input:
    nix flake update {{ input }}

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

# switch the system configuration
[group('system')]
switch:
    nh {{ system_target }} switch

# build the system configuration
[group('system')]
build:
    nh {{ system_target }} build

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
    nh clean all --no-gcroots --optimise --keep-since 7d --keep 3
