autoload -Uz zmv

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

# the scratch script can't move this shell, so cd into the folder it makes, or out of the one it trashes
scratch() {
  if (($#)); then
    local here=$PWD
    command scratch "$@" || return
    [[ -d $here ]] || cd ~
    return
  fi
  local dir
  dir=$(command scratch) && cd "$dir" && print -r -- "scratch: created ${dir/#$HOME/~}"
}

# glow prints unwrapped, so the terminal reflows the text on resize
# only -w 0 does that, since width 0 in glow.yml means auto
# its pager (-p) and tui (-t, or no args) can't reflow, so they keep glow's own wrapping at the window width
glow() {
  local -a args=("$@")
  if (($# == 0 || ${args[(I)(-p|--pager|-t|--tui)]})); then
    command glow "$@"
  else
    command glow -w 0 "$@"
  fi
}

# the mvproj script can't move this shell, so follow the shell's folder when the move took it along
mvproj() {
  local here=$(pwd -P)
  command mvproj "$@" || return
  [[ $(pwd -P) == "$here" ]] || cd "$(pwd -P)"
}
