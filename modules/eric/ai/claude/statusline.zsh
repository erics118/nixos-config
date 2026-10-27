# the claude and pi status lines, drawn with the zsh prompt's config and segments (cli/zsh/prompt).
# with no terminal gitstatusd cannot start, so one git status call fills its variables.
# an argument picks config.zsh's statusline_<name> list, as pi's statusline.ts passes pi

source ${XDG_CONFIG_HOME:-$HOME/.config}/zsh/conf/prompt/config.zsh
source ${XDG_CONFIG_HOME:-$HOME/.config}/zsh/conf/prompt/segments.zsh

# one jq pass into _sl, keyed by field. "${(@f)...}" keeps empty lines, so every field keeps its place
typeset -ga _sl_keys=(cwd model effort ctx five_hour seven_day seven_day_opus seven_day_sonnet fable
  reset_secs worktree pr_number pr_state added removed cost)
typeset -ga _sl_values=("${(@f)$(jq -r '.workspace.current_dir // .cwd // "",
  .model.display_name // "",
  .effort.level // "",
  .context_window.used_percentage // "",
  .rate_limits.five_hour.used_percentage // "",
  .rate_limits.seven_day.used_percentage // "",
  .rate_limits.seven_day_opus.used_percentage // "",
  .rate_limits.seven_day_sonnet.used_percentage // "",
  .rate_limits.fable.used_percentage // "",
  (.rate_limits.seven_day.resets_at // null
   | if type == "number" then . - now
     elif type == "string" then (try (((.[0:19] + "Z") | fromdateiso8601) - now) catch null)
     else null end
   | if . == null then "" else floor end),
  .workspace.git_worktree // .worktree.name // "",
  .pr.number // "",
  .pr.review_state // "",
  .cost.total_lines_added // 0,
  .cost.total_lines_removed // 0,
  .cost.total_cost_usd // ""')}")
typeset -gA _sl=("${(@)_sl_keys:^_sl_values}")

[[ -n $_sl[cwd] ]] && cd -q -- $_sl[cwd] 2>/dev/null

# fills the VCS_STATUS_* variables gitstatusd would, from git status --porcelain=v2
_statusline_git() {
  local out line gitdir d=$PWD xy
  VCS_STATUS_RESULT=
  out=$(GIT_OPTIONAL_LOCKS=0 git status --porcelain=v2 --branch --show-stash 2>/dev/null) || return
  VCS_STATUS_RESULT=ok-sync
  # the git dir without a git process. a linked worktree's .git is a file naming it
  while [[ -n $d && ! -e $d/.git ]]; do
    d=${d%/*}
  done
  gitdir=$d/.git
  if [[ -f $gitdir ]]; then
    gitdir=${${(f)"$(<$gitdir)"}[1]#gitdir: }
    [[ $gitdir == /* ]] || gitdir=$d/$gitdir
  fi
  for line in "${(@f)out}"; do
    case $line in
    '# branch.oid '*) VCS_STATUS_COMMIT=${line#\# branch.oid } ;;
    '# branch.head '*) [[ $line == *'(detached)' ]] || VCS_STATUS_LOCAL_BRANCH=${line#\# branch.head } ;;
    '# branch.ab '*)
      xy=${line#\# branch.ab +}
      VCS_STATUS_COMMITS_AHEAD=${xy%% *}
      VCS_STATUS_COMMITS_BEHIND=${xy##* -}
      ;;
    '# stash '*) VCS_STATUS_STASHES=${line#\# stash } ;;
    [12]' '*)
      xy=${line[3,4]}
      [[ $xy[1] != . ]] && ((VCS_STATUS_NUM_STAGED++))
      [[ $xy[1] == D ]] && ((VCS_STATUS_NUM_STAGED_DELETED++))
      [[ $xy[2] != . ]] && ((VCS_STATUS_NUM_UNSTAGED++))
      [[ $xy[2] == D ]] && ((VCS_STATUS_NUM_UNSTAGED_DELETED++))
      ;;
    'u '*) ((VCS_STATUS_NUM_CONFLICTED++)) ;;
    '? '*) ((VCS_STATUS_NUM_UNTRACKED++)) ;;
    esac
  done
  [[ -z $VCS_STATUS_LOCAL_BRANCH ]] && VCS_STATUS_TAG=$(git describe --tags --exact-match 2>/dev/null)
  # the action names and steps match gitstatusd's
  local step=
  if [[ -d $gitdir/rebase-merge ]]; then
    VCS_STATUS_ACTION=rebase-m
    [[ -e $gitdir/rebase-merge/interactive ]] && VCS_STATUS_ACTION=rebase-i
    step="$(<$gitdir/rebase-merge/msgnum)/$(<$gitdir/rebase-merge/end)"
  elif [[ -d $gitdir/rebase-apply ]]; then
    VCS_STATUS_ACTION=am/rebase
    [[ -e $gitdir/rebase-apply/rebasing ]] && VCS_STATUS_ACTION=rebase
    [[ -e $gitdir/rebase-apply/applying ]] && VCS_STATUS_ACTION=am
    step="$(<$gitdir/rebase-apply/next)/$(<$gitdir/rebase-apply/last)"
  elif [[ -e $gitdir/MERGE_HEAD ]]; then
    VCS_STATUS_ACTION=merge
  elif [[ -e $gitdir/CHERRY_PICK_HEAD ]]; then
    VCS_STATUS_ACTION=cherry-pick
  elif [[ -e $gitdir/REVERT_HEAD ]]; then
    VCS_STATUS_ACTION=revert
  elif [[ -e $gitdir/BISECT_LOG ]]; then
    VCS_STATUS_ACTION=bisect
  fi
  VCS_STATUS_ACTION+=${step:+ $step}
}
_statusline_git

_pseg_worktree() {
  [[ -n $_sl[worktree] ]] || return 1
  REPLY="wt ${_sl[worktree]//\%/%%}"
}

_pseg_pr() {
  [[ -n $_sl[pr_number] ]] || return 1
  REPLY="#$_sl[pr_number]${_sl[pr_state]:+ $_sl[pr_state]}"
}

_pseg_model() {
  [[ -n $_sl[model] ]] || return 1
  REPLY="${_sl[model]//\%/%%}${_sl[effort]:+ $_sl[effort]}"
}

_pseg_lines() {
  ((_sl[added] || _sl[removed])) || return 1
  local plus minus
  _prompt_fg added
  plus=$REPLY
  _prompt_fg removed
  minus=$REPLY
  REPLY="$plus+$_sl[added]%f $minus-$_sl[removed]%f"
}

_pseg_cost() {
  [[ $_sl[cost] == <->(|.<->) ]] || return 1
  printf -v REPLY '$%.2f' $_sl[cost]
}

# a usage percentage as label:value, colored green under 70, yellow under 90, red otherwise
_statusline_usage() {
  local label=$1 pct value
  printf -v pct '%.0f' $2
  if ((pct >= 90)); then
    _prompt_fg usage_high
  elif ((pct >= 70)); then
    _prompt_fg usage_mid
  else
    _prompt_fg usage_low
  fi
  value=$REPLY
  _prompt_fg label
  REPLY="$REPLY$label:%f$value$pct%%%f"
}

# true when a percentage is over 70. per-model buckets show only then
_statusline_hot() {
  [[ $1 == <->(|.<->) ]] && (($1 > 70))
}

# ctx, 5h and 7d, the per-model buckets when hot,
# and when the week is over half used and resets within 3 days, how soon
_pseg_usage() {
  local -a parts
  local label
  local -i secs=$_sl[reset_secs]
  [[ $_sl[ctx] == <->(|.<->) ]] && _statusline_usage ctx $_sl[ctx] && parts+=($REPLY)
  [[ $_sl[five_hour] == <->(|.<->) ]] && _statusline_usage 5h $_sl[five_hour] && parts+=($REPLY)
  [[ $_sl[seven_day] == <->(|.<->) ]] && _statusline_usage 7d $_sl[seven_day] && parts+=($REPLY)
  _statusline_hot $_sl[seven_day_opus] && _statusline_usage opus $_sl[seven_day_opus] && parts+=($REPLY)
  _statusline_hot $_sl[seven_day_sonnet] && _statusline_usage sonnet $_sl[seven_day_sonnet] && parts+=($REPLY)
  _statusline_hot $_sl[fable] && _statusline_usage fable $_sl[fable] && parts+=($REPLY)
  if [[ $_sl[reset_secs] == <-> && $_sl[seven_day] == <->(|.<->) ]] &&
    ((secs >= 1 && secs < 259200 && ${_sl[seven_day]%%.*} > 50)); then
    # hours when a day or less out, else days, rounded up
    if ((secs <= 86400)); then
      label="$(((secs + 3599) / 3600))h"
    else
      label="$(((secs + 86399) / 86400))d"
    fi
    _prompt_fg label
    parts+=("$REPLY(resets $label)%f")
  fi
  ((${#parts})) || return 1
  REPLY=${(j: :)parts}
}

typeset -g _sl_list=statusline${1:+_$1}
_prompt_fg separator
_prompt_render "$REPLY$prompt_separator%f" ${(P)_sl_list}
print -nrP -- $REPLY
