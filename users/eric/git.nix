{ pkgs, lib, ... }:

let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
in
{
  programs.git = {
    enable = true;
    ignores = [
      "*~"
      "*.swp"
      ".DS_Store"
      ".AppleDouble"
      ".LSOverride"
      ".DocumentRevisions-V100"
      ".fseventsd"
      ".Spotlight-V100"
      ".TemporaryItems"
      ".Trashes"
      ".VolumeIcon.icns"
      "*.icloud"
      ".AppleDB"
      ".AppleDesktop"
      "Network Trash Folder"
      "Temporary Items"
      ".apdisk"
      "*.dSYM"
      ".cache/**"
      "cache/**"
      ".claude/*.local.*"
    ];
    settings = {
      user = {
        name = "erics118";
        email = "52634785+erics118@users.noreply.github.com";
        signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO2fRl3E9j8GZxoB3JMJoho4GWM6nY90Ob+bqxASZMrM";
      };
      init.defaultBranch = "main";
      color.ui = "auto";
      core = {
        editor = "nvim";
        ignorecase = false;
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
}
