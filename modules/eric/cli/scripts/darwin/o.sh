#!/usr/bin/env bash
# macOS open, defaulting to the current directory

set -euo pipefail

exec open "${@:-.}"
