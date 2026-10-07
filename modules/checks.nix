# expose this system's host toplevels, config checks and the devShell as flake checks
# so `nix flake check` builds them. CI's runner matrix covers the other systems
{ lib, config, ... }: {
  perSystem =
    {
      system,
      self',
      pkgs,
      ...
    }:
    {
      checks =
        let
          # keep only the configs whose build is for this system, then prefix
          # the names so they don't collide across classes
          forSystem =
            prefix: configs: toDrv:
            lib.mapAttrs' (name: cfg: lib.nameValuePair "${prefix}-${name}" (toDrv cfg)) (
              lib.filterAttrs (_: cfg: cfg.config.nixpkgs.hostPlatform.system == system) configs
            );

          # start the host's neovim on the repo config with its home-manager plugins
          # nvim exits 0 even when init.lua errors, so any output fails the check
          nvimStartup =
            c:
            let
              hm = c.config.home-manager.users.eric;
            in
            pkgs.runCommand "nvim-startup" { } ''
              export HOME=$TMPDIR XDG_CONFIG_HOME=$TMPDIR/config XDG_DATA_HOME=$TMPDIR/data
              mkdir -p $XDG_CONFIG_HOME $XDG_DATA_HOME/nvim/site/pack
              ln -s ${../modules/eric/nvim} $XDG_CONFIG_HOME/nvim
              ln -s ${hm.home-files}/.local/share/nvim/site/pack/hm $XDG_DATA_HOME/nvim/site/pack/hm
              ${hm.programs.neovim.finalPackage}/bin/nvim --headless +qa > log 2>&1
              if [ -s log ]; then
                cat log
                exit 1
              fi
              touch $out
            '';

          # parse the host's generated zsh startup files and the repo's own zsh
          zshParse =
            c:
            let
              hm = c.config.home-manager.users.eric;
            in
            pkgs.runCommand "zsh-parse" { } ''
              for f in ${hm.home-files}/.config/zsh/{.zshenv,.zprofile,.zshrc} \
                ${../modules/eric/cli/zsh/init.zsh} ${../modules/eric/cli/rtmux/_rtmux}; do
                ${lib.getExe hm.programs.zsh.package} -n "$f"
              done
              touch $out
            '';

          # source the host's generated tmux.conf, plugins included
          # nested conf errors keep exit code 0, so any output fails
          tmuxStartup =
            c:
            let
              hm = c.config.home-manager.users.eric;
            in
            # the plugin scripts call tmux from PATH
            pkgs.runCommand "tmux-startup" { nativeBuildInputs = [ hm.programs.tmux.package ]; } ''
              export HOME=$TMPDIR
              mkdir -p $HOME/.config
              ln -s ${../modules/eric/cli/tmux} $HOME/.config/tmux
              tmux -S $TMPDIR/sock -f /dev/null start-server \; \
                source-file ${hm.home-files}/.config/tmux/tmux.conf > log 2>&1
              if [ -s log ]; then
                cat log
                exit 1
              fi
              touch $out
            '';

          # one lua-<dir> check per lua project, which a .luarc.json marks
          luaDirs = map dirOf (
            lib.filter (f: baseNameOf f == ".luarc.json") (lib.filesystem.listFilesRecursive ./.)
          );
          luaCheck =
            dir:
            pkgs.runCommand "lua-${baseNameOf dir}"
              {
                # the env vars the .luarc.json files load libraries from
                VIMRUNTIME = "${pkgs.neovim-unwrapped}/share/nvim/runtime";
                inherit (self'.devShells.default) HYPR_STUBS;
              }
              ''
                ${lib.getExe pkgs.lua-language-server} --check=${dir} --checklevel=Warning --logpath=$TMPDIR/log --metapath=$TMPDIR/meta
                touch $out
              '';
        in
        lib.mkMerge [
          (forSystem "nixos" config.flake.nixosConfigurations (c: c.config.system.build.toplevel))
          (forSystem "darwin" config.flake.darwinConfigurations (c: c.config.system.build.toplevel))
          (forSystem "nvim" config.flake.nixosConfigurations nvimStartup)
          (forSystem "nvim" config.flake.darwinConfigurations nvimStartup)
          (forSystem "zsh" config.flake.nixosConfigurations zshParse)
          (forSystem "zsh" config.flake.darwinConfigurations zshParse)
          (forSystem "tmux" config.flake.nixosConfigurations tmuxStartup)
          (forSystem "tmux" config.flake.darwinConfigurations tmuxStartup)
          (lib.listToAttrs (map (dir: lib.nameValuePair "lua-${baseNameOf dir}" (luaCheck dir)) luaDirs))
          # flake check only evaluates devShells, so build it here to catch a broken HYPR_STUBS
          { devShell = self'.devShells.default; }
          {
            firefox-js = pkgs.runCommand "firefox-js" { } ''
              for f in ${../modules/eric/desktop/firefox/chrome/JS}/*.js; do
                ${lib.getExe pkgs.nodejs} --check "$f"
              done
              touch $out
            '';
          }
          # wezterm exits 0 on a broken config, but ls-fonts logs the lua error
          # every system has the same wezterm and config
          (lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
            wezterm = pkgs.runCommand "wezterm-config" { } ''
              export HOME=$TMPDIR
              mkdir -p $HOME/.config
              ln -s ${../modules/eric/desktop/wezterm} $HOME/.config/wezterm
              ${lib.getExe pkgs.wezterm} ls-fonts > /dev/null 2> log
              # the sandbox has no nerd font, so only ERROR lines count
              if grep -q ' ERROR ' log; then
                cat log
                exit 1
              fi
              touch $out
            '';
          })
        ];
    };
}
