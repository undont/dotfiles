#!/bin/bash
# Theme defaults and shared logic
# This file is sourced by individual theme files to set up common patterns

# This function should be called after setting base colours and accents
apply_theme_defaults() {
    # Determine which accent to use for active elements (default: purple)
    local active_accent="${THEME_ACTIVE_ACCENT:-purple}"
    
    # ══════════════════════════════════════════════════════════════
    # Status bar - standard patterns across all themes
    # ══════════════════════════════════════════════════════════════
    TMUX_STATUS_BG="$TMUX_BG_PRIMARY"
    TMUX_STATUS_FG="$TMUX_FG_PRIMARY"
    TMUX_STATUS_INACTIVE_FG="$TMUX_FG_SECONDARY"
    TMUX_STATUS_BELL_FG="$TMUX_ACCENT_PINK"
    
    # Active window uses the theme's chosen accent
    case "$active_accent" in
        cyan)
            TMUX_STATUS_ACTIVE_BG="$TMUX_ACCENT_CYAN"
            ;;
        purple)
            TMUX_STATUS_ACTIVE_BG="$TMUX_ACCENT_PURPLE"
            ;;
        green)
            TMUX_STATUS_ACTIVE_BG="$TMUX_ACCENT_GREEN"
            ;;
        *)
            TMUX_STATUS_ACTIVE_BG="$TMUX_ACCENT_PURPLE"
            ;;
    esac
    TMUX_STATUS_ACTIVE_FG="$TMUX_BG_PRIMARY"
    
    # ══════════════════════════════════════════════════════════════
    # Pane borders - active border matches active window
    # ══════════════════════════════════════════════════════════════
    TMUX_PANE_BORDER_INACTIVE="$TMUX_BG_SECONDARY"
    TMUX_PANE_BORDER_ACTIVE="$TMUX_STATUS_ACTIVE_BG"
    
    # ══════════════════════════════════════════════════════════════
    # Message/command bar - uses active accent
    # ══════════════════════════════════════════════════════════════
    TMUX_MESSAGE_BG="$TMUX_STATUS_ACTIVE_BG"
    TMUX_MESSAGE_FG="$TMUX_BG_PRIMARY"
    TMUX_MESSAGE_COMMAND_BG="$TMUX_FG_SECONDARY"
    TMUX_MESSAGE_COMMAND_FG="$TMUX_FG_PRIMARY"
    
    # ══════════════════════════════════════════════════════════════
    # FZF Colours - standard pattern across all themes
    # ══════════════════════════════════════════════════════════════
    FZF_BG="$TMUX_BG_PRIMARY"
    FZF_FG="$TMUX_FG_PRIMARY"
    FZF_BG_PLUS="$TMUX_BG_SECONDARY"      # Current line background
    FZF_FG_PLUS="$TMUX_FG_PRIMARY"        # Current line foreground
    FZF_HL="$TMUX_STATUS_ACTIVE_BG"       # Highlighted substrings (uses active accent)
    FZF_HL_PLUS="$TMUX_ACCENT_PINK"       # Highlighted substrings (current line)
    FZF_BORDER="$TMUX_STATUS_ACTIVE_BG"   # Border (uses active accent)
    FZF_PROMPT="$TMUX_ACCENT_CYAN"        # Prompt
    FZF_POINTER="$TMUX_ACCENT_PINK"       # Pointer
    FZF_MARKER="$TMUX_ACCENT_GREEN"       # Multi-select marker
    FZF_SPINNER="$TMUX_ACCENT_YELLOW"     # Streaming input indicator
    FZF_HEADER="$TMUX_ACCENT_CYAN"        # Header
    FZF_INFO="$TMUX_FG_SECONDARY"         # Info line
    FZF_SEPARATOR="$TMUX_FG_SECONDARY"    # Border separator
    FZF_SCROLLBAR="$TMUX_STATUS_ACTIVE_BG" # Scrollbar (uses active accent)
    FZF_LABEL="$TMUX_FG_PRIMARY"          # Border label
    FZF_PREVIEW_BG="$TMUX_BG_PRIMARY"     # Preview window background
    FZF_PREVIEW_FG="$TMUX_FG_PRIMARY"     # Preview window foreground
}
