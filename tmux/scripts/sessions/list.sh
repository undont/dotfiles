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

# Pre-read alerts file once (avoids per-session/per-window tmux calls)
_all_alerts=""
[[ -f "$ALERTS_FILE" ]] && _all_alerts=$(< "$ALERTS_FILE")

# Get sessions sorted by activity
while read -r session; do
    icons=$(build_alert_icons "$_all_alerts" "^${session}:" "dedupe")

    if [[ -n "$icons" ]]; then
        printf "%s %b\n" "${session}" "${icons}"
    else
        echo "$session"
    fi
done < <(tmux list-sessions -F '#{session_activity} #{session_name}' | sort -rn | cut -d' ' -f2-)
