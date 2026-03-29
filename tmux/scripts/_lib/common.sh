#!/usr/bin/env bash
# Common utilities for tmux scripts
# Source this file: source "${BASH_SOURCE%/*}/_lib/common.sh"

# Guard against multiple sourcing
[[ -n "${_TMUX_COMMON_SH_LOADED:-}" ]] && return 0
_TMUX_COMMON_SH_LOADED=1

# Strict mode - scripts should set this themselves for clarity
# set -euo pipefail

# Determine dotfiles root from this library file's location
# Use readlink -f to resolve symlinks (or realpath if available)
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DOTFILES_ROOT="$(cd "$_LIB_DIR/../../.." && pwd)"

# Source colour definitions
# shellcheck source=scripts/_lib/colours.sh
source "$DOTFILES_ROOT/scripts/_lib/colours.sh"

# Convert hex colour (#RRGGBB) to ANSI truecolour foreground escape
# Usage: local c; c=$(hex_fg "#ff0000"); printf "${c}text${NC}\n"
hex_fg() {
    printf '\033[38;2;%d;%d;%dm' "0x${1:1:2}" "0x${1:3:2}" "0x${1:5:2}"
}

# Dim a hex colour by a percentage (0–100, where 100 = full brightness)
# Usage: dimmed=$(hex_dim "#8be9fd" 65)
hex_dim() {
    local hex="$1" pct="${2:-65}"
    printf '#%02x%02x%02x' \
        "$(( 16#${hex:1:2} * pct / 100 ))" \
        "$(( 16#${hex:3:2} * pct / 100 ))" \
        "$(( 16#${hex:5:2} * pct / 100 ))"
}

# Print the dotfiles ASCII art logo with theme-aware gradient
# Uses TMUX_ACCENT_CYAN → TMUX_ACCENT_PURPLE from the active theme
# Defaults to sage → forest gradient when no theme is loaded
# Call load_fzf_theme before this to ensure theme colours are available
# Usage: print_dotfiles_logo
# shellcheck disable=SC1003
print_dotfiles_logo() {
    local from="${TMUX_ACCENT_CYAN:-#8baf9e}"
    local to="${TMUX_ACCENT_PURPLE:-#38604a}"

    # Convert hex to RGB components
    local r1=$((16#${from:1:2})) g1=$((16#${from:3:2})) b1=$((16#${from:5:2}))
    local r2=$((16#${to:1:2})) g2=$((16#${to:3:2})) b2=$((16#${to:5:2}))

    # Logo lines (matching scripts/_lib/logo.txt)
    local lines=(
        '     _       _    __ _ _'
        '  __| | ___ | |_ / _(_) | ___  ___'
        ' / _` |/ _ \| __| |_| | |/ _ \/ __|'
        '| (_| | (_) | |_|  _| | |  __/\__ \'
        ' \__,_|\___/ \__|_| |_|_|\___||___/'
    )

    printf "\n"
    local i
    for i in 0 1 2 3 4; do
        local r=$(( r1 + (r2 - r1) * i / 4 ))
        local g=$(( g1 + (g2 - g1) * i / 4 ))
        local b=$(( b1 + (b2 - b1) * i / 4 ))
        printf "\033[38;2;%d;%d;%dm%s${NC}\n" "$r" "$g" "$b" "${lines[$i]}"
    done
    printf "\n"
}

# Launcher path constants
DOTFILES_LAUNCHERS="$DOTFILES_ROOT/launchers"
USER_LAUNCHERS="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/launchers"
LAUNCHER_HISTORY="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/launcher-history"
THEME_HISTORY="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/theme-history"
THEME_FAVOURITES="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/theme-favourites"

# Wrapper for tmux command that respects test socket
# When TMUX_TEST_SOCKET is set, all tmux commands use that socket.
# Exported so subshells (e.g. pipefail-safety tests) inherit the isolation.
tmux() {
    if [[ -n "${TMUX_TEST_SOCKET:-}" ]]; then
        command tmux -L "$TMUX_TEST_SOCKET" "$@"
    else
        command tmux "$@"
    fi
}
export -f tmux

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

# Check if fzf is available
require_fzf() {
    if ! command -v fzf &>/dev/null; then
        error "fzf is not installed (required for this picker)"
        exit 1
    fi
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

# Sanitise a launcher name for use as a filename
# - Lowercase, replace invalid chars with hyphen, strip leading dots/dashes
# - Truncate to 64 characters
# - Suffix reserved words to avoid shadowing shell builtins
# Usage: sanitised=$(sanitise_launcher_name "My Launcher!")
sanitise_launcher_name() {
    local raw="$1"
    raw=$(printf '%s' "$raw" | tr -c '[:alnum:]_.-' '-' | tr '[:upper:]' '[:lower:]')
    raw="${raw#"${raw%%[[:alnum:]_]*}"}"
    raw="${raw:0:64}"
    case "$raw" in
        test|cd|ls|rm|cp|mv|cat|echo|printf|export|source|exec|eval|exit) raw="${raw}_launcher" ;;
    esac
    printf '%s' "$raw"
}

# Sanitise session name (convert spaces, dots, and invalid chars to dashes, then trim trailing dashes)
# Note: dots are replaced because tmux uses '.' as a separator in target syntax (session:window.pane)
sanitise_session_name() {
    local name="$1"
    echo "$name" | tr -c '[:alnum:]_-' '-' | sed 's/-*$//'
}

# ═════════════════════════════════════════════════════════════════
# Session Validation
# ═════════════════════════════════════════════════════════════════

# Validate a tmux session name
# Session names must be alphanumeric with underscores and hyphens allowed.
# Dots are NOT allowed because tmux uses '.' as a separator in target syntax.
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

    # Session names should be alphanumeric with _ - allowed (no dots — tmux uses '.' as pane separator)
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        error "Invalid session name: '$name'. Use only letters, numbers, underscores, hyphens."
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

# Check if a pane is running a specific command by inspecting child processes
# Many CLI tools (Claude Code, OpenCode) run as child processes of the pane
# shell, so pane_current_command shows the runtime (e.g. Node.js version)
# rather than the tool name. This checks the process tree directly.
# Excludes suspended (Ctrl+Z) processes — only matches active foreground ones.
#
# Usage:
#   is_pane_running <pane_pid> <command_name> [-f]
#     -f  match against full command line (default: exact process name)
#
# Examples:
#   is_pane_running "$pane_pid" "claude"            # exact match
#   is_pane_running "$pane_pid" "opencode" -f       # command line match
is_pane_running() {
    local pane_pid="$1"
    local command_name="$2"
    local match_flag="-x"
    [[ "${3:-}" == "-f" ]] && match_flag="-f"

    local pid
    pid=$(pgrep -P "$pane_pid" "$match_flag" "$command_name" 2>/dev/null) || return 1
    # Filter out stopped/suspended processes (state 'T')
    [[ "$(ps -o state= -p "$pid" 2>/dev/null)" != T* ]]
}

# List project directories from PROJECT_DIRS (colon-separated, like PATH)
# Outputs paths with ~ prefix for display, one per line
# Uses fd if available, falls back to find
list_project_dirs() {
    local project_dirs="${PROJECT_DIRS:-$HOME/src}"
    local roots
    IFS=':' read -ra roots <<< "$project_dirs"
    for root in "${roots[@]}"; do
        [[ -n "$root" ]] || continue
        root="${root/#\~/$HOME}"
        [[ -d "$root" ]] || continue
        if command -v fd &>/dev/null; then
            fd --type d --max-depth 1 . "$root" 2>/dev/null
        else
            find "$root" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort
        fi
    done | while IFS= read -r d; do
        printf '%s\n' "${d/#$HOME/\~}"
    done
}

# ═════════════════════════════════════════════════════════════════
# Cross-Platform Helpers
# ═════════════════════════════════════════════════════════════════

# Return the clipboard copy command string (for use in fzf --bind, etc.)
# Usage: cmd=$(clipboard_copy_cmd)
clipboard_copy_cmd() {
    if [[ "$(uname)" == "Darwin" ]]; then
        printf 'pbcopy'
    elif command -v xclip &>/dev/null; then
        printf 'xclip -selection clipboard'
    elif command -v xsel &>/dev/null; then
        printf 'xsel --clipboard --input'
    elif command -v wl-copy &>/dev/null; then
        printf 'wl-copy'
    else
        printf 'cat >/dev/null'
    fi
}

# Copy stdin to system clipboard (works on macOS and Linux)
clipboard_copy() {
    if [[ "$(uname)" == "Darwin" ]]; then
        pbcopy
    elif command -v xclip &>/dev/null; then
        xclip -selection clipboard
    elif command -v xsel &>/dev/null; then
        xsel --clipboard --input
    elif command -v wl-copy &>/dev/null; then
        wl-copy
    else
        # Fallback: silently consume stdin
        cat >/dev/null
        return 1
    fi
}

# Open a URL or file with the system handler (works on macOS and Linux)
open_url() {
    local url="$1"
    if [[ "$(uname)" == "Darwin" ]]; then
        open "$url"
    elif command -v xdg-open &>/dev/null; then
        xdg-open "$url" &>/dev/null &
    elif command -v wslview &>/dev/null; then
        wslview "$url"
    else
        error "No handler found to open URLs"
        return 1
    fi
}

# Reverse lines (cross-platform replacement for macOS 'tail -r')
reverse_lines() {
    if command -v tac &>/dev/null; then
        tac
    else
        awk '{lines[NR]=$0} END {for(i=NR;i>=1;i--) print lines[i]}'
    fi
}

# Return the platform-appropriate modifier key label
# Usage: mod_key  →  "Opt" on macOS, "Alt" on Linux
mod_key() {
    if [[ "$(uname)" == "Darwin" ]]; then
        printf 'Opt'
    else
        printf 'Alt'
    fi
}
