#!/usr/bin/env bash
# List all running Gemini CLI instances across all tmux sessions
# Shows session, window, and pane information for each instance
#
# Usage: list-gemini.sh [--verbose]
#   --verbose: Show coloured output with header (default: fzf-friendly format)

set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/_lib/common.sh"
source "$SCRIPT_DIR/_lib/alerts.sh"

# Check if tmux is available
if ! command -v tmux &>/dev/null;
then
    if [[ "${1:-}" == "--verbose" ]]; then
        error "tmux is not installed"
    fi
    exit 1
fi

# Check if any sessions exist
if ! tmux list-sessions &>/dev/null;
then
    if [[ "${1:-}" == "--verbose" ]]; then
        info "No tmux sessions running"
    fi
    exit 0
fi

# Store results
gemini_panes=()

# Iterate through all panes in all sessions
while IFS= read -r line; do
    # Parse the pane info: session:window_index.pane_index command
    session=$(echo "$line" | cut -d: -f1)
    window_idx=$(echo "$line" | cut -d: -f2 | cut -d. -f1)
    pane_idx=$(echo "$line" | cut -d. -f2 | cut -d' ' -f1)
    command=$(echo "$line" | cut -d' ' -f2-)

    # Check if the command is gemini
    if [[ "$command" == "gemini" ]]; then
        # Get window name for better display
        window_name=$(tmux list-windows -t "$session" -F '#{window_index} #{window_name}' | grep "^$window_idx " | cut -d' ' -f2-)

        # Build target (session:window.pane)
        target="${session}:${window_idx}.${pane_idx}"

        # Check if this window has an alert for gemini
        # New format: session:window:agent
        if [[ -f "$ALERTS_FILE" ]] && grep -q "^${session}:${window_name}:gemini$" "$ALERTS_FILE" 2>/dev/null; then
            gemini_panes+=("${target} ${window_name} 🤖")
        else
            gemini_panes+=("${target} ${window_name}")
        fi
    fi
done < <(tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_current_command}')

# Display results
if [[ ${#gemini_panes[@]} -eq 0 ]]; then
    if [[ "${1:-}" == "--verbose" ]]; then
        info "No Gemini CLI instances running"
    fi
    exit 0
fi

# Verbose mode: coloured output with header
if [[ "${1:-}" == "--verbose" ]]; then
    printf "${CYAN}Gemini CLI Instances:${NC}\n"
    printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    for pane_info in "${gemini_panes[@]}"; do
        printf "  ${GREEN}•${NC} %s\n" "$pane_info"
    done

    printf "\n${YELLOW}Total: ${#gemini_panes[@]} instance(s)${NC}\n"
else
    # FZF mode: simple list
    for pane_info in "${gemini_panes[@]}"; do
        echo "$pane_info"
    done

    # Add Gemini robot at bottom (Dracula Cyan: #8be9fd ≈ 117)
    echo ""
    printf "\033[38;5;117m   🤖   \033[0m\n"
    printf "\033[38;5;117m  /  \\  \033[0m\n"
fi
