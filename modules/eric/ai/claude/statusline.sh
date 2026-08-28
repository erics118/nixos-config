#!/usr/bin/env bash
# Claude Code status line, styled after the user's starship prompt (catppuccin mocha)
set -uo pipefail

input=$(cat)

# one jq pass; newline-delimited + mapfile preserves empty fields
# (read with a tab IFS would collapse leading/consecutive empties)
mapfile -t f < <(
  jq -r '.workspace.current_dir // .cwd // "",
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
          | if . == null then "" else floor end)' <<<"$input"
)
cwd=${f[0]} model=${f[1]} effort=${f[2]} used_pct=${f[3]}
five_hour=${f[4]} seven_day=${f[5]} seven_day_opus=${f[6]} seven_day_sonnet=${f[7]} fable=${f[8]}
reset_secs=${f[9]}

# catppuccin mocha (truecolor), matching starship.toml palette
SEP=$'\033[38;2;69;71;90m'       # surface1, pill separators
TEAL=$'\033[38;2;148;226;213m'   # directory
PINK=$'\033[38;2;245;194;231m'   # git
BLUE=$'\033[38;2;137;180;250m'   # model + effort
DIM=$'\033[38;2;153;153;153m'    # matches claude code's secondary text (footer hints)
GREEN=$'\033[38;2;166;227;161m'  # usage low
YELLOW=$'\033[38;2;249;226;175m' # user@host, usage mid
RED=$'\033[38;2;243;139;168m'
RESET=$'\033[0m'

MID="${SEP}├┤${RESET}"
BRANCH=$'\xef\x90\x98' # nerd-font git branch glyph (U+F418), matching starship.toml

# color by usage: green < 70, yellow < 90, red otherwise
color_for() {
  local p=${1%%.*}
  if [ "${p:-0}" -ge 90 ]; then
    printf '%s' "$RED"
  elif [ "${p:-0}" -ge 70 ]; then
    printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"; fi
}

# true when a usage percentage exceeds 70 (per-model buckets only surface when high)
hot() {
  [[ $1 =~ ^[0-9.]+$ ]] || return 1
  local p=${1%%.*}
  [ "${p:-0}" -gt 70 ]
}

# shorten home to ~
[ -n "$cwd" ] && cwd="${cwd/#"$HOME"/\~}"

segs=()

# directory
[ -n "$cwd" ] && segs+=("${TEAL}${cwd}${RESET}")

# hostname, only over ssh (matching starship)
if [ -n "${SSH_CONNECTION:-}${SSH_TTY:-}" ]; then
  h=${HOSTNAME:-$(hostname 2>/dev/null)}
  [ -n "$h" ] && segs+=("${YELLOW}${h%%.*}${RESET}")
fi

# git: branch + status (modified ~, untracked +, ahead ↑ / behind ↓ / diverged ↕, no counts)
if [ -n "$cwd" ]; then
  expanded_cwd="${cwd/#\~/$HOME}"
  git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$expanded_cwd" symbolic-ref --short HEAD 2>/dev/null)
  if [ -n "$git_branch" ]; then
    status=""
    porcelain=$(GIT_OPTIONAL_LOCKS=0 git -C "$expanded_cwd" status --porcelain 2>/dev/null)
    if [ -n "$porcelain" ]; then
      grep -qv '^??' <<<"$porcelain" && status="${status}~"
      grep -q '^??' <<<"$porcelain" && status="${status}+"
    fi
    counts=$(GIT_OPTIONAL_LOCKS=0 git -C "$expanded_cwd" rev-list --count --left-right 'HEAD...@{upstream}' 2>/dev/null)
    if [ -n "$counts" ]; then
      ahead=${counts%%[[:space:]]*}
      behind=${counts##*[[:space:]]}
      if [ "${ahead:-0}" -gt 0 ] 2>/dev/null && [ "${behind:-0}" -gt 0 ] 2>/dev/null; then
        status="${status}↕"
      elif [ "${ahead:-0}" -gt 0 ] 2>/dev/null; then
        status="${status}↑"
      elif [ "${behind:-0}" -gt 0 ] 2>/dev/null; then
        status="${status}↓"
      fi
    fi
    [ -n "$status" ] && status=" ${status}"
    segs+=("${PINK}${BRANCH} ${git_branch}${status}${RESET}")
  fi
fi

# model + effort (same color)
if [ -n "$model" ]; then
  m="${BLUE}${model}${RESET}"
  [ -n "$effort" ] && m="${m} ${BLUE}${effort}${RESET}"
  segs+=("${m}")
fi

# usage: ctx, 5h, 7d (dim label, threshold-colored value)
usage=""
[[ $used_pct =~ ^[0-9.]+$ ]] && usage=$(printf '%sctx:%s%.0f%%%s' "$DIM" "$(color_for "$used_pct")" "$used_pct" "$RESET")
[[ $five_hour =~ ^[0-9.]+$ ]] && usage="${usage:+$usage }$(printf '%s5h:%s%.0f%%%s' "$DIM" "$(color_for "$five_hour")" "$five_hour" "$RESET")"
[[ $seven_day =~ ^[0-9.]+$ ]] && usage="${usage:+$usage }$(printf '%s7d:%s%.0f%%%s' "$DIM" "$(color_for "$seven_day")" "$seven_day" "$RESET")"
hot "$seven_day_opus" && usage="${usage:+$usage }$(printf '%sopus:%s%.0f%%%s' "$DIM" "$(color_for "$seven_day_opus")" "$seven_day_opus" "$RESET")"
hot "$seven_day_sonnet" && usage="${usage:+$usage }$(printf '%ssonnet:%s%.0f%%%s' "$DIM" "$(color_for "$seven_day_sonnet")" "$seven_day_sonnet" "$RESET")"
hot "$fable" && usage="${usage:+$usage }$(printf '%sfable:%s%.0f%%%s' "$DIM" "$(color_for "$fable")" "$fable" "$RESET")"
# resets: only when 7d usage > 50% and reset is under 3 days out
# hours when <= 1 day out, else days (integer ceil)
if [[ $reset_secs =~ ^[0-9]+$ ]] && [ "$reset_secs" -ge 1 ] && [ "$reset_secs" -lt 259200 ] &&
  [[ $seven_day =~ ^[0-9.]+$ ]] && [ "${seven_day%%.*}" -gt 50 ]; then
  if [ "$reset_secs" -le 86400 ]; then
    reset_label="$(((reset_secs + 3599) / 3600))h"
  else
    reset_label="$(((reset_secs + 86399) / 86400))d"
  fi
  usage="${usage:+$usage }$(printf '%s(resets %s)%s' "$DIM" "$reset_label" "$RESET")"
fi
[ -n "$usage" ] && segs+=("${usage}")

# assemble: seg├┤seg├┤...
out=""
if [ ${#segs[@]} -gt 0 ]; then
  out="${segs[0]}"
  for ((i = 1; i < ${#segs[@]}; i++)); do out="${out}${MID}${segs[i]}"; done
fi

printf '%s' "$out"
