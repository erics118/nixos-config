{ pkgs, ... }:

{
  programs.git = {
    enable = true;
    ignores = [
      "*~"
      "*.swp"
      ".DS_Store"
    ];
    settings = {
      user = {
        name = "erics118";
        email = "ericshen118@gmail.com";
      };
      alias = {
        tokei = "!tokei --vcs=git";
        lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      };
    };
  };

  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
    settings = {
      git_protocol = "ssh";
    };
    extensions = [
      pkgs.gh-dash
    ];
  };
}
