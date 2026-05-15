{ inputs }:

# each attribute is an overlay that is applied to nixpkgs
{
  # aliases 'pkgs.inputs.${flake}' to the flake's packages
  # eg: pkgs.inputs.nixvim.default
  flake-inputs = final: _: {
    inputs = builtins.mapAttrs (
      _: flake:
      let
        legacyPackages = (flake.legacyPackages or { }).${final.stdenv.hostPlatform.system} or { };
        packages = (flake.packages or { }).${final.stdenv.hostPlatform.system} or { };
      in
      if legacyPackages != { } then legacyPackages else packages
    ) inputs;
  };

  # rust toolchain overlay
  rust = inputs.rust-overlay.overlays.default;

  # adversarial-review wrapper
  # the upstream script writes artifacts/logs/tracking.json next to itself,
  # so we stage symlinks in $XDG_STATE_HOME at runtime and exec from there.
  adversarial-review =
    final: _:
    let
      src = inputs.adversarial-review;
      llmAgents = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system};
    in
    {
      adversarial-review = final.writeShellApplication {
        name = "adversarial-review";
        runtimeInputs = [
          final.jq
          final.coreutils
          final.bash
          llmAgents.claude-code
          llmAgents.codex
        ];
        text = ''
          state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/adversarial-review"
          mkdir -p "$state_dir"
          ln -sfn ${src}/lib "$state_dir/lib"
          ln -sfn ${src}/prompts "$state_dir/prompts"
          ln -sfn ${src}/adversarial_review.sh "$state_dir/adversarial_review.sh"
          exec bash "$state_dir/adversarial_review.sh" "$@"
        '';
      };
    };

  # custom wezterm fork (temporarily disabled)
  wezterm =
    final: prev:
    let
      inherit (final.stdenv.hostPlatform) system;
    in
    {
      wezterm = inputs.wezterm-src.packages.${system}.default.overrideAttrs (old: {
        # version = "erics118-custom";
        env = (old.env or { }) // {
          CC_aarch64_apple_darwin = "${prev.stdenv.cc.cc}/bin/clang";
        };
      });
    };

}
