{
  # the agent guard hooks, built from modules/eric/ai/guard
  flake.overlays.agent-guard = final: _: {
    agent-guard = final.buildGoModule {
      pname = "agent-guard";
      version = "0";
      src = ../eric/ai/guard;
      vendorHash = "sha256-5Ek77w2lFWehxLcQDOte4Gc4fiAzCdrTt6UGHY6JOlE=";
      # the check cases build git repos, dry-run just recipes, and load an .envrc for treefmt-on-edit
      nativeCheckInputs = [
        final.direnv
        final.git
        final.just
      ];
      meta.mainProgram = "agent-guard";
    };
  };
  perSystem = { pkgs, ... }: { packages.agent-guard = pkgs.agent-guard; };
}
