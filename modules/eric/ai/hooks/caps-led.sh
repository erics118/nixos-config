#!/usr/bin/env bash
# light the caps lock led until the next keyboard or trackpad input, so a finished agent shows from across the room
# always exit 0, since a Stop hook that exits 2 keeps the agent running
command -v capsled >/dev/null 2>&1 || exit 0
capsled on --until-input >/dev/null 2>&1
exit 0
