# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Personal dotfiles for macOS/Linux development environment. Manages configuration for zsh, tmux, neovim, hammerspoon, ghostty, and karabiner.

## Common Commands

### Installation

```bash
./install.sh              # Full installation (default)
./install.sh --minimal    # zsh + tmux only (servers/SSH)
./install.sh --core       # + nvim, ghostty, AI tools (cross-platform dev)
./install.sh --full       # + Hammerspoon, Karabiner (macOS power user)
./install.sh --check-only # Run checks without making changes
./install.sh --skip-brew  # Skip Homebrew/package installation
```

### Testing

```bash
# Run all tests with dynamic discovery (recommended)
scripts/run-tests.sh

# Run with verbose output
scripts/run-tests.sh --verbose

# Run only tmux-dependent tests
scripts/run-tests.sh --tmux-only

# Run only standalone tests (skip tmux tests)
scripts/run-tests.sh --no-tmux

# Individual test suites (if needed)
# ────────────────────────────────────

# Installation library tests
scripts/_lib/test-install-libs.sh

# Tmux library tests
tmux/.tmux/scripts/_lib/test-tmux-libs.sh

# Individual tmux script tests
tmux/.tmux/scripts/tests/test-list-claude.sh
tmux/.tmux/scripts/tests/test-session-management.sh
tmux/.tmux/scripts/tests/test-kill-undo.sh

# Clean up orphaned test resources (if tests were interrupted)
tmux/.tmux/scripts/tests/cleanup-tests.sh
tmux/.tmux/scripts/tests/cleanup-tests.sh --dry-run  # Preview only

# Dotfiles CLI tests
scripts/tests/test-dotfiles-cli.sh

# All tests run by CI
# See .github/workflows/ci.yml for full list
```

**Test Discovery**: The test runner (`scripts/run-tests.sh`) automatically discovers all test files:
- Library tests: `*/_lib/test-*-libs.sh`
- Script tests: `tmux/.tmux/scripts/tests/test-*.sh`, `scripts/hooks/tests/test-*.sh`
- Integration tests: `scripts/tests/test-*.sh`

Tests requiring tmux are automatically detected and skipped if tmux is not available.

### Linting

```bash
# ShellCheck on installation scripts
shellcheck -x install.sh scripts/install/*.sh scripts/_lib/*.sh

# ShellCheck on tmux scripts
shellcheck -x tmux/.tmux/scripts/*.sh tmux/.tmux/scripts/_lib/*.sh

# Lua check on Neovim config
luacheck nvim/lua/ --no-unused-args --no-max-line-length
```

### Management

```bash
dotfiles update    # Pull latest and re-run installer
dotfiles status    # Check sync status
dotfiles health    # Run health check
./scripts/install/health-check.sh  # Verify installation
./scripts/install/uninstall.sh     # Remove symlinks
```

## Architecture

### Directory Structure

```
dotfiles/
├── scripts/              # Installation and utilities
│   ├── dotfiles          # CLI tool (update/status/health)
│   ├── install/          # Installer modules
│   ├── _lib/             # Shared shell libraries (common.sh, brewfile.sh, test-install-libs.sh)
│   ├── hooks/            # Tool hooks (claude-alert.sh, opencode-alert.sh)
│   └── tests/            # Test suites
├── zsh/                  # Zsh configuration
│   ├── .zshrc            # Main config
│   └── .zsh/             # Additional configs, secrets template
├── tmux/                 # Tmux configuration
│   ├── .tmux.conf        # Main config
│   └── .tmux/scripts/    # Custom scripts (session management, undo, alerts)
├── nvim/                 # Neovim configuration (kickstart.nvim based)
│   ├── init.lua          # Entry point
│   └── lua/custom/       # Modular config (core/, plugins/)
├── launchers/            # Session launch scripts (tnew, dana, code)
├── hammerspoon/          # macOS window automation
├── ghostty/              # Terminal emulator config
└── karabiner/            # Keyboard customisation
```

### Install Presets

The installer uses presets to filter `Brewfile` packages and symlinks:

- **minimal**: zsh, tmux (marked with `# @preset: minimal`)
- **core**: + nvim, ghostty, AI tools, launchers (marked with `# @preset: core`)
- **full**: + Hammerspoon, Karabiner (marked with `# @preset: full`)

Preset is saved to `~/.config/dotfiles/preset` and used by `dotfiles update`.

### Shared Libraries

**`scripts/_lib/common.sh`**: Core utilities used by all installation scripts
- Colour definitions (RED, GREEN, YELLOW, CYAN, NC)
- Output functions (error, warn, info, success, print_header, print_step)
- Platform detection (is_macos, get_homebrew_prefix)
- Preset validation (should_install)

**`scripts/_lib/test-install-libs.sh`**: Installation library test suite
- Tests for common.sh, brewfile.sh functionality
- Includes test framework helpers (pass, fail, skip, section)

**`tmux/.tmux/scripts/_lib/test-tmux-libs.sh`**: Tmux library test suite
- Tests for tmux common.sh, paths.sh, session.sh, alerts.sh
- Includes assertion helpers (assert_success, assert_failure, assert_equals)

**`tmux/.tmux/scripts/_lib/`**: Tmux-specific utilities
- `common.sh`: Error handling, tmux validation
- `session.sh`: Session management functions
- `alerts.sh`: Multi-agent alert system (Claude, OpenCode)
- `ui.sh`: Terminal dialogs and prompts

### Tmux Scripts Architecture

Custom tmux functionality is implemented via scripts bound to keybindings:
- **Kill/Undo**: `kill-pane.sh`, `kill-window.sh`, `kill-session.sh` save state; `undo-*.sh` restore
- **Session management**: `list-sessions.sh`, `list-windows.sh` with fzf integration
- **Resurrect extensions**: `resurrect-split.sh` (post-save hook), `resurrect-restore.sh` (per-session restore)
- **Agent alerts**: `agent-alerts.sh` shows status bar indicators for AI agents

### Neovim Structure

Based on kickstart.nvim with modular organisation:
- `lua/custom/core/`: options.lua, keymaps.lua, autocmds.lua
- `lua/custom/plugins/`: ui.lua, lsp.lua, completion.lua, telescope.lua, editor.lua, copilot.lua, git.lua
- `lua/kickstart/plugins/`: neo-tree.lua, gitsigns.lua, autopairs.lua, debug.lua, lint.lua

## Shell Script Conventions

- Use `set -euo pipefail` at script start
- Source `scripts/_lib/common.sh` for shared utilities
- Use printf for coloured output (not echo)
- Conditional PATH additions: `[[ -n "$VAR" ]] && export PATH=$PATH:$VAR/bin`
- All scripts pass ShellCheck with standard exclusions (SC1091, SC2059, SC2015, SC2016, SC2034)

## Test Patterns

Tests use a simple pass/fail pattern:
```bash
source "path/to/_test-helpers.sh"  # For tmux tests
section "Test Group Name"
assert_success "description" command args
assert_equals "description" "expected" "$actual"
```

Tmux tests use isolated test servers via `setup_test_server`/`cleanup_test_server`.
