{
  # tmux master, since 3.8 draws pane output over an open menu and its display-popup gives no pane to style.
  # version matches what tmux -V prints, since nixpkgs checks it after the build.
  # drop once nixpkgs ships a release past 3.8
  flake.overlays.tmux = _final: prev: {
    tmux = prev.tmux.overrideAttrs {
      version = "next-3.9";
      src = prev.fetchFromGitHub {
        owner = "tmux";
        repo = "tmux";
        rev = "95c1c3d7c50795170fd95ec8614bf45fea09faab";
        hash = "sha256-8iHDI0CVcJLcLIaMhgJEI0V5HZ7rKMCjYIEXNgEOrhI=";
      };
    };
  };
}
