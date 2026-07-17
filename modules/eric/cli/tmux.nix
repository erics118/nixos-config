{
  flake.modules.homeManager.base =
    { pkgs, ... }:
    {
      programs.tmux = {
        enable = true;
        # socket under /run instead of /tmp; darwin has no XDG_RUNTIME_DIR so
        # scope to linux, else tmux points at a nonexistent /run/user dir
        secureSocket = pkgs.stdenv.hostPlatform.isLinux;
        extraConfig = ''
          # default is "screen", which only advertises 8 colors
          set -g default-terminal "tmux-256color"
          # pass truecolor and OSC 52 clipboard through to programs inside tmux;
          # terminfo here lacks the Ms cap, so assert clipboard support explicitly
          set -ag terminal-features ",xterm-256color:RGB:clipboard"

          # prefix C-a
          unbind C-b
          set -g prefix C-a
          bind C-a send-prefix

          set -g mouse on
          set -g history-limit 100000

          # start window and pane numbering at 1
          set -g base-index 1
          setw -g pane-base-index 1

          # vi keys
          set -g status-keys vi
          set -g mode-keys vi

          # let nvim autoread files changed outside tmux
          set -g focus-events on
          # size windows to the largest client viewing them, not the smallest attached
          setw -g aggressive-resize on

          # keep window numbers gapless when one is closed
          set -g renumber-windows on

          # auto-name each window after its current directory
          setw -g automatic-rename on
          setw -g automatic-rename-format '#{b:pane_current_path}'

          # show tmux messages long enough to read
          set -g display-time 4000

          # yank in copy-mode reaches the system clipboard via OSC 52
          set -g set-clipboard on
          bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel

          # repeatable window switching: hold ctrl, tap prefix then p/n
          bind C-p previous-window
          bind C-n next-window
          # quick toggle to the last window
          bind a last-window
        '';
      };
    };
}
