{
  # tmux 3.8-rc3 for the dim= style, which shades every colour in inactive panes.
  # drop once nixpkgs ships 3.8
  flake.overlays.tmux = _final: prev: {
    tmux = prev.tmux.overrideAttrs {
      version = "3.8-rc3";
      src = prev.fetchFromGitHub {
        owner = "tmux";
        repo = "tmux";
        rev = "331611b632ae3b9306d57dc44f21ca05f567b878";
        hash = "sha256-dWUD62onx4cSwngtZTlF9pggA/9Z/Vmn77nD53luld0=";
      };
    };
  };
}
