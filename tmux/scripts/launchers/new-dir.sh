#!/usr/bin/env bash
# shellcheck disable=SC2155
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# new directory picker (fzf become target)
# ══════════════════════════════════════════════════════════════
# shows a root picker (DEV_ROOT, PROJECTS_ROOT, Any directory)
# then prompts for a subdirectory name. passes the resulting
# path to the launcher.
#
# called via fzf become() from run.sh "n" keybind.
# usage: new-dir.sh <launcher_path>

SCRIPT_DIR="${BASH_SOURCE%/*}"

# shellcheck source=tmux/scripts/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

# load current theme colours for fzf
load_fzf_theme
require_fzf

LAUNCHER="${1:-}"
if [[ -z "$LAUNCHER" ]]; then
    exit 1
fi

# ─────────────────────────────────────────
# resolve root directories
# ─────────────────────────────────────────
dev_root="${DEV_ROOT:-}"
projects_root="${PROJECTS_ROOT:-}"

# build options list with resolved paths
options=""
option_count=0

if [[ -n "$dev_root" ]]; then
    dev_display="${dev_root/#$HOME/\~}"
    options+="    DEV_ROOT          ${GREY}${dev_display}${NC}"$'\n'
    option_count=$((option_count + 1))
fi

if [[ -n "$projects_root" ]]; then
    proj_display="${projects_root/#$HOME/\~}"
    options+="    PROJECTS_ROOT     ${GREY}${proj_display}${NC}"$'\n'
    option_count=$((option_count + 1))
fi

options+="    Any directory      ${GREY}enter a custom path${NC}"$'\n'
option_count=$((option_count + 1))

# ─────────────────────────────────────────
# show root picker
# ─────────────────────────────────────────
# build content with header
content=""
content+=$'\n'
content+="  ${GREEN}New directory${NC}"$'\n'
content+="  ${GREY}Select a root directory${NC}"$'\n'
content+=$'\n'
content+=$'\n'
content+="$options"

selection=$(printf '%s' "$content" | fzf \
    --ansi --reverse --disabled --cycle \
    --header-lines=5 \
    --padding=0,0,1,0 \
    --prompt=': ' \
    --border=rounded \
    --border-label=' j/k · spc/⏎ sel · q/esc ' \
    --border-label-pos=bottom \
    --bind 'j:down,k:up,q:abort' \
    --bind 'space:accept,enter:accept' \
    --bind 'esc:abort' \
    2>/dev/null) || exit 130

# extract the root name from selection
root_name=$(printf '%s' "$selection" | awk '{print $1}')

case "$root_name" in
    DEV_ROOT)
        root_path="$dev_root"
        ;;
    PROJECTS_ROOT)
        root_path="$projects_root"
        ;;
    Any)
        # free-form path prompt (mirrors original behaviour)
        dir=$(printf '' | fzf \
            --print-query --query='' \
            --prompt='Path: ' \
            --height=100% --layout=reverse \
            --border=rounded \
            --border-label=' ⏎ open · esc cancel ' \
            --border-label-pos=bottom \
            --no-info --pointer=' ' \
            --bind 'enter:print-query' \
            --bind 'esc:abort' \
            2>/dev/null | head -1) || exit 130

        [[ -n "$dir" ]] || exit 0
        dir="${dir/#\~/$HOME}"
        if [[ -d "$dir" ]]; then
            dir=$(cd "$dir" && pwd)
        fi
        exec "$LAUNCHER" "$dir"
        ;;
    *)
        exit 130
        ;;
esac

# ─────────────────────────────────────────
# prompt for subdirectory name
# ─────────────────────────────────────────
root_display="${root_path/#$HOME/\~}"

name=$(printf '' | fzf \
    --print-query --query='' \
    --prompt="${root_display}/" \
    --height=100% --layout=reverse \
    --border=rounded \
    --border-label=' ⏎ create · esc cancel ' \
    --border-label-pos=bottom \
    --no-info --pointer=' ' \
    --bind 'enter:print-query' \
    --bind 'esc:abort' \
    2>/dev/null | head -1) || exit 130

[[ -n "$name" ]] || exit 0

dir="${root_path}/${name}"

# create directory if it doesn't exist
if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
fi

exec "$LAUNCHER" "$dir"
