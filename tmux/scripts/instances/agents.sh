#!/usr/bin/env bash
# list all running codex or copilot instances across all tmux sessions
# emits a logo header then tab-delimited rows for fzf, in claude.sh's format:
#   {1}=display(shown)  {2}=jump/preview target session:window.pane
# the display leads with the agent's alert icon while its window has an alert.
# most recently viewed first. agents with per-pane state have their own
# listers (claude.sh, opencode.sh)
# usage: agents.sh <codex|copilot>

set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"
source "$SCRIPT_DIR/../_lib/alerts.sh"
source "$SCRIPT_DIR/../_lib/process.sh"

agent="${1:-}"
case "$agent" in
    codex | copilot) ;;
    *)
        echo "usage: agents.sh <codex|copilot>" >&2
        exit 2
        ;;
esac

if ! command -v tmux &>/dev/null; then
    exit 1
fi

if ! tmux list-sessions &>/dev/null; then
    exit 0
fi

declare -A agent_pids
while IFS= read -r pid; do
    agent_pids[$pid]=1
done < <(agent_pane_pids "$agent")

# window names and ids keyed by "session:window_index". the id is what the
# alerts file matches on; the name is for display
declare -A window_names window_ids
while IFS=$'\t' read -r key wid name; do
    window_names["$key"]="$name"
    window_ids["$key"]="$wid"
done < <(tmux list-windows -a -F $'#{session_name}:#{window_index}\t#{window_id}\t#{window_name}')

alerts_content=""
if [[ -f "$ALERTS_FILE" ]]; then
    alerts_content=$(<"$ALERTS_FILE")
fi

TAB=$(printf '\t')

panes=()

# all panes, most recently viewed first
while IFS="$TAB" read -r _viewed session window_idx pane_idx pane_pid; do
    [[ -n "${agent_pids[$pane_pid]:-}" ]] || continue

    target="${session}:${window_idx}.${pane_idx}"
    window_name="${window_names["${session}:${window_idx}"]:-}"
    # blank status keeps targets aligned with rows that have an icon
    icon="  "

    if alerts_has_agent "$alerts_content" "$agent" "$session" "$window_name" "${window_ids["${session}:${window_idx}"]:-}"; then
        display=$(get_agent_display "$agent")
        icon="${display%%|*}"
        [[ "$agent" == copilot ]] && icon=$(_ansi "${display##*|}" "$icon")
    fi

    panes+=("${icon}  ${target} ${window_name}${TAB}${target}")
done < <(tmux list-panes -a -F "#{?#{@pane-viewed},#{@pane-viewed},0}${TAB}#{session_name}${TAB}#{window_index}${TAB}#{pane_index}${TAB}#{pane_pid}" | sort -rn)

# the header height here is the binding's --header-lines in tmux.conf.template
echo ""
case "$agent" in
    codex)
        printf "${GREEN}█▀▀ █▀▀█ █▀▀▄ █▀▀ █ █${NC}\n"
        printf "${GREEN}█   █  █ █  █ █▀▀ ▄▀▄${NC}\n"
        printf "${GREEN}▀▀▀ ▀▀▀▀ ▀▀▀  ▀▀▀ ▀ ▀${NC}\n"
        echo ""
        ;;
    copilot)
        # periwinkle eyes, purple/green mouth bar
        periwinkle="\033[38;5;147m"
        purple="\033[38;5;176m"
        mouth_green="\033[38;5;107m"
        printf "   ${periwinkle}╭─╮╭─╮${NC}\n"
        printf "   ${periwinkle}╰─╯╰─╯${NC}\n"
        printf "   ${purple}█${NC} ${mouth_green}▘▝${NC} ${purple}█${NC}\n"
        printf "    ${purple}▔▔▔▔${NC}\n"
        echo ""
        ;;
esac

# tab-delimited rows below the header
for pane_info in ${panes[@]+"${panes[@]}"}; do
    printf '%s\n' "$pane_info"
done
