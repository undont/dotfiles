#!/usr/bin/env bash
# shellcheck disable=SC2155
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# New Launcher Prompt (fzf become target)
# ══════════════════════════════════════════════════════════════
# Prompts for a launcher name, then hands off to new-launcher.sh
# Called via fzf become() from the launcher picker (prefix + p)
#
# Usage:
#   new-launcher-prompt.sh              # Create mode
#   new-launcher-prompt.sh --edit NAME  # Edit mode (pre-fills name)

SCRIPT_DIR="${BASH_SOURCE%/*}"

# shellcheck source=tmux/scripts/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

# Load current theme colours for fzf
load_fzf_theme
require_fzf

edit_source=""

if [[ "${1:-}" == "--edit" ]]; then
    edit_source="${2:-}"
    shift 2
fi

default_query=""
prompt_label="New launcher: "
border_label=' ⏎ create · esc cancel '

if [[ -n "$edit_source" ]]; then
    default_query="$edit_source"
    prompt_label="Edit launcher: "
    border_label=' ⏎ edit · esc cancel '
fi

# Prompt for launcher name using fzf --print-query
name=$(printf '' | fzf \
    --print-query \
    --query="$default_query" \
    --prompt="$prompt_label" \
    --height=100% \
    --layout=reverse \
    --border=rounded \
    --border-label="$border_label" \
    --border-label-pos=bottom \
    --no-info \
    --pointer=' ' \
    --bind 'enter:print-query' \
    --bind 'esc:abort' \
    2>/dev/null | head -1) || exit 130

if [[ -z "$name" ]]; then
    exit 130
fi

if [[ -n "$edit_source" ]]; then
    exec "$SCRIPT_DIR/new.sh" --edit "$edit_source" "$name"
fi

# Hand off to the full scaffolding script
exec "$SCRIPT_DIR/new.sh" "$name"
