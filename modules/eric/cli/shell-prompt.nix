{
  flake.modules.homeManager.base = {
    programs.starship = {
      enable = true;
      enableZshIntegration = false; # pre-computed in zsh.nix
      settings = fromTOML (builtins.readFile ./starship/starship.toml);
    };
  };
}
