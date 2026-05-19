{
  flake.modules.homeManager.base = {
    programs.starship = {
      enable = true;
      settings = fromTOML (builtins.readFile ./files/starship.toml);
    };
  };
}
