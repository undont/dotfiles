#!/usr/bin/env bash
# Undo file path definitions for tmux scripts
# Source this file after common.sh

# Undo path constants (XDG-compliant)
# Stores kill/undo state in XDG cache directory instead of /tmp
# Migration: Old files in /tmp are checked as fallback

# Get the undo base directory (XDG-compliant)
# Returns ${XDG_CACHE_HOME}/tmux/undo or fallback to legacy /tmp location
get_undo_base_dir() {
    local xdg_undo_dir="${XDG_CACHE_HOME:-$HOME/.cache}/tmux/undo"
    local legacy_undo_dir="/tmp/tmux-undo-${UID:-$(id -u)}"

    # Prefer XDG location (create if needed)
    if [[ ! -d "$xdg_undo_dir" ]]; then
        mkdir -p "$xdg_undo_dir" 2>/dev/null || true
    fi

    if [[ -d "$xdg_undo_dir" ]]; then
        echo "$xdg_undo_dir"
    else
        # Fallback to legacy location
        echo "$legacy_undo_dir"
    fi
}

# Legacy compatibility: Check both XDG and /tmp locations for undo files
UNDO_BASE_DIR=$(get_undo_base_dir)
readonly UNDO_BASE_DIR

# Legacy undo directory for migration lookups
LEGACY_UNDO_DIR="/tmp/tmux-undo-${UID:-$(id -u)}"
readonly LEGACY_UNDO_DIR

# Migrate undo file from legacy /tmp location to XDG location
# Used by undo scripts to check for files in old location
#
# Usage: migrate_undo_file "pane" "session:window.pane"
# Arguments:
#   $1 - Type (pane, window, session)
#   $2 - Identifier (e.g., "session:window.pane")
#
# Returns: Path to undo file (XDG location), migrating from legacy if needed
migrate_undo_file() {
    local type="$1"
    local identifier="$2"
    local legacy_file="${LEGACY_UNDO_DIR}/${type}/${identifier}"
    local xdg_file="${UNDO_BASE_DIR}/${type}/${identifier}"

    # If file exists in legacy location and not in XDG location, migrate it
    if [[ -f "$legacy_file" && ! -f "$xdg_file" ]]; then
        # Create XDG subdirectory if needed
        mkdir -p "$(dirname "$xdg_file")" 2>/dev/null || return 1

        # Move file from legacy to XDG location
        if mv "$legacy_file" "$xdg_file" 2>/dev/null; then
            # Clean up empty legacy directory
            rmdir "$(dirname "$legacy_file")" 2>/dev/null || true
            rmdir "$LEGACY_UNDO_DIR" 2>/dev/null || true
        fi
    fi

    # Return XDG location (migration complete or file already there)
    echo "$xdg_file"
}

# Check if undo file exists in either XDG or legacy location
# Returns: Path to found file, or empty string if not found
#
# Usage: UNDO_FILE=$(find_undo_file "pane" "session:window.pane")
find_undo_file() {
    local type="$1"
    local identifier="$2"
    local xdg_file="${UNDO_BASE_DIR}/${type}/${identifier}"
    local legacy_file="${LEGACY_UNDO_DIR}/${type}/${identifier}"

    # Check XDG location first
    if [[ -f "$xdg_file" ]]; then
        echo "$xdg_file"
        return 0
    fi

    # Check legacy location
    if [[ -f "$legacy_file" ]]; then
        echo "$legacy_file"
        return 0
    fi

    # Not found
    return 1
}

# Migrate a flat undo file from legacy to XDG location
# Usage: _migrate_flat_undo_file "pane-state.txt"
# Returns: XDG path to the file
_migrate_flat_undo_file() {
    local filename="$1"
    local xdg_file="${UNDO_BASE_DIR}/${filename}"
    local legacy_file="${LEGACY_UNDO_DIR}/${filename}"

    if [[ -f "$legacy_file" && ! -f "$xdg_file" ]]; then
        mkdir -p "$(dirname "$xdg_file")" 2>/dev/null || true
        mv "$legacy_file" "$xdg_file" 2>/dev/null || true
        rmdir "$LEGACY_UNDO_DIR" 2>/dev/null || true
    fi

    echo "$xdg_file"
}

# Pane undo paths
get_pane_undo_file()    { _migrate_flat_undo_file "pane"; }
get_pane_undo_state()   { _migrate_flat_undo_file "pane-state.txt"; }
get_pane_undo_content() { _migrate_flat_undo_file "pane-content.txt"; }

# Window undo paths
get_window_undo_file()  { _migrate_flat_undo_file "window"; }
get_window_undo_state() { _migrate_flat_undo_file "window-state.txt"; }

get_window_undo_contents_dir() {
    local dir="${UNDO_BASE_DIR}/window-contents"
    mkdir -p "$dir"
    chmod 700 "$dir"

    # Migrate legacy window-contents directory if it exists
    local legacy_dir="${LEGACY_UNDO_DIR}/window-contents"
    if [[ -d "$legacy_dir" && ! -d "$dir" ]]; then
        mv "$legacy_dir" "$dir" 2>/dev/null || true
    fi

    echo "$dir"
}

# Session undo paths
get_session_undo_file()  { _migrate_flat_undo_file "session"; }
get_session_undo_state() { _migrate_flat_undo_file "session-state.txt"; }

get_session_undo_backup() {
    local xdg_file="${UNDO_BASE_DIR}/session-backup"
    local legacy_file="${LEGACY_UNDO_DIR}/session-backup"

    # Directory migration (not file)
    if [[ -d "$legacy_file" && ! -d "$xdg_file" ]]; then
        mkdir -p "$(dirname "$xdg_file")" 2>/dev/null || true
        mv "$legacy_file" "$xdg_file" 2>/dev/null || true
    fi

    echo "$xdg_file"
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

    # Platform-aware stat for modification time
    local stat_cmd
    if [[ "$(uname)" == "Darwin" ]]; then
        stat_cmd=(stat -f %m)
    else
        stat_cmd=(stat -c %Y)
    fi

    [[ -f "$base_dir/pane" ]] && pane_time=$("${stat_cmd[@]}" "$base_dir/pane" 2>/dev/null || echo 0)
    [[ -f "$base_dir/window" ]] && window_time=$("${stat_cmd[@]}" "$base_dir/window" 2>/dev/null || echo 0)
    [[ -f "$base_dir/session" ]] && session_time=$("${stat_cmd[@]}" "$base_dir/session" 2>/dev/null || echo 0)

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
