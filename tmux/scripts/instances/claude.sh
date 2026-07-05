#!/usr/bin/env bash
# list all running Claude Code instances across all tmux sessions
# shows session, window, and pane information for each instance

set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"
source "$SCRIPT_DIR/../_lib/alerts.sh"

# check if tmux is available
if ! command -v tmux &>/dev/null; then
    exit 1
fi

# check if any sessions exist
if ! tmux list-sessions &>/dev/null; then
    exit 0
fi

# build set of PIDs that are ancestors of an active (non-suspended) claude process
# walks up the process tree so wrapper scripts (e.g., ralph -> claude) are detected
declare -A active_claude_ppids
while IFS= read -r cpid; do
    state=$(ps -o state= -p "$cpid" 2>/dev/null) || continue
    [[ "$state" == T* ]] && continue
    # include claude itself: tmux new-window 'claude ...' execs claude as the pane process
    active_claude_ppids[$cpid]=1
    pid="$cpid"
    while true; do
        ppid=$(ps -o ppid= -p "$pid" 2>/dev/null) || break
        ppid="${ppid// /}"
        [[ "$ppid" == "0" || "$ppid" == "1" || -z "$ppid" ]] && break
        active_claude_ppids[$ppid]=1
        pid="$ppid"
    done
done < <(pgrep -x claude 2>/dev/null)

# pre-fetch window names: "session:window_index window_name"
declare -A window_names
while IFS= read -r wline; do
    key="${wline%% *}"
    name="${wline#* }"
    window_names["$key"]="$name"
done < <(tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name}')

# pre-load alerts file content (if it exists)
alerts_content=""
if [[ -f "$ALERTS_FILE" ]]; then
    alerts_content=$(<"$ALERTS_FILE")
fi

# store results
claude_panes=()

# iterate through all panes in all sessions, sorted by last viewed (most recent first)
while IFS= read -r line; do
    # parse: "last_viewed session:window_index.pane_index pane_pid"
    rest="${line#* }"          # strip last_viewed
    target="${rest%% *}"       # session:window_index.pane_index
    pane_pid="${rest##* }"     # pane_pid

    # check if this pane has an active claude child
    [[ -n "${active_claude_ppids[$pane_pid]:-}" ]] || continue

    # extract session and window_idx for lookups
    session="${target%%:*}"
    win_pane="${target#*:}"
    window_idx="${win_pane%%.*}"

    window_name="${window_names["${session}:${window_idx}"]:-}"

    # check if this window has an alert for claude (names stored percent-encoded)
    if [[ -n "$alerts_content" ]] && printf '%s' "$alerts_content" | grep -q "^${session}:$(alerts_encode_window "$window_name"):claude$" 2>/dev/null; then
        display=$(get_agent_display "claude")
        icon="${display%%|*}"
        claude_panes+=("${target} ${window_name} ${icon}")
    else
        claude_panes+=("${target} ${window_name}")
    fi
done < <(tmux list-panes -a -F '#{?#{@pane-viewed},#{@pane-viewed},0} #{session_name}:#{window_index}.#{pane_index} #{pane_pid}' | sort -rn)

# add Claude Code ghost at top (Anthropic terracotta: #D77757 = 215;119;87)
echo ""
printf "\033[38;2;215;119;87m ▐▛███▜▌\033[0m\n"
printf "\033[38;2;215;119;87m▝▜█████▛▘\033[0m\n"
printf "\033[38;2;215;119;87m  ▘▘ ▝▝\033[0m\n"
echo ""

# display results (empty list shows just the logo)
if [[ ${#claude_panes[@]} -eq 0 ]]; then
    exit 0
fi

# simple list below ghost
for pane_info in "${claude_panes[@]}"; do
    echo "$pane_info"
done
