#!/usr/bin/env bash
# connect to the cornell vpn, pulling credentials from 1password
# password is line 1 of stdin, line 2 answers the duo prompt with a push

set -euo pipefail

user=$(op read "op://Personal/Cornell/username")
pass=$(op read "op://Personal/Cornell/password")
printf '%s\npush\n' "$pass" | sudo "$(command -v openconnect)" \
  --authgroup=Two-Step_Login --user="$user" --passwd-on-stdin \
  cuvpn.cuvpn.cornell.edu
