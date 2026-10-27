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

# nvim emits \e[2 q on teardown regardless of guicursor
# a terminal can keep that block cursor after the alt screen exits, as tmux does, so restore the bar at each prompt
precmd_cursor() {
  print -n '\e[6 q'
}

# OSC 133 marks each prompt and command, so tmux sees when a command ends and its exit status.
# tmux colours the tab from that (see tmux/alerts.conf), and the prompt's A clears rex's program status spinner
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

# a command that runs this long gets the bell and rex's done or failed mark.
# the run time is the prompt's _command_duration_ms (prompt/prompt.zsh). tmux keeps its own 10s (tmux/alerts.conf)
typeset -gi _long_command_ms=10000

# outside tmux, ring the bell after a long command, so wezterm marks its tab.
# rex shows no mark for a bell, and marks the tab from the program status below
precmd_bell() {
  [[ -z $TMUX ]] && ((${_command_duration_ms:-0} >= _long_command_ms)) && print -n '\a'
}

# OSC 7 reports the folder as a file:// url, so rex starts new panes and popups there.
# the url is built on each cd, percent-encoded byte by byte, and sent at each prompt,
# since a nested shell or ssh that exits leaves its own folder reported
chpwd_osc7() {
  local LC_ALL=C url= c i
  for ((i = 1; i <= $#PWD; i++)); do
    c=${PWD[i]}
    if [[ $c == [[:alnum:]/._~-] ]]; then
      url+=$c
    else
      printf -v c '%%%02X' "'$c"
      url+=$c
    fi
  done
  _osc7="\e]7;file://${HOST}${url}\a"
}
precmd_osc7() {
  print -n "$_osc7"
}
add-zsh-hook chpwd chpwd_osc7
add-zsh-hook precmd precmd_osc7
chpwd_osc7

# OSC 7501 program status: a spinner once a command has run 1s, then done or failed if it was long (_long_command_ms).
# the prompt's OSC 133 A drops the spinner, ctrl-c (130) leaves no mark, and the next command clears a mark.
# interactive programs, and agents that report their own status, are skipped
zmodload zsh/zselect
_status_skip=(nvim vim vi ssh mosh lazygit claude codex pi yazi y less man htop btop top tmux t rtmux rext fzf)
# words before the program, which the program name skips along with their options and X=y assignments
_status_prefix=(noglob nocorrect command builtin exec sudo time env nohup)
_status_send() {
  print -n "\e]7501;state=${1}:app=${2}:msg=$(print -rn -- "$3" | base64 | tr -d '\n')\e\\"
}
preexec_status() {
  # $2 has aliases expanded, so the nix alias arrives as noglob nix. $1 is the command as typed
  local word name=
  for word in ${(z)2}; do
    [[ $word == *=* || $word == -* ]] || ((${_status_prefix[(Ie)$word]})) && continue
    name=${word:t}
    break
  done
  ((_status_marked)) && print -n '\e]7501;state=clear\e\\'
  _status_marked=0 _status_cmd=
  ((${_status_skip[(Ie)$name]})) && return
  _status_app=${${name//[^A-Za-z0-9._-]/}[1,32]:-zsh}
  _status_cmd=${${1//[[:cntrl:]]/ }[1,200]}
  { zselect -t 100; _status_send working $_status_app $_status_cmd } &!
  _status_pid=$!
}
precmd_status() {
  local ret=$?
  [[ -n $_status_pid ]] && kill $_status_pid 2>/dev/null
  _status_pid=
  if [[ -n $_status_cmd ]] && ((ret != 130 && ${_command_duration_ms:-0} >= _long_command_ms)); then
    if ((ret)); then
      _status_send error $_status_app "$_status_cmd: failed ($ret)"
    else
      _status_send done $_status_app "$_status_cmd: ok"
    fi
    _status_marked=1
  fi
  _status_cmd=
}
add-zsh-hook preexec preexec_status
add-zsh-hook precmd precmd_status

add-zsh-hook preexec preexec_osc133
add-zsh-hook precmd precmd_osc133
add-zsh-hook precmd precmd_bell
add-zsh-hook preexec preexec_title
add-zsh-hook precmd precmd_title
add-zsh-hook precmd precmd_cursor
