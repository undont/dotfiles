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
tmux/scripts/_lib/test-tmux-libs.sh

# Individual tmux script tests
tmux/scripts/tests/test-list-claude.sh
tmux/scripts/tests/test-session-management.sh
tmux/scripts/tests/test-kill-undo.sh

# Clean up orphaned test resources (if tests were interrupted)
tmux/scripts/tests/cleanup-tests.sh
tmux/scripts/tests/cleanup-tests.sh --dry-run  # Preview only

# Dotfiles CLI tests
scripts/tests/test-dotfiles-cli.sh

# All tests run by CI
# See .github/workflows/ci.yml for full list
```

**Test Discovery**: The test runner (`scripts/run-tests.sh`) automatically discovers all test files:
- Library tests: `*/_lib/test-*-libs.sh`
- Script tests: `tmux/scripts/tests/test-*.sh`
- Integration tests: `scripts/tests/test-*.sh`

Tests requiring tmux are automatically detected and skipped if tmux is not available.

### Linting

```bash
# ShellCheck on installation scripts
shellcheck -x install.sh scripts/install/*.sh scripts/_lib/*.sh

# ShellCheck on tmux scripts
shellcheck -x tmux/scripts/*/*.sh tmux/scripts/_lib/*.sh

# Lua check on Neovim config
luacheck nvim/lua/ --config nvim/.luacheckrc
```

### Makefile Shortcuts

```bash
make              # Show help
make test         # Run all tests
make lint         # Run all linters (shell + lua)
make install      # Full installation
make check        # Run checks only
make clean        # Clean orphaned test resources
```

### Management

```bash
dotfiles update    # Pull latest and re-run installer (shorthand: dot update)
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
│   ├── theme-switch      # Theme switching utility
│   ├── install/          # Installer modules
│   ├── _lib/             # Shared shell libraries (common.sh, brewfile.sh)
│   ├── hooks/            # Agent alert hooks
│   │   ├── agent-alert.sh, agent-alert-clear.sh
│   │   └── wrappers/     # Per-agent wrappers (claude, opencode)
│   └── tests/            # Test suites
├── themes/               # Theme definitions (dracula, catppuccin, tokyo-night, nord)
├── zsh/                  # Zsh configuration
│   ├── dotfiles.zsh      # Shared framework (sourced by ~/.zshrc)
│   ├── zshrc             # Backwards-compat wrapper (legacy symlinks)
│   ├── zshrc.template    # Template for user's ~/.zshrc
│   ├── zprofile          # Login shell config
│   ├── p10k.zsh          # Powerlevel10k theme config
│   └── *.template        # Templates for user config (secrets)
├── tmux/                 # Tmux configuration (symlinked to ~/.tmux)
│   ├── tmux.conf.template  # Theme template (processed by theme-switch)
│   └── scripts/          # Custom scripts organised by function (sessions/, windows/, instances/, etc.)
├── nvim/                 # Neovim configuration (kickstart.nvim based)
│   ├── init.lua          # Entry point
│   └── lua/custom/       # Modular config (core/, plugins/)
├── launchers/            # Session launch scripts (dev, github, btop)
├── hammerspoon/          # macOS window automation
├── ghostty/              # Terminal emulator config (config.template for theming)
├── karabiner/            # Keyboard customisation
└── Makefile              # Convenience targets for testing, linting, installation
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

**`tmux/scripts/_lib/test-tmux-libs.sh`**: Tmux library test suite
- Tests for tmux common.sh, paths.sh, session.sh, alerts.sh
- Includes assertion helpers (assert_success, assert_failure, assert_equals)

**`tmux/scripts/_lib/`**: Tmux-specific utilities
- `common.sh`: Error handling, tmux validation
- `paths.sh`: XDG-compliant undo file paths with legacy fallback
- `session.sh`: Session management functions
- `alerts.sh`: Multi-agent alert system (Claude, OpenCode)
- `ui.sh`: Terminal dialogs and prompts

### Theme System

Theme configuration follows XDG Base Directory standard to avoid git conflicts:

**Configuration Flow:**
1. `themes/*.theme` - Theme definitions (in repo)
2. `tmux/tmux.conf.template` - Tmux template with `{{PLACEHOLDERS}}` (in repo)
3. `ghostty/config.template` - Ghostty template with `{{PLACEHOLDERS}}` (in repo)
4. `~/.config/tmux/tmux.conf` - Generated config (XDG location)
5. `~/.tmux.conf` - Compatibility symlink → `~/.config/tmux/tmux.conf`
6. `~/.config/ghostty/config` - Generated ghostty config (XDG location, read natively on all platforms)

**Local Override Files (user-owned, survive theme changes):**
- `~/.config/ghostty/local` — appended to Ghostty config via `config-file` include
- `~/.config/tmux/local.conf` — sourced at end of tmux config via `source-file -q`
- `~/.config/nvim/local.lua` — personal Neovim settings (cursor, options, keymaps)
- `~/.config/gh-dash/local.yml` — deep-merged on top of generated config via `yq`
- `~/.config/lazygit/local.yml` — loaded via `LG_CONFIG_FILE` env var
- `~/.hammerspoon/local.lua` — loaded via `pcall(require, "local")` at end of init.lua

These files are created from templates on first install and never overwritten by `theme-switch` or `dotfiles update`. Add cursor style, font overrides, extra keybindings, etc. here.

**Switching Themes:**
```bash
theme-switch catppuccin-mocha    # Apply theme
theme-switch list                # Show available themes
theme-switch current             # Show current theme
```

**Benefits:**
- User theme changes don't create git conflicts
- Templates stay clean in repository
- Follows XDG standard (~/.config)
- Backwards compatible via ~/.tmux.conf symlink
- Personal overrides survive theme changes via local override files

**Migration:** Existing users should run `scripts/migrate-tmux-config.sh` once to move from the old setup to XDG.

### Config Ownership Patterns

Three patterns are used for configuration files. Choose based on whether the tool
supports a local override mechanism and how personal the config tends to be.

#### 1. Symlinked

Config lives in the repo. The installed path is a symlink pointing back to the
dotfiles directory. Changes committed to the repo propagate to all users on the
next `dotfiles update`.

**Used for:** configs shared exactly as-is with no per-user variation (zprofile,
p10k.zsh, tmux scripts, nvim plugins, launchers).

```
dotfiles/zsh/p10k.zsh  ←──symlink──  ~/.p10k.zsh
```

#### 2. Layered (symlink + local override)

The base config is symlinked from the repo (updates propagate), but the tool also
loads a second user-owned local file on top. The local file is created from a
`*.template` on first install and never overwritten by `dotfiles update`.

Use this pattern when the tool has a native include/multi-file mechanism.

**Used for:** tools that support layered configs — tmux, ghostty, nvim, lazygit,
hammerspoon, gh-dash.

| Tool | Base (symlinked) | Local override | Mechanism |
|---|---|---|---|
| tmux | `~/.config/tmux/tmux.conf` (generated) | `~/.config/tmux/local.conf` | `source-file -q` at end of config |
| ghostty | `~/.config/ghostty/config` (generated) | `~/.config/ghostty/local` | `config-file =` at end of config |
| nvim | `~/.config/nvim/` (symlinked dir) | `~/.config/nvim/local.lua` | `pcall(require, "local")` in init.lua |
| lazygit | `~/.config/lazygit/config.yml` (symlinked) | `~/.config/lazygit/local.yml` | `LG_CONFIG_FILE="base,local"` env var |
| hammerspoon | `~/.hammerspoon/init.lua` (symlinked) | `~/.hammerspoon/local.lua` | `pcall(require, "local")` at end of init.lua |
| gh-dash | `~/.config/gh-dash/config.yml` (generated) | `~/.config/gh-dash/local.yml` | `yq` deep-merge after `theme-switch` generation |

Template files for local overrides live in the repo next to the base config:
`lazygit/local.yml.template`, `hammerspoon/local.lua.template`, etc.

#### 3. Copy-on-install

Config is copied from the repo to the destination on first install, then becomes
fully user-owned. The repo version is a reference/default only — changes to it do
**not** propagate to existing installs. Use this only when the tool has no include
mechanism and the config is highly personal.

**Used for:** btop, lazydocker, karabiner, zshrc.

```
dotfiles/btop/btop.conf  ──copy──▶  ~/.config/btop/btop.conf  (user-owned)
```

**Implication:** if you improve a copy-on-install config in the repo, document the
change in `CHANGELOG.md` so users know to apply it manually.

### Tmux Scripts Architecture

Scripts are organised into functional subdirectories under `tmux/scripts/`:
- **sessions/**: `list.sh`, `new.sh`, `rename.sh`, `kill.sh`, `undo.sh` - Session management with fzf integration
- **windows/**: `list.sh`, `rename.sh`, `kill.sh`, `undo.sh`, `duplicate.sh`, `move.sh` - Window operations
- **panes/**: `kill.sh`, `undo.sh` - Pane management
- **launchers/**: `list.sh`, `picker.sh`, `run.sh`, `prompt.sh`, `new.sh`, `new-dir.sh`, `settings.sh`, `delete.sh` - Session launcher system
- **instances/**: `claude.sh`, `opencode.sh`, `nvim.sh`, `new.sh`, `kill.sh`, `connect-nvim.sh` - Process instance management (list, create, kill)
- **alerts/**: `show.sh`, `clear.sh`, `update-rename.sh`, `update-timestamp.sh` - Agent alert system for status bar
- **resurrect/**: `split.sh`, `restore.sh`, `delete.sh` - Per-session tmux-resurrect extensions
- **themes/**: `pick.sh`, `reload-fzf.sh`, `reload-ghostty.sh` - Runtime theme switching
- **utils/**: `undo-dispatch.sh`, `pick-url.sh`, `confirm.sh`, `dotfiles-status.sh` - Shared utilities
- **_lib/**: `common.sh`, `paths.sh`, `session.sh`, `alerts.sh`, `ui.sh` - Shared libraries
- **tests/**: `test-*.sh` - Test suites

### Neovim Structure

Based on kickstart.nvim with modular organisation:
- `lua/custom/core/`: options.lua, keymaps.lua, autocmds.lua
- `lua/custom/plugins/`: ui.lua, lsp.lua, completion.lua, telescope.lua, editor.lua, copilot.lua, git.lua
- `lua/kickstart/plugins/`: neo-tree.lua, gitsigns.lua, autopairs.lua, debug.lua, lint.lua, indent_line.lua

## Shell Script Conventions

- Use `set -euo pipefail` at script start
- Source `scripts/_lib/common.sh` for shared utilities
- Use printf for coloured output (not echo)
- Conditional PATH additions: `[[ -n "$VAR" ]] && export PATH=$PATH:$VAR/bin`
- All scripts pass ShellCheck with standard exclusions (SC1091, SC2059, SC2015, SC2016, SC2034)

### SCRIPT_DIR Pattern

Use consistent patterns for setting `SCRIPT_DIR` across all shell scripts:

**Production scripts** (launchers, installers, tmux scripts):
```bash
SCRIPT_DIR="${BASH_SOURCE%/*}"
```

**Test scripts** (test-*.sh, test-*-libs.sh):
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

**Rationale**:
- Production scripts: Simpler `${BASH_SOURCE%/*}` is faster and sufficient for scripts invoked from standard paths
- Test scripts: Full `cd` + `pwd` ensures absolute paths when tests are invoked from different directories
- Resurrect scripts: Use test pattern for consistency (invoked in various contexts)

**Examples**:
- ✓ `tmux/scripts/sessions/list.sh` - Uses `${BASH_SOURCE%/*}`
- ✓ `scripts/tests/test-brewfile.sh` - Uses `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`
- ✗ Don't mix patterns within the same category of scripts

## Test Patterns

Tests use a simple pass/fail pattern:
```bash
source "path/to/_test-helpers.sh"  # For tmux tests
section "Test Group Name"
assert_success "description" command args
assert_equals "description" "expected" "$actual"
```

Tmux tests use isolated test servers via `setup_test_server`/`cleanup_test_server`.

## Documentation Updates

After completing any code change, check whether relevant documentation needs updating. This is a final step — do it after the implementation is done, not during.

**Key documentation locations:**
- `README.md` — feature summaries, handy aliases list
- `zsh/README.md` — aliases & functions tables, tab completion table
- `scripts/dotfiles` — the `cmd_aliases()` function powering `dot aliases`
- `CLAUDE.md` — architecture, conventions, common commands
- Component READMEs (`tmux/README.md`, `nvim/README.md`, etc.) — component-specific docs

**What to check:**
- New aliases/functions → update `scripts/dotfiles` (`cmd_aliases`), `zsh/README.md`, and `README.md`
- New tmux keybindings/scripts → update `tmux/README.md`
- New nvim plugins/keymaps → update `nvim/README.md`
- New install behaviour/presets → update `CLAUDE.md` and `README.md`
- New test files → confirm they're discovered by `scripts/run-tests.sh` (auto-discovery)
