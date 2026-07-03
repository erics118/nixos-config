{
  # track HEAD instead of releases
  flake.overlays.yabai = final: prev: {
    yabai = prev.yabai.overrideAttrs {
      version = "HEAD";
      __intentionallyOverridingVersion = true;
      src = final.fetchFromGitHub {
        owner = "asmvik";
        repo = "yabai";
        rev = "dd845723416f5fe92af49fad5ebab00369e07edd";
        hash = "sha256-RPiGAuJS+tGsexekIzwgKYf/v+kA3lVn0+qMVIMC2Vk=";
      };
      # binary reports the upstream version, not the -unstable suffix
      doInstallCheck = false;
    };
  };
}
