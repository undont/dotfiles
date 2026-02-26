#!/usr/bin/env bash
# Agent alert utilities for tmux scripts
# Source this file after common.sh

# Alerts file location (only set if not already defined)
if [[ -z "${ALERTS_FILE:-}" ]]; then
    readonly ALERTS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/agent-alerts/alerts"
fi

# Alert file format: session:window:agent
# Future enhancement: Add timestamp field for age-based sorting and auto-expiry
# Proposed format: session:window:agent:timestamp

# Get agent icon (compatible with bash 3.2 - no associative arrays)
# Usage: get_agent_icon "agent_name"
# Returns: icon symbol
get_agent_icon() {
    local agent="$1"
    case "$agent" in
        claude) echo "⚡" ;;
        opencode) echo "🔮" ;;
        *) echo "🤖" ;;
    esac
}

# Get agent colour (compatible with bash 3.2 - no associative arrays)
# Usage: get_agent_colour "agent_name"
# Returns: hex colour code
get_agent_colour() {
    local agent="$1"
    case "$agent" in
        claude) echo "#f1fa8c" ;;      # Yellow
        opencode) echo "#bd93f9" ;;    # Dracula purple
        *) echo "#6272a4" ;;           # Dracula blue
    esac
}

# Get agent display icon and colour (inlined to avoid subshell forks)
# Usage: get_agent_display "agent_name"
# Returns: "icon|colour"
get_agent_display() {
    case "$1" in
        claude)   echo "⚡|#f1fa8c" ;;
        opencode) echo "🔮|#bd93f9" ;;
        *)        echo "🤖|#6272a4" ;;
    esac
}

# Exit code icon (separate from agent icons)
# Usage: get_exit_code_icon "exit_code"
get_exit_code_icon() {
    local code="$1"
    case "$code" in
        0)   echo "✓" ;;
        *)   echo "✗" ;;
    esac
}

# Exit code colour
# Usage: get_exit_code_colour "exit_code"
get_exit_code_colour() {
    local code="$1"
    case "$code" in
        0)   echo "#50fa7b" ;;    # Dracula green
        *)   echo "#ff5555" ;;    # Dracula red
    esac
}

# Exit code display (combined icon|colour, avoids subshell forks)
# Usage: get_exit_code_display "exit_code"
get_exit_code_display() {
    local code="$1"
    case "$code" in
        0)   echo "✓|#50fa7b" ;;
        *)   echo "✗|#ff5555" ;;
    esac
}

# Set an exit code alert for the current window
# Usage: set_exit_alert "exit_code" "label" [ring_bell]
# Sets @exit_alert and @exit_alert_colour window options and adds 5-field entry to alerts file
set_exit_alert() {
    local code="$1"
    local label="$2"
    local ring_bell="${3:-true}"

    # Ensure alerts directory exists
    local alerts_dir
    alerts_dir="$(dirname "$ALERTS_FILE")"
    if [[ ! -d "$alerts_dir" ]]; then
        mkdir -p "$alerts_dir"
        chmod 700 "$alerts_dir"
    fi

    # Get colour for this exit code
    local colour
    colour="$(get_exit_code_colour "$code")"

    # Determine the window target — prefer TMUX_PANE (a pane ID like %12) since
    # it's set to the origin pane by cmd-alert.sh and works even when we've
    # switched windows. tmux accepts pane IDs directly as -wt targets.
    local target=""
    if [[ -n "${TMUX_PANE:-}" ]]; then
        target="$TMUX_PANE"
    fi

    # Set the @exit_alert and @exit_alert_colour window options on the origin window
    if [[ -n "$target" ]]; then
        tmux set-option -wt "$target" "@exit_alert" 1 2>/dev/null
        tmux set-option -wt "$target" "@exit_alert_colour" "$colour" 2>/dev/null
    fi

    # Resolve session:window name for the alerts file (needed for show.sh / list.sh)
    local win=""
    if [[ -n "${TMUX_PANE:-}" ]]; then
        win=$(tmux display-message -t "$TMUX_PANE" -p '#S:#W' 2>/dev/null || true)
    fi
    if [[ -z "$win" && -n "${TMUX:-}" ]]; then
        win=$(tmux display-message -p '#S:#W' 2>/dev/null || true)
    fi

    # Add window to alerts file with exit code and label (5-field format)
    # Validate win is in format "session:window" (both non-empty, valid chars)
    if [[ "$win" =~ ^[a-zA-Z0-9._-]+:[a-zA-Z0-9._-]+$ ]]; then
        local entry="${win}:exit:${code}:${label}"
        grep -qxF "$entry" "$ALERTS_FILE" 2>/dev/null || echo "$entry" >> "$ALERTS_FILE"
    fi

    # Ring the terminal bell (only if requested and /dev/tty is available)
    if [[ "$ring_bell" == "true" ]]; then
        {
            if [[ -w /dev/tty ]]; then
                printf '\a' > /dev/tty
            fi
        } 2>/dev/null || true
    fi
}

# Set an alert for the current window
# Usage: set_window_alert "agent_name" [ring_bell]
# Sets tmux window option and adds to alerts file
set_window_alert() {
    local agent="${1:-claude}"
    local ring_bell="${2:-true}"

    # Ensure alerts directory exists
    local alerts_dir
    alerts_dir="$(dirname "$ALERTS_FILE")"
    if [[ ! -d "$alerts_dir" ]]; then
        mkdir -p "$alerts_dir"
        chmod 700 "$alerts_dir"
    fi

    # Get current tmux window identifier
    local win=""
    if [[ -n "${TMUX_PANE:-}" ]]; then
        win=$(tmux display-message -t "$TMUX_PANE" -p '#S:#W' 2>/dev/null)
    fi
    if [[ -z "$win" && -n "${TMUX:-}" ]]; then
        win=$(tmux display-message -p '#S:#W' 2>/dev/null)
    fi

    # Set the @agent_alert window option
    if [[ -n "$win" ]]; then
        tmux set-option -wt "$win" "@${agent}_alert" 1 2>/dev/null
    elif [[ -n "${TMUX_PANE:-}" ]]; then
        tmux set-option -wt "$TMUX_PANE" "@${agent}_alert" 1 2>/dev/null
    fi

    # Add window to alerts file with agent type if not already present
    # Validate win is in format "session:window" (both non-empty, valid chars)
    if [[ "$win" =~ ^[a-zA-Z0-9._-]+:[a-zA-Z0-9._-]+$ ]]; then
        local entry="${win}:${agent}"
        grep -qxF "$entry" "$ALERTS_FILE" 2>/dev/null || echo "$entry" >> "$ALERTS_FILE"
    fi

    # Ring the terminal bell (only if requested and /dev/tty is available)
    if [[ "$ring_bell" == "true" ]]; then
        {
            if [[ -w /dev/tty ]]; then
                printf '\a' > /dev/tty
            fi
        } 2>/dev/null || true
    fi
}

# File locking: uses mkdir as an atomic lock primitive (POSIX guarantees mkdir
# is atomic even on NFS). Lock acquisition retries 10 times with 100ms backoff
# (1 second total timeout). This prevents concurrent alert updates from
# corrupting the alerts file when multiple tmux scripts fire simultaneously.
#
# grep exit codes: 0 = lines matched (filtered), 1 = no matches (file cleared),
# both are valid. Exit code 2+ indicates an actual error.

# Clear all alerts for a specific window
# Usage: clear_window_alerts "session" "window" ["window_id"]
clear_window_alerts() {
    local session="$1"
    local window="$2"
    local window_id="${3:-}"

    # Remove from alerts file (any agent) with file locking
    if [[ -f "$ALERTS_FILE" ]]; then
        local lock_dir="${ALERTS_FILE}.lock"
        local lock_acquired=0

        # Try to acquire lock (with timeout to prevent deadlock)
        for _ in {1..10}; do
            if mkdir "$lock_dir" 2>/dev/null; then
                lock_acquired=1
                break
            fi
            sleep 0.1
        done

        if [[ $lock_acquired -eq 1 ]]; then
            local tmp_file="${ALERTS_FILE}.tmp.$$"
            local grep_exit=0
            grep -v "^${session}:${window}:" "$ALERTS_FILE" > "$tmp_file" 2>/dev/null || grep_exit=$?

            # Exit code 0 or 1 are both success (0 = matches found, 1 = no matches/all filtered)
            if [[ $grep_exit -le 1 ]]; then
                mv "$tmp_file" "$ALERTS_FILE" 2>/dev/null || rm -f "$tmp_file"
            else
                # grep encountered an error - clean up
                rm -f "$tmp_file"
            fi

            # Release lock
            rmdir "$lock_dir" 2>/dev/null || true
        fi
    fi

    # Unset all @*_alert window options (agent-agnostic wildcard clearing)
    local target
    if [[ -n "$window_id" ]]; then
        target="$window_id"
    else
        target="${session}:${window}"
    fi

    # Clear all agent alert options dynamically
    # Use a more robust approach that handles empty input correctly
    local alert_options
    alert_options=$(tmux show-options -wt "$target" 2>/dev/null | grep '@.*_alert' | cut -d' ' -f1 || true)

    if [[ -n "$alert_options" ]]; then
        while IFS= read -r option; do
            tmux set-option -wt "$target" -u "$option" 2>/dev/null || true
        done <<< "$alert_options"
    fi
}

# Clean up stale alerts (for windows/sessions that no longer exist)
# Usage: cleanup_stale_alerts
cleanup_stale_alerts() {
    [[ ! -f "$ALERTS_FILE" ]] && return 0

    local lock_dir="${ALERTS_FILE}.lock"
    local lock_acquired=0

    # Try to acquire lock (with timeout to prevent deadlock)
    for _ in {1..10}; do
        if mkdir "$lock_dir" 2>/dev/null; then
            lock_acquired=1
            break
        fi
        sleep 0.1
    done

    [[ $lock_acquired -eq 0 ]] && return 1

    local tmp_file="${ALERTS_FILE}.tmp.$$"
    local cleaned=0

    # Read each alert and verify the session:window exists
    while IFS=':' read -r session window agent; do
        # Validate format
        if [[ -z "$session" || -z "$window" || -z "$agent" ]]; then
            cleaned=1
            continue
        fi

        # Check if session exists
        if ! tmux has-session -t "$session" 2>/dev/null; then
            cleaned=1
            continue
        fi

        # Check if window exists in session
        if ! tmux list-windows -t "$session" -F '#{window_name}' 2>/dev/null | grep -qxF "$window"; then
            cleaned=1
            continue
        fi

        # Window exists, keep the alert
        echo "${session}:${window}:${agent}" >> "$tmp_file"
    done < "$ALERTS_FILE"

    # Update alerts file if we cleaned anything
    if [[ $cleaned -eq 1 ]]; then
        if [[ -f "$tmp_file" ]]; then
            mv "$tmp_file" "$ALERTS_FILE" 2>/dev/null
        else
            # No valid alerts remain, create empty file
            : > "$ALERTS_FILE"
        fi
    else
        rm -f "$tmp_file"
    fi

    # Release lock
    rmdir "$lock_dir" 2>/dev/null || true
}

# Clear all alerts for a session
# Usage: clear_session_alerts "session"
clear_session_alerts() {
    local session="$1"

    # Remove all entries for this session from alerts file with locking
    if [[ -f "$ALERTS_FILE" ]]; then
        local lock_dir="${ALERTS_FILE}.lock"
        local lock_acquired=0

        # Try to acquire lock (with timeout to prevent deadlock)
        for _ in {1..10}; do
            if mkdir "$lock_dir" 2>/dev/null; then
                lock_acquired=1
                break
            fi
            sleep 0.1
        done

        if [[ $lock_acquired -eq 1 ]]; then
            local tmp_file="${ALERTS_FILE}.tmp.$$"
            local grep_exit=0
            grep -v "^${session}:" "$ALERTS_FILE" > "$tmp_file" 2>/dev/null || grep_exit=$?

            # Exit code 0 or 1 are both success (0 = matches found, 1 = no matches/all filtered)
            if [[ $grep_exit -le 1 ]]; then
                mv "$tmp_file" "$ALERTS_FILE" 2>/dev/null || rm -f "$tmp_file"
            else
                # grep encountered an error - clean up
                rm -f "$tmp_file"
            fi

            # Release lock
            rmdir "$lock_dir" 2>/dev/null || true
        fi
    fi

    # Unset agent options for all windows in session
    local win
    for win in $(tmux list-windows -t "$session" -F '#D' 2>/dev/null); do
        # Clear all agent alert options dynamically with robust handling
        local alert_options
        alert_options=$(tmux show-options -wt "$win" 2>/dev/null | grep '@.*_alert' | cut -d' ' -f1 || true)

        if [[ -n "$alert_options" ]]; then
            while IFS= read -r option; do
                tmux set-option -wt "$win" -u "$option" 2>/dev/null || true
            done <<< "$alert_options"
        fi
    done
}
