#!/usr/bin/env bash
# List all running Claude Code instances across all tmux sessions
# Shows session, window, and pane information for each instance

set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/_lib/common.sh"

# Check if tmux is available
if ! command -v tmux &>/dev/null; then
    error "tmux is not installed"
    exit 1
fi

# Check if any sessions exist
if ! tmux list-sessions &>/dev/null; then
    info "No tmux sessions running"
    exit 0
fi

# Store results
claude_panes=()

# Iterate through all panes in all sessions
while IFS= read -r line; do
    # Parse the pane info: session:window.pane command
    session=$(echo "$line" | cut -d: -f1)
    window=$(echo "$line" | cut -d: -f2 | cut -d. -f1)
    pane=$(echo "$line" | cut -d. -f2 | cut -d' ' -f1)
    command=$(echo "$line" | cut -d' ' -f2-)

    # Check if the command is claude
    if [[ "$command" == "claude" ]]; then
        # Get window name for better display
        window_name=$(tmux list-windows -t "$session" -F '#{window_index} #{window_name}' | grep "^$window " | cut -d' ' -f2-)
        claude_panes+=("${session}:${window_name}.${pane}")
    fi
done < <(tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_current_command}')

# Display results
if [[ ${#claude_panes[@]} -eq 0 ]]; then
    info "No Claude Code instances running"
    exit 0
fi

# Print header
printf "${CYAN}Claude Code Instances:${NC}\n"
printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Print each instance
for pane_info in "${claude_panes[@]}"; do
    printf "  ${GREEN}•${NC} %s\n" "$pane_info"
done

printf "\n${YELLOW}Total: ${#claude_panes[@]} instance(s)${NC}\n"
