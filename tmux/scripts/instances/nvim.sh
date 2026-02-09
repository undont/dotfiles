#!/usr/bin/env bash
# List all running nvim instances across all tmux sessions
# Shows session, window, pane, and cwd information for each instance

set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"

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

# Build PID -> PPID map for all nvim socket PIDs in one ps call.
# This avoids repeated ps calls when walking the process tree.
declare -A ppid_map=()
if [[ ${#socket_map[@]} -gt 0 ]]; then
    # Collect all PIDs we might need to walk (nvim pids + ancestors up to 5 levels)
    all_pids=()
    for pid in "${!socket_map[@]}"; do
        all_pids+=("$pid")
    done
    # Get ppid for all processes in one call (faster than per-pid ps)
    while IFS= read -r pline; do
        [[ -z "$pline" ]] && continue
        p_pid="${pline%% *}"
        p_pid="${p_pid// /}"
        p_ppid="${pline##* }"
        p_ppid="${p_ppid// /}"
        [[ "$p_pid" =~ ^[0-9]+$ ]] || continue
        ppid_map[$p_pid]="$p_ppid"
    done < <(ps -e -o pid=,ppid= 2>/dev/null)
fi

# Pre-fetch window names: "session:window_index window_name"
declare -A window_names
while IFS= read -r wline; do
    key="${wline%% *}"
    name="${wline#* }"
    window_names["$key"]="$name"
done < <(tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name}')

# Store results
nvim_panes=()

# Iterate through all panes in all sessions, sorted by last viewed (most recent first)
while IFS= read -r line; do
    # Parse: "last_viewed session:window_index.pane_index pane_pid command"
    rest="${line#* }"              # strip last_viewed
    target="${rest%% *}"           # session:window_index.pane_index
    rest2="${rest#* }"             # pane_pid command
    pane_pid="${rest2%% *}"        # pane_pid
    command="${rest2#* }"          # command

    # Check if the command is nvim
    [[ "$command" == "nvim" ]] || continue

    # Extract session and window_idx for lookups
    session="${target%%:*}"
    win_pane="${target#*:}"
    window_idx="${win_pane%%.*}"

    window_name="${window_names["${session}:${window_idx}"]:-}"

    # Find the nvim socket for this pane (check nvim PID and children)
    socket=""
    # First check if pane_pid itself is nvim
    if [[ -n "${socket_map[$pane_pid]:-}" ]]; then
        socket="${socket_map[$pane_pid]}"
    else
        # Check child processes for nvim using pre-built ppid_map
        for nvim_pid in "${!socket_map[@]}"; do
            check_pid="$nvim_pid"
            for _ in {1..5}; do
                if [[ "$check_pid" == "$pane_pid" ]]; then
                    socket="${socket_map[$nvim_pid]}"
                    break 2
                fi
                check_pid="${ppid_map[$check_pid]:-}"
                [[ -z "$check_pid" || "$check_pid" == "1" ]] && break
            done
        done
    fi

    # Build display: target window_name <tab> socket
    display="${target} ${window_name}"

    # Append socket path after tab for pick-nvim.sh to extract
    if [[ -n "$socket" ]]; then
        nvim_panes+=("${display}"$'\t'"${socket}")
    else
        nvim_panes+=("${display}"$'\t'"")
    fi
done < <(tmux list-panes -a -F '#{?#{@last-viewed},#{@last-viewed},0} #{session_name}:#{window_index}.#{pane_index} #{pane_pid} #{pane_current_command}' | sort -rn)

# Add NVIM logo at top (green: 107)
NVIM_GREEN="\033[38;5;107m"
echo ""
printf "${NVIM_GREEN}███╗  ██╗██╗   ██╗██╗███╗   ███╗${NC}\n"
printf "${NVIM_GREEN}██╔██╗██║██║   ██║██║██╔██╗██╔██║${NC}\n"
printf "${NVIM_GREEN}██║╚████║╚██╗ ██╔╝██║██║╚██╔╝██║${NC}\n"
printf "${NVIM_GREEN}██║ ╚███║ ╚████╔╝ ██║██║ ╚═╝ ██║${NC}\n"
printf "${NVIM_GREEN}╚═╝  ╚══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝${NC}\n"
echo ""

# Display results (empty list shows just the logo)
if [[ ${#nvim_panes[@]} -eq 0 ]]; then
    exit 0
fi

# Output list (display<tab>socket)
for pane_info in "${nvim_panes[@]}"; do
    echo "$pane_info"
done
