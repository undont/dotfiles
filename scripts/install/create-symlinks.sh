#!/usr/bin/env bash
# shellcheck disable=SC1091
set -euo pipefail

# Create symlinks for all dotfiles based on preset
# Requires DOTFILES_DIR to be set

SCRIPT_DIR="${BASH_SOURCE%/*}"
DOTFILES_DIR="${DOTFILES_DIR:-$(dirname "$(dirname "$SCRIPT_DIR")")}"
export DOTFILES_DIR

source "$SCRIPT_DIR/../_lib/common.sh"
source "$SCRIPT_DIR/../_lib/rollback.sh"

PRESET="${DOTFILES_PRESET:-full}"
FAILED=0

create_link() {
    local source="$1"
    local dest="$2"

    # Ensure parent directory exists
    mkdir -p "$(dirname "$dest")"

    # Remove existing symlink if present
    if [[ -L "$dest" ]]; then
        rm "$dest"
    fi

    # If destination exists and is not a symlink, back it up inline
    if [[ -e "$dest" ]]; then
        local backup_base="$HOME/.dotfiles-backup"
        local backup_dir
        backup_dir="$backup_base/inline-$(date +%Y%m%d-%H%M%S)-$$"
        mkdir -p "$backup_dir"

        local relative_path="${dest#"$HOME"/}"
        local backup_path="$backup_dir/$relative_path"
        mkdir -p "$(dirname "$backup_path")"

        mv "$dest" "$backup_path"
        printf "${YELLOW}Backed up:${NC} %s -> %s\n" "$dest" "$backup_path"
    fi

    # Create symlink
    if ln -sf "$source" "$dest"; then
        printf "${GREEN}Created:${NC} %s -> %s\n" "$dest" "$source"
        # Record for rollback
        record_symlink "$dest" "$source"
        return 0
    else
        printf "${RED}FAILED:${NC} Could not create symlink %s\n" "$dest"
        FAILED=1
        return 1
    fi
}

print_section "Creating symlinks"
echo "Source: $DOTFILES_DIR"
echo "Preset: $PRESET"
echo ""

# Zsh (minimal)
echo "Zsh configuration:"
create_link "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
create_link "$DOTFILES_DIR/zsh/.zprofile" "$HOME/.zprofile"
create_link "$DOTFILES_DIR/zsh/.p10k.zsh" "$HOME/.p10k.zsh"
create_link "$DOTFILES_DIR/zsh/.zsh" "$HOME/.zsh"

# Tmux (minimal)
echo ""
echo "Tmux configuration:"
create_link "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
create_link "$DOTFILES_DIR/tmux/.tmux" "$HOME/.tmux"

# Dotfiles CLI (minimal)
echo ""
echo "Dotfiles CLI:"
mkdir -p "$HOME/.local/bin"
create_link "$DOTFILES_DIR/scripts/dotfiles" "$HOME/.local/bin/dotfiles"

# Neovim (core)
if should_install "core"; then
    echo ""
    echo "Neovim configuration:"
    create_link "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"
fi

# Hammerspoon (full)
if should_install "full"; then
    echo ""
    echo "Hammerspoon configuration:"
    create_link "$DOTFILES_DIR/hammerspoon" "$HOME/.hammerspoon"
fi

# Ghostty (core)
if should_install "core"; then
    echo ""
    echo "Ghostty configuration:"
    mkdir -p "$HOME/.config/ghostty"
    create_link "$DOTFILES_DIR/ghostty/config" "$HOME/.config/ghostty/config"
fi

# Karabiner (full)
if should_install "full"; then
    echo ""
    echo "Karabiner configuration:"
    mkdir -p "$HOME/.config/karabiner"
    create_link "$DOTFILES_DIR/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"
fi

# Launchers (core)
if should_install "core"; then
    echo ""
    echo "Launchers:"
    mkdir -p "$HOME/.local/launchers"
    create_link "$DOTFILES_DIR/launchers/tnew" "$HOME/.local/launchers/tnew"
    create_link "$DOTFILES_DIR/launchers/dana" "$HOME/.local/launchers/dana"
    create_link "$DOTFILES_DIR/launchers/code" "$HOME/.local/launchers/code"
fi

# Claude/OpenCode shared configuration (core)
if should_install "core"; then
    # Check if claude-config repository exists
    CLAUDE_CONFIG_DIR="$HOME/claude-config"
    
    if [[ -d "$CLAUDE_CONFIG_DIR" ]]; then
        echo ""
        echo "Claude configuration:"
        mkdir -p "$HOME/.claude"
        create_link "$CLAUDE_CONFIG_DIR/agents" "$HOME/.claude/agents"
        create_link "$CLAUDE_CONFIG_DIR/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
        create_link "$CLAUDE_CONFIG_DIR/commands" "$HOME/.claude/commands"
        create_link "$CLAUDE_CONFIG_DIR/settings.json" "$HOME/.claude/settings.json"
        create_link "$CLAUDE_CONFIG_DIR/statusline/statusline.sh" "$HOME/.claude/statusline.sh"
        
        # Local plans and docs from dotfiles
        create_link "$DOTFILES_DIR/.claude/plans" "$HOME/.claude/plans"
        create_link "$DOTFILES_DIR/.claude/docs" "$HOME/.claude/docs"
        
        echo ""
        echo "OpenCode configuration:"
        mkdir -p "$HOME/.config/opencode"
        create_link "$DOTFILES_DIR/opencode/opencode.json" "$HOME/.config/opencode/opencode.json"
        create_link "$DOTFILES_DIR/opencode/package.json" "$HOME/.config/opencode/package.json"
        create_link "$DOTFILES_DIR/opencode/plugin" "$HOME/.config/opencode/plugin"
        
        # Share commands between Claude and OpenCode
        create_link "$CLAUDE_CONFIG_DIR/commands" "$HOME/.config/opencode/command"
    else
        warn "claude-config directory not found at $CLAUDE_CONFIG_DIR"
        warn "Skipping Claude/OpenCode configuration symlinks"
    fi
fi

echo ""

# Record step completion
record_step "symlinks"

if [[ $FAILED -eq 0 ]]; then
    success "All symlinks created successfully!"
    exit 0
else
    error "Some symlinks failed to create. Check the output above."
    exit 1
fi
