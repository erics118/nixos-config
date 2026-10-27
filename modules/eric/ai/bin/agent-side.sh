#!/usr/bin/env bash
# opens another claude or pi in a tmux or rex split beside the calling pane, for their /side commands

set -euo pipefail

die() {
  echo "side: $*"
  exit 1
}

if [[ ${1-} == -h || ${1-} == --help ]]; then
  cat <<EOF
Usage: agent-side.sh claude [fork [QUESTION] | handoff DOC TASK | new [PROMPT]]
       agent-side.sh pi [fork SESSION [QUESTION] | handoff DOC TASK | new [PROMPT]]

  fork              fork the conversation, sending QUESTION if given.
                    claude forks \$CLAUDE_CODE_SESSION_ID, pi opens the branched SESSION file
  handoff DOC TASK  a fresh agent that reads DOC, then does TASK
  new               a fresh agent with no history, sending PROMPT if given
EOF
  exit
fi

# tmux first, since a tmux inside a rex terminal owns the pane
if [[ -n ${TMUX-} ]]; then
  where=tmux
elif [[ -n ${REX_BLOCK-} ]]; then
  where=rex
else
  die "needs an active tmux session or a rex terminal"
fi

# $1 is a shell command line, which tmux runs through its default shell and rex through sh -c
split() {
  if [[ $where == tmux ]]; then
    tmux split-window -h -t "${TMUX_PANE-}" -c "$PWD" "$1"
  else
    rex split --block "$REX_BLOCK" --split=right --cwd "$PWD" -- sh -c "$1" >/dev/null
  fi
}

# the prompt travels through a file, so no quote in it can break the pane's command.
# the pane's shell deletes the file once it has read it
with_prompt() {
  local f
  f=$(mktemp /tmp/side-XXXXXX)
  printf '%s' "$2" >"$f"
  split "$1 \"\$(cat '$f'; rm -f '$f')\"" || {
    rm -f "$f"
    die "could not open a $where split"
  }
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
    [[ -n ${CLAUDE_CODE_SESSION_ID-} ]] || die "claude fork needs CLAUDE_CODE_SESSION_ID, which claude sets"
    fork="claude --resume $CLAUDE_CODE_SESSION_ID --fork-session"
  else
    (($#)) || die "pi fork needs the branched session file"
    printf -v fork 'pi --session %q' "$1"
    shift
  fi
  if (($#)); then with_prompt "$fork$sep" "$*"; else split "$fork" || die "could not open a $where split"; fi
  echo "side: opened a fork in a $where split"
  ;;
handoff)
  (($# >= 2)) || die "handoff needs a task, as in /side handoff <task>"
  doc=$1
  shift
  with_prompt "$fresh$sep" "You were opened with /side from another agent's session. Read $doc, which that agent wrote: treat its claims as notes to check, not as facts from me. Then do this task: $*"
  echo "side: opened a handoff in a $where split ($doc)"
  ;;
new)
  if (($#)); then with_prompt "$fresh$sep" "$*"; else split "$fresh" || die "could not open a $where split"; fi
  echo "side: opened a new conversation in a $where split"
  ;;
*) die "unknown mode '$mode', use 'fork', 'handoff', or 'new'" ;;
esac
