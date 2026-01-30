#!/usr/bin/env bash
# List all running nvim instances across all tmux sessions
# Shows session, window, pane, and cwd information for each instance

set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/_lib/common.sh"

# Check if tmux is available
if ! command -v tmux &>/dev/null; then
    exit 1
fi

# Check if any sessions exist
if ! tmux list-sessions &>/dev/null; then
    exit 0
fi

# Find nvim sockets and map PID -> socket
declare -A socket_map=()
while IFS= read -r sock; do
    [[ -z "$sock" ]] && continue
    pid=$(basename "$sock" | sed 's/nvim\.\([0-9]*\)\..*/\1/')
    socket_map[$pid]="$sock"
done < <(find "${TMPDIR}nvim.${USER}" -type s -name "nvim.*" 2>/dev/null || true)

# Store results
nvim_panes=()

# Iterate through all panes in all sessions, sorted by last viewed (most recent first)
while IFS= read -r line; do
    # Parse the pane info: last_viewed session:window_index.pane_index pane_pid command
    # last_viewed=$(echo "$line" | cut -d' ' -f1)  # Unused: for sorting only
    session=$(echo "$line" | cut -d' ' -f2 | cut -d: -f1)
    window_idx=$(echo "$line" | cut -d: -f2 | cut -d. -f1)
    pane_idx=$(echo "$line" | cut -d. -f2 | cut -d' ' -f1)
    pane_pid=$(echo "$line" | cut -d' ' -f3)
    command=$(echo "$line" | cut -d' ' -f4-)

    # Check if the command is nvim
    if [[ "$command" == "nvim" ]]; then
        # Get window name for better display
        window_name=$(tmux list-windows -t "$session" -F '#{window_index} #{window_name}' | grep "^$window_idx " | cut -d' ' -f2-)

        # Build target (session:window.pane)
        target="${session}:${window_idx}.${pane_idx}"

        # Find the nvim socket for this pane (check nvim PID and children)
        socket=""
        # First check if pane_pid itself is nvim
        if [[ -n "${socket_map[$pane_pid]:-}" ]]; then
            socket="${socket_map[$pane_pid]}"
        else
            # Check child processes for nvim
            for nvim_pid in "${!socket_map[@]}"; do
                # Check if nvim_pid is a descendant of pane_pid
                check_pid="$nvim_pid"
                for _ in {1..5}; do
                    if [[ "$check_pid" == "$pane_pid" ]]; then
                        socket="${socket_map[$nvim_pid]}"
                        break 2
                    fi
                    check_pid=$(ps -o ppid= -p "$check_pid" 2>/dev/null | tr -d ' ')
                    [[ -z "$check_pid" || "$check_pid" == "1" ]] && break
                done
            done
        fi

        # Get cwd if we have a socket
        cwd=""
        if [[ -n "$socket" ]]; then
            nvim_pid=$(basename "$socket" | sed 's/nvim\.\([0-9]*\)\..*/\1/')
            if [[ -d "/proc/$nvim_pid/cwd" ]]; then
                cwd=$(readlink "/proc/$nvim_pid/cwd" 2>/dev/null)
            else
                cwd=$(lsof -a -p "$nvim_pid" -d cwd -Fn 2>/dev/null | grep '^n/' | cut -c2-)
            fi
        fi

        # Build display: target window_name <tab> socket
        display="${target} ${window_name}"

        # Append socket path after tab for pick-nvim.sh to extract
        if [[ -n "$socket" ]]; then
            nvim_panes+=("${display}"$'\t'"${socket}")
        else
            nvim_panes+=("${display}"$'\t'"")
        fi
    fi
done < <(tmux list-panes -a -F '#{?#{@last-viewed},#{@last-viewed},0} #{session_name}:#{window_index}.#{pane_index} #{pane_pid} #{pane_current_command}' | sort -rn)

# Add NVIM logo at top (green: 107)
NVIM_GREEN="\033[38;5;107m"
NVIM_NC="\033[0m"
echo ""
printf "${NVIM_GREEN}███╗  ██╗██╗   ██╗██╗███╗   ███╗${NVIM_NC}\n"
printf "${NVIM_GREEN}██╔██╗██║██║   ██║██║██╔██╗██╔██║${NVIM_NC}\n"
printf "${NVIM_GREEN}██║╚████║╚██╗ ██╔╝██║██║╚██╔╝██║${NVIM_NC}\n"
printf "${NVIM_GREEN}██║ ╚███║ ╚████╔╝ ██║██║ ╚═╝ ██║${NVIM_NC}\n"
printf "${NVIM_GREEN}╚═╝  ╚══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝${NVIM_NC}\n"
echo ""

# Display results (empty list shows just the logo)
if [[ ${#nvim_panes[@]} -eq 0 ]]; then
    exit 0
fi

# Output list (display<tab>socket)
for pane_info in "${nvim_panes[@]}"; do
    echo "$pane_info"
done
