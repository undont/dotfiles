#!/usr/bin/env bash
# copy stdin to the clipboard of the machine running the app, through the home
# server's copy_text action: the app ignores OSC 52 from another host's panes
set -euo pipefail

# shellcheck source=/dev/null
source "${BASH_SOURCE%/*}/_lib.sh"

home_rex "do" copy_text "text=$(cat)" >/dev/null
