#!/usr/bin/env bash
# the dotfiles launcher picker, run inside a floating layer by the pick_launcher
# action. launchers build through the picker's rex backend
# usage: pick-launcher.sh <client_id> <origin_session_id> <origin_block_id> <origin_zoomed>
set -euo pipefail

# shellcheck source=/dev/null
source "${BASH_SOURCE%/*}/_lib.sh"

picker_start "$1" "$2" "$3" "$4"
import_shell_env
wait_for_resize

export LAUNCHER_BACKEND=rex
"$DOTFILES_ROOT/launchers/bin/picker.sh"
