{
  flake.modules.homeManager.base = {
    # exports XDG_CONFIG_HOME / DATA / CACHE / STATE and manages the base dirs
    xdg.enable = true;
  };
}
