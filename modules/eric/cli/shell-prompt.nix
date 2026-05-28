{
  flake.modules.homeManager.base = {
    programs.starship = {
      enable = true;
      enableZshIntegration = false; # pre-computed in shell.nix
      settings = fromTOML (builtins.readFile ./files/starship.toml);
    };
  };
}
