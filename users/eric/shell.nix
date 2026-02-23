{ ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    defaultKeymap = "emacs";

    autocd = false;

    initContent = ''
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

      cloc = "tokei";
      sshn = "ssh -F /dev/null -o PubkeyAuthentication=no";

      j = "just";
    };

    zsh-abbr = {
      enable = true;
      abbreviations = {
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
}
