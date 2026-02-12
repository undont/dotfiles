#!/usr/bin/env bash
# List all running Gemini instances across all tmux sessions
# Shows session, window, and pane information for each instance

set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"
source "$SCRIPT_DIR/../_lib/alerts.sh"

# Check if tmux is available
if ! command -v tmux &>/dev/null; then
    exit 1
fi

# Check if any sessions exist
if ! tmux list-sessions &>/dev/null; then
    exit 0
fi

# Build set of PIDs that are ancestors of an active (non-suspended) gemini process.
# Walks up the process tree so wrapper scripts are detected.
declare -A active_gemini_ppids
while IFS= read -r cpid; do
    state=$(ps -o state= -p "$cpid" 2>/dev/null) || continue
    [[ "$state" == T* ]] && continue
    pid="$cpid"
    while true; do
        ppid=$(ps -o ppid= -p "$pid" 2>/dev/null) || break
        ppid="${ppid// /}"
        [[ "$ppid" == "0" || "$ppid" == "1" || -z "$ppid" ]] && break
        active_gemini_ppids[$ppid]=1
        pid="$ppid"
    done
done < <(pgrep -f gemini 2>/dev/null)

# Pre-fetch window names: "session:window_index window_name"
declare -A window_names
while IFS= read -r wline; do
    key="${wline%% *}"
    name="${wline#* }"
    window_names["$key"]="$name"
done < <(tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name}')

# Pre-load alerts file content (if it exists)
alerts_content=""
if [[ -f "$ALERTS_FILE" ]]; then
    alerts_content=$(<"$ALERTS_FILE")
fi

# Store results
gemini_panes=()

# Iterate through all panes in all sessions, sorted by last viewed (most recent first)
while IFS= read -r line; do
    # Parse: "last_viewed session:window_index.pane_index pane_pid"
    rest="${line#* }"          # strip last_viewed
    target="${rest%% *}"       # session:window_index.pane_index
    pane_pid="${rest##* }"     # pane_pid

    # Check if this pane has an active gemini child
    [[ -n "${active_gemini_ppids[$pane_pid]:-}" ]] || continue

    # Extract session and window_idx for lookups
    session="${target%%:*}"
    win_pane="${target#*:}"
    window_idx="${win_pane%%.*}"

    window_name="${window_names["${session}:${window_idx}"]:-}"

    # Check if this window has an alert for gemini
    if [[ -n "$alerts_content" ]] && printf '%s' "$alerts_content" | grep -q "^${session}:${window_name}:gemini$" 2>/dev/null; then
        display=$(get_agent_display "gemini")
        icon="${display%%|*}"
        gemini_panes+=("${target} ${window_name} ${icon}")
    else
        gemini_panes+=("${target} ${window_name}")
    fi
done < <(tmux list-panes -a -F '#{?#{@pane-viewed},#{@pane-viewed},0} #{session_name}:#{window_index}.#{pane_index} #{pane_pid}' | sort -rn)

# Add Gemini logo at top (cyan: #8be9fd ≈ colour 117)
LOGO_CYAN="\033[38;5;117m"
echo ""
printf "${LOGO_CYAN}██╗      ██████╗ ${NC}\n"
printf "${LOGO_CYAN} ██╗    ██╔════╝ ${NC}\n"
printf "${LOGO_CYAN}  ██║   ██║  ███╗${NC}\n"
printf "${LOGO_CYAN} ██╔╝   ██║   ██║${NC}\n"
printf "${LOGO_CYAN}╚═╝     ╚██████╔╝${NC}\n"
echo ""

# Display results (empty list shows just the logo)
if [[ ${#gemini_panes[@]} -eq 0 ]]; then
    exit 0
fi

# Simple list below logo
for pane_info in "${gemini_panes[@]}"; do
    echo "$pane_info"
done
