# Brewfile: homebrew bundle
# install with: brew bundle install
#
# preset markers:
#   @preset: minimal - included in minimal, core, and full
#   @preset: core    - included in core and full
#   @preset: full    - included in full only

# =============================================================================
# @preset: minimal
# Shell & Terminal Essentials (zsh + tmux)
# =============================================================================

brew "bash"                   # macOS ships 3.2; the scripts need 4+ (declare -A, local -n)
brew "zsh"
brew "tmux"                   # >= 3.3 for the popup style options
brew "powerlevel10k"
brew "zsh-autosuggestions"
brew "zsh-completions"
brew "fzf"                    # >= 0.53 for the --tmux flag
brew "direnv"
brew "carapace"               # multi-shell completion provider (bridges zsh completion)

# =============================================================================
# @preset: core
# Editors & Development Tools
# =============================================================================

# Taps
tap "Adembc/homebrew-tap"
tap "charmbracelet/tap"
tap "libsql/sqld"
tap "morantron/tmux-fingers"
tap "neur0map/tap"
tap "oven-sh/bun"
tap "undont/tap"

# Editors
brew "neovim"            # >= 0.12 required by nvim-treesitter
brew "tree-sitter-cli"   # required by nvim-treesitter for parser compilation
brew "nano"
cask "zed"               # editor
brew "duti"              # macOS-only; sets Zed as default handler for code files

# AI Coding Assistants
brew "opencode"
cask "codexbar" # menu bar usage monitor for Codex and Claude

# Git & GitHub
brew "gh"
brew "lazygit"       # Git TUI

# Search & Navigation
brew "ripgrep"       # >= 13.0
brew "fd"            # fast find alternative
brew "tree"
brew "jq"
brew "yq"            # used by the gh-dash local merge
brew "wget"
brew "bat"           # cat with syntax highlighting
brew "diffnav"       # diff navigator for GitHub PRs
brew "monolith" unless OS.linux? && Hardware::CPU.arm?  # no Linux ARM bottle
brew "zoxide"        # smart cd replacement

# File Manager
brew "yazi"          # terminal file manager
brew "poppler"       # PDF rendering (pdftoppm) for yazi file previews
brew "ffmpegthumbnailer"  # video thumbnails for yazi file previews
brew "resvg"         # SVG rendering for yazi file previews
brew "sevenzip"      # archive previews (7zz) for yazi file previews

# Build Tools
brew "binutils" # GNU binary utilities
brew "gcc"      # GNU compiler collection
brew "nasm"     # netwide assembler
brew "bear"     # generates compile_commands.json for clang tooling (C/C++/ObjC)

# Tmux Extras
brew "morantron/tmux-fingers/tmux-fingers" # quick pattern copy (requires gcc on Linux)
brew "undont/tap/poke"                     # teammate pokes (tmux status segment)

# =============================================================================
# @preset: core
# Languages & Runtimes
# =============================================================================

# Node.js (via fnm)
brew "fnm"             # macOS-only (Linux uses curl installer)
brew "oven-sh/bun/bun" # >= 1.0

# Go
brew "go"

# Python
brew "python@3.13"
brew "uv"            # python package and tool manager (`uv tool install`, `uvx`)


# Java
brew "openjdk"

# Android (commandline tools: SDK manager, emulator, adb)
cask "android-commandlinetools"

# .NET
cask "dotnet-sdk"

# =============================================================================
# @preset: core
# Development Tools
# =============================================================================

# Code Quality
brew "shellcheck"                    # shell script linter
brew "luacheck"                      # lua linter
brew "undont/tap/supplyscan" # supply chain vulnerability scanner
brew "sonar-scanner"

# Database
brew "postgresql@17"
brew "mongosh"
brew "libsql/sqld/sqld"

# Containers & Infrastructure
brew "act"                          # GitHub Actions locally
brew "cloudflared"                  # Cloudflare Tunnel client
brew "lazydocker"                   # Docker TUI
brew "Adembc/homebrew-tap/lazyssh"  # SSH host manager TUI
cask "gcloud-cli"

# Misc Dev Tools
brew "cmake"
brew "ninja"
brew "staticcheck"   # Go linter
brew "golangci-lint" # Go meta-linter
brew "swift-format"  # macOS-only
brew "swiftlint"     # macOS-only; Swift linter (nvim-lint)
brew "golang-migrate"
brew "scc"
brew "httpyac"

# =============================================================================
# @preset: core
# Extra Utilities & Tools
# =============================================================================

brew "ffmpeg"
brew "imagemagick"
brew "btop"                          # system monitor (htop replacement)
brew "gdu"                           # disk usage analyser TUI (du replacement)
brew "watch"                         # periodic command refresh
brew "fastfetch"                     # neofetch replacement (faster, maintained)
brew "glow"                          # markdown renderer
brew "asciinema"                     # terminal session recorder
brew "figlet"                        # ASCII art text banners
brew "toilet"                        # unicode/colour text banners (figlet-compatible)
brew "chafa"                         # terminal image renderer (used by music.nvim)
brew "charmbracelet/tap/freeze"      # render code/terminal output to an image
brew "undont/tap/jiru"               # Jira TUI app
brew "neur0map/tap/gpk"              # unified package manager TUI
brew "hyperfine"                     # benchmarking CLI
brew "snitch" unless OS.linux? && Hardware::CPU.arm? # no Linux ARM bottle

# =============================================================================
# @preset: core
# Terminal & Fonts
# =============================================================================

# Terminal
cask "ghostty"

# Nerd Fonts for terminal icons
cask "font-meslo-lg-nerd-font"
cask "font-jetbrains-mono-nerd-font"
cask "font-monaspace-nf"            # Monaspace Neon NF

# =============================================================================
# @preset: full
# Desktop Applications
# =============================================================================

# Automation
cask "hammerspoon"
cask "karabiner-elements"  # keyboard customisation

# Music
cask "music-presence"      # Discord Rich Presence for Apple Music

# Utilities
cask "raycast"             # Spotlight replacement
