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

          # the sandbox sets neither HOME nor USER, and the configs read both as a login session would have them
          check =
            name: args: script:
            pkgs.runCommand name args ''
              export HOME=$TMPDIR USER=nixbld
              ${script}
              touch $out
            '';

          # start the host's neovim on the repo config with its home-manager plugins
          # nvim exits 0 even when init.lua errors, so any output fails the check
          nvimStartup =
            c:
            let
              hm = c.config.home-manager.users.eric;
            in
            check "nvim-startup" { } ''
              mkdir -p $HOME/.config $HOME/.local/share/nvim/site/pack
              ln -s ${../modules/eric/nvim} $HOME/.config/nvim
              ln -s ${hm.home-files}/.local/share/nvim/site/pack/hm $HOME/.local/share/nvim/site/pack/hm
              ${hm.programs.neovim.finalPackage}/bin/nvim --headless +qa > log 2>&1
              if [ -s log ]; then
                cat log
                exit 1
              fi
            '';

          # parse the host's generated zsh startup files and the repo's own zsh
          zshParse =
            c:
            let
              hm = c.config.home-manager.users.eric;
            in
            check "zsh-parse" { } ''
              for f in ${hm.home-files}/.config/zsh/{.zshenv,.zprofile,.zshrc} \
                ${../modules/eric/cli/zsh}/*.zsh ${../modules/eric/cli/zsh}/prompt/*.zsh \
                ${../modules/eric/ai/claude/statusline.zsh} ${../modules/eric/cli/rtmux/_rtmux}; do
                ${lib.getExe hm.programs.zsh.package} -n "$f"
              done
            '';

          # resolve every named host in the host's generated ssh config, so a bad line fails ci
          # the sandbox has no network, so the turtle Match exec takes its fallback branch
          sshConfig =
            c:
            let
              hm = c.config.home-manager.users.eric;
            in
            check "ssh-config" { nativeBuildInputs = [ pkgs.openssh ]; } ''
              config=${hm.home-files}/.ssh/config
              for host in $(awk 'tolower($1) == "host" { for (i = 2; i <= NF; i++) if ($i !~ /[*?!]/) print $i }' "$config"); do
                ssh -G -F "$config" "$host" > /dev/null
              done
            '';

          # one lua-<dir> check per lua project, which a .luarc.json marks
          luaDirs = map dirOf (
            lib.filter (f: baseNameOf f == ".luarc.json") (lib.filesystem.listFilesRecursive ./.)
          );
          luaCheck =
            dir:
            check "lua-${baseNameOf dir}"
              {
                # the env vars the .luarc.json files load libraries from
                VIMRUNTIME = "${pkgs.neovim-unwrapped}/share/nvim/runtime";
                inherit (self'.devShells.default) HYPR_STUBS;
              }
              ''
                ${lib.getExe pkgs.lua-language-server} --check=${dir} --checklevel=Warning --logpath=$TMPDIR/log --metapath=$TMPDIR/meta
              '';
        in
        lib.mkMerge [
          (forSystem "nixos" config.flake.nixosConfigurations (c: c.config.system.build.toplevel))
          (forSystem "darwin" config.flake.darwinConfigurations (c: c.config.system.build.toplevel))
          (forSystem "nvim" config.flake.nixosConfigurations nvimStartup)
          (forSystem "nvim" config.flake.darwinConfigurations nvimStartup)
          (forSystem "zsh" config.flake.nixosConfigurations zshParse)
          (forSystem "zsh" config.flake.darwinConfigurations zshParse)
          (forSystem "ssh" config.flake.nixosConfigurations sshConfig)
          (forSystem "ssh" config.flake.darwinConfigurations sshConfig)
          (lib.listToAttrs (map (dir: lib.nameValuePair "lua-${baseNameOf dir}" (luaCheck dir)) luaDirs))
          # flake check only evaluates devShells, so build it here to catch a broken HYPR_STUBS
          { devShell = self'.devShells.default; }
          {
            # sourcing runs every command, so an option a newer tmux dropped fails too
            tmux = check "tmux-config" { } ''
              cd ${../modules/eric/cli/tmux}
              ${lib.getExe pkgs.tmux} -S $TMPDIR/sock -f /dev/null start-server \; \
                source-file main.conf base.conf keys.conf popups.conf tabline.conf alerts.conf
            '';

            # rex loads init.lua from ~/.config/rex, as rex.nix links it
            rex-config = check "rex-config" { } ''
              mkdir -p $HOME/.config/rex
              ln -s ${../modules/eric/cli/rex/init.lua} $HOME/.config/rex/init.lua
              ${lib.getExe pkgs.inputs.rex.rex} --autostart=false config check
            '';

            # the agent config files agree with each other and with the guard's checks
            agent-config =
              check "agent-config"
                {
                  nativeBuildInputs = [
                    pkgs.agent-guard
                    pkgs.jq
                  ];
                }
                ''
                  ${lib.getExe pkgs.bash} ${../modules/eric/ai/consistency.sh} ${../modules/eric/ai}
                '';

            firefox-js = check "firefox-js" { } ''
              for f in ${../modules/eric/desktop/firefox/chrome/JS}/*.js; do
                ${lib.getExe pkgs.nodejs} --check "$f"
              done
            '';
          }
          # wezterm exits 0 on a broken config, but ls-fonts logs the lua error
          # every system has the same wezterm and config
          (lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
            wezterm = check "wezterm-config" { } ''
              mkdir -p $HOME/.config
              ln -s ${../modules/eric/desktop/wezterm} $HOME/.config/wezterm
              ${lib.getExe pkgs.wezterm} ls-fonts > /dev/null 2> log
              # the sandbox has no nerd font, so only ERROR lines count
              if grep -q ' ERROR ' log; then
                cat log
                exit 1
              fi
            '';
          })
        ];
    };
}
