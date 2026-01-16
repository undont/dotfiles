#!/usr/bin/env bash
# Terminal UI utilities for tmux scripts
# Source this file after common.sh

# Display a visual confirmation for last window/pane scenarios
# Shows confirmation first, then switches to another session if user confirms
# Usage: tmux_confirm_last_item "window" "session_name" "target" "window_name"
#        tmux_confirm_last_item "pane" "session_name" "target" ""
tmux_confirm_last_item() {
    local item_type="$1"        # "window" or "pane"
    local current_session="$2"   # session being affected
    local target="$3"            # full target (e.g., "session:window" or "session:window.pane")
    local window_name="$4"       # window name (for clearing alerts, optional)
    
    local other_session
    other_session=$(find_other_session "$current_session")
    
    # Clear alerts before showing confirmation
    if [[ -n "$window_name" && "$item_type" == "window" ]]; then
        clear_window_alerts "$current_session" "$window_name"
    fi
    
    local title="Close Last ${item_type^}"
    local message command
    
    if [[ -n "$other_session" ]]; then
        # Build command that will switch session then kill
        message="This is the last ${item_type} in session '${current_session}'"
        command="tmux switch-client -t \"${other_session}\" \\; kill-${item_type} -t \"${target}\""
    else
        # No other session, killing this will kill the entire session
        message="This will kill session '${current_session}' (last ${item_type})"
        command="tmux kill-${item_type} -t \"${target}\""
    fi
    
    show_visual_confirm "$title" "$message" "$command"
    return $?
}

# Display a centered message box
# Usage: show_centered_message "Title" "Message line 1" "Message line 2" ...
show_centered_message() {
    local title="$1"
    shift
    local lines=("$@")

    # Calculate dimensions
    local max_width=0
    for line in "$title" "${lines[@]}"; do
        local len=${#line}
        ((len > max_width)) && max_width=$len
    done

    local box_width=$((max_width + 6))
    local box_height=$((${#lines[@]} + 4))

    # Use LINES/COLUMNS if set (tmux popup), otherwise fall back to tput
    local term_height term_width
    term_height=${LINES:-$(tput lines)}
    term_width=${COLUMNS:-$(tput cols)}

    local v_pad=$(( (term_height - box_height) / 2 ))
    [[ $v_pad -lt 0 ]] && v_pad=0

    local h_pad=$(( (term_width - box_width) / 2 ))
    [[ $h_pad -lt 0 ]] && h_pad=0

    local pad
    pad=$(printf '%*s' "$h_pad" '')

    clear

    # Vertical padding
    for ((i=0; i<v_pad; i++)); do
        printf '\n'
    done

    # Title
    printf '%s\033[38;5;141m%s\033[0m\n' "$pad" "$title"
    printf '%s\033[38;5;60m%s\033[0m\n' "$pad" "$(printf '%.0s─' $(seq 1 ${#title}))"
    printf '\n'

    # Message lines
    for line in "${lines[@]}"; do
        printf '%s%s\n' "$pad" "$line"
    done

    printf '\n'
}

# Display a confirmation dialog (y/n)
# Usage: confirm_action "Are you sure?" && do_something
confirm_action() {
    local prompt="${1:-Are you sure?}"
    local response

    read -r -p "$prompt [y/N] " response
    [[ "$response" =~ ^[Yy]$ ]]
}

# Display a centered confirmation dialog
# Usage: show_centered_confirm "Title" "Message" && do_something
show_centered_confirm() {
    local title="$1"
    local message="$2"

    show_centered_message "$title" "$message" "" "Press y to confirm, any other key to cancel"

    local response
    read -rsn1 response
    [[ "$response" =~ ^[Yy]$ ]]
}

# Visual confirmation dialog using fzf with Yes/No options
# Usage: show_visual_confirm "Title" "Message"
# Returns: 0 if confirmed, 1 if cancelled
show_visual_confirm() {
    local title="$1"
    local message="$2"

    local choice
    choice=$(printf "yes\nno" | fzf \
        --height=100% --layout=reverse --disabled \
        --prompt=': ' \
        --border=rounded \
        --border-label=" ${title} " \
        --border-label-pos=top \
        --header="${message}" \
        --no-info \
        --pointer='▌' \
        --bind 'j:down,k:up,space:accept,enter:accept' \
        --bind 'change:clear-query' \
        --bind 'y:pos(1)+accept,n:pos(2)+accept' \
        --bind 'esc:abort,q:abort' \
        2>/dev/null) || return 1

    [[ "$choice" == "yes" ]]
}

# Wait for any key press
# Usage: wait_for_key "prompt" [true] - pass true as second arg to centre the prompt
wait_for_key() {
    local prompt="${1:-Press any key to continue...}"
    local centred="${2:-false}"

    if [[ "$centred" == "true" ]]; then
        local term_width
        term_width=${COLUMNS:-$(tput cols)}
        local h_pad=$(( (term_width - ${#prompt}) / 2 ))
        [[ $h_pad -lt 0 ]] && h_pad=0
        prompt=$(printf '%*s%s' "$h_pad" '' "$prompt")
    fi

    read -rsn1 -p "$prompt"
}

# Show a brief notification that auto-dismisses
# Usage: show_notification "Success!" 2
show_notification() {
    local message="$1"
    local duration="${2:-1}"

    # Use LINES/COLUMNS if set (tmux popup), otherwise fall back to tput
    local term_height term_width
    term_height=${LINES:-$(tput lines)}
    term_width=${COLUMNS:-$(tput cols)}

    local h_pad=$(( (term_width - ${#message}) / 2 ))
    [[ $h_pad -lt 0 ]] && h_pad=0

    local v_pad=$(( term_height / 2 ))

    clear
    for ((i=0; i<v_pad; i++)); do
        printf '\n'
    done

    printf '%*s\033[32m%s\033[0m\n' "$h_pad" '' "$message"

    sleep "$duration"
}
