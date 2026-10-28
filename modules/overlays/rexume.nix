{ inputs, ... }: {
  # restores rex sessions and their agent conversations after the rex server restarts
  flake.overlays.rexume = final: _: {
    rexume = final.rustPlatform.buildRustPackage {
      pname = "rexume";
      version = "HEAD";

      src = inputs.rexume-src;
      cargoLock.lockFile = "${inputs.rexume-src}/Cargo.lock";

      # Cargo.toml asks for rustc 1.99.1, a patch release ahead of nixpkgs
      cargoBuildFlags = [ "--ignore-rust-version" ];
      cargoTestFlags = [ "--ignore-rust-version" ];

      # a test runs the pi extension
      nativeCheckInputs = [ final.nodejs ];

      # these start a daemon against the rex cli the app installs, which the build lacks
      checkFlags = [
        "--skip=wait::a_daemon_starts_as_soon_as_a_server_appears_under_directories_that_did_not_exist"
        "--skip=upgrade::a_daemon_exits_when_an_upgrade_replaces_its_executable"
      ];

      meta = {
        description = "restores Rex sessions and their agent conversations after the server restarts";
        homepage = "https://github.com/Entwining/rexume";
        license = final.lib.licenses.mit;
        mainProgram = "rexume";
        platforms = final.lib.platforms.darwin;
      };
    };
  };
}
