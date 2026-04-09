# Brewfile - Homebrew Bundle
# Install with: brew bundle install
#
# Preset markers:
#   @preset: minimal - included in minimal, core, and full
#   @preset: core    - included in core and full
#   @preset: full    - included in full only

# Taps
tap "Adembc/homebrew-tap"
tap "libsql/sqld"
tap "morantron/tmux-fingers"
tap "oven-sh/bun"
tap "seanhalberthal/tap"
tap "teamookla/speedtest"

# =============================================================================
# @preset: minimal
# Shell & Terminal Essentials (zsh + tmux)
# =============================================================================

brew "zsh"
brew "tmux"                   # >= 3.3 required for popup support
brew "powerlevel10k"
brew "zsh-autosuggestions"
brew "fzf"                    # >= 0.40 for --tmux flag
brew "direnv"

# =============================================================================
# @preset: core
# Editors & Development Tools
# =============================================================================

# Editors
brew "neovim"            # >= 0.11 required for nvim-treesitter
brew "tree-sitter-cli"   # Required by nvim-treesitter for parser compilation
cask "visual-studio-code"

# AI Coding Assistants
brew "opencode"
cask "codexbar" # Menu bar usage monitor for Codex and Claude

# Git & GitHub
brew "gh"
brew "lazygit"

# Search & Navigation
brew "ripgrep"       # >= 13.0
brew "fd"            # Fast find alternative
brew "tree"
brew "jq"
brew "yq"            # YAML processor (used by gh-dash local merge)
brew "wget"
brew "bat"           # Cat with syntax highlighting
brew "diffnav"       # Diff navigator for GitHub PRs
brew "monolith" unless OS.linux? && Hardware::CPU.arm?  # No Linux ARM bottle

# Build Tools
brew "binutils" # GNU binary utilities
brew "gcc"      # GNU compiler collection
brew "nasm"     # Netwide assembler
brew "nano"     # Text editor

# Tmux Extras
brew "morantron/tmux-fingers/tmux-fingers" # Quick pattern copy (requires gcc on Linux)

# =============================================================================
# @preset: core
# Languages & Runtimes
# =============================================================================

# Node.js (via fnm - Fast Node Manager)
brew "fnm"             # macOS-only (Linux uses curl installer)
brew "oven-sh/bun/bun" # >= 1.0

# Go
brew "go"

# Python
brew "python@3.13"
brew "pipx"


# Java
brew "openjdk"
cask "zulu@17"

# .NET
cask "dotnet-sdk"

# =============================================================================
# @preset: core
# Development Tools
# =============================================================================

# Code Quality
brew "shellcheck"                    # Shell script linter
brew "luacheck"                      # Lua linter
brew "seanhalberthal/tap/supplyscan" # Supply chain vulnerability scanner
brew "sonar-scanner"

# Database
brew "postgresql@14"
brew "mongosh"
brew "libsql/sqld/sqld"
brew "gotermsql" unless OS.linux? && Hardware::CPU.arm? # No Linux ARM formula

# Containers & Infrastructure
brew "act"                          # GitHub Actions locally
brew "cloudflared"                  # Cloudflare Tunnel client
brew "lazydocker"                   # Docker TUI
brew "Adembc/homebrew-tap/lazyssh"  # SSH host manager TUI

# Misc Dev Tools
brew "cmake"
brew "staticcheck"   # Go linter
brew "golangci-lint" # Go meta-linter
brew "swift-format"  # macOS-only
brew "golang-migrate"

# =============================================================================
# @preset: core
# Extra Utilities & Tools
# =============================================================================

brew "ffmpeg"
brew "imagemagick"
brew "btop"                          # System monitor (htop replacement)
brew "fastfetch"                     # neofetch replacement (faster, maintained)
brew "teamookla/speedtest/speedtest" # Speedtest CLI from Ookla
brew "glow"                          # Markdown renderer
brew "asciinema"                     # Terminal session recorder
brew "figlet"                        # ASCII art text banners
brew "toilet"                        # Unicode/colour text banners (figlet-compatible)
brew "chafa"                         # Terminal image renderer (used by music.nvim)
brew "seanhalberthal/tap/lazycron"   # Cron job manager TUI
brew "seanhalberthal/tap/jiru"       # Jira TUI app
brew "snitch" unless OS.linux? && Hardware::CPU.arm? # No Linux ARM bottle

# =============================================================================
# @preset: core
# Terminal & Fonts
# =============================================================================

# Terminal
cask "ghostty"

# Cloud
cask "gcloud-cli"

# Nerd Fonts for terminal icons
cask "font-meslo-lg-nerd-font"
cask "font-jetbrains-mono-nerd-font"

# =============================================================================
# @preset: full
# macOS-Specific Applications
# =============================================================================

# Automation
cask "hammerspoon"
cask "karabiner-elements"  # Keyboard customisation

# Music
cask "music-presence"      # Discord Rich Presence for Apple Music

# Utilities
cask "raycast"             # Spotlight replacement
