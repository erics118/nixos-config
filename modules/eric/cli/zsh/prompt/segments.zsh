# the segments the prompt and the claude statusline share, and the renderer that joins them.
# a segment _pseg_<name> sets REPLY to its text, or returns 1 to hide.
# segments only read variables, so each caller fills them its own way:
#   VCS_STATUS_* as gitstatusd names them, _prompt_status, _command_duration_ms

# a character by its unicode codepoint
_prompt_glyph() { REPLY=${(#):-$1} }

# the color escape for a segment or palette name, empty when it has none
_prompt_fg() {
  local c=${prompt_color[$1]:-$1}
  REPLY=
  [[ -n $prompt_palette[$c] ]] && REPLY="%F{$prompt_palette[$c]}"
}

# joins the shown segments with the separator in $1, each with its icon and color
_prompt_render() {
  local sep=$1 name text out=
  shift
  for name in "$@"; do
    _pseg_$name || continue
    text=$REPLY
    if [[ -n $prompt_icon[$name] ]]; then
      _prompt_glyph $prompt_icon[$name]
      text=$REPLY${text:+ $text}
    fi
    _prompt_fg $name
    [[ -n $REPLY ]] && text="$REPLY$text%f"
    ((${prompt_bold[(Ie)$name]})) && text="%B$text%b"
    out+=${out:+$sep}$text
  done
  REPLY=$out
}

# home as ~ and at most the last prompt_dir_parts parts, then a lock if it is read-only.
# %~ would use named directories such as ~n instead
_pseg_dir() {
  local d=${PWD/#$HOME/\~} lock
  local -a parts=(${(s:/:)d})
  if ((${#parts} > prompt_dir_parts)); then
    _prompt_glyph $prompt_icon[ellipsis]
    d="$REPLY/${(j:/:)parts[-prompt_dir_parts,-1]}"
  fi
  d=${d//\%/%%}
  if [[ ! -w $PWD ]]; then
    _prompt_glyph $prompt_icon[lock]
    lock=$REPLY
    _prompt_fg lock
    d+=" $REPLY$lock%f"
  fi
  REPLY=$d
}

_pseg_host() {
  [[ -n $SSH_CONNECTION$SSH_TTY ]] || return 1
  REPLY=%m
}

# branch, or HEAD and the commit when detached, then the state and status marks
_pseg_git() {
  [[ $VCS_STATUS_RESULT == ok-* ]] || return 1
  local text mark marks=
  if [[ -n $VCS_STATUS_LOCAL_BRANCH ]]; then
    text=$VCS_STATUS_LOCAL_BRANCH
  else
    text="HEAD ${VCS_STATUS_COMMIT[1,7]}${VCS_STATUS_TAG:+ $VCS_STATUS_TAG}"
  fi
  [[ -n $VCS_STATUS_ACTION ]] && text+=" ${(U)VCS_STATUS_ACTION}"
  local -A count=(
    conflicted $((VCS_STATUS_NUM_CONFLICTED))
    stashed $((VCS_STATUS_STASHES))
    deleted $((VCS_STATUS_NUM_STAGED_DELETED + VCS_STATUS_NUM_UNSTAGED_DELETED))
    modified $((VCS_STATUS_NUM_UNSTAGED - VCS_STATUS_NUM_UNSTAGED_DELETED))
    staged $((VCS_STATUS_NUM_STAGED))
    untracked $((VCS_STATUS_NUM_UNTRACKED))
  )
  for mark in $prompt_git_marks; do
    ((count[$mark] > 0)) && marks+=$prompt_git_symbol[$mark]
  done
  if ((VCS_STATUS_COMMITS_AHEAD && VCS_STATUS_COMMITS_BEHIND)); then
    marks+=$prompt_git_symbol[diverged]
  elif ((VCS_STATUS_COMMITS_AHEAD)); then
    marks+=$prompt_git_symbol[ahead]
  elif ((VCS_STATUS_COMMITS_BEHIND)); then
    marks+=$prompt_git_symbol[behind]
  fi
  REPLY="${text//\%/%%}${marks:+ $marks}"
}

# a check once direnv has loaded the nearest .envrc, a cross while it is blocked or denied, and a dash while it loads.
# DIRENV_DIR is the loaded folder after a dash, and direnv keeps an outer .envrc loaded when a nearer one is blocked
_pseg_direnv() {
  local d=$PWD
  while [[ -n $d && ! -e $d/.envrc ]]; do
    d=${d%/*}
  done
  if [[ -n $DIRENV_DIR && ( -z $d || $DIRENV_DIR == -$d ) ]]; then
    _prompt_glyph $prompt_icon[direnv_loaded]
  elif [[ -z $d ]]; then
    return 1
  # set by prompt.zsh's TRAPUSR1 from direnv's blocked message
  elif [[ $d == $_prompt_direnv_blocked ]]; then
    _prompt_glyph $prompt_icon[direnv_blocked]
  else
    REPLY=-
  fi
}

# a nix develop or nix-shell entered by hand. direnv's use flake sets IN_NIX_SHELL too
_pseg_nix() {
  [[ -n $IN_NIX_SHELL && -z $DIRENV_DIR ]] || return 1
  REPLY=
}

_pseg_shlvl() {
  ((SHLVL > 1)) || return 1
  REPLY="shlvl $SHLVL"
}

# 3s57ms, 1m2s3ms: every unit from the largest nonzero one down
_pseg_duration() {
  [[ -n $_command_duration_ms ]] || return 1
  local -i ms=_command_duration_ms
  local -i h=ms/3600000 m=ms/60000%60 s=ms/1000%60
  REPLY=
  ((h)) && REPLY+=${h}h
  ((h || m)) && REPLY+=${m}m
  ((h || m || s)) && REPLY+=${s}s
  REPLY+=$((ms % 1000))ms
}

# the exit code of a failed command, except ctrl-c (130)
_pseg_status() {
  ((_prompt_status && _prompt_status != 130)) || return 1
  REPLY=$_prompt_status
}

typeset -g _prompt_os=linux
if [[ $OSTYPE == darwin* ]]; then
  _prompt_os=macos
elif [[ -r /etc/os-release ]]; then
  _prompt_os=${${(M)${(f)"$(</etc/os-release)"}:#ID=*}#ID=}
  [[ -n $prompt_icon[$_prompt_os] ]] || _prompt_os=linux
fi

_pseg_os() {
  _prompt_glyph $prompt_icon[$_prompt_os]
}

# the prompt character, red after any failure
_pseg_char() {
  local color=
  ((_prompt_status)) && _prompt_fg char_error && color=$REPLY
  _prompt_glyph $prompt_icon[arrow]
  REPLY="%B${color}$REPLY${color:+%f}%b"
}
