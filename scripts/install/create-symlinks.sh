#!/usr/bin/env bash
# shellcheck disable=SC1091
set -euo pipefail

# Create symlinks for all dotfiles based on preset
# Requires DOTFILES_DIR to be set

SCRIPT_DIR="${BASH_SOURCE%/*}"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "$(dirname "$SCRIPT_DIR")")" && pwd)}"
export DOTFILES_DIR

source "$SCRIPT_DIR/../_lib/common.sh"
source "$SCRIPT_DIR/../_lib/rollback.sh"

PRESET="${DOTFILES_PRESET:-full}"
FAILED=0

create_link() {
    local source="$1"
    local dest="$2"

    # Validate source exists before creating symlink
    if [[ ! -e "$source" && ! -L "$source" ]]; then
        printf "${RED}FAILED:${NC} Source not found: %s\n" "$source"
        FAILED=1
        return 1
    fi

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
        mkdir -p "$backup_base"
        chmod 700 "$backup_base"
        mkdir -p "$backup_dir"
        chmod 700 "$backup_dir"

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

# Zsh migration: handle transition from old symlink-based setup to personal ~/.zshrc.
# Four possible states:
#   1. ~/.zshrc is a symlink to dotfiles/zsh/zshrc → offer migration to personal file
#   2. ~/.zshrc is a symlink elsewhere → leave it alone (user's custom setup)
#   3. ~/.zshrc is a regular file sourcing dotfiles.zsh → already migrated, check for unmigrated local-aliases
#   4. ~/.zshrc doesn't exist → create from template
#
# Migration also consolidates local-aliases.zsh (deprecated) into ~/.zshrc directly,
# since the new model sources dotfiles.zsh from a personal .zshrc rather than symlinking.

# Zsh (minimal)
echo "Zsh configuration:"

# Check if ~/.zshrc needs migration from symlink to personal file
if [[ -L "$HOME/.zshrc" ]]; then
  # Currently a symlink (old setup) — offer migration
  symlink_target="$(readlink "$HOME/.zshrc")"

  if [[ "$symlink_target" == *"dotfiles/zsh/zshrc"* ]]; then
    info "Found ~/.zshrc symlinked to dotfiles (old setup)"
    if [[ -t 0 ]]; then
      printf '  %s⚠%s  Migrate to personal ~/.zshrc? Your config will be preserved. [Y/n] ' "${YELLOW}" "${NC}"
      read -r -t 60 response || response="y"
    else
      response="y"
    fi

    if [[ ! "$response" =~ ^[Nn]$ ]]; then
      # Remove symlink
      rm "$HOME/.zshrc"

      # Create personal .zshrc from template
      cp "$DOTFILES_DIR/zsh/zshrc.template" "$HOME/.zshrc"

      # Migrate local-aliases.zsh content into the new .zshrc
      ZSH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
      if [[ -f "$ZSH_CONFIG_DIR/local-aliases.zsh" && -s "$ZSH_CONFIG_DIR/local-aliases.zsh" ]]; then
        {
          printf "\n# =============================================================================\n"
          printf "# MIGRATED FROM local-aliases.zsh\n"
          printf "# =============================================================================\n"
          cat "$ZSH_CONFIG_DIR/local-aliases.zsh"
        } >> "$HOME/.zshrc"

        # Keep a backup, remove original
        mv "$ZSH_CONFIG_DIR/local-aliases.zsh" "$ZSH_CONFIG_DIR/local-aliases.zsh.bak"
        success "Migrated local-aliases.zsh content into ~/.zshrc"
        info "Backup saved: $ZSH_CONFIG_DIR/local-aliases.zsh.bak"
      fi

      success "Created personal ~/.zshrc (sources dotfiles framework)"
      printf '  %s→%s Edit with: nvim ~/.zshrc\n' "${CYAN}" "${NC}"
    else
      info "Keeping symlink (still supported via backwards-compat wrapper)"
    fi
  else
    # Symlink points somewhere else — leave it alone
    warn "$HOME/.zshrc is a symlink to $symlink_target (not dotfiles). Skipping."
  fi
elif [[ -f "$HOME/.zshrc" ]]; then
  # Regular file exists — check if it already sources dotfiles.zsh
  if grep -q "dotfiles.zsh" "$HOME/.zshrc" 2>/dev/null; then
    success "Personal ~/.zshrc exists (sources dotfiles framework)"

    # Check for unmigrated local-aliases.zsh
    ZSH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
    if [[ -f "$ZSH_CONFIG_DIR/local-aliases.zsh" && -s "$ZSH_CONFIG_DIR/local-aliases.zsh" ]]; then
      if ! grep -q "local-aliases" "$HOME/.zshrc" 2>/dev/null; then
        info "Found unmigrated local-aliases.zsh"
        if [[ -t 0 ]]; then
          printf '  %s⚠%s  Append local-aliases.zsh content into ~/.zshrc? [Y/n] ' "${YELLOW}" "${NC}"
          read -r -t 60 response || response="y"
        else
          response="y"
        fi

        if [[ ! "$response" =~ ^[Nn]$ ]]; then
          {
            printf "\n# =============================================================================\n"
            printf "# MIGRATED FROM local-aliases.zsh\n"
            printf "# =============================================================================\n"
            cat "$ZSH_CONFIG_DIR/local-aliases.zsh"
          } >> "$HOME/.zshrc"

          mv "$ZSH_CONFIG_DIR/local-aliases.zsh" "$ZSH_CONFIG_DIR/local-aliases.zsh.bak"
          success "Migrated local-aliases.zsh content into ~/.zshrc"
          info "Backup saved: $ZSH_CONFIG_DIR/local-aliases.zsh.bak"
        fi
      fi
    fi
  else
    warn "$HOME/.zshrc exists but doesn't source dotfiles.zsh"
    info "Add this line to source the framework: source ~/dotfiles/zsh/dotfiles.zsh"
  fi
else
  # No .zshrc at all — create from template
  cp "$DOTFILES_DIR/zsh/zshrc.template" "$HOME/.zshrc"
  success "Created ~/.zshrc from template"
  printf '  %s→%s Edit with: nvim ~/.zshrc\n' "${CYAN}" "${NC}"
fi

# These are still symlinked (shared config, not personal)
create_link "$DOTFILES_DIR/zsh/zprofile" "$HOME/.zprofile"
create_link "$DOTFILES_DIR/zsh/p10k.zsh" "$HOME/.p10k.zsh"

# User config files go to XDG location
ZSH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
mkdir -p "$ZSH_CONFIG_DIR"

# Tmux (minimal)
echo ""
echo "Tmux configuration:"
# Note: .tmux.conf is generated by theme-switch to XDG location
# We'll create the compatibility symlink after theme generation (see below)
create_link "$DOTFILES_DIR/tmux" "$HOME/.tmux"

# Create local override file from template (never overwrite user customisations)
tmux_local="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/local.conf"
mkdir -p "$(dirname "$tmux_local")"
if [[ ! -f "$tmux_local" ]]; then
    cp "$DOTFILES_DIR/tmux/local.conf.template" "$tmux_local"
    success "Created $tmux_local from template"
    printf '  %s→%s Edit with: nvim %s\n' "${CYAN}" "${NC}" "$tmux_local"
else
    info "Kept existing $tmux_local"
fi

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

    # Create local override file from template (never overwrite user customisations)
    nvim_local="$HOME/.config/nvim/local.lua"
    if [[ ! -f "$nvim_local" ]]; then
        cp "$DOTFILES_DIR/nvim/local.lua.template" "$nvim_local"
        success "Created $nvim_local from template"
        printf '  %s→%s Edit with: nvim %s\n' "${CYAN}" "${NC}" "$nvim_local"
    else
        info "Kept existing $nvim_local"
    fi
fi

# Hammerspoon (full)
if should_install "full"; then
    echo ""
    echo "Hammerspoon configuration:"
    create_link "$DOTFILES_DIR/hammerspoon" "$HOME/.hammerspoon"
fi

# Ghostty (core)
# Config is generated by theme-switch to XDG location (~/.config/ghostty/config)
# On macOS, symlink Application Support to XDG location
if should_install "core"; then
    echo ""
    echo "Ghostty configuration:"
    mkdir -p "$HOME/.config/ghostty"

    # Note: Ghostty on macOS loads from BOTH ~/Library/Application Support/
    # and ~/.config/ghostty/. We only write to XDG — no symlink needed.
    # A symlink between them causes double-loading and config-file cycle errors.

    # Create local override file from template (never overwrite user customisations)
    ghostty_local="$HOME/.config/ghostty/local"
    if [[ ! -f "$ghostty_local" ]]; then
        cp "$DOTFILES_DIR/ghostty/local.template" "$ghostty_local"
        success "Created $ghostty_local from template"
        printf '  %s→%s Edit with: nvim %s\n' "${CYAN}" "${NC}" "$ghostty_local"
    else
        info "Kept existing $ghostty_local"
    fi
fi

# Karabiner (full)
if should_install "full"; then
    echo ""
    echo "Karabiner configuration:"
    mkdir -p "$HOME/.config/karabiner"
    create_link "$DOTFILES_DIR/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"
fi

# btop (core)
if should_install "core"; then
    echo ""
    echo "btop configuration:"
    mkdir -p "$HOME/.config/btop"
    create_link "$DOTFILES_DIR/btop/btop.conf" "$HOME/.config/btop/btop.conf"
fi
# Launchers (core)
if should_install "core"; then
    echo ""
    echo "Launchers:"
    mkdir -p "$HOME/.local/launchers"
    create_link "$DOTFILES_DIR/launchers/tnew" "$HOME/.local/launchers/tnew"
fi

# LazyGit / LazyDocker (core)
if should_install "core"; then
    echo ""
    echo "LazyGit configuration:"
    if [[ "$(uname)" == "Darwin" ]]; then
        mkdir -p "$HOME/Library/Application Support/lazygit"
        create_link "$DOTFILES_DIR/lazygit/config.yml" "$HOME/Library/Application Support/lazygit/config.yml"
        mkdir -p "$HOME/Library/Application Support/lazydocker"
        create_link "$DOTFILES_DIR/lazydocker/config.yml" "$HOME/Library/Application Support/lazydocker/config.yml"
    else
        mkdir -p "$HOME/.config/lazygit"
        create_link "$DOTFILES_DIR/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"
        mkdir -p "$HOME/.config/lazydocker"
        create_link "$DOTFILES_DIR/lazydocker/config.yml" "$HOME/.config/lazydocker/config.yml"
    fi
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

# ─────────────────────────────────────────
# Generate themed configurations
# ─────────────────────────────────────────
echo ""
info "Generating themed configurations"

if [[ -x "$DOTFILES_DIR/scripts/theme-switch" ]]; then
    # Get current theme or default to dracula
    current_theme="dracula"
    theme_file="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/current-theme"

    if [[ -f "$theme_file" ]]; then
        current_theme=$(cat "$theme_file")
    fi

    info "Applying theme: $current_theme"
    "$DOTFILES_DIR/scripts/theme-switch" "$current_theme" --quiet || {
        warn "Failed to apply theme, using default (dracula)"
        "$DOTFILES_DIR/scripts/theme-switch" dracula --quiet
    }
    success "Generated themed configurations"
    
    # Create compatibility symlink from ~/.tmux.conf to XDG location
    # (do this after theme-switch generates the file)
    echo ""
    info "Creating tmux compatibility symlink"
    xdg_tmux_conf="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"
    if [[ -f "$xdg_tmux_conf" ]]; then
        create_link "$xdg_tmux_conf" "$HOME/.tmux.conf"
    else
        warn "XDG tmux config not found at $xdg_tmux_conf"
    fi
else
    warn "theme-switch script not found, skipping theme generation"
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
