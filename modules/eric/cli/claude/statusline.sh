#!/usr/bin/env bash
# Claude Code status line, styled after the user's starship prompt (catppuccin mocha)
set -uo pipefail

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_hour=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_day=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# catppuccin mocha (truecolor), matching starship.toml palette
SEP=$'\033[38;2;69;71;90m'     # surface1, pill separators
TEAL=$'\033[38;2;148;226;213m' # directory
PINK=$'\033[38;2;245;194;231m' # git
BLUE=$'\033[38;2;137;180;250m' # model
DIM=$'\033[38;2;108;112;134m'  # overlay0, effort
GREEN=$'\033[38;2;166;227;161m'
YELLOW=$'\033[38;2;249;226;175m'
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

# shorten home to ~
[ -n "$cwd" ] && cwd="${cwd/#"$HOME"/\~}"

segs=()

# directory
[ -n "$cwd" ] && segs+=("${TEAL}${cwd}${RESET}")

# git: branch + status (modified ~, untracked +, ahead/behind)
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
      [ "${ahead:-0}" -gt 0 ] 2>/dev/null && status="${status}↑${ahead}"
      [ "${behind:-0}" -gt 0 ] 2>/dev/null && status="${status}↓${behind}"
    fi
    [ -n "$status" ] && status=" ${status}"
    segs+=("${PINK}${BRANCH} ${git_branch}${status}${RESET}")
  fi
fi

# model + effort
if [ -n "$model" ]; then
  m="${BLUE}${model}${RESET}"
  [ -n "$effort" ] && m="${m} ${DIM}${effort}${RESET}"
  segs+=("${m}")
fi

# usage: ctx, 5h, 7d (threshold-colored)
usage=""
[[ $used_pct =~ ^[0-9.]+$ ]] && usage=$(printf '%sctx:%.0f%%%s' "$(color_for "$used_pct")" "$used_pct" "$RESET")
[[ $five_hour =~ ^[0-9.]+$ ]] && usage="${usage:+$usage }$(printf '%s5h:%.0f%%%s' "$(color_for "$five_hour")" "$five_hour" "$RESET")"
[[ $seven_day =~ ^[0-9.]+$ ]] && usage="${usage:+$usage }$(printf '%s7d:%.0f%%%s' "$(color_for "$seven_day")" "$seven_day" "$RESET")"
[ -n "$usage" ] && segs+=("${usage}")

# assemble: seg├┤seg├┤...
out=""
if [ ${#segs[@]} -gt 0 ]; then
  out="${segs[0]}"
  for ((i = 1; i < ${#segs[@]}; i++)); do out="${out}${MID}${segs[i]}"; done
fi
printf '%s' "$out"
