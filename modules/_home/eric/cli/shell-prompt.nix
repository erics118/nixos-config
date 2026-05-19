{
  programs.starship = {
    enable = true;
    settings = fromTOML (builtins.readFile ./starship.toml);
  };
}
