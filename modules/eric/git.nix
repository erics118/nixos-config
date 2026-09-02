{
  flake.modules.homeManager.base =
    { pkgs, lib, ... }:

    let
      inherit (pkgs.stdenv.hostPlatform) isDarwin;
    in
    {
      programs.git = {
        enable = true;
        ignores = [
          # general
          "*~"
          "*.sw?"
          # macos
          ".DS_Store"
          ".localized"
          "__MACOSX/"
          ".AppleDouble"
          "._*"
          ".LSOverride"
          "Icon\r"
          "*.icloud"
          # windows
          "Thumbs.db"
          "ehthumbs.db"
          "Desktop.ini"
          # claude
          "**/.claude/*.local.*"
          "**/.claude/worktrees/"
          "CLAUDE.local.md"
          # nix
          ".direnv/"
          ".devenv/"
          # misc
          ".cache/"
          # env
          ".env"
          ".env.*"
          "!.env.example"
          ".antigravitycli"
        ];
        lfs = {
          enable = true;
        };
        settings = {
          user = {
            name = "erics118";
            email = "52634785+erics118@users.noreply.github.com";
            signingkey = "~/.ssh/id_ed25519_github_erics118.pub";
          };
          init.defaultBranch = "main";
          color.ui = "auto";
          # explicit CA bundle so git's OpenSSL works even when the
          # NIX_SSL_CERT_FILE env var is stripped (e.g. by homebrew)
          http.sslCAInfo = lib.mkIf isDarwin "/etc/ssl/certs/ca-certificates.crt";
          core = {
            editor = "nvim";
            ignorecase = false;
          };
          pull.ff = "only";
          push = {
            autoSetupRemote = true;
            autoSetupMerge = true;
          };
          fetch.prune = true;
          rerere.enabled = true;
          rebase.autoStash = true;
          diff.colorMoved = "zebra";
          commit.gpgsign = true;
          gpg = {
            format = "ssh";
            ssh.program = lib.mkIf isDarwin "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
          };
          merge = {
            conflictStyle = "zdiff3";
          };
          mergetool.prompt = false;
          alias = {
            tokei = "!tokei --vcs=git";
            lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
          };
        };
      };

      programs.delta = {
        enable = true;
        enableGitIntegration = true;
        options = {
          navigate = true;
          dark = true;
          syntax-theme = "Catppuccin Mocha";
          line-numbers = true;
          hyperlinks = true;
        };
      };

      programs.gh = {
        enable = true;
        gitCredentialHelper.enable = true;
        settings = {
          git_protocol = "ssh";
          aliases = {
            co = "pr checkout";
          };
        };
        extensions = with pkgs; [
          gh-dash
          gh-markdown-preview
          gh-notify
          gh-skyline
        ];
      };
    };
}
