{
  # the agent guard hooks, built from modules/eric/ai/guard
  flake.overlays.agent-guard = final: _: {
    agent-guard = final.buildGoModule {
      pname = "agent-guard";
      version = "0";
      src = ../eric/ai/guard;
      vendorHash = "sha256-sULOJKCnZ9nS/EVH8Q4MhH7U9zdrcruxCKI6HqP/1a4=";
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
