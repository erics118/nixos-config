setopt auto_menu
setopt complete_in_word
setopt always_to_end
setopt auto_pushd
setopt pushd_ignore_dups
setopt pushdminus
setopt autocd
setopt interactive_comments
setopt no_beep

autoload -Uz edit-command-line
autoload -Uz zmv

# fzf-tab
# disable zsh's own menu so fzf-tab can capture the completion
zstyle ':completion:*' menu no
# group headers and colorized listings
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ''
# preview files/dirs in the fzf popup, matching the default fzf preview
zstyle ':fzf-tab:complete:*' fzf-preview \
  'if [ -f "$realpath" ]; then bat --color=always --style=numbers --line-range=:500 -- "$realpath"; elif [ -d "$realpath" ]; then eza --tree --color=always --icons=always -- "$realpath"; fi'
# switch completion groups with < and >
zstyle ':fzf-tab:*' switch-group '<' '>'
# drop the leading dot marker on each entry
zstyle ':fzf-tab:*' prefix ''
# tab confirms the selection
zstyle ':fzf-tab:*' fzf-bindings 'tab:accept'

# prevent glob expansion of URLs and other special chars
autoload -Uz bracketed-paste-magic url-quote-magic
zle -N bracketed-paste bracketed-paste-magic
zle -N self-insert url-quote-magic

stty -ixon 2>/dev/null
bindkey '^Q' push-line-or-edit

hash -d n="$HOME/nixos-config"
hash -d p="$HOME/nixos-config-private"
hash -d d="$HOME/dev"

clipboard-copy() {
  if (($+commands[wl-copy])); then
    wl-copy
  elif (($+commands[xclip])); then
    xclip -selection clipboard
  elif (($+commands[xsel])); then
    xsel --clipboard --input
  else
    print -u2 "no clipboard tool found"
    return 1
  fi
}

clipboard-paste() {
  if (($+commands[wl-paste])); then
    wl-paste --no-newline
  elif (($+commands[xclip])); then
    xclip -selection clipboard -o
  elif (($+commands[xsel])); then
    xsel --clipboard --output
  else
    print -u2 "no clipboard tool found"
    return 1
  fi
}

if ! (($+commands[pbcopy])); then
  alias pbcopy='clipboard-copy'
fi

if ! (($+commands[pbpaste])); then
  alias pbpaste='clipboard-paste'
fi

sudo-command-line() {
  [[ -z $BUFFER ]] && zle up-history
  if [[ $BUFFER == sudo\ * ]]; then
    BUFFER="${BUFFER#sudo }"
  else
    BUFFER="sudo $BUFFER"
  fi
  zle end-of-line
}

clear-scrollback() {
  zle -I
  printf '\033[H\033[2J\033[3J'
  zle redisplay
}

copy-command-line() {
  print -rn -- "$BUFFER" | pbcopy
}

copy-working-directory() {
  print -rn -- "$PWD" | pbcopy
}

zle -N edit-command-line
zle -N sudo-command-line
zle -N clear-scrollback
zle -N copy-command-line
zle -N copy-working-directory

# don't highlight path separators
typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[path]="fg=none"
ZSH_HIGHLIGHT_STYLES[path_prefix]="fg=none"
ZSH_HIGHLIGHT_STYLES[path_pathseparator]="none"
ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]="none"
ZSH_HIGHLIGHT_STYLES[autodirectory]="fg=none"
ZSH_HIGHLIGHT_STYLES[autodirectory_prefix]="fg=none"

# ctrl-X as leader for custom widgets
bindkey '^Xc' copy-command-line
bindkey '^Xd' copy-working-directory
bindkey '^Xe' edit-command-line
# tmux takes C-l for pane nav, so clearing lives here
bindkey '^Xl' clear-screen
bindkey '^XL' clear-scrollback
bindkey '^Xs' sudo-command-line

# explicit undo binding for terminals that send ^_
bindkey '^_' undo

bindkey '^X ' magic-space

# opt-left
bindkey "^[[1;3D" backward-word
# opt-right
bindkey "^[[1;3C" forward-word
# ctrl-left
bindkey "^[[1;5D" beginning-of-line
# ctrl-right
bindkey "^[[1;5C" end-of-line

# shell title hooks
# host prefix only when sshed and outside tmux; inside tmux this string is just
# the window name, and tmux adds the host to the outer title on its own
if [[ -n $SSH_CONNECTION && -z $TMUX ]]; then
  _title_host="%m: "
else
  _title_host=""
fi

preexec_title() {
  # prompt-expand only the prefix, so % and \ in the command print literally.
  # control chars such as newlines would end the escape sequence early
  print -Pn "\e]0;${_title_host}%~ - "
  print -rn -- "${1//[[:cntrl:]]/ }"
  print -n '\a'
}

precmd_title() {
  print -Pn "\e]0;${_title_host}%~\a"
}

# nvim emits \e[2 q on teardown regardless of guicursor; wezterm undoes it when
# the alt screen exits but tmux does not, so restore the bar at each prompt
precmd_cursor() {
  print -n '\e[6 q'
}

# OSC 133 marks each prompt and command, so tmux sees when a command ends and its exit status.
# tmux colours the tab from that (see tmux/tabline.conf)
preexec_osc133() {
  _osc133_ran=1
  print -n '\e]133;C\a'
}
precmd_osc133() {
  local ret=$?
  ((_osc133_ran)) && print -n "\e]133;D;$ret\a"
  _osc133_ran=0
  print -n '\e]133;A\a'
}

# outside tmux, ring the bell after a command that ran 10s or more, so wezterm marks its tab
zmodload zsh/datetime
preexec_bell() {
  _cmd_start=$EPOCHSECONDS
}
precmd_bell() {
  [[ -z $TMUX ]] && ((_cmd_start && EPOCHSECONDS - _cmd_start >= 10)) && print -n '\a'
  _cmd_start=0
}

add-zsh-hook preexec preexec_osc133
add-zsh-hook precmd precmd_osc133
add-zsh-hook preexec preexec_bell
add-zsh-hook precmd precmd_bell
add-zsh-hook preexec preexec_title
add-zsh-hook precmd precmd_title
add-zsh-hook precmd precmd_cursor

# cd into a fresh ~/dev/scratch folder, which mvproj NAME promotes to ~/dev/NAME.
# not mktemp: agents key sessions by folder, and macOS cleans /var/folders, which would break resuming them
scratch() {
  if (($#)); then
    local usage='Usage: scratch

  Make ~/dev/scratch/<date-time> and cd into it.
  From its top folder, mvproj NAME keeps it as ~/dev/NAME.'
    if [[ $1 == -h || $1 == --help ]]; then
      print -r -- $usage
      return
    fi
    print -ru2 -- $usage
    return 1
  fi
  local dir=~/dev/scratch/$(date +%Y-%m-%d-%H%M%S)
  mkdir -p "$dir" && cd "$dir" && print -r -- "scratch: created ${dir/#$HOME/~}"
}

# the mvproj script can't move this shell, so follow the shell's folder when the move took it along
mvproj() {
  local here=$(pwd -P)
  command mvproj "$@" || return
  [[ $(pwd -P) == "$here" ]] || cd "$(pwd -P)"
}

# herdr-automatic-rename names the herdr tab after each command as it starts.
# herdr runs it from the local clone linked with `herdr plugin link`
[[ -r ~/dev/herdr-automatic-rename/shell/hook.zsh ]] && source ~/dev/herdr-automatic-rename/shell/hook.zsh
