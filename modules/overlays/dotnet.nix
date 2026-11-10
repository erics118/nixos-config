{
  flake.overlays.dotnet = _: prev: {
    # hydra's source-built .net for aarch64-darwin has failed since 9.0.22 (nixpkgs issue 584390), so consumers like marksman compile it
    # drop this once hydra builds dotnetCorePackages.runtime_9_0 on aarch64-darwin again
    dotnetCorePackages =
      if prev.stdenv.hostPlatform.isDarwin then
        prev.dotnetCorePackages.overrideScope (_: dprev: { runtime_9_0 = dprev.runtime_9_0-bin; })
      else
        prev.dotnetCorePackages;
  };
}
