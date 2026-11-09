#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2059
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# launcher runner (fzf become target)
# ══════════════════════════════════════════════════════════════
# post-selection handler for the launcher picker (prefix + p).
# routes to the appropriate handler based on launcher type:
#   - fixed-session: instance picker (attach existing or create new)
#   - directory (no session key): directory picker
#
# called via fzf become() with launcher name as $1

SCRIPT_DIR="${BASH_SOURCE%/*}"

# shellcheck source=launchers/lib/data.sh
source "$SCRIPT_DIR/../lib/data.sh"
# shellcheck source=launchers/lib/backend.sh
source "$SCRIPT_DIR/../lib/backend.sh"

# strip shell-escape backslashes from a pasted path. fzf gives literal text
# (not shell-parsed), so `~/Library/Mobile\ Documents/...` arrives with the
# backslashes intact and fails the [[ -d ... ]] check downstream
unescape_paste() {
    local s="$1"
    s="${s//\\ / }"
    s="${s//\\~/~}"
    printf '%s' "$s"
}

if [[ -z "${DOTFILES_ROOT:-}" ]] || [[ ! -d "$DOTFILES_ROOT" ]]; then
    error "DOTFILES_ROOT not set or invalid: ${DOTFILES_ROOT:-<empty>}"
    exit 1
fi

load_fzf_theme
require_fzf

name="${1:-}"
if [[ -z "$name" ]]; then
    exit 0
fi

# record launcher usage for MRU ordering
mkdir -p "$(dirname "$LAUNCHER_HISTORY")"
printf '%s\n' "$name" >>"$LAUNCHER_HISTORY"
# cap the history length
if [[ $(wc -l <"$LAUNCHER_HISTORY") -gt 100 ]]; then
    tail -100 "$LAUNCHER_HISTORY" >"$LAUNCHER_HISTORY.tmp" && mv "$LAUNCHER_HISTORY.tmp" "$LAUNCHER_HISTORY"
fi

if ! LAUNCHER_FILE=$(launcher_file "$name"); then
    show_error "Launcher not found: $name"
    exit 1
fi
LAUNCH="$SCRIPT_DIR/launch.sh"

# description, instance mode (prompt asks for a suffix, auto counts up) and
# the base session, empty for a directory launcher
# (NUL-separated: a TOML string can span lines)
{
    IFS= read -r -d '' description
    IFS= read -r -d '' instance_mode
    IFS= read -r -d '' base_name
} < <(launcher_json "$LAUNCHER_FILE" |
    jq -j '(.description // ""), "\u0000", (.instance // "auto"), "\u0000", (.session // ""), "\u0000"')

# ─────────────────────────────────────────
# fixed-session launcher handler
# ─────────────────────────────────────────
handle_fixed_session() {
    # find running sessions matching base name or base-<suffix> pattern
    # matches both auto-incremented (acme-2) and prompted (acme-1234) instances
    local running=()
    while IFS= read -r session; do
        if [[ "$session" == "$base_name" || "$session" == "$base_name-"?* ]]; then
            running+=("$session")
        fi
    done < <(launcher_sessions)

    # no running sessions, launch directly
    if [[ ${#running[@]} -eq 0 ]]; then
        exec "$LAUNCH" "$name"
    fi

    # one or more running, show instance picker
    # build content: header lines + items (piped together for consistent alignment)
    # note: avoid $(printf...) for line building, command substitution strips trailing newlines
    local content=""
    content+=$'\n'
    content+="  ${GREEN}${name}${NC}"$'\n'
    content+="  ${GREY}${description}${NC}"$'\n'
    content+=$'\n'
    content+=$'\n'

    for session in "${running[@]}"; do
        # use printf for %-16s field width, then append newline separately
        content+="    ${GREEN}●${NC} $(printf '%-16s' "$session") ${GREY}(running)${NC}"$'\n'
    done

    # build the become() command for 'n' (new instance)
    local safe_base_name safe_launch safe_name
    safe_base_name=$(printf '%q' "$base_name")
    safe_launch=$(printf '%q' "$LAUNCH")
    safe_name=$(printf '%q' "$name")

    local new_cmd
    if [[ "$instance_mode" == "prompt" ]]; then
        # prompt for a suffix (e.g. ticket number) → acme-1234
        new_cmd="suffix=\$(printf '' | fzf --query='' --prompt=${safe_base_name}- --height=100% --layout=reverse --border=rounded --border-label=' ⏎ create · esc cancel ' --border-label-pos=bottom --no-info --pointer=' ' --bind 'enter:print-query' --bind 'esc:abort' 2>/dev/null) && [ -n \"\$suffix\" ] && suffix=\$(printf '%s' \"\$suffix\" | tr -c '[:alnum:]_-' '-') && SESSION_NAME=${safe_base_name}-\$suffix exec ${safe_launch} ${safe_name}"
    else
        # auto-increment → acme-2, acme-3, etc.
        local num=2
        while launcher_session_exists "$base_name-$num"; do
            num=$((num + 1))
        done
        new_cmd="SESSION_NAME=${safe_base_name}-$num exec ${safe_launch} ${safe_name}"
    fi

    local selection
    selection=$(printf '%s' "$content" | fzf \
        --ansi --reverse --exact --disabled --cycle \
        --header-lines=5 \
        --padding=0,0,1,0 \
        --prompt=': ' \
        --border=rounded \
        --border-label=' j/k · d/u · g/G · spc/⏎ sel · / search · n new · q/esc ' \
        --border-label-pos=bottom \
        --bind 'j:down,k:up,g:first,G:last,d:half-page-down,u:half-page-up,q:abort' \
        --bind 'space:accept,enter:accept' \
        --bind 'change:transform:[[ $FZF_PROMPT == ": " ]] && echo "clear-query"' \
        --bind '/:enable-search+change-prompt(> )+unbind(j,k,g,G,d,u,q,space,n)' \
        --bind 'esc:transform:[[ $FZF_PROMPT == "> " ]] && echo "disable-search+clear-query+change-prompt(: )+rebind(j,k,g,G,d,u,q,space,n)" || echo "abort"' \
        --bind 'ctrl-k:up,ctrl-l:clear-query' \
        --bind "n:become($new_cmd)" \
        2>/dev/null) || exit 130

    # extract session name from selection (after ● marker)
    local target
    target=$(printf '%s' "$selection" | sed 's/.*● *//' | awk '{print $1}')
    if [[ -n "$target" ]]; then
        launcher_focus_session "$target"
    fi
}

# ─────────────────────────────────────────
# session collision handler (parameterised)
# ─────────────────────────────────────────
handle_session_collision() {
    local session="$1"
    local dir="$2"

    # the existing session's directory, for context (tmux only)
    local existing_path=""
    if [[ "$(launcher_backend)" == tmux ]]; then
        existing_path=$(tmux display-message -t "=${session}:" -p '#{pane_current_path}' 2>/dev/null || true)
        existing_path="${existing_path/#$HOME/\~}"
    fi

    # find next available auto-increment suffix
    local num=2
    while launcher_session_exists "${session}-${num}"; do
        num=$((num + 1))
    done

    # build become() command for 'n': suffix prompt with auto-number as default
    # user can type a custom suffix or press enter to accept the default
    local safe_session safe_launch safe_name safe_dir
    safe_session=$(printf '%q' "$session")
    safe_launch=$(printf '%q' "$LAUNCH")
    safe_name=$(printf '%q' "$name")
    safe_dir=$(printf '%q' "$dir")

    local new_cmd
    new_cmd="suffix=\$(printf '' | fzf --query='${num}' --prompt=${safe_session}- --height=100% --layout=reverse --border=rounded --border-label=' ⏎ create · esc cancel ' --border-label-pos=bottom --no-info --pointer=' ' --bind 'enter:print-query' --bind 'esc:abort' 2>/dev/null) && { [ -n \"\$suffix\" ] || suffix=${num}; } && suffix=\$(printf '%s' \"\$suffix\" | tr -c '[:alnum:]_-' '-') && SESSION_NAME=${safe_session}-\$suffix exec ${safe_launch} ${safe_name} ${safe_dir}"

    local content=""
    content+=$'\n'
    content+="  ${GREEN}${name}${NC}"$'\n'
    content+="  ${GREY}${description}${NC}"$'\n'
    content+="  ${YELLOW}Session '${session}' exists${NC} ${GREY}· ${existing_path}${NC}"$'\n'
    content+=$'\n'

    content+="    ${GREEN}●${NC} $(printf '%-20s' "$session") ${GREY}attach${NC}"$'\n'

    local selection
    selection=$(printf '%s' "$content" | fzf \
        --ansi --reverse --disabled \
        --header-lines=5 \
        --padding=0,0,1,0 \
        --prompt=': ' \
        --border=rounded \
        --border-label=' ⏎ attach · n new · esc cancel ' \
        --border-label-pos=bottom \
        --bind 'j:down,k:up,q:abort' \
        --bind 'space:accept,enter:accept' \
        --bind "n:become($new_cmd)" \
        2>/dev/null) || exit 130

    # only reachable via enter/space; 'n' goes through become()
    if [[ "$selection" == *"●"* ]]; then
        launcher_focus_session "$session"
        exit 0
    fi
}

# ─────────────────────────────────────────
# parameterised launcher handler
# ─────────────────────────────────────────
handle_parameterised() {
    # collect directories from PROJECT_DIRS using shared helper
    local display_dirs=()
    while IFS= read -r d; do
        display_dirs+=("$d")
    done < <(list_project_dirs)

    # build content: header lines + directory list
    # note: avoid $(printf...) for line building, command substitution strips trailing newlines
    local content="" header_lines=5
    content+=$'\n'
    content+="  ${GREEN}${name}${NC}"$'\n'
    content+="  ${GREY}${description}${NC}"$'\n'

    # empty list usually means PROJECT_DIRS isn't reaching the popup. show why
    # rather than a blank picker. the var is exported in ~/.zshrc but only reaches
    # a tmux popup via update-environment on attach (see tmux.conf update-environment)
    if [[ ${#display_dirs[@]} -eq 0 ]]; then
        local pd_display="${PROJECT_DIRS:-not set}"
        content+="  ${YELLOW}No project directories found${NC}"$'\n'
        content+="  ${GREY}PROJECT_DIRS: ${pd_display} · set it in ~/.zshrc, then detach + reattach${NC}"$'\n'
        header_lines=7
    fi

    content+=$'\n'
    content+=$'\n'

    for d in "${display_dirs[@]}"; do
        content+="    ${d}"$'\n'
    done

    local result
    result=$(printf '%s' "$content" | fzf \
        --ansi --reverse --exact --disabled --cycle \
        --print-query \
        --header-lines="$header_lines" \
        --padding=0,0,1,0 \
        --prompt=': ' \
        --border=rounded \
        --border-label=' j/k · d/u · g/G · spc/⏎ sel · / search · n new · q/esc ' \
        --border-label-pos=bottom \
        --bind 'j:down,k:up,g:first,G:last,d:half-page-down,u:half-page-up,q:abort' \
        --bind 'space:accept,enter:accept' \
        --bind 'change:transform:[[ $FZF_PROMPT == ": " ]] && echo "clear-query"' \
        --bind '/:enable-search+change-prompt(> )+unbind(j,k,g,G,d,u,q,space,n)' \
        --bind 'esc:transform:[[ $FZF_PROMPT == "> " ]] && echo "disable-search+clear-query+change-prompt(: )+rebind(j,k,g,G,d,u,q,space,n)" || echo "abort"' \
        --bind 'ctrl-k:up,ctrl-l:clear-query' \
        --bind "n:become($SCRIPT_DIR/new-dir.sh $(printf '%q' "$name"))" \
        2>/dev/null) || exit 130

    # --print-query outputs: line 1 = query, line 2 = selected item
    local query selected dir
    query=$(printf '%s' "$result" | sed -n '1p' | sed 's/^[[:space:]]*//')
    selected=$(printf '%s' "$result" | sed -n '2p' | sed 's/^[[:space:]]*//')

    # use selected item if available, otherwise use the typed query
    dir="${selected:-$query}"
    [[ -n "$dir" ]] || exit 0

    dir=$(unescape_paste "$dir")

    # expand ~ back to $HOME
    dir="${dir/#\~/$HOME}"

    # resolve to absolute path if relative
    if [[ -d "$dir" ]]; then
        dir=$(cd "$dir" && pwd)
    fi

    # derive expected session name (parameterised launchers use the directory basename)
    local expected_session
    expected_session="$(sanitise_session_name "$(basename "$dir")")"
    if [[ -n "$expected_session" ]] && launcher_session_exists "$expected_session"; then
        handle_session_collision "$expected_session" "$dir"
    fi

    exec "$LAUNCH" "$name" "$dir"
}

# ─────────────────────────────────────────
# main
# ─────────────────────────────────────────
if [[ -n "$base_name" ]]; then
    handle_fixed_session
else
    handle_parameterised
fi
