#!/usr/bin/env bash
# shellcheck disable=SC2034  # Unused vars are positional placeholders for parsing
# ══════════════════════════════════════════════════════════════
# restore-resurrect.sh
# ══════════════════════════════════════════════════════════════
# Restores a single tmux session from its individual backup file.
#
# This script works with per-session backup files created by
# split-resurrect.sh (the post-save hook). Unlike the built-in
# resurrect restore which restores ALL sessions at once, this
# allows restoring individual sessions independently.
#
# Features:
#   - Restores session structure (windows, panes, layouts)
#   - Restores working directories for each pane
#   - Restores scrollback history (if @resurrect-capture-pane-contents enabled)
#   - Restores running commands (if @resurrect-processes configured)
#
# Usage:
#   restore-resurrect.sh                          # Restore ALL sessions
#   restore-resurrect.sh --session <name>         # Restore specific session
#   restore-resurrect.sh --session <name> --replace  # Kill existing first
#   restore-resurrect.sh --delete <name>          # Delete backup
#   restore-resurrect.sh --list                   # List backups
#
# Session files are stored in: ~/.tmux/resurrect/sessions/
#
# Configuration Options (in .tmux.conf):
#   set -g @resurrect-capture-pane-contents 'on'  # Enable scrollback restore
#   set -g @resurrect-processes 'ssh vim htop'    # Commands to restore
#   set -g @resurrect-processes ':all:'           # Restore all commands
# ══════════════════════════════════════════════════════════════

set -euo pipefail

# Source common utilities (provides tmux wrapper and colours)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../_lib/common.sh"
source "$SCRIPT_DIR/../_lib/paths.sh"

# Get the resurrect directories using shared functions
RESURRECT_DIR=$(get_resurrect_dir)
SESSIONS_DIR=$(get_resurrect_sessions_dir)

# ─────────────────────────────────────────────────────────────
# Pane Contents Restoration Helpers
# ─────────────────────────────────────────────────────────────

# Check if pane contents restoration is enabled
pane_contents_enabled() {
    local option
    option="$(tmux show-option -gqv @resurrect-capture-pane-contents)"
    [[ "$option" == "on" ]]
}

# Get path to pane contents file for a specific pane
pane_contents_file() {
    local session_name="$1"
    local window_number="$2"
    local pane_index="$3"
    local pane_id="${session_name}:${window_number}.${pane_index}"

    # Pane contents are stored in resurrect/pane_contents/ directory
    echo "${RESURRECT_DIR}/pane_contents/${pane_id}"
}

# Check if pane contents file exists for restoration
pane_contents_file_exists() {
    local session_name="$1"
    local window_number="$2"
    local pane_index="$3"
    local file
    file="$(pane_contents_file "$session_name" "$window_number" "$pane_index")"
    [[ -f "$file" ]]
}

# Get the default shell command from tmux config
get_default_command() {
    local default_shell
    default_shell="$(tmux show-option -gqv default-shell)"
    local opt=""
    if [[ "$(basename "$default_shell")" == "bash" ]]; then
        opt="-l "
    fi
    local default_command
    default_command="$(tmux show-option -gqv default-command)"
    if [[ -n "$default_command" ]]; then
        echo "$default_command"
    else
        echo "${opt}${default_shell}"
    fi
}

# Build pane creation command with contents restoration
pane_creation_command() {
    local session_name="$1"
    local window_number="$2"
    local pane_index="$3"
    local contents_file
    contents_file="$(pane_contents_file "$session_name" "$window_number" "$pane_index")"

    # Escape single quotes in the path to prevent injection
    local escaped_file="${contents_file//\'/\'\\\'\'}"

    # Command that cats the saved contents then execs the default shell
    # This displays the scrollback history before starting the shell
    echo "cat '${escaped_file}'; exec $(get_default_command)"
}

usage() {
    echo -e "${CYAN}Usage:${NC} $0 [options]"
    echo ""
    echo "Options:"
    echo "  (no args)              Restore ALL saved sessions"
    echo "  --session <name>       Restore a specific session"
    echo "  --replace              Kill existing session before restoring (use with --session)"
    echo "  --delete <name>        Delete a saved session backup"
    echo "  --list                 List available sessions"
    echo ""
    list_sessions
    exit 1
}

# Restore all saved sessions
restore_all_sessions() {
    if [[ ! -d "${SESSIONS_DIR}" ]] || [[ -z "$(ls -A "${SESSIONS_DIR}" 2>/dev/null)" ]]; then
        echo -e "${YELLOW}No session backups found.${NC}"
        return 1
    fi

    local restored=0
    local skipped=0
    local failed=0

    for f in "${SESSIONS_DIR}"/*.txt; do
        [[ -e "$f" ]] || continue
        local session
        session=$(basename "$f" .txt)

        # Skip if session already running
        if tmux has-session -t "${session}" 2>/dev/null; then
            echo -e "${YELLOW}Skipping${NC} ${session} (already running)"
            ((++skipped))
            continue
        fi

        echo -e "${CYAN}Restoring${NC} ${session}..."
        "$0" --session "$session" --no-switch

        # Verify restoration by checking if session now exists
        if tmux has-session -t "${session}" 2>/dev/null; then
            ((++restored))
        else
            echo -e "${RED}Failed${NC} to restore ${session}"
            ((++failed))
        fi
    done

    echo ""
    echo -e "${GREEN}Restored:${NC} ${restored}  ${YELLOW}Skipped:${NC} ${skipped}  ${RED}Failed:${NC} ${failed}"
}

list_sessions() {
    if [[ ! -d "${SESSIONS_DIR}" ]] || [[ -z "$(ls -A "${SESSIONS_DIR}" 2>/dev/null)" ]]; then
        echo -e "${YELLOW}No session backups found.${NC}"
        echo "Run resurrect save (prefix + Ctrl-s) to create backups."
        return
    fi

    echo -e "${CYAN}Available session backups:${NC}"
    echo ""

    for f in "${SESSIONS_DIR}"/*.txt; do
        [[ -e "$f" ]] || continue
        session=$(basename "$f" .txt)
        windows=$(grep -c '^window' "$f" 2>/dev/null || echo 0)
        windows=${windows//[$'\n\r']/}  # Strip newlines
        panes=$(grep -c '^pane' "$f" 2>/dev/null || echo 0)
        panes=${panes//[$'\n\r']/}  # Strip newlines
        modified=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$f" 2>/dev/null || stat -c "%y" "$f" 2>/dev/null | cut -d. -f1)

        # Check if session currently exists
        if tmux has-session -t "${session}" 2>/dev/null; then
            status="${GREEN}[ACTIVE]${NC}"
        else
            status=""
        fi

        printf "  ${CYAN}%-20s${NC} %2d windows, %2d panes  (%s) %b\n" "${session}" "${windows}" "${panes}" "${modified}" "${status}"
    done
}

# Parse arguments
REPLACE=false
DELETE=false
RESTORE_ALL=false
SESSION_NAME=""
NO_SWITCH=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --session|-s)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}Error: --session requires a session name${NC}" >&2
                usage
            fi
            SESSION_NAME="$2"
            shift 2
            ;;
        --replace)
            REPLACE=true
            shift
            ;;
        --no-switch)
            NO_SWITCH=true
            shift
            ;;
        --delete|-d)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}Error: --delete requires a session name${NC}" >&2
                usage
            fi
            DELETE=true
            SESSION_NAME="$2"
            shift 2
            ;;
        --list|-l)
            list_sessions
            exit 0
            ;;
        --help|-h)
            usage
            ;;
        *)
            # Backward compatibility: treat a lone non-flag positional argument
            # as a session name (equivalent to: --session <name>)
            if [[ "$1" != -* ]] && [[ -z "$SESSION_NAME" ]]; then
                SESSION_NAME="$1"
                shift
            else
                echo -e "${RED}Error: Unknown argument: $1${NC}" >&2
                usage
            fi
            ;;
    esac
done

# No session specified = restore all
if [[ -z "${SESSION_NAME}" ]] && [[ "${DELETE}" == "false" ]]; then
    restore_all_sessions
    exit $?
fi

# Validate session name to prevent path traversal attacks
if [[ "$SESSION_NAME" =~ \.\. ]] || [[ "$SESSION_NAME" =~ / ]]; then
    echo -e "${RED}Error: Invalid session name (contains path traversal characters): ${SESSION_NAME}${NC}" >&2
    exit 1
fi

SESSION_FILE="${SESSIONS_DIR}/${SESSION_NAME}.txt"

if [[ ! -f "${SESSION_FILE}" ]]; then
    echo -e "${RED}Error: Session file not found: ${SESSION_FILE}${NC}" >&2
    echo "Use --list to see available sessions."
    exit 1
fi

# Handle delete
if [[ "${DELETE}" == "true" ]]; then
    rm -f "${SESSION_FILE}"
    echo -e "${GREEN}Deleted session backup: ${SESSION_NAME}${NC}"
    exit 0
fi

# Check if session already exists
if tmux has-session -t "${SESSION_NAME}" 2>/dev/null; then
    if [[ "${REPLACE}" == "true" ]]; then
        echo -e "${YELLOW}Killing existing session: ${SESSION_NAME}${NC}"
        tmux kill-session -t "${SESSION_NAME}"
    else
        echo -e "${YELLOW}Session '${SESSION_NAME}' already running${NC}"
        if [[ "$NO_SWITCH" == false ]]; then
            tmux switch-client -t "${SESSION_NAME}" 2>/dev/null || tmux attach-session -t "${SESSION_NAME}"
        fi
        exit 0
    fi
fi

# ─────────────────────────────────────────────────────────────
# Session Restoration (three-pass algorithm)
# ─────────────────────────────────────────────────────────────
# Pass 1: Create session, windows, and panes with working directories
# Pass 2: Apply window layouts and names
# Pass 3: Select the correct active pane in each window

# Delimiter for parsing (resurrect uses tab-separated values)
d=$'\t'

# Get base-index setting (windows may start at 0 or 1)
BASE_INDEX=$(tmux show -gv base-index 2>/dev/null || echo 0)

# Track state during restoration (Bash 3.2 compatible - no associative arrays)
SESSION_CREATED=false
WINDOWS_CREATED_LIST=""         # Space-delimited list of created window numbers
PANES_CREATED_LIST=""           # Space-delimited list of created pane keys (window.pane)

# Helper functions for tracking (Bash 3.2 compatible)
window_exists() {
    [[ " $WINDOWS_CREATED_LIST " == *" $1 "* ]]
}

mark_window_created() {
    WINDOWS_CREATED_LIST="$WINDOWS_CREATED_LIST $1 "
}

pane_exists() {
    [[ " $PANES_CREATED_LIST " == *" $1 "* ]]
}

mark_pane_created() {
    PANES_CREATED_LIST="$PANES_CREATED_LIST $1 "
}

# Setup cleanup trap - if restoration fails partway, remove partial session
cleanup_on_error() {
    if [[ "$SESSION_CREATED" == "true" ]]; then
        echo -e "${YELLOW}Error during restoration - cleaning up partial session${NC}" >&2
        tmux kill-session -t "${SESSION_NAME}" 2>/dev/null || true
    fi
}
trap cleanup_on_error ERR

# ─────────────────────────────────────────
# Pass 1: Create session and panes
# ─────────────────────────────────────────
while IFS="${d}" read -r line_type sess_name window_number window_active window_flags pane_index pane_title dir pane_active pane_command pane_full_command rest; do
    [[ "${line_type}" == "pane" ]] || continue

    # Validate critical fields
    [[ -z "$window_number" || -z "$pane_index" ]] && continue

    # Skip duplicate pane entries (resurrect files sometimes have duplicates)
    pane_key="${window_number}.${pane_index}"
    if pane_exists "$pane_key"; then
        continue
    fi
    mark_pane_created "$pane_key"

    # Remove leading colon from dir if present
    dir="${dir#:}"
    # Expand tilde and handle escaped spaces
    dir="${dir/#\~/$HOME}"
    dir="${dir//\\ / }"  # Pure bash - safer than echo -e

    # Ensure directory exists, fallback to home
    if [[ ! -d "${dir}" ]]; then
        dir="${HOME}"
    fi

    if [[ "${SESSION_CREATED}" == "false" ]]; then
        # Create the session with first window
        if pane_contents_enabled && pane_contents_file_exists "$SESSION_NAME" "$window_number" "$pane_index"; then
            # Create session with pane contents restoration
            create_cmd="$(pane_creation_command "$SESSION_NAME" "$window_number" "$pane_index")"
            tmux new-session -d -s "${SESSION_NAME}" -c "${dir}" "$create_cmd" 2>/dev/null || {
                TMUX="" tmux new-session -d -s "${SESSION_NAME}" -c "${dir}" "$create_cmd" 2>/dev/null
            }
        else
            # Create session normally
            tmux new-session -d -s "${SESSION_NAME}" -c "${dir}" 2>/dev/null || {
                TMUX="" tmux new-session -d -s "${SESSION_NAME}" -c "${dir}" 2>/dev/null
            }
        fi

        # Handle base-index - rename first window if needed
        FIRST_WIN="${BASE_INDEX}"
        if [[ "${window_number}" != "${FIRST_WIN}" ]]; then
            tmux move-window -s "${SESSION_NAME}:${FIRST_WIN}" -t "${SESSION_NAME}:${window_number}" 2>/dev/null || true
        fi

        mark_window_created "${window_number}"
        # Prevent automatic-rename from overwriting saved names before Pass 2
        tmux set-option -t "${SESSION_NAME}:${window_number}" automatic-rename off 2>/dev/null || true
        SESSION_CREATED=true
        continue
    fi

    # Check if window exists
    if ! window_exists "${window_number}"; then
        # Create new window
        if pane_contents_enabled && pane_contents_file_exists "$SESSION_NAME" "$window_number" "$pane_index"; then
            create_cmd="$(pane_creation_command "$SESSION_NAME" "$window_number" "$pane_index")"
            tmux new-window -d -t "${SESSION_NAME}:${window_number}" -c "${dir}" "$create_cmd" 2>/dev/null || true
        else
            tmux new-window -d -t "${SESSION_NAME}:${window_number}" -c "${dir}" 2>/dev/null || true
        fi
        mark_window_created "${window_number}"
        # Prevent automatic-rename from overwriting saved names before Pass 2
        tmux set-option -t "${SESSION_NAME}:${window_number}" automatic-rename off 2>/dev/null || true
    else
        # Add pane to existing window (split)
        if pane_contents_enabled && pane_contents_file_exists "$SESSION_NAME" "$window_number" "$pane_index"; then
            create_cmd="$(pane_creation_command "$SESSION_NAME" "$window_number" "$pane_index")"
            tmux split-window -t "${SESSION_NAME}:${window_number}" -c "${dir}" "$create_cmd" 2>/dev/null || true
        else
            tmux split-window -t "${SESSION_NAME}:${window_number}" -c "${dir}" 2>/dev/null || true
        fi
    fi

done < "${SESSION_FILE}"

# ─────────────────────────────────────────
# Pass 2: Apply window layouts and names
# ─────────────────────────────────────────
while IFS="${d}" read -r line_type sess_name window_number window_name window_active window_flags window_layout automatic_rename rest; do
    [[ "${line_type}" == "window" ]] || continue

    # Validate critical fields
    [[ -z "$window_number" || -z "$window_layout" ]] && continue

    # Remove leading colon from window_name
    window_name="${window_name#:}"

    # Apply layout (may fail if pane count doesn't match, that's ok)
    tmux select-layout -t "${SESSION_NAME}:${window_number}" "${window_layout}" 2>/dev/null || true

    # Set window name
    if [[ -n "${window_name}" ]]; then
        tmux rename-window -t "${SESSION_NAME}:${window_number}" "${window_name}" 2>/dev/null || true
    fi

    # Handle automatic-rename option
    if [[ -n "${automatic_rename:-}" && "${automatic_rename}" != ":" ]]; then
        tmux set-option -t "${SESSION_NAME}:${window_number}" automatic-rename "${automatic_rename}" 2>/dev/null || true
    fi

done < "${SESSION_FILE}"

# ─────────────────────────────────────────
# Pass 3: Select active pane and window
# ─────────────────────────────────────────
while IFS="${d}" read -r line_type sess_name window_number window_active window_flags pane_index pane_title dir pane_active pane_command pane_full_command rest; do
    [[ "${line_type}" == "pane" ]] || continue
    [[ "${pane_active}" == "1" ]] || continue

    # Validate critical fields
    [[ -z "$window_number" || -z "$pane_index" ]] && continue

    tmux select-pane -t "${SESSION_NAME}:${window_number}.${pane_index}" 2>/dev/null || true
done < "${SESSION_FILE}"

# Find and select active window
ACTIVE_WINDOW=$(awk -F'\t' '/^window/ && $4 == 1 { print $3; exit }' "${SESSION_FILE}")
if [[ -n "${ACTIVE_WINDOW}" ]]; then
    tmux select-window -t "${SESSION_NAME}:${ACTIVE_WINDOW}" 2>/dev/null || true
fi

# ─────────────────────────────────────────
# Pass 4: Restore running commands/processes
# ─────────────────────────────────────────

# Check if process restoration is enabled
restore_processes_enabled() {
    local restore_processes
    restore_processes="$(tmux show-option -gqv @resurrect-processes)"
    if [[ -z "$restore_processes" || "$restore_processes" == "false" ]]; then
        return 1
    else
        return 0
    fi
}

# Get list of processes configured for restoration
get_restore_processes_list() {
    local user_processes
    user_processes="$(tmux show-option -gqv @resurrect-processes)"
    local default_processes="vi vim nvim emacs man less more tail top htop irssi weechat mutt ssh"

    if [[ -z "$user_processes" ]]; then
        echo "$default_processes"
    elif [[ "$user_processes" == ":all:" ]]; then
        echo ":all:"
    else
        echo "$default_processes $user_processes"
    fi
}

# Check if a command should be restored
should_restore_command() {
    local command="$1"
    local process_list
    process_list="$(get_restore_processes_list)"

    # Empty command - don't restore
    [[ -z "$command" || "$command" == ":" ]] && return 1

    # Restore all processes
    [[ "$process_list" == ":all:" ]] && return 0

    # Extract base command (first word) - pure bash
    local base_cmd="${command%% *}"

    # Check if command is in the restore list
    for proc in $process_list; do
        # Handle tilde prefix for fuzzy matching
        if [[ "$proc" =~ ^~ ]]; then
            local match="${proc#\~}"
            [[ "$command" =~ $match ]] && return 0
        else
            # Exact match on base command
            [[ "$base_cmd" == "$proc" ]] && return 0
        fi
    done

    return 1
}

# Wait for pane to be ready (responsive to tmux commands)
wait_for_pane() {
    local session_name="$1"
    local window_number="$2"
    local pane_index="$3"
    local max_attempts=20
    local attempt=0

    while [[ $attempt -lt $max_attempts ]]; do
        if tmux display-message -t "${session_name}:${window_number}.${pane_index}" -p "" 2>/dev/null; then
            return 0
        fi
        sleep 0.05
        ((attempt++))
    done
    return 1
}

# Restore command in a pane
restore_pane_command() {
    local session_name="$1"
    local window_number="$2"
    local pane_index="$3"
    local command="$4"
    local full_command="$5"

    # Use full_command if available, otherwise command
    local cmd_to_run="${full_command:-$command}"

    # Remove leading colon if present
    cmd_to_run="${cmd_to_run#:}"

    if should_restore_command "$cmd_to_run"; then
        # Validate command doesn't contain dangerous shell metacharacters
        # Allow: alphanumeric, spaces, dashes, underscores, dots, slashes, colons, equals, quotes
        if [[ "$cmd_to_run" =~ [\;\|\&\<\>\$\`\\] ]]; then
            echo -e "${YELLOW}Warning: Skipping command with suspicious characters: ${cmd_to_run}${NC}" >&2
            return 0
        fi

        # Wait for pane to be ready before sending command
        if wait_for_pane "$session_name" "$window_number" "$pane_index"; then
            # Send the command to the pane
            tmux send-keys -t "${session_name}:${window_number}.${pane_index}" "$cmd_to_run" C-m
        else
            echo -e "${YELLOW}Warning: Pane ${session_name}:${window_number}.${pane_index} not ready, skipping command restoration${NC}" >&2
        fi
    fi
}

# Restore commands if enabled
if restore_processes_enabled; then
    while IFS="${d}" read -r line_type sess_name window_number window_active window_flags pane_index pane_title dir pane_active pane_command pane_full_command rest; do
        [[ "${line_type}" == "pane" ]] || continue

        # Validate critical fields
        [[ -z "$window_number" || -z "$pane_index" ]] && continue

        # Remove leading colon from commands
        pane_command="${pane_command#:}"
        pane_full_command="${pane_full_command#:}"

        # Restore the command in this pane
        restore_pane_command "$SESSION_NAME" "$window_number" "$pane_index" "$pane_command" "$pane_full_command"
    done < "${SESSION_FILE}"
fi

# Disable cleanup trap on successful completion
trap - ERR

# Verify session was actually created
if ! tmux has-session -t "${SESSION_NAME}" 2>/dev/null; then
    echo -e "${RED}Error: Session restoration failed - session does not exist${NC}" >&2
    exit 1
fi

echo -e "${GREEN}Restored session: ${SESSION_NAME}${NC}"

# Switch to the restored session (unless --no-switch)
if [[ "$NO_SWITCH" == false ]]; then
    tmux switch-client -t "${SESSION_NAME}" 2>/dev/null || tmux attach-session -t "${SESSION_NAME}" 2>/dev/null || true
fi
