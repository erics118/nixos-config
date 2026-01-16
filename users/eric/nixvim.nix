{
  inputs,
  pkgs,
  ...
}:

let
  nixvimPackage = inputs.nixvim.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  home.packages = [ nixvimPackage ];

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
