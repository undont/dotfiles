#!/usr/bin/env bash
# Undo file path definitions for tmux scripts
# Source this file after common.sh

# Create a secure temporary directory for this user
# Using a user-specific subdirectory improves security
get_undo_base_dir() {
    local base_dir="/tmp/tmux-undo-${UID:-$(id -u)}"

    if [[ ! -d "$base_dir" ]]; then
        mkdir -p "$base_dir"
        chmod 700 "$base_dir"
    fi

    echo "$base_dir"
}

# Pane undo paths
get_pane_undo_file() {
    echo "$(get_undo_base_dir)/pane"
}

get_pane_undo_state() {
    echo "$(get_undo_base_dir)/pane-state.txt"
}

get_pane_undo_content() {
    echo "$(get_undo_base_dir)/pane-content.txt"
}

# Window undo paths
get_window_undo_file() {
    echo "$(get_undo_base_dir)/window"
}

get_window_undo_state() {
    echo "$(get_undo_base_dir)/window-state.txt"
}

get_window_undo_contents_dir() {
    local dir
    dir="$(get_undo_base_dir)/window-contents"
    mkdir -p "$dir"
    chmod 700 "$dir"
    echo "$dir"
}

# Session undo paths
get_session_undo_file() {
    echo "$(get_undo_base_dir)/session"
}

get_session_undo_state() {
    echo "$(get_undo_base_dir)/session-state.txt"
}

get_session_undo_backup() {
    echo "$(get_undo_base_dir)/session-backup"
}

# Clean up undo files for a specific type
# Usage: cleanup_undo_files "pane" | "window" | "session"
cleanup_undo_files() {
    local type="$1"
    local base_dir
    base_dir=$(get_undo_base_dir)

    case "$type" in
        pane)
            rm -f "$base_dir/pane" "$base_dir/pane-state.txt" "$base_dir/pane-content.txt"
            ;;
        window)
            rm -f "$base_dir/window" "$base_dir/window-state.txt"
            rm -rf "$base_dir/window-contents"
            mkdir -p "$base_dir/window-contents"
            chmod 700 "$base_dir/window-contents"
            ;;
        session)
            rm -f "$base_dir/session" "$base_dir/session-state.txt"
            rm -rf "$base_dir/session-backup"
            ;;
        *)
            error "Unknown undo type: $type"
            return 1
            ;;
    esac
}

# Get the most recent undo type based on file timestamps
get_most_recent_undo_type() {
    local base_dir
    base_dir=$(get_undo_base_dir)

    local pane_time=0 window_time=0 session_time=0

    [[ -f "$base_dir/pane" ]] && pane_time=$(stat -f %m "$base_dir/pane" 2>/dev/null || echo 0)
    [[ -f "$base_dir/window" ]] && window_time=$(stat -f %m "$base_dir/window" 2>/dev/null || echo 0)
    [[ -f "$base_dir/session" ]] && session_time=$(stat -f %m "$base_dir/session" 2>/dev/null || echo 0)

    if [[ $pane_time -ge $window_time && $pane_time -ge $session_time && $pane_time -gt 0 ]]; then
        echo "pane"
    elif [[ $window_time -ge $session_time && $window_time -gt 0 ]]; then
        echo "window"
    elif [[ $session_time -gt 0 ]]; then
        echo "session"
    else
        echo ""
    fi
}

# ═════════════════════════════════════════════════════════════════
# Resurrect Path Discovery
# ═════════════════════════════════════════════════════════════════
# The functions below discover where tmux-resurrect stores session data.
# They check both XDG-compliant and legacy locations.

# Get the resurrect data directory
# Returns the directory where tmux-resurrect stores its data
#
# Usage: RESURRECT_DIR=$(get_resurrect_dir)
# Output: Path to resurrect directory
get_resurrect_dir() {
    # Check for existing 'last' symlink (best indicator)
    if [[ -L "${HOME}/.tmux/resurrect/last" || -f "${HOME}/.tmux/resurrect/last" ]]; then
        echo "${HOME}/.tmux/resurrect"
    elif [[ -L "${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect/last" || -f "${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect/last" ]]; then
        echo "${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect"
    # Fall back to checking for sessions directory
    elif [[ -d "${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect/sessions" ]]; then
        echo "${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect"
    elif [[ -d "${HOME}/.tmux/resurrect/sessions" ]]; then
        echo "${HOME}/.tmux/resurrect"
    # Default to legacy location if neither exists
    else
        echo "${HOME}/.tmux/resurrect"
    fi
}

# Get the resurrect sessions directory
# Returns the directory where session state files are stored
#
# Usage: SESSIONS_DIR=$(get_resurrect_sessions_dir)
# Output: Path to resurrect sessions directory
get_resurrect_sessions_dir() {
    local resurrect_dir
    resurrect_dir=$(get_resurrect_dir)
    echo "${resurrect_dir}/sessions"
}
