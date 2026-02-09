#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# split-resurrect.sh
# ══════════════════════════════════════════════════════════════
# Post-save hook for tmux-resurrect.
#
# By default, tmux-resurrect saves ALL sessions to a single combined
# file. This hook runs after each save and splits that file into
# individual per-session files, enabling independent session restore.
#
# Called automatically via: @resurrect-hook-post-save-all
#
# Input:  ~/.tmux/resurrect/last (symlink to latest save)
# Output: ~/.tmux/resurrect/sessions/<session-name>.txt
#
# Also cleans up session files for sessions that no longer exist.
# ══════════════════════════════════════════════════════════════

set -euo pipefail

# Source path utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../_lib/paths.sh"

# Get the resurrect directories using shared functions
RESURRECT_DIR=$(get_resurrect_dir)
SESSIONS_DIR=$(get_resurrect_sessions_dir)
LAST_FILE="${RESURRECT_DIR}/last"

# Ensure sessions directory exists
mkdir -p "${SESSIONS_DIR}"

# Get the actual save file (resolve symlink)
if [[ ! -L "${LAST_FILE}" ]] && [[ ! -f "${LAST_FILE}" ]]; then
    exit 0  # No save file yet, nothing to do
fi

if [[ -L "${LAST_FILE}" ]]; then
    # Use realpath if available, otherwise use readlink (macOS compatible)
    if command -v realpath >/dev/null 2>&1; then
        SAVE_FILE=$(realpath "${LAST_FILE}" 2>/dev/null) || exit 0
    else
        # macOS readlink doesn't support -f, so manually resolve
        SAVE_FILE=$(readlink "${LAST_FILE}" 2>/dev/null) || exit 0
        # If relative path, make it absolute
        if [[ "${SAVE_FILE}" != /* ]]; then
            SAVE_FILE="${RESURRECT_DIR}/${SAVE_FILE}"
        fi
    fi
else
    SAVE_FILE="${LAST_FILE}"
fi

if [[ ! -f "${SAVE_FILE}" ]]; then
    exit 0
fi

# ─────────────────────────────────────────
# Extract session names
# ─────────────────────────────────────────
# Resurrect save format: tab-separated values with session name in field 2
SESSIONS=$(awk -F'\t' '/^(pane|window)/ { print $2 }' "${SAVE_FILE}" | sort -u)

if [[ -z "${SESSIONS}" ]]; then
    exit 0
fi

# ─────────────────────────────────────────
# Split into per-session files
# ─────────────────────────────────────────
# Track sessions saved this run (Bash 3.2 compatible - no associative arrays)
CURRENT_SESSIONS_LIST=""

for session in ${SESSIONS}; do
    SESSION_FILE="${SESSIONS_DIR}/${session}.txt"
    CURRENT_SESSIONS_LIST="$CURRENT_SESSIONS_LIST $session "

    # Extract all lines belonging to this session (pane, window, grouped_session)
    awk -F'\t' -v sess="${session}" '
        /^pane/ && $2 == sess { print }
        /^window/ && $2 == sess { print }
        /^grouped_session/ && $2 == sess { print }
    ' "${SAVE_FILE}" > "${SESSION_FILE}"
done

# ─────────────────────────────────────────
# Cleanup: remove orphaned session files
# ─────────────────────────────────────────
# Delete backup files for sessions that no longer exist
for existing_file in "${SESSIONS_DIR}"/*.txt; do
    [[ -e "${existing_file}" ]] || continue
    session_name=$(basename "${existing_file}" .txt)
    # Check if session is in current sessions list (Bash 3.2 compatible)
    if [[ " $CURRENT_SESSIONS_LIST " != *" $session_name "* ]]; then
        rm -f "${existing_file}"
    fi
done

# ─────────────────────────────────────────
# Cleanup: remove old resurrect save files
# ─────────────────────────────────────────
# Keep only the 20 most recent saves to prevent unbounded growth
cleanup_old_backups() {
    local dir="$1"
    local keep="$2"
    local count=0

    while IFS= read -r file; do
        count=$((count + 1))
        if [[ $count -gt $keep ]]; then
            rm -f "$file"
        fi
    done < <(ls -1t "$dir"/tmux_resurrect_*.txt 2>/dev/null)
}

cleanup_old_backups "$RESURRECT_DIR" 20
