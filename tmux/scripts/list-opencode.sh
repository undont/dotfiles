#!/usr/bin/env bash
# List all running OpenCode instances across all tmux sessions
# Shows session, window, and pane information for each instance

set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/_lib/alerts.sh"

# Check if tmux is available
if ! command -v tmux &>/dev/null; then
    exit 1
fi

# Check if any sessions exist
if ! tmux list-sessions &>/dev/null; then
    exit 0
fi

# Check if a pane is running opencode by inspecting its process tree
# OpenCode runs as 'node' so we need to check child processes
is_opencode_pane() {
    local pane_pid="$1"
    # Check if any child process of the pane contains 'opencode' in its command
    pgrep -P "$pane_pid" -f opencode &>/dev/null
}

# Store results
opencode_panes=()

# Iterate through all panes in all sessions, sorted by last viewed (most recent first)
while IFS= read -r line; do
    # Parse the pane info: last_viewed session:window_index.pane_index pane_pid
    # last_viewed=$(echo "$line" | cut -d' ' -f1)  # Unused: for sorting only
    session=$(echo "$line" | cut -d' ' -f2 | cut -d: -f1)
    window_idx=$(echo "$line" | cut -d: -f2 | cut -d. -f1)
    pane_idx=$(echo "$line" | cut -d. -f2 | cut -d' ' -f1)
    pane_pid=$(echo "$line" | cut -d' ' -f3)

    # Check if this pane is running opencode
    if is_opencode_pane "$pane_pid"; then
        # Get window name for better display
        window_name=$(tmux list-windows -t "$session" -F '#{window_index} #{window_name}' | grep "^$window_idx " | cut -d' ' -f2-)

        # Build target (session:window.pane)
        target="${session}:${window_idx}.${pane_idx}"

        # Check if this window has an alert for opencode
        # New format: session:window:agent
        if [[ -f "$ALERTS_FILE" ]] && grep -q "^${session}:${window_name}:opencode$" "$ALERTS_FILE" 2>/dev/null; then
            display=$(get_agent_display "opencode")
            icon="${display%%|*}"
            opencode_panes+=("${target} ${window_name} ${icon}")
        else
            opencode_panes+=("${target} ${window_name}")
        fi
    fi
done < <(tmux list-panes -a -F '#{?#{@last-viewed},#{@last-viewed},0} #{session_name}:#{window_index}.#{pane_index} #{pane_pid}' | sort -rn)

# Add OpenCode logo at top
# "open" in dark slate (colour 60), "code" in light blue (colour 103)
DARK="\033[38;5;60m"
LIGHT="\033[38;5;103m"
NC="\033[0m"
echo ""
printf "${DARK}█▀▀█ █▀▀█ █▀▀ █▀▀▄${NC} ${LIGHT}█▀▀ █▀▀█ █▀▀▄ █▀▀${NC}\n"
printf "${DARK}█  █ █  █ █▀▀ █  █${NC} ${LIGHT}█   █  █ █  █ █▀▀${NC}\n"
printf "${DARK}▀▀▀▀ █▀▀▀ ▀▀▀ ▀  ▀${NC} ${LIGHT}▀▀▀ ▀▀▀▀ ▀▀▀  ▀▀▀${NC}\n"
echo ""

# Display results (empty list shows just the logo)
if [[ ${#opencode_panes[@]} -eq 0 ]]; then
    exit 0
fi

# Simple list below logo
for pane_info in "${opencode_panes[@]}"; do
    echo "$pane_info"
done
