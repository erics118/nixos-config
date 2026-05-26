{ inputs, ... }:
{
  # adversarial-review wrapper
  # the upstream script writes artifacts/logs/tracking.json next to itself,
  # so we stage symlinks in $XDG_STATE_HOME at runtime and exec from there.
  flake.overlays.adversarial-review =
    final: _:
    let
      src = inputs.adversarial-review;
    in
    {
      adversarial-review = final.writeShellApplication {
        name = "adversarial-review";
        runtimeInputs = [
          final.jq
          final.coreutils
          final.bash
          final.claude-code
          final.codex
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
}
