{
  flake.modules.homeManager.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # pre-compute the zsh init scripts for these tools at nix build time to
      # reduce shell startup time
      mkInit =
        name: cmd:
        pkgs.runCommand "${name}-init.zsh" { } ''
          export HOME="$TMPDIR/home"
          export XDG_CONFIG_HOME="$HOME/.config"
          export XDG_CACHE_HOME="$HOME/.cache"
          mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
          ${cmd} > $out
        '';
      starshipInit = mkInit "starship" "${pkgs.starship}/bin/starship init zsh --print-full-init";
      zoxideInit = mkInit "zoxide" "${pkgs.zoxide}/bin/zoxide init zsh";
      direnvInit = mkInit "direnv" "${pkgs.direnv}/bin/direnv hook zsh";
      nixYourShellInit = mkInit "nix-your-shell" "${pkgs.nix-your-shell}/bin/nix-your-shell zsh";
      fzfInit = mkInit "fzf" "${pkgs.fzf}/bin/fzf --zsh";
      atuinInit = mkInit "atuin" "${pkgs.atuin}/bin/atuin init zsh";
    in
    {
      home.sessionVariables.COLORTERM = "truecolor";

      programs.zsh = {
        enable = true;
        enableCompletion = true;
        completionInit = ''
          # nix populates fpath via /etc/zshenv + home-manager
          # only add system locations nix doesn't know about
          fpath+=(
            /opt/homebrew/share/zsh/site-functions
            /usr/local/share/zsh/site-functions
            /usr/share/zsh/site-functions
            ${pkgs.nix-zsh-completions}/share/zsh/vendor-completions
          )

          autoload -U compinit

          # rebuild the dump when the system generation is newer, so completions
          # from newly installed packages get registered; zshrc is nix-managed so
          # a generation bump covers config changes too
          # -L reads the link's own mtime, the store path it points at is epoch 0
          # keep a zcompiled .zwc bytecode copy for faster loads
          typeset -g ZSH_COMPDUMP="$ZDOTDIR/.zcompdump"
          zmodload -F zsh/stat b:zstat
          zstat -L -A _gen +mtime /run/current-system 2>/dev/null
          zstat -A _dump +mtime "$ZSH_COMPDUMP" 2>/dev/null
          if (( ''${_dump[1]:-0} < ''${_gen[1]:-1} )); then
            compinit -d "$ZSH_COMPDUMP"
            zcompile -R -- "$ZSH_COMPDUMP.zwc" "$ZSH_COMPDUMP" 2>/dev/null
          else
            compinit -C -d "$ZSH_COMPDUMP"
            [[ -s "$ZSH_COMPDUMP.zwc" && "$ZSH_COMPDUMP" -ot "$ZSH_COMPDUMP.zwc" ]] \
              || zcompile -R -- "$ZSH_COMPDUMP.zwc" "$ZSH_COMPDUMP" 2>/dev/null
          fi
          unset _gen _dump
        '';

        dotDir = "${config.home.homeDirectory}/.config/zsh";

        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;

        plugins = [
          {
            name = "fzf-tab";
            src = pkgs.zsh-fzf-tab;
            file = "share/fzf-tab/fzf-tab.plugin.zsh";
          }
        ];

        defaultKeymap = "emacs";

        history.path = "$HOME/.cache/zsh/history";

        initContent = ''
          source "$ZDOTDIR/init.zsh"

          # pre-computed tool inits
          source ${zoxideInit}
          source ${direnvInit}
          source ${starshipInit}
          source ${nixYourShellInit}

          if [[ $options[zle] = on ]]; then
            source ${fzfInit}
            source ${atuinInit}
          fi
        '';

        localVariables = {
          WORDCHARS = "*?_-.~";
          NIXPKGS_ALLOW_UNFREE = "1";
        };

        shellAliases = {
          ":q" = "exit";

          ls = "eza --icons auto --color auto -F always";

          mv = "mv -i";
          cp = "cp -i";
          rm = "rm -i";

          t = "tmux";
          r = "rtmux";

          mmv = "noglob zmv -W";
          zmv = "noglob zmv";

          sshn = "ssh -F /dev/null -o PubkeyAuthentication=no";

          ws = "wezterm cli spawn -- ";

          # # is an extended-glob operator in zsh; disable globbing so flake
          # refs like nixpkgs#foo work without quoting
          nix = "noglob nix";
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          reboot-windows = "sudo systemctl reboot --boot-loader-entry=auto-windows";
        };
      };

      programs.zsh-abbr-lite = {
        enable = true;

        abbreviations = {
          # misc
          n = "nvim";
          j = "just";
          lg = "lazygit";

          # ls
          la = "ls -la";
          lah = "ls -lah";
          lt = "ls --tree";
          tree = "ls --tree";

          # git
          g = "git";
          ga = "git add";
          gb = "git branch";
          # cl = clone
          gcl = "git clone";
          # c = commit
          gc = "git commit";
          gca = "git commit -v --amend";
          gcan = "git commit -v --amend --no-edit";
          gcm = "git commit -m";
          gchp = "git cherry-pick";
          gd = "git diff";
          gds = "git diff --staged";
          gl = "git log";
          glg = "git lg";
          # m = merge
          gm = "git merge";
          gmc = "git merge --continue";
          gma = "git merge --abort";
          gms = "git merge --squash";
          # p = pull
          gp = "git pull";
          # P = push
          gP = "git push";
          gPf = "git push -f";
          # f = fetch
          gf = "git fetch";
          # s = status
          gs = "git status";
          # sh = show
          gsh = "git show";
          # sw = switch
          gsw = "git switch";
          gswc = "git switch -c";
          # st = stash
          gst = "git stash";
          # st = stash
          gstl = "git stash list";
          gstd = "git stash drop";
          gsta = "git stash apply";
          gstp = "git stash pop";
          # r = rebase
          gr = "git rebase -i";
          grc = "git rebase --continue";
          gra = "git rebase --abort";
          # rh = reset head
          grh = "git reset HEAD";
          grhh = "git reset --hard HEAD";
          # rt = restore
          grt = "git restore --staged";
          grtt = "git restore";

          # docker
          d = "docker";
          db = "docker build";
          de = "docker exec";
          di = "docker inspect";
          dl = "docker logs";
          dlf = "docker logs -f";
          dr = "docker run";
          ds = "docker stop";
          drm = "docker rm";
          dps = "docker ps";
          dpsa = "docker ps -a";
          dim = "docker images";

          # docker compose
          dcu = "docker compose up";
          dcub = "docker compose up --build";
          dcud = "docker compose up -d";
          dcudb = "docker compose up --build -d";
          dcd = "docker compose down";
          dce = "docker compose exec";
          dci = "docker compose inspect";
          dcl = "docker compose logs";
          dclf = "docker compose logs -f";
          dcr = "docker compose run";
          dcrs = "docker compose restart";
          dcs = "docker compose stop";
          dcrm = "docker compose rm";
          dcps = "docker compose ps";
          dcpsa = "docker compose ps -a";
          dcim = "docker compose images";
        };

        globalAbbreviations = {
          "..." = "../..";
          "...." = "../../..";
          "....." = "../../../..";
          "......" = "../../../../..";
          DO = "1>/dev/null";
          DE = "2>/dev/null";
          DA = ">/dev/null 2>&1";
          JQ = "| jq";
          C = "| pbcopy";
        };
      };

      xdg.configFile."zsh/init.zsh".source = ./cli/zsh/init.zsh;
    };
}
