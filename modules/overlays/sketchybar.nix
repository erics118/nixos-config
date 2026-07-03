{
  # sketchybar fork, overrides global one
  flake.overlays.sketchybar = final: prev: {
    sketchybar = prev.sketchybar.overrideAttrs (old: {
      version = old.version + "-eric";
      __intentionallyOverridingVersion = true;
      src = final.fetchFromGitHub {
        owner = "erics118";
        repo = "SketchyBar";
        # eric branch, feat: optionally use typographical width
        rev = "f44b57d20c4207353b92f3cf046b0e1804f3acb3";
        hash = "sha256-YiUOomnuPfE4UHw+f6j/K3MKTnWfjXN23l14N4zbuD4=";
      };
      # binary reports upstream version
      doInstallCheck = false;
    });
  };
}
