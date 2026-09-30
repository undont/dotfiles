#!/usr/bin/env bash
# connect an nvim instance to a pane via NVIM_SOCKET
# usage: connect-nvim.sh <fzf_selection_line>
# shows a pane picker for the current session, copies the export command to the
# clipboard and switches to the selected pane

set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"

load_fzf_theme

if [[ -z "${1:-}" ]]; then
    error "No selection provided"
    exit 1
fi

# extract socket path (after tab in the selection)
SOCKET=$(echo "$1" | cut -f2)

if [[ -z "$SOCKET" || ! -S "$SOCKET" ]]; then
    error "No valid socket found"
    exit 1
fi

CURRENT_SESSION=$(tmux display-message -p '#S')

# list panes in current session, sorted by last-viewed, excluding nvim panes
# format: timestamp window_index.pane_index<tab>window_name (command)
pane_list=$(tmux list-panes -s -F '#{?#{@pane-viewed},#{@pane-viewed},0} #{window_index}.#{pane_index}	#{window_name} (#{pane_current_command})' 2>/dev/null |
    grep -v '(nvim)$' |
    sort -rn |
    cut -d' ' -f2-)

if [[ -z "$pane_list" ]]; then
    error "No panes found"
    exit 1
fi

TARGET_PANE=$(echo "$pane_list" | fzf --ansi --reverse --exact --disabled --cycle \
    --delimiter=$'\t' \
    --with-nth=2 \
    --prompt ': ' \
    --border=rounded \
    --border-label=" Connect nvim to pane (${CURRENT_SESSION}) " \
    --border-label-pos=top \
    --preview "tmux capture-pane -ep -t ${CURRENT_SESSION}:\$(echo {} | cut -f1)" \
    --preview-window=right:70% \
    --bind 'j:down,k:up,g:first,G:last,q:abort,space:accept' \
    --bind 'enter:accept' \
    --bind '/:enable-search+change-prompt(> )+unbind(j,k,g,G,q,space)' \
    --bind 'esc:transform:[[ $FZF_PROMPT == "> " ]] && echo "disable-search+clear-query+change-prompt(: )+rebind(j,k,g,G,q,space)" || echo "abort"' |
    cut -f1)

if [[ -z "$TARGET_PANE" ]]; then
    exit 0 # user cancelled
fi

FULL_TARGET="${CURRENT_SESSION}:${TARGET_PANE}"

EXPORT_CMD="export NVIM_SOCKET='$SOCKET' && claude"

echo -n "$EXPORT_CMD" | clipboard_copy

tmux select-window -t "$FULL_TARGET"
tmux select-pane -t "$FULL_TARGET"

tmux display-message "Copied to clipboard - paste to connect"
