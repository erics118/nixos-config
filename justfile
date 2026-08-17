set shell := ["zsh", "-uc"]
set script-interpreter := ["zsh", "-eu"]

system_target := if os() == "macos" { "darwin" } else { "os" }
ntfy_topic := "nix"
ntfy_token := `cat /run/secrets/ntfy/token 2>/dev/null || echo ""`

set default-list

[private]
ntfy msg status:
    #!/usr/bin/env zsh
    [[ -z "{{ ntfy_token }}" ]] && exit 0
    curl -s -o /dev/null \
      -H "Authorization: Bearer {{ ntfy_token }}" \
      -H "Title: just on `hostname` ({{ invocation_directory_native() }})" \
      -H "Tags: nix,{{ if status == "0" { "white_check_mark" } else { "x" } }}" \
      -d "just {{ msg }}: {{ if status == "0" { "ok" } else { "failed" } }}" \
      "https://ntfy.eriz.cc/{{ ntfy_topic }}"

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
[script]
switch:
    trap 'just ntfy switch $?' EXIT
    nh {{ system_target }} switch

# build the system configuration
[group('system')]
[script]
build:
    trap 'just ntfy build $?' EXIT
    nh {{ system_target }} build

# switch with a local checkout of the private input
[group('system')]
[script]
dev:
    trap 'just ntfy dev $?' EXIT
    nh {{ system_target }} switch . -- --override-input nixos-config-private path:../nixos-config-private

# test the NixOS configuration (Linux only)
[group('system')]
[linux]
[script]
test:
    trap 'just ntfy test $?' EXIT
    nh os test

# garbage collect unused nix store entries
[group('system')]
gc:
    nh clean all --keep-since 7d --keep 5 --optimise    
