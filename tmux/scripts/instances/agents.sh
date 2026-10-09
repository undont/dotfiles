#!/usr/bin/env bash
# list all running codex, opencode or copilot instances across all tmux sessions
# shows a logo header then one "session:window.pane window_name [icon]" row per
# instance, most recently viewed first. claude has its own lister (claude.sh)
# usage: agents.sh <codex|opencode|copilot>

set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"
source "$SCRIPT_DIR/../_lib/alerts.sh"
source "$SCRIPT_DIR/../_lib/process.sh"

agent="${1:-}"
case "$agent" in
    codex | opencode | copilot) ;;
    *)
        echo "usage: agents.sh <codex|opencode|copilot>" >&2
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

panes=()

# all panes, most recently viewed first: "last_viewed session:window.pane pane_pid"
while IFS= read -r line; do
    rest="${line#* }"
    target="${rest%% *}"
    pane_pid="${rest##* }"

    [[ -n "${agent_pids[$pane_pid]:-}" ]] || continue

    session="${target%%:*}"
    win_pane="${target#*:}"
    window_idx="${win_pane%%.*}"
    window_name="${window_names["${session}:${window_idx}"]:-}"

    if alerts_has_agent "$alerts_content" "$agent" "$session" "$window_name" "${window_ids["${session}:${window_idx}"]:-}"; then
        display=$(get_agent_display "$agent")
        icon="${display%%|*}"
        [[ "$agent" == copilot ]] && icon=$(_ansi "${display##*|}" "$icon")
        panes+=("${target} ${window_name} ${icon}")
    else
        panes+=("${target} ${window_name}")
    fi
done < <(tmux list-panes -a -F '#{?#{@pane-viewed},#{@pane-viewed},0} #{session_name}:#{window_index}.#{pane_index} #{pane_pid}' | sort -rn)

# the header height here is the binding's --header-lines in tmux.conf.template
echo ""
case "$agent" in
    codex)
        printf "${GREEN}█▀▀ █▀▀█ █▀▀▄ █▀▀ █ █${NC}\n"
        printf "${GREEN}█   █  █ █  █ █▀▀ ▄▀▄${NC}\n"
        printf "${GREEN}▀▀▀ ▀▀▀▀ ▀▀▀  ▀▀▀ ▀ ▀${NC}\n"
        echo ""
        ;;
    opencode)
        # two-tone blue from the theme's cyan accent
        load_fzf_theme
        accent_cyan="${TMUX_ACCENT_CYAN:-#8be9fd}"
        dark=$(hex_fg "$(hex_dim "$accent_cyan" 65)")
        light=$(hex_fg "$accent_cyan")
        printf "${dark}█▀▀█ █▀▀█ █▀▀█ █▀▀▄${NC} ${light}█▀▀ █▀▀█ █▀▀▄ █▀▀█${NC}\n"
        printf "${dark}█  █ █  █ █▀▀▀ █  █${NC} ${light}█   █  █ █  █ █▀▀▀${NC}\n"
        printf "${dark}▀▀▀▀ █▀▀▀ ▀▀▀▀ ▀  ▀${NC} ${light}▀▀▀ ▀▀▀▀ ▀▀▀▀ ▀▀▀▀${NC}\n"
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

for pane_info in ${panes[@]+"${panes[@]}"}; do
    echo "$pane_info"
done
