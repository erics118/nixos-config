{
  flake.modules.homeManager.base =
    { config, pkgs, ... }:
    {
      programs.zsh = {
        enable = true;
        enableCompletion = true;
        dotDir = "${config.home.homeDirectory}/.config/zsh";

        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;

        defaultKeymap = "emacs";

        autocd = false;

        history.path = "$HOME/.cache/zsh/history";

        plugins = [
          # allows using nix-shell with zsh
          {
            name = "zsh-nix-shell";
            file = "nix-shell.plugin.zsh";
            src = pkgs.fetchFromGitHub {
              owner = "chisui";
              repo = "zsh-nix-shell";
              rev = "v0.8.0";
              sha256 = "1lzrn0n4fxfcgg65v0qhnj7wnybybqzs4adz7xsrkgmcsr0ii8b7";
            };
          }
        ];

        initContent = ''
          # don't highlight path separators
          ZSH_HIGHLIGHT_STYLES[path_pathseparator]="none"
          ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]="none"

          # opt-left
          bindkey "^[[1;3D" backward-word
          # opt-right
          bindkey "^[[1;3C" forward-word
          # ctrl-left
          bindkey "^[[1;5D" beginning-of-line
          # ctrl-right
          bindkey "^[[1;5C" end-of-line

          # shell title hooks
          preexec_title() {
            print -Pn "\e]0;%n@%m: %~ - $1\a"
          }

          precmd_title() {
            print -Pn "\e]0;%n@%m: %~\a"
          }

          add-zsh-hook preexec preexec_title
          add-zsh-hook precmd precmd_title

          # api keys from sops-nix decrypted secrets
          # _nia_key_file="$HOME/.config/sops-nix/secrets/api/nia"
          # [[ -r "$_nia_key_file" ]] && export NIA_API_KEY="$(<"$_nia_key_file")"
          # unset _nia_key_file
        '';

        localVariables = {
          WORDCHARS = "*?_-.~";

          # zsh abbr
          ABBR_SET_LINE_CURSOR = "1";
          ABBR_SET_EXPANSION_CURSOR = "1";

          ABBR_LINE_CURSOR_MARKER = "{{}}";
          ABBR_EXPANSION_CURSOR_MARKER = "{{}}";

          ABBR_GET_AVAILABLE_ABBREVIATION = "1";
          ABBR_LOG_AVAILABLE_ABBREVIATION = "1";
        };

        shellAliases = {
          ls = "eza";

          n = "nvim";
          c = "bat";

          mv = "mv -i";
          cp = "cp -i";
          rm = "rm -i";

          sshn = "ssh -F /dev/null -o PubkeyAuthentication=no";

          j = "just";
        };

        zsh-abbr = {
          enable = true;
          abbreviations = {
            # git
            g = "git";
            ga = "git add";
            gb = "git branch";
            gc = "git commit";
            gca = "git commit -v --amend";
            gcb = "git checkout -b";
            gcl = "git clone";
            gcm = "git commit -m \"{{}}\"";
            gco = "git checkout";
            gchp = "git cherry-pick";
            gd = "git diff";
            gds = "git diff --staged";
            gl = "git log";
            glg = "git lg";
            gm = "git merge";
            gmc = "git merge --continue";
            gma = "git merge --abort";
            gms = "git merge --squash";
            gP = "git pull";
            gp = "git push";
            gpf = "git push -f";
            gs = "git status";
            gsw = "git switch";
            gst = "git stash";
            gstl = "git stash list";
            gstd = "git stash drop";
            gsta = "git stash apply";
            gstp = "git stash pop";
            gr = "git rebase -i";
            grc = "git rebase --continue";
            gra = "git rebase --abort";
            grh = "git reset HEAD";
            grhh = "git reset --hard HEAD";

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

            # ls
            la = "ls -la";
            lah = "ls -lah";
            lt = "ls --tree";
            tree = "ls --tree";

            lg = "lazygit";
          };

          globalAbbreviations = {
            "..." = "../..";
            "...." = "../../..";
          };
        };
      };

      # Force overwrite zsh-abbr user-abbreviations file
      xdg.configFile."zsh-abbr/user-abbreviations".force = true;
    };
}
