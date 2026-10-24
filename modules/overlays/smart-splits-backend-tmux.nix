{ inputs, ... }: {
  # smart-splits.nvim v3 moved tmux support into this plugin, which nixpkgs lacks
  flake.overlays.smart-splits-backend-tmux = final: prev: {
    vimPlugins = prev.vimPlugins.extend (
      _: _: {
        smart-splits-backend-tmux = final.vimUtils.buildVimPlugin {
          pname = "smart-splits-backend-tmux";
          version = "HEAD";
          src = inputs.smart-splits-backend-tmux-src;
        };
      }
    );
  };
}
