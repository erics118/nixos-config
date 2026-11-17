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

      # nixpkgs' cargo setup hook makes rusqlite link system sqlite instead of its bundled copy
      nativeBuildInputs = [ final.pkg-config ];
      buildInputs = [ final.sqlite ];

      # a test runs the pi extension, and the snapshot tests run git and git lfs
      nativeCheckInputs = [
        final.nodejs
        final.git
        final.git-lfs
      ];

      # these start a daemon against the rex cli the app installs, which the build lacks
      checkFlags = [
        "--skip=wait::a_daemon_starts_as_soon_as_a_server_appears_under_directories_that_did_not_exist"
        "--skip=upgrade::a_daemon_exits_when_an_upgrade_replaces_its_executable"
        # these run git filters under sandbox-exec, which cannot nest inside the nix build sandbox
        "--skip=git::filter::tests::a_changed_file_runs_its_filter_only_denied_writes_to_the_repository"
        "--skip=git::filter::tests::a_filter_runs_for_no_file_unchanged_or_deleted"
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
