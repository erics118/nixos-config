#!/usr/bin/env bash
# debug in the cs3410 risc-v container: interactive, core dumps on, mounted at the same path as on the host

set -euo pipefail

exec docker run -it --rm --init --name testing --ulimit core=-1 \
  --mount type=bind,source="$PWD"/,target="$PWD"/ -v "$PWD":/root \
  ghcr.io/sampsyo/cs3410-infra "$@"
