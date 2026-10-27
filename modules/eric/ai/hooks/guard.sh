#!/usr/bin/env bash
# the harnesses call this path. the checks live in agent-guard, built from ../guard
# exit 2 blocks the call, so a missing binary fails closed
command -v agent-guard >/dev/null 2>&1 || {
  printf 'guard hook cannot run: agent-guard is not on PATH, so the command was not checked.\n' >&2
  exit 2
}
exec agent-guard "$@"
