# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.1.11] - 2026-01-14

### Added
- Tmux: `cleanup-tests.sh` script to clean up orphaned test servers and session backups
- Tmux: `tcleanup` shell alias for test cleanup script
- Tmux: trap handlers in test scripts for automatic cleanup on exit/interrupt
- Scripts: `run-tests.sh` - dynamic test discovery runner with per-suite summaries
- CI: ShellCheck now lints test scripts in `tmux/.tmux/scripts/tests/` and `scripts/tests/`
- CI: Dynamic test discovery automatically finds and runs all test files
- Ghostty: `opt+up` and `opt+down` keybindings for terminal navigation

### Changed
- CI: Replaced manual test execution with dynamic discovery via `run-tests.sh`
- CI: Renamed "Library Tests" job to "All Tests" to reflect comprehensive coverage
- Tests: Standardised patterns in test runner (boolean comparisons, counter management, skip handling)
- Tmux: Simplified fzf session/window switcher keybindings - removed page navigation (`f`/`b`) and half-page (`d`/`u`) keys, now use only `j`/`k` for navigation
- Tmux: Changed kill/undo keybindings from `alt+x`/`alt+u` to `x`/`u` in fzf switchers for better ergonomics
- Tmux: Updated border labels and keybinding hints in session and window switchers to reflect simplified navigation

### Fixed
- Tmux: test scripts now properly clean up resources even when interrupted
- CI: Now runs all 12 tests instead of only 4 (discovered 8 previously uncovered tests)
- OpenCode alerts: Fixed `agent-alert.sh` to work reliably when `$TMUX_PANE` environment variable is not set, improving alert delivery from OpenCode plugin hooks
- Tmux: Fixed terminal dimension detection in `ui.sh` to use `LINES`/`COLUMNS` environment variables when available (tmux popups), falling back to `tput` for better compatibility

## [0.1.10] - 2026-01-14

### Added
- Scripts: `scripts/hooks/wrappers/` - subdirectory for agent-specific alert wrappers
- Scripts: `scripts/hooks/wrappers/opencode-alert.sh` - OpenCode alert wrapper (placeholder)
- Tmux: Agent visual identity system (Claude ⚡ yellow, OpenCode 🔮 purple, fallback 🤖 blue)
- Tmux: `get_agent_display()` helper function for agent icons and colours
- Tmux: Dynamic wildcard clearing for all `@*_alert` options (agent-agnostic)
- Tmux: Confirmation dialogs when closing last pane/window in a session

### Changed
- Scripts: Moved `claude-alert.sh` to `scripts/hooks/wrappers/` subdirectory
- Scripts: Renamed `agents-alert-clear.sh` → `agent-alert-clear.sh` for consistency
- Tmux: `agent-alerts.sh` now displays agent-specific icons with colours
- Tmux: `update-alert-on-rename.sh` fixed to handle 3-field format (session:window:agent)
- Tmux: Alert library enhanced with multi-agent icon/colour configuration
- Tests: Updated `test-list-claude.sh` to check for `ALERTS_FILE` instead of `CLAUDE_ALERTS_FILE`

### Removed
- Scripts: `claude-alert-clear.sh` (broken 2-field regex, replaced by library)

## [0.1.9] - 2026-01-12

### Added
- Scripts: `agent-alert.sh` - generic foundation for multi-agent alert support
- Scripts: `agent-alert-clear.sh` - unified alert clearing across agents
- Tmux: `move-window.sh` script for window management

### Changed
- Tmux: refactored alert system with `session:window:agent` format (internal) for future multi-agent support
- Tmux: renamed `claude-alerts.sh` to `agent-alerts.sh` reflecting generic architecture
- Scripts: `claude-alert.sh` simplified to wrapper around `agent-alert.sh`
- Tmux: `list-claude.sh` now sorts by last-viewed timestamp for better recency ordering
- Tmux: alert clearing centralized with `clear_window_alerts()` function

### Fixed
- Scripts: `/dev/tty` unavailable errors in hook scripts
- Tmux: alert display deduplicates windows when multiple agents present
- Tmux: session and window pickers correctly show alerts with new internal format

## [0.1.8] - 2026-01-11

### Added
- Tmux: Claude instance switcher with fzf (`prefix + c`) - shows all running Claude Code instances across sessions with alerts highlighted
- Tmux: automatic alert tracking update when windows are renamed (prevents stale alerts)
- Hammerspoon: Notion app added to auto-centre windows on creation

### Changed
- `list-claude.sh` now outputs fzf-friendly format (use `--verbose` flag for coloured CLI output)
- `prefix + c` keybinding added for interactive Claude instance switcher

### Removed
- `tclaude` shell command (replaced by `prefix + c` fzf picker)

### Fixed
- Tmux: stale Claude alerts persisting after window renames
- Tmux: improved alert file handling with literal string matching

## [0.1.7] - 2026-01-11

### Fixed
- Hammerspoon auto-center: removed invalid `setAlpha()` calls causing errors
- Hammerspoon auto-center: position-based detection prevents window flicker when opening URLs from browser

## [0.1.6] - 2026-01-11

### Added
- `uninstall.sh` script with preset-aware Homebrew package removal
- Inline backup during symlink creation (handles existing files gracefully)
- Rollback now works from backups even after successful installation

### Changed
- Replaced deprecated `neofetch` with `fastfetch` (faster, actively maintained)
- Prerequisites check now uses app paths for casks (Ghostty, Karabiner)
- nvim-treesitter updated to new API (no longer uses deprecated `.configs` module)

### Fixed
- Homebrew PATH not available in step 2 of fresh installations (subshell PATH issue)
- Bun formula not found on fresh installs (now uses `oven-sh/bun` tap)
- Removed deprecated `homebrew/bundle` and `homebrew/cask-fonts` taps
- `sqld` formula not found (now uses `libsql/sqld` tap)
- `speedtest` formula not found (now uses `teamookla/speedtest` tap)
- Removed `turso` (build issues on ARM)
- Invalid Ghostty keybind removed
- Symlinks now created even when files already exist (backed up inline)
- First-time nvim launch no longer errors (pcall fallback for treesitter)

## [0.1.4] - 2026-01-11

### Added
- `tclaude` command to list all running Claude Code instances across tmux sessions
- `tmux/.tmux/scripts/list-claude.sh` script for tracking Claude processes
- `~/.local/launchers` added to PATH for launcher script discovery

## [0.1.3] - 2026-01-11

### Added
- **Dotfiles CLI** (`scripts/dotfiles`): Manage your installation with simple commands
  - `dotfiles update`: Pull latest changes and re-run installer with saved preset
  - `dotfiles status`: Show sync status and local changes
  - `dotfiles sync`: Preview incoming changes without applying
  - `dotfiles health`: Run full health check
  - `dotfiles edit`: Open dotfiles directory in $EDITOR
  - `dotfiles cd`: Print dotfiles path for navigation
- `launchers/code`: VS Code dynamic launcher using macOS Spotlight
- `visual-studio-code` and `docker` casks to Brewfile (Containers & Infrastructure section)
- Tmux status bar sync indicator (↓↑↕) shows when dotfiles are behind/ahead of origin
- Shell startup profiling with `zsh-profile` and `zsh-profile-detailed` functions
- Tab completion for `dotfiles` command in zsh
- **Nvim LSP/Treesitter**: Expanded language support
  - LSP servers: bashls, cssls, html, jsonls, yamlls
  - Treesitter parsers: C#, CSS, Go, JavaScript, JSON, Python, TypeScript/TSX, YAML
  - Formatters: goimports, prettier (JS/TS/JSON/YAML)
  - Linter: golangci-lint

### Changed
- Dotfiles CLI installed to `~/.local/bin/dotfiles` (XDG-compliant)
- Installer saves preset to `~/.config/dotfiles/preset` for future updates
- Nvim Mason tool installer reorganised for clearer LSP server vs formatter/linter separation

### Fixed
- Header centering calculation in `print_header` function
- Nvim LSP cursor position errors when jumping to invalid locations

## [0.1.2] - 2026-01-11

### Added
- **Install presets**: Three installation modes for different use cases
  - `--minimal`: zsh + tmux only (servers, remote machines)
  - `--core`: minimal + nvim, ghostty, AI/CLI tools, session launchers (cross-platform dev)
  - `--full`: core + Hammerspoon, Karabiner, music-presence (macOS power user)
- Brewfile sections with `# @preset:` markers for preset-based filtering
- Preset-aware scripts: backup, symlinks, health-check, prerequisites all respect preset
- Test suite for preset filtering and `should_install` helper function
- Session launchers directory (`launchers/`) added to PATH in .zprofile

### Changed
- **Renamed**: `bin/tm` → `launchers/tnew`, `bin/ta` removed (use `tattach` function)
- **Renamed**: `bin/dana` → `launchers/dana`
- Moved `music-presence` cask to full preset (macOS-only)
- Installation guide updated with preset documentation
- TPM (Tmux Plugin Manager) pinned to v3.1.0 for reproducibility

### Fixed
- Security: command injection vulnerability in zsh preexec function
- Security: hardcoded username paths in .zprofile replaced with $HOME
- Security: path traversal vulnerability in rollback restore
- Security: race condition when creating secrets file (now uses umask)
- Health check exit code now reflects all check failures
- DOTFILES_DIR default derived from script location instead of hardcoded path
- Install preset validation rejects invalid values with clear error
- Backup directory names include PID for uniqueness

## [0.1.1] - 2026-01-11

### Added
- `alerts.sh` library: centralised alert utilities for tmux scripts
- `list-windows.sh`: window listing script with ⚡ indicator for Claude alerts
- Session switcher now shows ⚡ indicator for sessions containing Claude alerts

### Fixed
- Claude alerts now properly cleared when killing windows or sessions (prevents orphaned alerts)
- Window timestamp hook clears alerts as safety net when switching windows
- alerts.sh: prevent errexit from triggering on grep exit code 1

## [0.1.0] - 2026-01-10

Initial public release of the dotfiles configuration.

### Core Configuration

#### Zsh
- Powerlevel10k prompt with custom configuration
- fnm (Fast Node Manager) integration with auto-switching
- fzf integration for fuzzy finding
- Comprehensive aliases for git, docker, and common operations
- Modular structure with secrets file support

#### Tmux
- Custom keybindings with Option-key navigation
- fzf-based window and session switchers
- Undo system for killed windows, panes, and sessions
- Claude Code integration with alert notifications
- Session resurrection with per-session backups
- Custom scripts library with validation and UI helpers

#### Neovim
- Based on kickstart.nvim with modular plugin organisation
- LSP support via Mason (gopls, pyright, ts_ls, lua_ls, clangd, omnisharp)
- Completion with blink.cmp
- GitHub Copilot integration
- LazyGit integration
- Auto dark/light mode following system theme (Dracula/Catppuccin)
- Telescope for fuzzy finding
- Neo-tree file explorer
- Treesitter syntax highlighting

#### macOS Applications
- Hammerspoon: auto-centre windows for Ghostty, Arc, Dia, JetBrains IDEs, Discord, Slack
- Karabiner-Elements: Caps Lock to Escape/Control, UK keyboard layout fixes
- Ghostty terminal configuration

### Project Tooling
- `launchers/tnew`: Generic tmux development session launcher
- `launchers/dana`: Dana project-specific multi-window tmux session
- Automated installation script with rollback support
- Health check and prerequisites verification scripts
- CI workflow with shellcheck, stylua, and library tests

### Documentation
- Comprehensive README with installation guide and keybinding reference
- Troubleshooting guide with common issues and solutions
- Per-component README files (tmux, nvim, hammerspoon, etc.)

### Added
- Help text (`-h`/`--help`) for `launchers/dana`, `launchers/tnew`, and install scripts
- Dana project launcher documentation in README.md
- macOS and Linux compatibility badges in README.md
- `show_error()` helper function in common.sh for popup error display
- UI error messages in undo-window.sh and undo-session.sh
- Discord and Slack to Hammerspoon auto-centre apps
- Extended troubleshooting guide: common error messages table, Linux/macOS platform differences, fnm/Node.js issues, ANDROID_HOME issues, installation failure recovery
- kill-window.sh now supports target argument (`session:window`) for use from fzf picker

### Changed
- **Tmux script naming convention**: renamed session scripts for consistency
  - `session-kill.sh` → `kill-session.sh`
  - `session-new.sh` → `new-session.sh`
  - `session-rename.sh` → `rename-session.sh`
  - `session-undo.sh` removed (consolidated into `undo-session.sh`)
  - `window-kill.sh` removed (consolidated into `kill-window.sh`)
- `session_exists()` now uses exact match (`grep -qxF`) instead of prefix match
- rename-window.sh: improved fzf prompt styling with border and labels
- undo-session.sh: now uses shared library functions and UI helpers
- Neovim README.md: complete rewrite with proper structure and documentation
- Updated LICENSE copyright year to 2026

### Fixed
- ANDROID_HOME PATH issue: conditional check prevents invalid PATH entry when variable is unset
- Alert file operations: use `grep -F` for fixed string matching to prevent regex metacharacter issues
- rename-window.sh: disabled automatic-rename after manual rename to preserve custom names
- undo-window.sh: restores automatic-rename setting correctly
- rename-session.sh: proper error handling with show_error() for popup context
- .tmux.conf: updated script references from `window-kill.sh` to `kill-window.sh`
