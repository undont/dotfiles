#!/bin/bash
# FZF theme configuration
# Sources the current theme and exports FZF_DEFAULT_OPTS
# Can be sourced by .zshrc or individual scripts

# Determine dotfiles root
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    # Bash
    DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
elif [[ -n "${ZSH_VERSION:-}" ]]; then
    # Zsh - use eval to avoid bash parse errors
    DOTFILES_ROOT="$(cd "$(dirname "$(eval 'echo ${(%):-%x}')")/.." && pwd)"
else
    # Fallback
    DOTFILES_ROOT="${HOME}/dotfiles"
fi

THEMES_DIR="$DOTFILES_ROOT/themes"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
CURRENT_THEME_FILE="$CONFIG_DIR/current-theme"

# Get current theme
if [[ -f "$CURRENT_THEME_FILE" ]]; then
    CURRENT_THEME=$(cat "$CURRENT_THEME_FILE")
else
    CURRENT_THEME="dracula"
fi

# Source theme file with validation
THEME_FILE="$THEMES_DIR/$CURRENT_THEME.theme"
if [[ -f "$THEME_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$THEME_FILE"
elif [[ -f "$THEMES_DIR/dracula.theme" ]]; then
    # Fallback to dracula if current theme not found
    # shellcheck disable=SC1091
    source "$THEMES_DIR/dracula.theme"
else
    # Last resort: set minimal safe defaults
    FZF_BG="#1e1e1e"
    FZF_FG="#d4d4d4"
    FZF_BG_PLUS="#2e2e2e"
    FZF_FG_PLUS="#ffffff"
    FZF_HL="#569cd6"
    FZF_HL_PLUS="#4fc1ff"
    FZF_BORDER="#3e3e3e"
    FZF_PROMPT="#ce9178"
    FZF_POINTER="#4ec9b0"
    FZF_MARKER="#c586c0"
fi

# Export FZF_DEFAULT_OPTS with theme colours
# Format: --color=element:colour
export FZF_DEFAULT_OPTS="
--color=bg:${FZF_BG}
--color=fg:${FZF_FG}
--color=bg+:${FZF_BG_PLUS}
--color=fg+:${FZF_FG_PLUS}
--color=hl:${FZF_HL}
--color=hl+:${FZF_HL_PLUS}
--color=border:${FZF_BORDER}
--color=prompt:${FZF_PROMPT}
--color=pointer:${FZF_POINTER}
--color=marker:${FZF_MARKER}
--color=spinner:${FZF_SPINNER}
--color=header:${FZF_HEADER}
--color=info:${FZF_INFO}
--color=separator:${FZF_SEPARATOR}
--color=scrollbar:${FZF_SCROLLBAR}
--color=label:${FZF_LABEL}
--color=preview-bg:${FZF_PREVIEW_BG}
--color=preview-fg:${FZF_PREVIEW_FG}
"

# Also export individual colours for scripts that need direct access
export FZF_THEME_BG="$FZF_BG"
export FZF_THEME_FG="$FZF_FG"
export FZF_THEME_BORDER="$FZF_BORDER"
export FZF_THEME_PROMPT="$FZF_PROMPT"
export FZF_THEME_POINTER="$FZF_POINTER"
export FZF_THEME_HEADER="$FZF_HEADER"
