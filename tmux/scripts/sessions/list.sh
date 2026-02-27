#!/usr/bin/env bash
# List tmux sessions sorted by activity (most recent first)
# Used by the session switcher (prefix + s)
# Shows agent-specific indicators for sessions with alerts

SCRIPT_DIR="${BASH_SOURCE%/*}"
# Note: Production scripts use ${BASH_SOURCE%/*} pattern.
# Test scripts use $(cd "$(dirname "${BASH_SOURCE[0]}")") && pwd).
# shellcheck source=tmux/scripts/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"
# shellcheck source=tmux/scripts/_lib/alerts.sh
source "$SCRIPT_DIR/../_lib/alerts.sh"

load_fzf_theme
print_dotfiles_logo

# Get sessions sorted by activity
while read -r session; do
    # Check all windows in this session for alert options
    icons=""
    while read -r win_id; do
        [[ -z "$win_id" ]] && continue
        opts=$(tmux show-options -wt "$win_id" 2>/dev/null || true)
        [[ -z "$opts" ]] && continue
        icons="${icons}$(get_window_alert_icons "$opts")"
    done < <(tmux list-windows -t "$session" -F '#{window_id}' 2>/dev/null)

    if [[ -n "$icons" ]]; then
        printf "%s %b\n" "${session}" "${icons}"
    else
        echo "$session"
    fi
done < <(tmux list-sessions -F '#{session_activity} #{session_name}' | sort -rn | cut -d' ' -f2-)
