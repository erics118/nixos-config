{ inputs, ... }: {
  # smart-splits.nvim v3 backend for rex, which nixpkgs lacks
  flake.overlays.smart-splits-backend-rex = final: prev: {
    vimPlugins = prev.vimPlugins.extend (
      _: _: {
        smart-splits-backend-rex = final.vimUtils.buildVimPlugin {
          pname = "smart-splits-backend-rex";
          version = "HEAD";
          src = inputs.smart-splits-backend-rex-src;
        };
      }
    );
  };
}
