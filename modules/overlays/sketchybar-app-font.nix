{
  # nixpkgs lags upstream releases, which add icons for new apps
  flake.overlays.sketchybar-app-font = final: prev: {
    sketchybar-app-font = prev.sketchybar-app-font.overrideAttrs (
      finalAttrs: _: {
        version = "3.0.20";
        src = final.fetchFromGitHub {
          owner = "kvndrsslr";
          repo = "sketchybar-app-font";
          tag = "v${finalAttrs.version}";
          hash = "sha256-EutIFcE3eq3Non9nEt7rYc7QHtHSmzSwwL/DkR755sQ=";
        };
        pnpmDeps = final.fetchPnpmDeps {
          inherit (finalAttrs) pname version src;
          pnpm = final.pnpm_11;
          fetcherVersion = 4;
          hash = "sha256-zFheFcVSCZWDrThn5PnxhJscRhLG/psSI8Q8g48nXNU=";
        };
      }
    );
  };
}
