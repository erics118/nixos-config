{ inputs, ... }:
{
  flake.modules.homeManager.base =
    { pkgs, ... }:
    {
      home.packages = [
        inputs.wezterm-src.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    };
}
