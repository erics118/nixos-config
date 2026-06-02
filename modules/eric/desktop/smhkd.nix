{
  flake.modules.homeManager.darwin = {
    home.file = {
      ".config/smhkd/smhkdrc".source = ./smhkd/smhkdrc;
    };
  };
}
