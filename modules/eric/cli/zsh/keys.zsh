autoload -Uz edit-command-line

# prevent glob expansion of URLs and other special chars
autoload -Uz bracketed-paste-magic url-quote-magic
zle -N bracketed-paste bracketed-paste-magic
zle -N self-insert url-quote-magic

bindkey '^Q' push-line-or-edit

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

# ctrl-X as leader for custom widgets
bindkey '^Xc' copy-command-line
bindkey '^Xd' copy-working-directory
bindkey '^Xe' edit-command-line
# tmux takes C-l for pane nav, so clearing lives here
bindkey '^Xl' clear-screen
bindkey '^XL' clear-scrollback
bindkey '^Xs' sudo-command-line

# shift-enter adds a line to the command instead of running it. rex sends it as ^[[27;2;13~
insert-newline() {
  LBUFFER+=$'\n'
}
zle -N insert-newline
bindkey '^[[27;2;13~' insert-newline

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
