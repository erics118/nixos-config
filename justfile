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

# update all flake inputs
[group('flake')]
update-all:
    nix flake update

# update a single flake input
[group('flake')]
update input:
    nix flake update {{ input }}

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

# switch with a local checkout of the private input
[group('system')]
[script]
dev:
    trap 'just ntfy dev $?' EXIT
    nh {{ system_target }} switch . -- --override-input nixos-config-private git+file:../nixos-config-private

# build a signed agent from a local checkout and install it, `just switch` restores the flake build
[group('system')]
[macos]
[script]
install-local agent src:
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"; just ntfy install-local $?' EXIT
    cfg=".#darwinConfigurations.$(scutil --get LocalHostName).config"
    pkg=$(nix build --no-link --print-out-paths --override-input {{ agent }}-src "path:$(realpath {{ src }})" "$cfg.signedAgents.{{ agent }}")
    read cert label <<< "$(nix eval --raw "$cfg" --apply 'c: "${c.signedAgentsCert} ${c.launchd.user.agents.{{ agent }}.serviceConfig.Label}"')"
    cp "$pkg/bin/{{ agent }}" "$tmp/bin" && chmod u+w "$tmp/bin" && codesign -fs "$cert" "$tmp/bin"
    sudo install -o root -g wheel -m 755 "$tmp/bin" /usr/local/bin/{{ agent }}
    # the next switch sees a different source and reinstalls the flake build
    echo "$pkg/bin/{{ agent }}" | sudo tee /usr/local/bin/{{ agent }}.source >/dev/null
    launchctl kickstart -k "gui/$(id -u)/$label"

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
