#!/usr/bin/env bash
# Alert picker — lists active alerts and navigates to the selected one
# If only one alert exists, jumps directly without showing a picker.

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"
source "$SCRIPT_DIR/../_lib/alerts.sh"
source "$SCRIPT_DIR/../_lib/ui.sh"

# Load current theme colours for fzf
load_fzf_theme

CURRENT_SESSION=$(tmux display-message -p '#S' 2>/dev/null)
CURRENT_WINDOW=$(tmux display-message -p '#W' 2>/dev/null)

if [[ ! -f "$ALERTS_FILE" ]] || [[ ! -s "$ALERTS_FILE" ]]; then
    show_centered_message "Alerts" "No active alerts"
    read -rsn1
    exit 0
fi

# --list mode: output entries only (used by fzf reload-sync)
LIST_MODE=0
[[ "${1:-}" == "--list" ]] && LIST_MODE=1

# Load entries from alerts file
_load_entries() {
    local entries=()
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        IFS=':' read -r session window field3 field4 field5 <<< "$line"
        [[ -z "$session" || -z "$window" || -z "$field3" ]] && continue

        # Skip alerts for the current window (already visible)
        [[ "$session" == "$CURRENT_SESSION" && "$window" == "$CURRENT_WINDOW" ]] && continue

        local target="${session}:${window}"
        local icon colour display label

        if [[ "$field3" == "exit" ]]; then
            label="$field5"
            display=$(get_exit_code_display "$field4")
            icon="${display%%|*}"
            colour="${display##*|}"
        else
            label="$field3"
            display=$(get_agent_display "$field3")
            icon="${display%%|*}"
            colour="${display##*|}"
        fi

        entries+=("$(printf '\033[38;2;%d;%d;%dm%s  %s  %s\033[0m' \
            "0x${colour:1:2}" "0x${colour:3:2}" "0x${colour:5:2}" \
            "$icon" "$target" "$label")")
    done < "$ALERTS_FILE"

    printf '%s\n' "${entries[@]}"
}

# Extract session:window target from a picker line (strip ANSI, grab field 2)
_extract_target() {
    printf '%s' "$1" | sed 's/\x1b\[[0-9;]*m//g' | awk '{print $2}'
}

entries=$(_load_entries)
count=$(printf '%s\n' "$entries" | grep -c .)

# --list mode: just output entries for fzf reload (empty if none)
if [[ $LIST_MODE -eq 1 ]]; then
    printf '%s\n' "$entries"
    exit 0
fi

# Check if all alerts are on current window (filtered out)
if [[ $count -eq 0 ]] && [[ -f "$ALERTS_FILE" ]] && [[ -s "$ALERTS_FILE" ]]; then
    show_centered_message "Alerts" "Alert is on current window"
    read -rsn1
    exit 0
fi

# No alerts — show message and wait
if [[ $count -eq 0 ]]; then
    show_centered_message "Alerts" "No active alerts"
    read -rsn1
    exit 0
fi

# Show fzf picker (handles single or multiple alerts)
selected=$(printf '%s\n' "$entries" | fzf \
    --ansi --reverse --exact --cycle \
    --no-info --no-header \
    --prompt ': ' \
    --border=rounded \
    --color="label:${TMUX_FG_PRIMARY:-#ffffff}" \
    --border-label=' j/k · spc/⏎ sel · x clear · / srch · q/esc ' \
    --border-label-pos=bottom \
    --bind 'j:down,k:up,q:abort,space:accept' \
    --bind 'enter:accept' \
    --bind 'change:transform:[[ $FZF_PROMPT == ": " ]] && echo "clear-query"' \
    --bind '/:enable-search+change-prompt(> )+unbind(j,k,q,space,x)' \
    --bind 'esc:transform:[[ $FZF_PROMPT == "> " ]] && echo "disable-search+clear-query+change-prompt(: )+rebind(j,k,q,space,x)" || echo "abort"' \
    --bind 'ctrl-k:kill-line,ctrl-w:unix-line-discard' \
    --bind "x:execute-silent(
        target=\$(echo {} | sed 's/\x1b\[[0-9;]*m//g' | awk '{print \$2}')
        session=\${target%%:*}
        window=\${target#*:}
        $SCRIPT_DIR/clear.sh \"\$session\" \"\$window\"
    )+reload-sync($SCRIPT_DIR/pick.sh --list)")

[[ -z "$selected" ]] && exit 0

target=$(_extract_target "$selected")

if [[ -n "$target" ]]; then
    tmux switch-client -t "$target" 2>/dev/null
fi
