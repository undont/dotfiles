#!/usr/bin/env bash
# list all running OpenCode instances across all tmux sessions
# emits an 8-line header (logo + state legend) then tab-delimited rows for fzf:
#   {1}=display(shown)  {2}=jump/preview target session:window.pane
# state comes from the agent-state registry (_lib/alerts.sh agent_state_*),
# written by the opencode-tmux-alert plugin through
# scripts/hooks/wrappers/opencode-state.sh. no stuck derivation: opencode's
# pane title carries no activity spinner and the plugin only writes on state
# changes, so an old working state is just a long turn

set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"
source "$SCRIPT_DIR/../_lib/alerts.sh"
source "$SCRIPT_DIR/../_lib/process.sh"

if ! command -v tmux &>/dev/null; then
    exit 1
fi

if ! tmux list-sessions &>/dev/null; then
    exit 0
fi

declare -A active_opencode_ppids
while IFS= read -r pid; do
    active_opencode_ppids[$pid]=1
done < <(agent_pane_pids opencode)

# pre-fetch window names: "session:window_index window_name"
declare -A window_names
while IFS= read -r wline; do
    key="${wline%% *}"
    name="${wline#* }"
    window_names["$key"]="$name"
done < <(tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name}')

TAB=$(printf '\t')
now=$(date +%s)

# store results; track panes for the stale-state sweep below
opencode_panes=()
live_panes="" opencode_pane_ids=""

# iterate through all panes in all sessions, sorted by last viewed (most recent
# first). pane_title is last so an embedded tab in it can't shift other fields
while IFS="$TAB" read -r _viewed session window_idx pane_idx pane_id pane_pid title; do
    [[ -n "$pane_id" ]] || continue
    live_panes+="${pane_id}"$'\n'

    [[ -n "${active_opencode_ppids[$pane_pid]:-}" ]] || continue
    opencode_pane_ids+="${pane_id}"$'\n'

    target="${session}:${window_idx}.${pane_idx}"
    window_name="${window_names["${session}:${window_idx}"]:-}"

    # per-pane label from opencode's pane title ("OC | <session title>"), so
    # split panes don't all show the window name. squash tabs (title is
    # untrusted) and fall back to the window name until a session is titled
    label="${title//$TAB/ }"
    label="${label#"OC | "}"
    case "$label" in "" | OpenCode | opencode) label="$window_name" ;; esac

    state="" age=""
    IFS="$TAB" read -r state age <<<"$(agent_state_read opencode "$pane_id" "$now")"

    row=$(agent_state_row "$state" "$age" "$target" "$label")
    opencode_panes+=("${row}${TAB}${target}")
done < <(tmux list-panes -a -F "#{?#{@pane-viewed},#{@pane-viewed},0}${TAB}#{session_name}${TAB}#{window_index}${TAB}#{pane_index}${TAB}#{pane_id}${TAB}#{pane_pid}${TAB}#{pane_title}" | sort -rn)

# opportunistic GC: drop state files for panes that are gone, and opencode
# files for panes whose opencode has exited
agent_state_sweep opencode "$live_panes" "$opencode_pane_ids"

# two-tone blue logo from the theme's cyan accent
load_fzf_theme
accent_cyan="${TMUX_ACCENT_CYAN:-#8be9fd}"
dark=$(hex_fg "$(hex_dim "$accent_cyan" 65)")
light=$(hex_fg "$accent_cyan")
echo ""
printf "                                ${light}▄${NC}\n"
printf "${dark}█▀▀█ █▀▀█ █▀▀█ █▀▀▄${NC} ${light}█▀▀ █▀▀█ █▀▀█ █▀▀█${NC}\n"
printf "${dark}█  █ █  █ █▀▀▀ █  █${NC} ${light}█   █  █ █  █ █▀▀▀${NC}\n"
printf "${dark}▀▀▀▀ █▀▀▀ ▀▀▀▀ ▀  ▀${NC} ${light}▀▀▀ ▀▀▀▀ ▀▀▀▀ ▀▀▀▀${NC}\n"
echo ""

# state legend (line 7 of the 8-line header)
agent_state_legend
echo ""

# tab-delimited rows below the header (empty list shows just the header)
for pane_info in ${opencode_panes[@]+"${opencode_panes[@]}"}; do
    printf '%s\n' "$pane_info"
done
