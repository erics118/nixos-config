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

# wrap direnv-instant's TRAPUSR1 to rebuild the prompt after it loads the env,
# and to auto-allow a fresh worktree whose .envrc matches its repo's (zsh.nix), reloading at once
if (($+functions[TRAPUSR1])); then
  functions[_prompt_direnv_TRAPUSR1]=$functions[TRAPUSR1]
  TRAPUSR1() {
    # direnv's routine status is silenced, so its stderr here is real errors; drop the
    # "is blocked" note (the segment's glyph already says that), keep the rest
    local -a _errs
    if [[ -n $__DIRENV_INSTANT_STDERR_FILE && -s $__DIRENV_INSTANT_STDERR_FILE ]]; then
      _errs=(${(f)"$(<$__DIRENV_INSTANT_STDERR_FILE)"})
      : >$__DIRENV_INSTANT_STDERR_FILE
      _errs=(${_errs:#*' is blocked. Run '*})
    fi
    # apply the env direnv-instant loaded
    [[ -n $__DIRENV_INSTANT_ENV_FILE && -f $__DIRENV_INSTANT_ENV_FILE ]] && eval "$(<$__DIRENV_INSTANT_ENV_FILE)"
    # auto-allow a fresh worktree matching its repo (never an explicit deny, 2), then reload
    local _auto=
    if [[ $__DIRENV_INSTANT_ALLOWED == 1 && -n $__DIRENV_INSTANT_CURRENT_DIR ]] \
      && (($+functions[_direnv_allow_worktree])) \
      && _direnv_allow_worktree $__DIRENV_INSTANT_CURRENT_DIR; then
      _direnv_hook
      _auto=1
    fi
    # a clean load redraws nothing, which is what avoids the new-shell double prompt (its
    # async redraw stacked under Rex). errors print above a freshly drawn prompt; auto-allow just redraws.
    if (($#_errs)) && zle; then
      _prompt_build
      zle .reset-prompt && zle -R
      zle -I
      print -rn -- $'\e8\e[J'
      print -rl -- $_errs
    elif [[ -n $_auto ]] && zle; then
      _prompt_build
      zle .reset-prompt && zle -R
    fi
    return 0
  }
fi

_prompt_fg continuation
PROMPT2="$REPLY$prompt_continuation%f "
add-zsh-hook preexec _prompt_preexec
precmd_functions=(_prompt_precmd $precmd_functions)
