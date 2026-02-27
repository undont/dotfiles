#!/usr/bin/env bash
# List tmux windows sorted by last viewed (most recent first)
# Used by the window switcher (prefix + f)
# Shows agent-specific indicators for windows with alerts
#
# Usage: list-windows.sh [--all]
#   --all: List windows from all sessions (default: current session only)

SCRIPT_DIR="${BASH_SOURCE%/*}"
# shellcheck source=tmux/scripts/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"
# shellcheck source=tmux/scripts/_lib/alerts.sh
source "$SCRIPT_DIR/../_lib/alerts.sh"

load_fzf_theme
print_dotfiles_logo

# Get windows sorted by last-viewed, then add alert indicator
# Format includes window_id (tab-separated) for direct tmux option queries
if [[ "$1" == "--all" ]]; then
    # All sessions: session_name:window_index window_name
    FORMAT='#{?#{@last-viewed},#{@last-viewed},0} #{session_name}:#{window_index} #{window_name}'$'\t''#{window_id}'
    tmux list-windows -a -F "$FORMAT"
else
    # Current session only
    SESSION=$(tmux display-message -p '#S')
    FORMAT="#{?#{@last-viewed},#{@last-viewed},0} ${SESSION}:#{window_index} #{window_name}"$'\t''#{window_id}'
    tmux list-windows -F "$FORMAT"
fi | sort -rn | cut -d' ' -f2- | while IFS=$'\t' read -r display_line window_id; do
    # display_line: "session:window_index window_name", window_id: "@N"

    # Query tmux window options once for all alert checks
    icons=""
    if [[ -n "$window_id" ]]; then
        opts=$(tmux show-options -wt "$window_id" 2>/dev/null || true)
        icons=$(get_window_alert_icons "$opts")
    fi

    if [[ -n "$icons" ]]; then
        printf "%s %b\n" "$display_line" "${icons}"
    else
        echo "$display_line"
    fi
done
