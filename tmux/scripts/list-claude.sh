#!/usr/bin/env bash
# List all running Claude Code instances across all tmux sessions
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

# Store results
claude_panes=()

# Iterate through all panes in all sessions, sorted by last viewed (most recent first)
while IFS= read -r line; do
    # Parse the pane info: last_viewed session:window_index.pane_index command
    # last_viewed=$(echo "$line" | cut -d' ' -f1)  # Unused: for sorting only
    session=$(echo "$line" | cut -d' ' -f2 | cut -d: -f1)
    window_idx=$(echo "$line" | cut -d: -f2 | cut -d. -f1)
    pane_idx=$(echo "$line" | cut -d. -f2 | cut -d' ' -f1)
    command=$(echo "$line" | cut -d' ' -f3-)

    # Check if the command is claude
    if [[ "$command" == "claude" ]]; then
        # Get window name for better display
        window_name=$(tmux list-windows -t "$session" -F '#{window_index} #{window_name}' | grep "^$window_idx " | cut -d' ' -f2-)

        # Build target (session:window.pane)
        target="${session}:${window_idx}.${pane_idx}"

        # Check if this window has an alert for claude
        # New format: session:window:agent
        if [[ -f "$ALERTS_FILE" ]] && grep -q "^${session}:${window_name}:claude$" "$ALERTS_FILE" 2>/dev/null; then
            display=$(get_agent_display "claude")
            icon="${display%%|*}"
            claude_panes+=("${target} ${window_name} ${icon}")
        else
            claude_panes+=("${target} ${window_name}")
        fi
    fi
done < <(tmux list-panes -a -F '#{?#{@last-viewed},#{@last-viewed},0} #{session_name}:#{window_index}.#{pane_index} #{pane_current_command}' | sort -rn)

# Add Claude Code ghost at top (Anthropic orange: #d97757 ≈ 173)
echo ""
printf "\033[38;5;173m ▐▛███▜▌\033[0m\n"
printf "\033[38;5;173m▝▜█████▛▘\033[0m\n"
printf "\033[38;5;173m  ▘▘ ▝▝\033[0m\n"
echo ""

# Display results (empty list shows just the logo)
if [[ ${#claude_panes[@]} -eq 0 ]]; then
    exit 0
fi

# Simple list below ghost
for pane_info in "${claude_panes[@]}"; do
    echo "$pane_info"
done
