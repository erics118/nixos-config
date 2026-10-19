set shell := ["zsh", "-uc"]
set script-interpreter := ["zsh", "-eu"]

system_target := if os() == "macos" { "darwin" } else { "os" }
ntfy_topic := "nix"

set default-list

[private]
ntfy msg status:
    #!/usr/bin/env zsh
    # read here, not as a just variable, so `just --evaluate` and curl's argv never show it
    token=$(cat /run/secrets/ntfy/token 2>/dev/null) || exit 0
    [[ -n "$token" ]] || exit 0
    curl -s -o /dev/null \
      -H @<(printf 'Authorization: Bearer %s\n' "$token") \
      -H "Title: just on `hostname` ({{ invocation_directory_native() }})" \
      -H "Tags: nix,{{ if status == "0" { "white_check_mark" } else { "x" } }}" \
      -d "just {{ msg }}: {{ if status == "0" { "ok" } else { "failed" } }}" \
      "https://ntfy.eriz.cc/{{ ntfy_topic }}"

# update the named flake inputs, or all of them when none are named
[group('flake')]
update *inputs:
    nix flake update {{ inputs }}

# format all files with treefmt
[group('flake')]
fmt:
    nix fmt -- --no-cache

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

# switch with one flake input from a local checkout, the private repo by default
[group('system')]
[script]
dev input="nixos-config-private" src="../nixos-config-private":
    trap 'just ntfy dev $?' EXIT
    nh {{ system_target }} switch . -- --override-input {{ input }} "git+file:$(realpath {{ src }})"

# test the NixOS configuration
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
