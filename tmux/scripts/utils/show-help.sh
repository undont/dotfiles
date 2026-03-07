#!/usr/bin/env bash
set -euo pipefail

# Display tmux help with platform-appropriate modifier key names
# macOS shows "Opt", Linux shows "Alt"

SCRIPT_DIR="${BASH_SOURCE%/*}"

# shellcheck source=tmux/scripts/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

TEMPLATE="$SCRIPT_DIR/../../tmux-help.template"
MOD=$(mod_key)

sed "s/{{M}}/$MOD/g" "$TEMPLATE"
