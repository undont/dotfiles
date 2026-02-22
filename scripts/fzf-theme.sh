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

# Apply theme defaults (derives FZF colours from base theme)
# shellcheck disable=SC1091
source "$THEMES_DIR/theme-defaults.sh"
apply_theme_defaults

# Export FZF_DEFAULT_OPTS with theme colours
# Format: --color=element:colour
# Use ${VAR:-} to avoid unbound variable errors if theme doesn't define all vars
export FZF_DEFAULT_OPTS="--color=bg:${FZF_BG:-#1e1e1e},fg:${FZF_FG:-#d4d4d4},bg+:${FZF_BG_PLUS:-#2e2e2e},fg+:${FZF_FG_PLUS:-#ffffff},hl:${FZF_HL:-#569cd6},hl+:${FZF_HL_PLUS:-#4fc1ff},border:${FZF_BORDER:-#3e3e3e},prompt:${FZF_PROMPT:-#ce9178},pointer:${FZF_POINTER:-#4ec9b0},marker:${FZF_MARKER:-#c586c0},spinner:${FZF_SPINNER:-#4ec9b0},header:${FZF_HEADER:-#569cd6},info:${FZF_INFO:-#d4d4d4},separator:${FZF_SEPARATOR:-#3e3e3e},scrollbar:${FZF_SCROLLBAR:-#569cd6},label:${FZF_LABEL:-#ffffff},preview-bg:${FZF_PREVIEW_BG:-#1e1e1e},preview-fg:${FZF_PREVIEW_FG:-#d4d4d4}"

# Also export individual colours for scripts that need direct access
export FZF_THEME_BG="$FZF_BG"
export FZF_THEME_FG="$FZF_FG"
export FZF_THEME_BORDER="$FZF_BORDER"
export FZF_THEME_PROMPT="$FZF_PROMPT"
export FZF_THEME_POINTER="$FZF_POINTER"
export FZF_THEME_HEADER="$FZF_HEADER"
