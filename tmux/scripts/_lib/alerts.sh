#!/usr/bin/env bash
# Agent alert utilities for tmux scripts
# Source this file after common.sh

# Guard against multiple sourcing
[[ -n "${_TMUX_ALERTS_SH_LOADED:-}" ]] && return 0
_TMUX_ALERTS_SH_LOADED=1

# Alerts file location (only set if not already defined, allowing tests to override)
if [[ -z "${ALERTS_FILE:-}" ]]; then
    readonly ALERTS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/tmux-alerts/alerts"
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
        copilot) echo "✦" ;;
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
        copilot) echo "#58a6ff" ;;     # GitHub blue
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
        copilot)  echo "✦|#58a6ff" ;;
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
        0)   echo "#7aab88" ;;    # Muted green
        *)   echo "#c07878" ;;    # Muted red
    esac
}

# Exit code display (combined icon|colour, avoids subshell forks)
# Usage: get_exit_code_display "exit_code"
get_exit_code_display() {
    local code="$1"
    case "$code" in
        0)   echo "✓|#7aab88" ;;
        *)   echo "✗|#c07878" ;;
    esac
}

# Build alert icon string from tmux window options output
# Usage: icons=$(get_window_alert_icons "$opts")
# Returns: ANSI-coloured icon string (empty if no alerts)
get_window_alert_icons() {
    local opts="$1"
    local icons=""

    # Exit alert
    if printf '%s\n' "$opts" | grep -q '^@exit_alert '; then
        local exit_code exit_label display icon colour
        exit_code=$(printf '%s\n' "$opts" | grep '^@exit_alert_code ' | cut -d' ' -f2)
        exit_label=$(printf '%s\n' "$opts" | grep '^@exit_alert_label ' | cut -d' ' -f2-)
        exit_label="${exit_label#\"}"
        exit_label="${exit_label%\"}"
        # Escape '#' to prevent tmux format injection
        exit_label="${exit_label//\#/##}"
        display=$(get_exit_code_display "$exit_code")
        icon="${display%%|*}"
        colour="${display##*|}"
        icons="${icons}\033[38;2;$(printf '%d;%d;%d' "0x${colour:1:2}" "0x${colour:3:2}" "0x${colour:5:2}")m${icon} ${exit_label}\033[0m "
    fi

    # Agent alerts
    local agent
    for agent in claude opencode copilot; do
        if printf '%s\n' "$opts" | grep -q "^@${agent}_alert "; then
            display=$(get_agent_display "$agent")
            icon="${display%%|*}"
            colour="${display##*|}"
            # Apply colour only for non-emoji icons (emojis are self-coloured)
            case "$agent" in
                copilot)
                    icons="${icons}\033[38;2;$(printf '%d;%d;%d' "0x${colour:1:2}" "0x${colour:3:2}" "0x${colour:5:2}")m${icon}\033[0m "
                    ;;
                *)
                    icons="${icons}${icon} "
                    ;;
            esac
        fi
    done

    printf '%s' "$icons"
}

# Build alert icons from pre-read alerts file content
# Avoids per-window tmux calls by reading the flat file once
# Usage: icons=$(build_alert_icons "$alerts_content" "^session_name:" [dedupe])
#   $1 - Full alerts file content (pre-read)
#   $2 - Grep pattern to filter entries (e.g. "^mysession:" or "^mysession:mywindow:")
#   $3 - Optional: pass "dedupe" to deduplicate agent icons across entries
# Returns: ANSI-coloured icon string (empty if no alerts match)
build_alert_icons() {
    local alerts_content="$1"
    local pattern="$2"
    local dedupe="${3:-}"

    [[ -z "$alerts_content" ]] && return

    local icons="" seen_agents="" display icon colour

    while IFS=: read -r _sess _win field3 rest; do
        if [[ "$field3" == "exit" ]]; then
            # Exit alert: rest is "code:label"
            local code="${rest%%:*}"
            local label="${rest#*:}"
            # Escape '#' to prevent tmux format injection
            label="${label//\#/##}"
            display=$(get_exit_code_display "$code")
            icon="${display%%|*}"
            colour="${display##*|}"
            icons="${icons}\033[38;2;$(printf '%d;%d;%d' "0x${colour:1:2}" "0x${colour:3:2}" "0x${colour:5:2}")m${icon} ${label}\033[0m "
        else
            # Agent alert: field3 is agent name
            local agent="$field3"
            if [[ "$dedupe" == "dedupe" ]]; then
                case "$seen_agents" in *"|${agent}|"*) continue ;; esac
                seen_agents="${seen_agents}|${agent}|"
            fi
            display=$(get_agent_display "$agent")
            icon="${display%%|*}"
            colour="${display##*|}"
            case "$agent" in
                copilot)
                    icons="${icons}\033[38;2;$(printf '%d;%d;%d' "0x${colour:1:2}" "0x${colour:3:2}" "0x${colour:5:2}")m${icon}\033[0m "
                    ;;
                *)
                    icons="${icons}${icon} "
                    ;;
            esac
        fi
    done < <(printf '%s\n' "$alerts_content" | grep "$pattern" 2>/dev/null || true)

    printf '%s' "$icons"
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
        tmux set-option -wt "$target" "@exit_alert_code" "$code" 2>/dev/null
        tmux set-option -wt "$target" "@exit_alert_label" "$label" 2>/dev/null
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

    # Validate agent name against whitelist
    case "$agent" in
        claude|opencode|copilot) ;;
        *) return 1 ;;
    esac

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
# Stale lock recovery: if the lock holder PID is no longer alive, the lock is
# removed and acquisition retried.
#
# grep exit codes: 0 = lines matched (filtered), 1 = no matches (file cleared),
# both are valid. Exit code 2+ indicates an actual error.

# Acquire the alerts file lock
# Usage: _acquire_alerts_lock
# Returns: 0 on success, 1 on failure
_acquire_alerts_lock() {
    local lock_dir="${ALERTS_FILE}.lock"
    local pid_file="${lock_dir}/pid"

    for _ in {1..10}; do
        if mkdir "$lock_dir" 2>/dev/null; then
            echo $$ > "$pid_file" 2>/dev/null
            return 0
        fi

        # Check for stale lock — if holder PID is no longer alive, remove it
        if [[ -f "$pid_file" ]]; then
            local holder_pid
            holder_pid=$(cat "$pid_file" 2>/dev/null) || true
            if [[ -n "$holder_pid" ]] && ! kill -0 "$holder_pid" 2>/dev/null; then
                rmdir "$lock_dir" 2>/dev/null || rm -rf "$lock_dir" 2>/dev/null || true
                continue
            fi
        fi

        sleep 0.1
    done

    return 1
}

# Release the alerts file lock
# Usage: _release_alerts_lock
_release_alerts_lock() {
    local lock_dir="${ALERTS_FILE}.lock"
    rm -f "${lock_dir}/pid" 2>/dev/null
    rmdir "$lock_dir" 2>/dev/null || true
}

# Clear all alerts for a specific window
# Usage: clear_window_alerts "session" "window" ["window_id"]
clear_window_alerts() {
    local session="$1"
    local window="$2"
    local window_id="${3:-}"

    # Remove from alerts file (any agent) with file locking
    if [[ -f "$ALERTS_FILE" ]] && _acquire_alerts_lock; then
        local tmp_file
        tmp_file=$(mktemp "${ALERTS_FILE}.tmp.XXXXXX")
        local grep_exit=0
        grep -vF "${session}:${window}:" "$ALERTS_FILE" > "$tmp_file" 2>/dev/null || grep_exit=$?

        # Exit code 0 or 1 are both success (0 = matches found, 1 = no matches/all filtered)
        if [[ $grep_exit -le 1 ]]; then
            mv "$tmp_file" "$ALERTS_FILE" 2>/dev/null || rm -f "$tmp_file" 2>/dev/null
        else
            rm -f "$tmp_file" 2>/dev/null
        fi

        _release_alerts_lock
    fi

    # Unset all @*_alert window options (agent-agnostic wildcard clearing)
    local target
    if [[ -n "$window_id" ]]; then
        target="$window_id"
    else
        target="${session}:${window}"
    fi

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

    _acquire_alerts_lock || return 1

    local tmp_file
    tmp_file=$(mktemp "${ALERTS_FILE}.tmp.XXXXXX")
    local cleaned=0

    # Read each alert and verify the session:window exists
    # Lines may be 3-field (session:window:agent) or 5-field (session:window:exit:code:label)
    # so we read the full line and only split the first two fields for validation.
    while IFS= read -r line; do
        IFS=':' read -r session window field3 _rest <<< "$line"

        # Validate format — need at least session, window, and one more field
        if [[ -z "$session" || -z "$window" || -z "$field3" ]]; then
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

        # Window exists, keep the alert — preserve original line intact
        echo "$line" >> "$tmp_file"
    done < "$ALERTS_FILE"

    if [[ $cleaned -eq 1 ]]; then
        if [[ -f "$tmp_file" ]]; then
            mv "$tmp_file" "$ALERTS_FILE" 2>/dev/null
        else
            : > "$ALERTS_FILE"
        fi
    else
        rm -f "$tmp_file"
    fi

    _release_alerts_lock
}

# Clear all alerts for a session
# Usage: clear_session_alerts "session"
clear_session_alerts() {
    local session="$1"

    # Remove all entries for this session from alerts file with locking
    if [[ -f "$ALERTS_FILE" ]] && _acquire_alerts_lock; then
        local tmp_file
        tmp_file=$(mktemp "${ALERTS_FILE}.tmp.XXXXXX")
        local grep_exit=0
        grep -vF "${session}:" "$ALERTS_FILE" > "$tmp_file" 2>/dev/null || grep_exit=$?

        # Exit code 0 or 1 are both success (0 = matches found, 1 = no matches/all filtered)
        if [[ $grep_exit -le 1 ]]; then
            mv "$tmp_file" "$ALERTS_FILE" 2>/dev/null || rm -f "$tmp_file" 2>/dev/null
        else
            rm -f "$tmp_file" 2>/dev/null
        fi

        _release_alerts_lock
    fi

    # Unset agent options for all windows in session
    local win
    for win in $(tmux list-windows -t "$session" -F '#D' 2>/dev/null); do
        local alert_options
        alert_options=$(tmux show-options -wt "$win" 2>/dev/null | grep '@.*_alert' | cut -d' ' -f1 || true)

        if [[ -n "$alert_options" ]]; then
            while IFS= read -r option; do
                tmux set-option -wt "$win" -u "$option" 2>/dev/null || true
            done <<< "$alert_options"
        fi
    done
}
