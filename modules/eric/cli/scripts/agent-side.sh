#!/usr/bin/env bash
# opens another claude or pi in a tmux split beside the calling pane, for their /side commands

set -euo pipefail

die() {
  echo "side: $*"
  exit 1
}

if [[ ${1-} == -h || ${1-} == --help ]]; then
  cat <<EOF
Usage: agent-side claude [fork [QUESTION] | handoff DOC TASK | new]
       agent-side pi [fork SESSION [QUESTION] | handoff DOC TASK | new]

  fork              fork the conversation, sending QUESTION if given.
                    claude forks \$CLAUDE_CODE_SESSION_ID, pi opens the branched SESSION file
  handoff DOC TASK  a fresh agent that reads DOC, then does TASK
  new               a fresh agent with no history
EOF
  exit
fi

[[ -n ${TMUX-} ]] || die "needs an active tmux session"

split() {
  tmux split-window -h -t "${TMUX_PANE-}" -c "$PWD" "$1"
}

# the prompt travels through a file, so no quote in it can break the pane's command.
# the pane's shell deletes the file once it has read it
with_prompt() {
  local f
  f=$(mktemp /tmp/side-XXXXXX)
  printf '%s' "$2" >"$f"
  split "$1 \"\$(cat '$f'; rm -f '$f')\""
}

agent=${1-}
shift || true
# pi reads anything after -- as the prompt, even text that starts with a dash
case $agent in
claude) fresh="claude${CLAUDE_EFFORT:+ --effort $CLAUDE_EFFORT}" sep="" ;;
pi) fresh="pi" sep=" --" ;;
*) die "unknown agent '$agent', use 'claude' or 'pi'" ;;
esac

mode=${1:-fork}
shift || true

case $mode in
fork)
  if [[ $agent == claude ]]; then
    fork="claude --resume ${CLAUDE_CODE_SESSION_ID:?} --fork-session"
  else
    (($#)) || die "pi fork needs the branched session file"
    fork="pi --session $(printf %q "$1")"
    shift
  fi
  if (($#)); then with_prompt "$fork$sep" "$*"; else split "$fork"; fi
  echo "side: opened a fork in a tmux split"
  ;;
handoff)
  (($# >= 2)) || die "handoff needs a task, as in /side handoff <task>"
  doc=$1
  shift
  with_prompt "$fresh$sep" "Read $doc, then do this task: $*"
  echo "side: opened a handoff in a tmux split ($doc)"
  ;;
new)
  split "$fresh"
  echo "side: opened a new conversation in a tmux split"
  ;;
*) die "unknown mode '$mode', use 'fork', 'handoff', or 'new'" ;;
esac
