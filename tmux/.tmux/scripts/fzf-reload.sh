#!/bin/bash
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# FZF Theme Reload Helper
# ══════════════════════════════════════════════════════════════
# Reloads FZF theme colours by sourcing fzf-theme.sh and updating
# tmux environment variables so all panes/windows get the new colours

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source fzf-theme.sh to load current theme colours
if [[ -f "$DOTFILES_ROOT/scripts/fzf-theme.sh" ]]; then
    # shellcheck disable=SC1091
    source "$DOTFILES_ROOT/scripts/fzf-theme.sh"
else
    exit 1
fi

# Update tmux environment if tmux is running
if command -v tmux >/dev/null 2>&1 && tmux info &>/dev/null; then
    # Export FZF variables to tmux global environment
    # This makes them available to all new panes/windows
    tmux set-environment -g FZF_DEFAULT_OPTS "$FZF_DEFAULT_OPTS" 2>/dev/null || true
    tmux set-environment -g FZF_THEME_BG "$FZF_THEME_BG" 2>/dev/null || true
    tmux set-environment -g FZF_THEME_FG "$FZF_THEME_FG" 2>/dev/null || true
    tmux set-environment -g FZF_THEME_BORDER "$FZF_THEME_BORDER" 2>/dev/null || true
    tmux set-environment -g FZF_THEME_PROMPT "$FZF_THEME_PROMPT" 2>/dev/null || true
    tmux set-environment -g FZF_THEME_POINTER "$FZF_THEME_POINTER" 2>/dev/null || true
    tmux set-environment -g FZF_THEME_HEADER "$FZF_THEME_HEADER" 2>/dev/null || true
fi

# Note: Existing shell sessions need to source fzf-theme.sh manually
# or run: source ~/dotfiles/scripts/fzf-theme.sh
