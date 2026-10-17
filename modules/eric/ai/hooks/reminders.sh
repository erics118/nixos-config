#!/usr/bin/env bash
# give the agent the global reminders and the current repo's reminders at session start
# usage: reminders.sh, with cwd in the JSON on stdin
# always exit 0, so a failure never blocks the agent
cwd=$(jq -r '.cwd // empty' 2>/dev/null)
global=$HOME/.local/state/eric/reminders.md
# the main worktree's list, so every worktree of a repo shares one
main=$(git -C "${cwd:-$PWD}" worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')
repo_file=${main:+$main/.eric/reminders.md}

lists=
[[ -s $global ]] && lists+=$'\n\n'"Global reminders:"$'\n'$(<"$global")
[[ -n $repo_file && -s $repo_file ]] && lists+=$'\n\n'"Reminders for this repo:"$'\n'$(<"$repo_file")
[[ -n $lists ]] || exit 0

files="Global reminders live in $global."
[[ -n $repo_file ]] && files+=" This repo's reminders live in $repo_file."
rules="Open reminders for the user. Tell the user each one at the start of this conversation, soonest first, one line per item that starts with the item, never grouped by date. Remove an item from its file only when the user says it is done. A new reminder about this repo's work goes in the repo's file, any other goes in the global file, unless the user names one. Label each item \"(global)\" or \"(local)\", never with its file path."
jq -n --arg c "$rules $files$lists" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}'
exit 0
