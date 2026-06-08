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
        settings = {
          user = {
            name = "erics118";
            email = "52634785+erics118@users.noreply.github.com";
            signingkey = "~/.ssh/id_ed25519_github_erics118.pub";
          };
          init.defaultBranch = "main";
          color.ui = "auto";
          core = {
            pager = "delta";
            editor = "nvim";
            ignorecase = false;
          };
          interactive = {
            diffFilter = "delta --color-only";
          };
          delta = {
            navigate = true;
            dark = true;
          };
          pull.ff = "only";
          push = {
            autoSetupRemote = true;
            autoSetupMerge = true;
          };
          commit.gpgsign = true;
          gpg = {
            format = "ssh";
            ssh.program = lib.mkIf isDarwin "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
          };
          merge = {
            conflictStyle = "zdiff3";
          };
          mergetool.prompt = false;
          filter.lfs = {
            smudge = "git-lfs smudge -- %f";
            process = "git-lfs filter-process";
            required = true;
            clean = "git-lfs clean -- %f";
          };
          alias = {
            tokei = "!tokei --vcs=git";
            lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
            change-commits = ''!f() { VAR=$1; OLD=$2; NEW=$3; shift 3; git filter-branch --env-filter "if [[ \"$`echo $VAR`\" = '$OLD' ]]; then export $VAR='$NEW'; fi" $@; }; f'';
          };
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
