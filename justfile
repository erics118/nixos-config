set shell := ["zsh", "-uc"]
system_target := if os() == "macos" { "darwin" } else { "os" }
ntfy_topic := `cat /run/secrets/ntfy/topic 2>/dev/null || echo ""`

[private]
ntfy msg status:
    #!/usr/bin/env zsh
    [[ -z "{{ ntfy_topic }}" ]] && exit 0
    curl -s -o /dev/null \
      -H "Title: just ({{ invocation_directory_native() }})" \
      -H "Tags: nix,{{ if status == "0" { "white_check_mark" } else { "x" } }}" \
      -d "just {{ msg }}: {{ if status == "0" { "ok" } else { "failed" } }}" \
      "https://ntfy.sh/{{ ntfy_topic }}"

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
    nh {{ system_target }} switch; just ntfy switch $?

# build the system configuration
[group('system')]
build:
    nh {{ system_target }} build; just ntfy build $?

# build the system configuration with private override
[group('system')]
dev:
    nh os switch . -- --override-input nixos-config-private path:../nixos-config-private; just ntfy dev $?

# test the NixOS configuration (Linux only)
[group('system')]
[linux]
test:
    nh os test; just ntfy test $?

# switch home-manager configuration
[group('system')]
home:
    nh home switch; just ntfy home $?

# garbage collect unused nix store entries
[group('system')]
gc:
    nh clean all --no-gcroots --optimise --keep-since 7d --keep 3
