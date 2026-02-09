#!/usr/bin/env bash
# shellcheck disable=SC2155
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# New Launcher Prompt (fzf become target)
# ══════════════════════════════════════════════════════════════
# Prompts for a launcher name, then hands off to new-launcher.sh
# Called via fzf become() from the launcher picker (prefix + p)

SCRIPT_DIR="${BASH_SOURCE%/*}"

# shellcheck source=tmux/scripts/_lib/common.sh
source "$SCRIPT_DIR/_lib/common.sh"

# Load current theme colours for fzf
load_fzf_theme
require_fzf

# Prompt for launcher name using fzf --print-query
name=$(printf '' | fzf \
    --print-query \
    --query='' \
    --prompt='New launcher: ' \
    --height=100% \
    --layout=reverse \
    --border=rounded \
    --border-label=' ⏎ create · esc cancel ' \
    --border-label-pos=bottom \
    --no-info \
    --pointer=' ' \
    --bind 'enter:print-query' \
    --bind 'esc:abort' \
    2>/dev/null | head -1) || true

if [[ -z "$name" ]]; then
    exit 0
fi

# Hand off to the full scaffolding script
exec "$DOTFILES_ROOT/scripts/new-launcher.sh" "$name"
