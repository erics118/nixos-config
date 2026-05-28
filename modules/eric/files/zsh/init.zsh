setopt auto_menu
setopt complete_in_word
setopt always_to_end
setopt extended_glob
setopt auto_pushd
setopt pushd_ignore_dups
setopt pushdminus
setopt autocd
setopt interactive_comments
setopt no_beep

autoload -Uz edit-command-line
autoload -Uz zmv

# prevent glob expansion of URLs and other special chars
autoload -Uz bracketed-paste-magic url-quote-magic
zle -N bracketed-paste bracketed-paste-magic
zle -N self-insert url-quote-magic

stty -ixon 2>/dev/null
bindkey '^Q' push-line-or-edit

hash -d n="$HOME/nixos-config"
hash -d v="$HOME/nixvim"
hash -d d="$HOME/dev"

clipboard-copy() {
  if (($+commands[pbcopy])) && [[ $(command -v pbcopy) != *shell_functions* ]]; then
    command pbcopy
  elif (($+commands[wl - copy])); then
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
  if (($+commands[pbpaste])) && [[ $(command -v pbpaste) != *shell_functions* ]]; then
    command pbpaste
  elif (($+commands[wl - paste])); then
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
ZSH_HIGHLIGHT_STYLES[path]="fg=none"
ZSH_HIGHLIGHT_STYLES[path_prefix]="fg=none"
ZSH_HIGHLIGHT_STYLES[path_pathseparator]="none"
ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]="none"
ZSH_HIGHLIGHT_STYLES[autodirectory]="fg=none"
ZSH_HIGHLIGHT_STYLES[autodirectory_prefix]="fg=none"

# ctrl-X ase leader for custom widgets
bindkey '^Xc' copy-command-line
bindkey '^Xd' copy-working-directory
bindkey '^Xe' edit-command-line
bindkey '^Xl' clear-scrollback
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
preexec_title() {
  print -Pn "\e]0;%n@%m: %~ - $1\a"
}

precmd_title() {
  print -Pn "\e]0;%n@%m: %~\a"
}

add-zsh-hook preexec preexec_title
add-zsh-hook precmd precmd_title
