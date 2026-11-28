#!/usr/bin/env bash
# run a command in a new window of the current session and show it in the app.
# rex run only moves the server's active window; the app keeps its own
# usage: run-window.sh DIR -- COMMAND...
set -euo pipefail

# ~/.config/rex links to the repo's rex/, so -P resolves to the repo root
# shellcheck source=/dev/null
source "$(cd -P "${BASH_SOURCE%/*}/../.." && pwd)/launchers/lib/rex.sh"

dir="$1"
shift 2

session=$(rex block inspect "$REX_BLOCK" --json | jq -r '.session_id')
window=$(rex run --json -c "$dir" -- "$@" | jq -r '.window_id')
_rex_select "$session" "$window"
