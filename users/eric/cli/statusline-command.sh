#!/usr/bin/env bash
# Claude Code status line script

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_hour=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_day=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# ANSI color codes
CYAN='\033[36m'
GREEN='\033[32m'
MAGENTA='\033[35m'
YELLOW='\033[33m'
RESET='\033[0m'

# Shorten home directory to ~
if [ -n "$cwd" ]; then
    home="$HOME"
    cwd="${cwd/#$home/\~}"
fi

# Get git branch from the cwd
git_branch=""
if [ -n "$cwd" ]; then
    expanded_cwd="${cwd/#\~/$HOME}"
    git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$expanded_cwd" symbolic-ref --short HEAD 2>/dev/null)
fi

# Build context usage string
ctx_str=""
if [ -n "$used_pct" ]; then
    ctx_str=$(printf "${YELLOW}ctx:%.0f%%${RESET}" "$used_pct")
fi

# Build rate limit string
rate_str=""
if [ -n "$five_hour" ]; then
    rate_str=$(printf "${YELLOW}5h:%.0f%%${RESET}" "$five_hour")
fi
if [ -n "$seven_day" ]; then
    week_str=$(printf "${YELLOW}7d:%.0f%%${RESET}" "$seven_day")
    if [ -n "$rate_str" ]; then
        rate_str="$rate_str $week_str"
    else
        rate_str="$week_str"
    fi
fi

# Assemble parts
parts=()
[ -n "$cwd" ] && parts+=("${CYAN}${cwd}${RESET}")
[ -n "$git_branch" ] && parts+=("${MAGENTA}(${git_branch})${RESET}")
[ -n "$model" ] && parts+=("${GREEN}[${model}]${RESET}")
[ -n "$ctx_str" ] && parts+=("$ctx_str")
[ -n "$rate_str" ] && parts+=("$rate_str")

printf "%b" "${parts[*]}"
