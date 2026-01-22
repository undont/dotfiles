#!/usr/bin/env bash
# Common utilities for tmux scripts
# Source this file: source "${BASH_SOURCE%/*}/_lib/common.sh"

# Strict mode - scripts should set this themselves for clarity
# set -euo pipefail

# Determine dotfiles root from this library file's location
# Use readlink -f to resolve symlinks (or realpath if available)
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DOTFILES_ROOT="$(cd "$_LIB_DIR/../../../.." && pwd)"

# Source colour definitions
# shellcheck source=scripts/_lib/colours.sh
source "$DOTFILES_ROOT/scripts/_lib/colours.sh"

# Wrapper for tmux command that respects test socket
# When TMUX_TEST_SOCKET is set, all tmux commands use that socket
tmux() {
    if [[ -n "${TMUX_TEST_SOCKET:-}" ]]; then
        command tmux -L "$TMUX_TEST_SOCKET" "$@"
    else
        command tmux "$@"
    fi
}

# Load FZF theme colours from current theme
# Call this before using fzf to ensure it uses the active theme
load_fzf_theme() {
    if [[ -f "$DOTFILES_ROOT/scripts/fzf-theme.sh" ]]; then
        # shellcheck disable=SC1091
        source "$DOTFILES_ROOT/scripts/fzf-theme.sh"
    fi
}

# Print error message to stderr
error() {
    printf "${RED}Error:${NC} %s\n" "$1" >&2
}

# Print warning message to stderr
warn() {
    printf "${YELLOW}Warning:${NC} %s\n" "$1" >&2
}

# Print info message
info() {
    printf "${CYAN}%s${NC}\n" "$1"
}

# Print success message
success() {
    printf "${GREEN}%s${NC}\n" "$1"
}

# Show error via tmux display-message (visible after popup closes)
# Use this for errors in popup/fzf contexts instead of error()
show_error() {
    tmux display-message "Error: $1"
}

# Check if tmux is running
require_tmux() {
    if ! command -v tmux &>/dev/null; then
        error "tmux is not installed"
        exit 1
    fi

    # Skip the TMUX variable check if we're in test mode
    # Tests can set TMUX_TEST_MODE=1 to bypass the "inside tmux" requirement
    if [[ -z "${TMUX:-}" && "${TMUX_TEST_MODE:-0}" != "1" ]]; then
        error "Not running inside tmux"
        exit 1
    fi
}

# Sanitise session name (convert spaces and invalid chars to dashes, then trim trailing dashes)
sanitise_session_name() {
    local name="$1"
    echo "$name" | tr -c '[:alnum:]_.-' '-' | sed 's/-*$//'
}

# ═════════════════════════════════════════════════════════════════
# Session Validation
# ═════════════════════════════════════════════════════════════════

# Validate a tmux session name
# Session names must be alphanumeric with dots, underscores, and hyphens allowed.
#
# Usage:
#   if ! validate_session_name "$name"; then
#       exit 1
#   fi
#
# Note: This function outputs error messages via error() on failure.
#       Callers should NOT add additional error messages.
#
# Arguments:
#   $1 - Session name to validate
#
# Returns:
#   0 - Valid session name
#   1 - Invalid session name (empty or contains invalid characters)
#
validate_session_name() {
    local name="$1"

    if [[ -z "$name" ]]; then
        error "Session name cannot be empty"
        return 1
    fi

    # Session names should be alphanumeric with _ - . allowed
    if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        error "Invalid session name: '$name'. Use only letters, numbers, dots, underscores, hyphens."
        return 1
    fi

    return 0
}

# Validate pane ID format (e.g., %123)
validate_pane_id() {
    local pane_id="$1"

    if [[ -z "$pane_id" ]]; then
        error "Pane ID cannot be empty"
        return 1
    fi

    if [[ ! "$pane_id" =~ ^%[0-9]+$ ]]; then
        error "Invalid pane ID format: '$pane_id'"
        return 1
    fi

    return 0
}

# Validate window index format
validate_window_index() {
    local index="$1"

    if [[ -z "$index" ]]; then
        error "Window index cannot be empty"
        return 1
    fi

    if [[ ! "$index" =~ ^[0-9]+$ ]]; then
        error "Invalid window index: '$index'"
        return 1
    fi

    return 0
}

# Check if a session exists (exact match, not prefix)
session_exists() {
    local session="$1"
    tmux list-sessions -F '#{session_name}' 2>/dev/null | grep -qxF "$session"
}

# Get the number of windows in a session
get_window_count() {
    local session="$1"
    tmux list-windows -t "$session" 2>/dev/null | wc -l | tr -d ' '
}

# Check if this is the last session
is_last_session() {
    local count
    count=$(tmux list-sessions 2>/dev/null | wc -l | tr -d ' ')
    [[ "$count" -eq 1 ]]
}

# Check if this is the last window in session
is_last_window() {
    local count
    count=$(get_window_count "$(tmux display-message -p '#{session_name}')")
    [[ "$count" -eq 1 ]]
}

# Check if this is the last pane in window
is_last_pane() {
    local count
    count=$(get_pane_count)
    [[ "$count" -eq 1 ]]
}
