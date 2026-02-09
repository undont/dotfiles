#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2059
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# Launcher Runner (fzf become target)
# ══════════════════════════════════════════════════════════════
# Post-selection handler for the launcher picker (prefix + p).
# Routes to the appropriate handler based on launcher type:
#   - Fixed-session: instance picker (attach existing or create new)
#   - Parameterised: directory picker (choose project directory)
#
# Called via fzf become() with launcher name as $1.

SCRIPT_DIR="${BASH_SOURCE%/*}"

# shellcheck source=tmux/scripts/_lib/common.sh
source "$SCRIPT_DIR/_lib/common.sh"

if [[ -z "${DOTFILES_ROOT:-}" ]] || [[ ! -d "$DOTFILES_ROOT" ]]; then
    error "DOTFILES_ROOT not set or invalid: ${DOTFILES_ROOT:-<empty>}"
    exit 1
fi

# Load current theme colours for fzf
load_fzf_theme
require_fzf

name="${1:-}"
if [[ -z "$name" ]]; then
    exit 0
fi

# ─────────────────────────────────────────
# Find the launcher file
# ─────────────────────────────────────────
LAUNCHER=""

if [[ -x "$USER_LAUNCHERS/$name" ]]; then
    LAUNCHER="$USER_LAUNCHERS/$name"
elif [[ -x "$DOTFILES_LAUNCHERS/$name" ]]; then
    LAUNCHER="$DOTFILES_LAUNCHERS/$name"
fi

if [[ -z "$LAUNCHER" ]]; then
    show_error "Launcher not found: $name"
    exit 1
fi

# ─────────────────────────────────────────
# Extract launcher metadata
# ─────────────────────────────────────────
description=$(grep -m1 '# @description:' "$LAUNCHER" 2>/dev/null | sed 's/.*# @description: *//' || true)

# Instance creation mode: "prompt" asks for a name, "auto" (default) auto-increments
# Set via: # @instance: prompt
instance_mode=$(grep -m1 '# @instance:' "$LAUNCHER" 2>/dev/null | sed 's/.*# @instance: *//' || true)

# Detect launcher type by checking for a fixed SESSION= value
# Fixed: SESSION="myproject" or SESSION="${SESSION_NAME:-myproject}"
# Parameterised: no SESSION= line (e.g. tnew derives session from directory)
session_value=$(grep -m1 '^SESSION=' "$LAUNCHER" 2>/dev/null | sed 's/^SESSION=//' | tr -d '"' || true)

is_fixed_session() {
    # Has a SESSION= line and it's not purely variable-based
    [[ -n "$session_value" ]]
}

# Extract the base session name from SESSION= value
# Handles: SESSION="${SESSION_NAME:-myproject}" → myproject
#          SESSION="myproject" → myproject
get_base_session_name() {
    local val="$session_value"
    # Handle ${SESSION_NAME:-default} pattern
    if [[ "$val" =~ :-([^}]+)\} ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    else
        # Plain value (strip any remaining $ or { chars)
        # shellcheck disable=SC2016
        printf '%s' "$val" | tr -d '${}'
    fi
}

# ─────────────────────────────────────────
# Fixed-session launcher handler
# ─────────────────────────────────────────
handle_fixed_session() {
    local base_name
    base_name=$(get_base_session_name)

    # Find running sessions matching base name or base-<suffix> pattern
    # Matches both auto-incremented (dana-2) and prompted (dana-1234) instances
    local running=()
    while IFS= read -r session; do
        if [[ "$session" == "$base_name" ]] || [[ "$session" =~ ^${base_name}-.+$ ]]; then
            running+=("$session")
        fi
    done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null || true)

    # No running sessions — launch directly
    if [[ ${#running[@]} -eq 0 ]]; then
        exec "$LAUNCHER"
    fi

    # One or more running — show instance picker
    # Build content: header lines + items (piped together for consistent alignment)
    # Note: avoid $(printf...) for line building — command substitution strips trailing newlines
    local content=""
    content+=$'\n'
    content+="  ${GREEN}${name}${NC}"$'\n'
    content+="  ${GREY}${description}${NC}"$'\n'
    content+=$'\n'
    content+=$'\n'

    for session in "${running[@]}"; do
        # Use printf for %-16s field width, then append newline separately
        content+="    ${GREEN}●${NC} $(printf '%-16s' "$session") ${GREY}(running)${NC}"$'\n'
    done

    # Build the become() command for 'n' (new instance)
    local new_cmd
    if [[ "$instance_mode" == "prompt" ]]; then
        # Prompt for a suffix (e.g. ticket number) → dana-1234
        new_cmd="suffix=\$(printf '' | fzf --print-query --query='' --prompt='${base_name}-' --height=100% --layout=reverse --border=rounded --border-label=' ⏎ create · esc cancel ' --border-label-pos=bottom --no-info --pointer=' ' --bind 'enter:print-query' --bind 'esc:abort' 2>/dev/null | head -1) && [ -n \"\$suffix\" ] && suffix=\$(printf '%s' \"\$suffix\" | tr -c '[:alnum:]_.-' '_') && SESSION_NAME='${base_name}-'\$suffix exec '${LAUNCHER}'"
    else
        # Auto-increment → dana-2, dana-3, etc.
        new_cmd="num=2; while tmux has-session -t '${base_name}-'\$num 2>/dev/null; do num=\$((num+1)); done; SESSION_NAME='${base_name}-'\$num exec '${LAUNCHER}'"
    fi

    local selection
    selection=$(printf '%s' "$content" | fzf \
        --ansi --reverse --disabled --cycle \
        --header-lines=5 \
        --padding=0,0,1,0 \
        --prompt=': ' \
        --border=rounded \
        --border-label=' j/k · g/G · spc/⏎ sel · / srch · n new · q/esc ' \
        --border-label-pos=bottom \
        --bind 'j:down,k:up,g:first,G:last,q:abort' \
        --bind 'space:accept,enter:accept' \
        --bind 'change:transform:[[ $FZF_PROMPT == ": " ]] && echo "clear-query"' \
        --bind '/:enable-search+change-prompt(> )+unbind(j,k,g,G,q,space,n)' \
        --bind 'esc:transform:[[ $FZF_PROMPT == "> " ]] && echo "disable-search+clear-query+change-prompt(: )+rebind(j,k,g,G,q,space,n)" || echo "abort"' \
        --bind 'ctrl-k:kill-line,ctrl-w:unix-line-discard' \
        --bind "n:become($new_cmd)" \
        2>/dev/null) || exit 0

    # Extract session name from selection (after ● marker)
    local target
    target=$(printf '%s' "$selection" | sed 's/.*● *//' | awk '{print $1}')
    if [[ -n "$target" ]]; then
        tmux switch-client -t "$target"
    fi
}

# ─────────────────────────────────────────
# Parameterised launcher handler
# ─────────────────────────────────────────
handle_parameterised() {
    # Collect directories from PROJECT_DIRS (colon-separated, like PATH)
    local project_dirs="${PROJECT_DIRS:-$HOME/src}"
    local dirs=()

    IFS=':' read -ra roots <<< "$project_dirs"
    for root in "${roots[@]}"; do
        # Skip empty entries (from trailing colons or double colons)
        [[ -n "$root" ]] || continue
        # Expand ~ to $HOME
        root="${root/#\~/$HOME}"
        [[ -d "$root" ]] || continue

        # List immediate subdirectories
        if command -v fd &>/dev/null; then
            while IFS= read -r d; do
                dirs+=("$d")
            done < <(fd --type d --max-depth 1 . "$root" 2>/dev/null)
        else
            while IFS= read -r d; do
                dirs+=("$d")
            done < <(find "$root" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)
        fi
    done

    # Replace $HOME prefix with ~ for display
    local display_dirs=()
    for d in "${dirs[@]}"; do
        display_dirs+=("${d/#$HOME/~}")
    done

    # Build content: header lines + directory list
    # Note: avoid $(printf...) for line building — command substitution strips trailing newlines
    local content=""
    content+=$'\n'
    content+="  ${GREEN}${name}${NC}"$'\n'
    content+="  ${GREY}${description}${NC}"$'\n'
    content+=$'\n'
    content+=$'\n'

    for d in "${display_dirs[@]}"; do
        content+="    ${d}"$'\n'
    done

    local result
    result=$(printf '%s' "$content" | fzf \
        --ansi --reverse --disabled --cycle \
        --print-query \
        --header-lines=5 \
        --padding=0,0,1,0 \
        --prompt=': ' \
        --border=rounded \
        --border-label=' j/k · g/G · spc/⏎ sel · / srch · n new · q/esc ' \
        --border-label-pos=bottom \
        --bind 'j:down,k:up,g:first,G:last,q:abort' \
        --bind 'space:accept,enter:accept' \
        --bind 'change:transform:[[ $FZF_PROMPT == ": " ]] && echo "clear-query"' \
        --bind '/:enable-search+change-prompt(> )+unbind(j,k,g,G,q,space,n)' \
        --bind 'esc:transform:[[ $FZF_PROMPT == "> " ]] && echo "disable-search+clear-query+change-prompt(: )+rebind(j,k,g,G,q,space,n)" || echo "abort"' \
        --bind 'ctrl-k:kill-line,ctrl-w:unix-line-discard' \
        --bind "n:become(dir=\$(printf '' | fzf --print-query --query='' --prompt='Path: ' --height=100% --layout=reverse --border=rounded --border-label=' ⏎ open · esc cancel ' --border-label-pos=bottom --no-info --pointer=' ' --bind 'enter:print-query' --bind 'esc:abort' 2>/dev/null | head -1) && [ -n \"\$dir\" ] && dir=\$(realpath -m -- \"\$dir\" 2>/dev/null || printf '%s' \"\$dir\") && exec '${LAUNCHER}' \"\$dir\")" \
        2>/dev/null) || exit 0

    # --print-query outputs: line 1 = query, line 2 = selected item
    local query selected dir
    query=$(printf '%s' "$result" | sed -n '1p' | sed 's/^[[:space:]]*//')
    selected=$(printf '%s' "$result" | sed -n '2p' | sed 's/^[[:space:]]*//')

    # Use selected item if available, otherwise use the typed query
    dir="${selected:-$query}"
    [[ -n "$dir" ]] || exit 0

    # Expand ~ back to $HOME
    dir="${dir/#\~/$HOME}"

    # Resolve to absolute path if relative
    if [[ -d "$dir" ]]; then
        dir=$(cd "$dir" && pwd)
    fi

    exec "$LAUNCHER" "$dir"
}

# ─────────────────────────────────────────
# Main
# ─────────────────────────────────────────
if is_fixed_session; then
    handle_fixed_session
else
    handle_parameterised
fi
