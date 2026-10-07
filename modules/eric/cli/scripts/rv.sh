#!/usr/bin/env bash
# run a command in the cs3410 risc-v container with the current directory mounted

set -euo pipefail

exec docker run -i --init --rm -v "$PWD":/root ghcr.io/sampsyo/cs3410-infra "$@"
