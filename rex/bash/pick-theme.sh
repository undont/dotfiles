#!/usr/bin/env bash
# the dotfiles theme picker, run inside a floating layer by the pick_theme action
# usage: pick-theme.sh <client_id> <origin_session_id> <origin_block_id> <origin_zoomed>
set -euo pipefail

# shellcheck source=/dev/null
source "${BASH_SOURCE%/*}/_lib.sh"

picker_start "$1" "$2" "$3" "$4"
wait_for_resize

"$DOTFILES_ROOT/tmux/scripts/themes/picker.sh"
