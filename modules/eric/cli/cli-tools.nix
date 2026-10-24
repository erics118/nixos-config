{
  flake.modules.homeManager.base =
    {
      config,
      repoFile,
      lib,
      pkgs,
      ...
    }:
    {
      programs.zoxide = {
        enable = true;
        enableZshIntegration = false; # pre-computed in zsh.nix
      };

      programs.nix-your-shell = {
        enable = true;
        enableZshIntegration = false; # pre-computed in zsh.nix
      };

      programs.fzf = {
        enable = true;
        enableZshIntegration = false; # pre-computed in zsh.nix
        # a script keeps the preview's own quoting out of FZF_DEFAULT_OPTS, which
        # home-manager exports inside unescaped double quotes
        # zsh/init.zsh copies this preview for fzf-tab
        defaultOptions = [
          "--preview='${pkgs.writeShellScript "fzf-preview" ''
            if [ -f "$1" ]; then
              bat --color=always --style=numbers --line-range=:500 --terminal-width="$FZF_PREVIEW_COLUMNS" -- "$1"
            elif [ -d "$1" ]; then
              eza --tree --color=always --icons=always -- "$1"
            else
              printf '%s\n' "$1"
            fi
          ''} {}'"
          "--tabstop=4"
        ];
        historyWidget.command = "";
      };

      programs.atuin = {
        enable = true;
        enableZshIntegration = false; # pre-computed in zsh.nix
        forceOverwriteSettings = true;
        settings = {
          enter_accept = true;
          history_filter = [
            "^\\?"
            # literal secrets, while $VAR and $(...) references still get saved
            "(?i)\\b\\w*(token|key|secret|passw(or)?d)=['\"]?[^$\\s'\"(]"
            "(?i)(authorization|cookie):\\s*(bearer\\s+|basic\\s+|token\\s+)?['\"]?[^$\\s'\"]"
            "(?i)\\bbearer\\s+[A-Za-z0-9._~+/=-]{12,}"
            # a JWT anywhere, like a token passed as a plain argument
            "eyJ[A-Za-z0-9_-]{10,}\\.eyJ"
          ];
          filter_mode_shell_up_key_binding = "session";
          prefers_reduced_motion = true;
          records = true;
          stats = {
            common_subcommands = [
              "apt"
              "cargo"
              "docker"
              "git"
              "go"
              "kubectl"
              "nix"
              "npm"
              "pnpm"
              "podman"
              "port"
              "systemctl"
              "tmux"
              "yarn"
              "dune"
              "just"
              "npx"
            ];
            common_prefix = [ "sudo" ];
            command_aliases = {
              "dune te" = "dune runtest";
              "dune test" = "dune runtest";
              "dune b" = "dune build";
              "k" = "killall";
              "sshn" = "ssh";
              "npm i" = "npm install";
              "cargo b" = "cargo build";
            };
          };
        };
      };

      programs.eza = {
        enable = true;
        # these generate the `eza` alias, and zsh.nix points ls at it
        colors = "auto";
        icons = "auto";
        extraOptions = [
          "-F"
          "auto"
        ];
        # disable the ls/ll/la aliases, as ls is set up manually
        enableZshIntegration = false;
      };

      # build/project files only bold and yellow
      home.sessionVariables.EZA_COLORS = "bu=1;33";

      programs.tealdeer = {
        enable = true;
        settings = {
          display = {
            compact = false;
            use_pager = false;
            show_title = true;
          };
          updates.auto_update = true;
        };
      };

      # home-manager writes tealdeer's config to Application Support on darwin, but tealdeer reads ~/.config
      xdg.configFile."tealdeer/config.toml" = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        inherit (config.home.file."Library/Application Support/tealdeer/config.toml") source;
      };

      programs.jq.enable = true;

      programs.ripgrep.enable = true;

      programs.fd.enable = true;

      # macOS ships /usr/bin/trash
      home.packages = lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.trash-cli;

      programs.bat = {
        enable = true;
        config = {
          style = "changes";
          italic-text = "always";
          tabs = "4";
          paging = "never";
          theme = lib.mkForce "Catppuccin Mocha Nvim";
        };
        # catppuccin mocha with nvim's italics, LineNr gutter, and render-markdown colors
        # yazi/theme.toml points its syntect theme at this file
        themes."Catppuccin Mocha Nvim".src =
          pkgs.runCommand "catppuccin-mocha-nvim.tmTheme" { nativeBuildInputs = [ pkgs.python3 ]; }
            ''
              python3 - "${config.catppuccin.sources.bat}/Catppuccin Mocha.tmTheme" "$out" <<'EOF'
              import plistlib, sys
              with open(sys.argv[1], "rb") as f:
                  theme = plistlib.load(f)
              theme["name"] = "Catppuccin Mocha Nvim"
              theme["settings"][0]["settings"]["gutterForeground"] = "#45475a"
              for rule in theme["settings"][1:]:
                  style = rule.get("settings", {})
                  words = style.get("fontStyle", "").split()
                  scope = rule.get("scope", "")
                  if "italic" in words and "comment" not in scope and "markup.italic" not in scope:
                      style["fontStyle"] = " ".join(w for w in words if w != "italic")
              # bat's markdown grammar puts heading text in entity.name.section, which the theme's entity.name rule turns teal
              # the more specific selectors below win over it
              heading = "markup.heading{0} entity.name.section, markup.heading{0} punctuation.definition.heading"
              markdown = [
                  (heading.format(""), {"foreground": "#f9e2af"}),
                  (heading.format(".1"), {"foreground": "#f38ba8"}),
                  (heading.format(".2"), {"foreground": "#fab387"}),
                  ("markup.raw.inline, markup.raw.inline punctuation.definition.raw", {"foreground": "#a6e3a1"}),
                  ("punctuation.definition.list_item.markdown", {"foreground": "#94e2d5"}),
                  ("markup.quote.markdown, punctuation.definition.blockquote.markdown", {"foreground": "#f5c2e7"}),
              ]
              theme["settings"] += [{"scope": scope, "settings": style} for scope, style in markdown]
              with open(sys.argv[2], "wb") as f:
                  plistlib.dump(theme, f)
              EOF
            '';
      };

      # glamour theme matching nvim's render-markdown colors, read by gh, glow, and yazi/yazi.toml
      home.file.".config/glow/catppuccin-mocha-nvim.json".source =
        repoFile "modules/eric/cli/glow/catppuccin-mocha-nvim.json";
      home.sessionVariables.GLAMOUR_STYLE = "${config.home.homeDirectory}/.config/glow/catppuccin-mocha-nvim.json";
      # glow's cli render ignores GLAMOUR_STYLE, which only its tui reads
      xdg.configFile."glow/glow.yml".text = ''
        style: "${config.home.sessionVariables.GLAMOUR_STYLE}"
      '';

      programs.btop = {
        enable = true;
        # cudaSupport only runs autoAddDriverRunpath so btop finds libnvidia-ml at
        # runtime for the gpu panel, it pulls in no cuda toolkit and stays cached
        package = pkgs.btop.override { cudaSupport = true; };
        settings = {
          vim_keys = true;
          rounded_corners = true;
          theme_background = true;
          truecolor = true;
        };
      };
    };
}
