#!/usr/bin/env bash
set -euo pipefail

# send "source ~/.zshrc" to all panes running zsh across all sessions

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"

require_tmux

count=0
skipped=0

while IFS=' ' read -r pane_id cmd; do
    if [[ "$cmd" == "zsh" ]]; then
        tmux send-keys -t "$pane_id" 'source ~/.zshrc' Enter
        tmux send-keys -t "$pane_id" 'cl' Enter
        count=$((count + 1))
    else
        skipped=$((skipped + 1))
    fi
done < <(tmux list-panes -a -F '#{pane_id} #{pane_current_command}')

# report via tmux message
if [[ $count -gt 0 ]]; then
    tmux display-message "Sourced ~/.zshrc in $count pane(s) ($skipped skipped)"
else
    tmux display-message "No zsh panes found ($skipped pane(s) skipped)"
fi
