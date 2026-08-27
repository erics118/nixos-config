{
  # non_portable build searches Contents/Resources, but nixpkgs installs
  # shaders and configs to Contents/MacOS, so pages render blank without them
  flake.overlays.sioyek = final: prev: {
    sioyek = prev.sioyek.overrideAttrs (old: {
      postInstall =
        old.postInstall
        + final.lib.optionalString final.stdenv.hostPlatform.isDarwin ''
          res="$out/Applications/sioyek.app/Contents/Resources"
          mkdir -p "$res"
          ln -s ../MacOS/shaders "$res/shaders"
          ln -s ../MacOS/prefs.config "$res/prefs.config"
          ln -s ../MacOS/keys.config "$res/keys.config"
        '';
    });
  };
}
