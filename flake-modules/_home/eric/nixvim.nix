{ pkgs, ... }:

{
  # Uses the flake-inputs overlay: pkgs.inputs.nixvim.default
  home.packages = [ pkgs.inputs.nixvim.default ];

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
