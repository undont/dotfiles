#!/usr/bin/env bash
# Connect an nvim instance to a pane by setting NVIM_SOCKET
# Usage: connect-nvim.sh <fzf_selection_line>
# Called from fzf with "c" key binding
# Shows pane picker for current session, sends export command to selected pane

set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"

# Load current theme colours for fzf
load_fzf_theme

if [[ -z "${1:-}" ]]; then
    error "No selection provided"
    exit 1
fi

# Extract socket path (after tab in the selection)
SOCKET=$(echo "$1" | cut -f2)

if [[ -z "$SOCKET" || ! -S "$SOCKET" ]]; then
    error "No valid socket found"
    exit 1
fi

# Get current session
CURRENT_SESSION=$(tmux display-message -p '#S')

# List panes in current session, sorted by last-viewed, excluding nvim panes
# Format: timestamp window_index.pane_index<tab>window_name (command)
pane_list=$(tmux list-panes -s -F '#{?#{@pane-viewed},#{@pane-viewed},0} #{window_index}.#{pane_index}	#{window_name} (#{pane_current_command})' 2>/dev/null | \
    grep -v '(nvim)$' | \
    sort -rn | \
    cut -d' ' -f2-)

if [[ -z "$pane_list" ]]; then
    error "No panes found"
    exit 1
fi

# Let user pick a pane
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
    --bind 'esc:transform:[[ $FZF_PROMPT == "> " ]] && echo "disable-search+clear-query+change-prompt(: )+rebind(j,k,g,G,q,space)" || echo "abort"' \
    | cut -f1)

if [[ -z "$TARGET_PANE" ]]; then
    exit 0  # User cancelled
fi

# Build full target with session name
FULL_TARGET="${CURRENT_SESSION}:${TARGET_PANE}"

EXPORT_CMD="export NVIM_SOCKET='$SOCKET' && claude"

# Copy export command to clipboard
echo -n "$EXPORT_CMD" | clipboard_copy

# Switch to the target pane
tmux select-window -t "$FULL_TARGET"
tmux select-pane -t "$FULL_TARGET"

# Show message in tmux status bar
tmux display-message "Copied to clipboard - paste to connect"
