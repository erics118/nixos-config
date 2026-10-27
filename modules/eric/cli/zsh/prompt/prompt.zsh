# the zsh prompt, drawn by zsh itself with no process per prompt.
# config.zsh says what it shows, segments.zsh draws each part.
# git state comes from gitstatusd, a daemon that answers a query in about a millisecond

zmodload zsh/datetime
source ${0:h}/config.zsh
source ${0:h}/segments.zsh

# counts every change, so a deletion can be told from a modification
gitstatus_start -s -1 -u -1 -c -1 -d -1 PROMPT

# the last command's start time, exit status and run time, which the segments read.
# _command_duration_ms is the shell's one measure of a command, which terminal.zsh's hooks read too
typeset -g _command_start= _command_duration_ms=
typeset -gi _prompt_status=0

_prompt_preexec() {
  _command_start=$EPOCHREALTIME
}

# put before every other precmd hook, so the duration leaves out their time and is set when they run
_prompt_precmd() {
  _prompt_status=$?
  _command_duration_ms=
  if [[ -n $_command_start ]]; then
    _command_duration_ms=$(((EPOCHREALTIME - _command_start) * 1000))
    _command_start=
  fi
  _prompt_build
}

_prompt_build() {
  gitstatus_query -t 0.2 -d $PWD PROMPT || VCS_STATUS_RESULT=
  local start line1
  _prompt_fg separator
  start=$REPLY
  _prompt_render "$start$prompt_separator%f" $prompt_line1
  line1=$REPLY
  _prompt_render ' ' $prompt_line2
  # \e7 saves the cursor where the prompt begins, so output can replace the prompt (see TRAPUSR1)
  PROMPT=$'%{\e7%}\n'"$start$prompt_line1_start%f$line1"$'\n'"$start$prompt_line2_start%f$REPLY "
}

# direnv-instant's TRAPUSR1 would print direnv's output after the shown prompt and leave two.
# this prints it in place of the prompt instead, and rebuilds so the direnv segment is current.
# __DIRENV_INSTANT_STDERR_FILE is direnv-instant's own (its hooks/zsh.sh)
if (($+functions[TRAPUSR1])); then
  functions[_prompt_direnv_TRAPUSR1]=$functions[TRAPUSR1]
  TRAPUSR1() {
    # direnv's export runs inside this call, so a local named like an exported variable
    # (out, for one, in a nix shell) would take its value. hence the prefixed name
    local _prompt_direnv_out=
    if zle && [[ -s $__DIRENV_INSTANT_STDERR_FILE ]]; then
      _prompt_direnv_out=$(<$__DIRENV_INSTANT_STDERR_FILE)
      : >$__DIRENV_INSTANT_STDERR_FILE
    fi
    _prompt_direnv_TRAPUSR1 "$@"
    _prompt_build
    if [[ -n $_prompt_direnv_out ]]; then
      # a redraw first saves the cursor (\e7 in PROMPT) where the prompt starts now, after any scroll.
      # zle -I makes zle redraw the prompt wherever the cursor is when the trap ends.
      # \e8 returns to where the prompt began and \e[J clears from there down
      zle .reset-prompt && zle -R
      zle -I
      print -rn -- $'\e8\e[J'
      print -r -- $_prompt_direnv_out
    else
      zle && zle .reset-prompt && zle -R
    fi
    # a nonzero return would make zsh act as if interrupted
    return 0
  }
fi

_prompt_fg continuation
PROMPT2="$REPLY$prompt_continuation%f "
add-zsh-hook preexec _prompt_preexec
precmd_functions=(_prompt_precmd $precmd_functions)
