#!/usr/bin/env bash
# build a resolved launcher (data.sh) as a tmux session
# source this file: source "${BASH_SOURCE%/*}/../lib/tmux.sh"

[[ -n "${_LAUNCHER_TMUX_SH_LOADED:-}" ]] && return 0
_LAUNCHER_TMUX_SH_LOADED=1

# shellcheck source=tmux/scripts/_lib/common.sh
source "${BASH_SOURCE%/*}/../../tmux/scripts/_lib/common.sh"

tmux_sessions() {
    tmux list-sessions -F '#{session_name}' 2>/dev/null || true
}

tmux_session_exists() {
    session_exists "$1"
}

tmux_focus_session() {
    focus_session "=$1"
}

# one line per window and pane, as shell words: W <name> <auto_rename> <focus>,
# then P <split> <of> <size> <dir> <cmd> <focus> for each of its panes
# shellcheck disable=SC2016 # jq source
_tmux_launch_steps() {
    jq -r '.windows[] |
        (["W", (.name // ""), .auto_rename, .focus] | @sh),
        (.panes[] | ["P", (.split // ""), (.of // ""), (.size // ""), .dir, .cmd, .focus] | @sh)' <<<"$1"
}

# usage: tmux_launch RESOLVED_JSON
tmux_launch() {
    local json="$1" name session cols rows line
    name=$(jq -r .name <<<"$json")
    session=$(jq -r .session <<<"$json")
    if tmux_session_exists "$session"; then
        tmux_focus_session "$session"
        return
    fi

    # tmux builds a detached session at 80x24 and the resize on attach hands out
    # the difference unevenly, which skews percentage splits
    cols=$(tmux display-message -p '#{client_width}' 2>/dev/null || true)
    rows=$(tmux display-message -p '#{client_height}' 2>/dev/null || true)
    [[ -n "$cols" ]] || cols=$(tput cols 2>/dev/null || echo 80)
    [[ -n "$rows" ]] || rows=$(tput lines 2>/dev/null || echo 24)

    local -a step panes=() auto_windows=() focus_panes=() sizing
    local created=0 window="" focus_window="" kind wname auto wfocus split of size dir cmd pfocus pane named
    while IFS= read -r line; do
        eval "step=($line)"
        kind="${step[0]}"
        if [[ "$kind" == W ]]; then
            wname="${step[1]}" auto="${step[2]}" wfocus="${step[3]}"
            window="" panes=()
            continue
        fi
        split="${step[1]}" of="${step[2]}" size="${step[3]}" dir="${step[4]}" cmd="${step[5]}" pfocus="${step[6]}"
        if [[ -z "$window" ]]; then
            named=()
            [[ -n "$wname" ]] && named=(-n "$wname")
            if [[ $created -eq 0 ]]; then
                line=$(tmux new-session -d -s "$session" "${named[@]}" -c "$dir" -x "$cols" -y "$rows" \
                    -P -F '#{window_id} #{pane_id}')
                tmux set-option -t "=$session:" @launcher "$name"
                created=1
            else
                line=$(tmux new-window -d -t "=$session:" "${named[@]}" -c "$dir" -P -F '#{window_id} #{pane_id}')
            fi
            window="${line% *}"
            pane="${line#* }"
            [[ "$wfocus" == true ]] && focus_window="$window"
            [[ "$auto" == true ]] && auto_windows+=("$window")
        else
            sizing=()
            [[ -n "$size" ]] && sizing=(-l "$size%")
            pane=$(tmux split-window -d -t "${panes[of - 1]}" "-$split" "${sizing[@]}" -c "$dir" -P -F '#{pane_id}')
        fi
        panes+=("$pane")
        if [[ -n "$cmd" ]]; then
            tmux send-keys -t "$pane" -l "$cmd"
            tmux send-keys -t "$pane" Enter
        fi
        [[ "$pfocus" == true ]] && focus_panes+=("$pane")
    done < <(_tmux_launch_steps "$json")

    for window in "${auto_windows[@]}"; do
        tmux set-option -w -t "$window" automatic-rename on
    done
    for pane in "${focus_panes[@]}"; do
        tmux select-pane -t "$pane"
    done
    tmux select-window -t "$focus_window"
    tmux_focus_session "$session"
}
