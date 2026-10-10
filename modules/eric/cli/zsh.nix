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
      # zsh -n fails the build on an init zsh can't parse
      mkInit =
        name: script:
        pkgs.runCommand "${name}-init.zsh" { } ''
          export HOME="$TMPDIR/home"
          export XDG_CONFIG_HOME="$HOME/.config"
          export XDG_CACHE_HOME="$HOME/.cache"
          mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
          {
            ${script}
          } > $out
          ${lib.getExe pkgs.zsh} -n $out
        '';
      starship = lib.getExe pkgs.starship;

      # without a right_format, RPROMPT would run starship at every prompt to print nothing
      noRightPrompt = !config.programs.starship.settings ? right_format;

      # init lines that run starship, replaced with values computed here
      bakedLines = [ "^PROMPT2=" ] ++ lib.optional noRightPrompt "^RPROMPT=";

      starshipInit = mkInit "starship" ''
        # STARSHIP_SHELL makes it wrap escapes in %{ %}, as it does when zsh runs it
        export STARSHIP_CONFIG=${./starship/starship.toml} STARSHIP_SHELL=zsh
        init=$(${starship} init zsh --print-full-init)
        # each baked line must appear exactly once, so a change in starship's init fails the build
        for re in ${lib.escapeShellArgs bakedLines}; do
          [ "$(grep -c -e "$re" <<<"$init")" = 1 ] || { echo "starship init: expected one $re line" >&2; exit 1; }
        done
        grep -v ${lib.concatMapStringsSep " " (re: "-e ${lib.escapeShellArg re}") bakedLines} <<<"$init"
        printf 'PROMPT2=%q\n' "$(${starship} prompt --continuation)"
        ${lib.optionalString noRightPrompt "echo RPROMPT="}
      '';

      zoxideInit = mkInit "zoxide" "${pkgs.zoxide}/bin/zoxide init zsh";

      direnvInit = mkInit "direnv" "${pkgs.direnv}/bin/direnv hook zsh";

      nixYourShellInit = mkInit "nix-your-shell" "${pkgs.nix-your-shell}/bin/nix-your-shell zsh";

      fzfInit = mkInit "fzf" "${pkgs.fzf}/bin/fzf --zsh";

      atuinInit = mkInit "atuin" "${pkgs.atuin}/bin/atuin init zsh --disable-ai";
    in
    {
      home.sessionVariables.COLORTERM = "truecolor";

      # exported so ad-hoc `nix shell --impure nixpkgs#<unfree>` evaluates. flake
      # refs ignore it without --impure
      home.sessionVariables.NIXPKGS_ALLOW_UNFREE = "1";

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
          # compiled to a per-shell file and renamed, so a shell starting at the same
          # moment never reads a half-written .zwc
          zmodload -F zsh/files b:zf_mv
          _compdump_compile() {
            zcompile -R -- "$ZSH_COMPDUMP.$$.zwc" "$ZSH_COMPDUMP" 2>/dev/null \
              && zf_mv -f "$ZSH_COMPDUMP.$$.zwc" "$ZSH_COMPDUMP.zwc"
          }
          if (( ''${_dump[1]:-0} < ''${_gen[1]:-1} )); then
            # compinit skips rewriting an unchanged dump, which would leave it older than
            # the generation and rebuild it at every start
            command rm -f "$ZSH_COMPDUMP"
            compinit -d "$ZSH_COMPDUMP"
            _compdump_compile
          else
            compinit -C -d "$ZSH_COMPDUMP"
            [[ -s "$ZSH_COMPDUMP.zwc" && "$ZSH_COMPDUMP" -ot "$ZSH_COMPDUMP.zwc" ]] || _compdump_compile
          fi
          unset _gen _dump
          unfunction _compdump_compile
        '';

        dotDir = "${config.home.homeDirectory}/.config/zsh";

        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;

        defaultKeymap = "emacs";

        history.path = "$HOME/.cache/zsh/history";

        initContent = lib.mkMerge [
          # sourced at home-manager's plugin slot (900), after compinit and autosuggestions.
          # programs.zsh.plugins would also put the plugin's dir on PATH
          (lib.mkOrder 900 "source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh")
          ''
            source "$ZDOTDIR/init.zsh"

            # pre-computed tool inits
            source ${zoxideInit}
            source ${direnvInit}
            source ${starshipInit}
            source ${nixYourShellInit}

            if [[ $options[zle] = on ]]; then
              source ${fzfInit}
              # atuin's init runs `atuin uuid` unless this shell level already has a session
              # a UUIDv7 built here in the same 32-hex format skips that process
              if [[ -z $ATUIN_SESSION || $ATUIN_SHLVL != $SHLVL ]]; then
                zmodload zsh/datetime
                typeset -i _atuin_ms=$(( EPOCHREALTIME * 1000 ))
                printf -v ATUIN_SESSION '%012x7%03x%x%03x%04x%04x%04x' $_atuin_ms \
                  $(( RANDOM & 4095 )) $(( 8 + (RANDOM & 3) )) $(( RANDOM & 4095 )) $RANDOM $RANDOM $RANDOM
                export ATUIN_SESSION ATUIN_SHLVL=$SHLVL
                unset _atuin_ms
              fi
              source ${atuinInit}
            fi
          ''
        ];

        localVariables = {
          WORDCHARS = "*?_-.~";
        };

        shellAliases = {
          ":q" = "exit";

          ls = "eza";

          mv = "mv -i";
          cp = "cp -i";
          rm = "rm -i";

          r = "rtmux";
          "?" = "noglob ask";

          mmv = "noglob zmv -W";
          zmv = "noglob zmv";

          # ssh with forced password auth
          sshn = "ssh -o PubkeyAuthentication=no -o PreferredAuthentications=keyboard-interactive,password";

          ws = "wezterm cli spawn -- ";

          scc = "scc --no-cocomo";

          # flake refs can carry glob characters, like ? in github:owner/repo?ref=main
          nix = "noglob nix";
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          reboot-windows = "sudo systemctl reboot --boot-loader-entry=auto-windows";
        };
      };

      programs.zsh-abbr-lite = {
        enable = true;

        commandPrefixWords = [
          "noglob"
          "time"
          "sudo"
          "command"
          "builtin"
        ];

        abbreviations = {
          # misc
          n = "nvim";
          j = "just";
          lg = "lazygit";

          # ai
          c = "claude";
          cr = "claude --resume";

          p = "pi";
          pr = "pi resume";

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

      xdg.configFile."zsh/init.zsh".source = ./zsh/init.zsh;
    };
}
