#!/usr/bin/env bash
# a pane's scrollback in read-only nvim, run by the copy_mode action in a
# floating layer over the pane: a snapshot, so output after it opens doesn't appear
# usage: copy-mode.sh <client_id> <origin_session_id> <origin_block_id> <origin_zoomed>
set -euo pipefail

# shellcheck source=/dev/null
source "${BASH_SOURCE%/*}/_lib.sh"

picker_start "$1" "$2" "$3" "$4"
[[ -n "$PICK_ORIGIN_BLOCK" ]] || exit 0

scrollback=$(mktemp -t rex-scrollback)
rex capture -s "$PICK_ORIGIN_SESSION" -b "$PICK_ORIGIN_BLOCK" --unwrap --trim >"$scrollback"

wait_for_resize
nvim -R "$scrollback" \
    -c 'setlocal buftype=nofile bufhidden=wipe nomodifiable noswapfile' \
    -c 'set clipboard=unnamedplus' \
    -c 'nnoremap <buffer> q <cmd>qa!<cr>' \
    -c 'normal! G'
rm -f "$scrollback"
