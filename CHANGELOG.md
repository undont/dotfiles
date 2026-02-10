# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.2.18] - 2026-02-10

### Added
- Neovim: Quickfix build picker (`<leader>q`) — run project builds and populate quickfix with errors
  - Detects Go (`go vet`), TypeScript (`tsc`), .NET (`dotnet build`), and Makefile projects
  - TypeScript: Auto-detects package manager (bun/pnpm/yarn/npm) from lockfiles
  - Makefile: Parses build targets, shows numbered picker sorted by complexity
  - Buffer-aware: Walks up from current file to find nearest project marker
  - Progress: Shows fidget spinner during build
  - Only opens quickfix on failure (exit ≠ 0), shows "Succeeded" notification otherwise
  - ANSI codes stripped from output, quickfix height capped at 10 lines
- Neovim: .NET solution auto-selection — skips `.ci.sln`/`.ci.slnx` variants when only one non-CI solution exists
- Makefile: Git worktree management targets (`worktree-create`, `worktree-list`, `worktree-remove`)

## [0.2.17] - 2026-02-09

### Added
- Tmux: Edit launcher from picker (`e` key) — opens wizard pre-filled with existing values
- Shared library: `sanitise_launcher_name()` function in `common.sh` for reusable name validation

### Changed
- Tmux: Rename `agents/` directory to `instances/` for clearer naming (process instance management)
- Tmux: Reorganise all scripts into functional subdirectories (`sessions/`, `windows/`, `panes/`, `instances/`, `alerts/`, `launchers/`, `resurrect/`, `themes/`, `utils/`)
- Tmux: `new.sh` uses `new-window -P` to capture exact window target, avoiding name collisions with duplicate window names
- Tmux: URL picker keybinding changed from `Opt+y` to `prefix + y`
- Tmux: Launcher picker now supports half-page scroll (`Ctrl+d` / `Ctrl+u`)
- Tmux: Launcher picker uses "system launcher" terminology instead of "repo launcher"
- Tmux: Launcher picker (`prefix + p`) now sorts by most recently used (MRU) — last used launcher appears at top
- Tmux: `tmux.conf.template` updated with all new script paths
- Ghostty: Add `Cmd+Left` / `Cmd+Right` keybindings for Home/End
- Neovim: Add macOS-style navigation keybindings (`Opt+arrows`, `Opt+f/b`, `Home/End`) in normal, visual, and insert modes
- Neovim: PR review plugin flushes pending deletes before add lines for correct diff ordering
- Neovim: PR review plugin now uses custom highlight groups immune to gitsigns overrides
- Neovim: PR review plugin navigation (`]c`/`[c`) now jumps by hunks instead of individual lines
- Neovim: PR review plugin adds JetBrains-style gutter bars for modified sections
- Neovim: Gitsigns no longer defines `GitSignsDeleteVirtLn` (moved to PR review plugin as `OctoReviewDeleteVirtLn`)
- CI: ShellCheck glob updated for new subdirectory layout
- Zsh: `trestore` and `tkill` functions updated for new script paths
- CLAUDE.md: Updated directory structure and tmux scripts architecture documentation
- Launcher wizard: `--edit SOURCE` flag for editing existing launchers (rename, re-describe, modify windows)
- Launcher wizard: `ask()` now uses readline `-i` for editable default values instead of `[default]` hints
- Launcher name sanitisation extracted from `new-launcher.sh` into shared `sanitise_launcher_name()` function
- `new-launcher.sh` now sources `common.sh` instead of `colours.sh`
- `tnew` launcher: Minor description and help text cleanup

### Fixed
- Tests: Update Claude/nvim picker test paths for instances/ layout
- Tests: Normalise TMPDIR handling in nvim sync test to avoid invalid socket paths
- Tmux: Launcher picker rewritten for Bash 3.2 compatibility (macOS default bash, no associative arrays)
- Tmux: Launcher picker uses explicit cleanup instead of EXIT trap to avoid scope issues in pipes

## [0.2.16] - 2026-02-09

### Added
- Tmux: Session launcher picker (`prefix + p`) — create, run, and delete session launchers
- Tmux: Launcher wizard (`new-launcher.sh`) — step-based interactive scaffolding for new launchers
- Tmux: Theme-aware dotfiles logo in session, window, and launcher pickers
- Tmux: `require_fzf()` helper in common.sh for fzf dependency checks
- Tmux: Launcher path constants (`USER_LAUNCHERS`, `DOTFILES_LAUNCHERS`) in shared library
- Neovim: Markdown display improvements (wrap, conceallevel, visual line nav)
- Zsh: Ghostty TERMINFO fix for local and SSH sessions
- Tests: `test-launchers.sh` — 50 tests covering launcher management scripts
- Tests: `--pos` flag tests for theme picker
- Tests: Process tree ancestor-walking tests for Claude detection

### Fixed
- Security: Sanitise user input in fzf `become()` commands to prevent command injection
- Security: Escape single quotes in generated `send-keys` commands
- Security: Path traversal protection in `delete-launcher.sh` via basename guard
- DRY: Extracted `find_dotfiles_root()` from 3 scripts into shared `common.sh`
- Shebang: `list-launchers.sh` changed from `#!/bin/bash` to `#!/usr/bin/env bash`

### Changed
- Launcher name validation: length cap (64), strip leading dots/dashes, block reserved words
- Window count capped at 20 in launcher wizard
- `pick-theme.sh` and `list-launchers.sh` refactored to source `common.sh`

### Removed
- `launchers/dana` — use the launcher wizard (`prefix + p` → `n`) to create project launchers
- `launchers/code` — VS Code's `code` command is available via shell integration

## [0.2.15] - 2026-02-08

### Fixed
- Installer: `get_homebrew_prefix()` now returns correct Linux Homebrew path (`/home/linuxbrew/.linuxbrew`) instead of assuming macOS
- Installer: `xcode-select` no longer called on Linux — installs build prerequisites via apt/yum instead
- Installer: `brew bundle` no longer fails on Linux due to cask entries — cask lines filtered out on non-macOS
- Installer: Claude Code install no longer aborts entire installation on failure
- Installer: `brew list --cask` guarded behind `is_macos` (casks don't exist on Linux)
- Installer: Prerequisites checker now shows platform-appropriate install hints (apt on Linux, brew on macOS)
- Installer: macOS-only tools (swift-format, Karabiner, Hammerspoon, Ghostty app check) skipped on Linux

### Added
- `is_linux()` helper in common.sh for platform detection

## [0.2.14] - 2026-02-08

### Added
- Tmux: `new-instance.sh` - create new process window from picker (`n` key in Claude/OpenCode/nvim pickers)
- Tmux: `kill-instance.sh` - kill process in pane from picker with confirmation (`x` key in Claude/OpenCode/nvim pickers)
- Neovim: neotest-golang adapter (gotestsum runner, pinned to v1.15.1 for treesitter compatibility)
- Neovim: neotest-vitest adapter for Bun/TypeScript tests (`bun run test`)

### Changed
- Neovim: Fugitive review mode now shows deleted/old lines inline via gitsigns `show_deleted`
- Neovim: LSP go-to-definition, references, implementations, and type-definition now deduplicate results and display via Telescope
- Neovim: `<leader>q` diagnostic quickfix now filters to warnings and errors (skips hints/info)
- Neovim: Telescope path display changed to filename-first for easier scanning
- Neovim: Octo `]f` (next file) now marks the current file as viewed; `[f` (prev file) does not
- Neovim: Octo unified mode is the default when starting a review (toggle with `<localleader>u`)
- Tmux: list-claude, list-nvim, and list-opencode scripts refactored for performance — batch process detection, pre-fetched window names, and parameter expansion replace per-pane subshells
- Tmux: Claude, OpenCode, and nvim pickers now support `n` (new instance) and `x` (kill instance) inline actions
- Tmux: Removed `f`/`b` copy mode bindings for page navigation (use `Ctrl+f`/`Ctrl+b` instead)
- Installer: Unmigrated `local-aliases.zsh` content is now automatically appended into `~/.zshrc` during symlink creation

### Added
- Neovim: Octo unified review mode — single-pane PR diffs with gitsigns-style added/deleted line highlights and inline deleted lines as virtual text
- Neovim: `]c`/`[c` navigation between individual changed lines in Octo unified review mode
- Neovim: `<localleader>u` toggle between unified and side-by-side diff in Octo reviews
- Neovim: `GitSignsDeleteVirtLn` highlight group for inline deleted lines
- Neovim: Cheatsheet entries for VCS (Fugitive), test runner, .NET, snippets, window resize, and PR review navigation
- Neovim: `q` and `<leader>vc` keybindings to close fugitive status and cleanly exit review mode
- Tmux: Click session name in status bar to open session switcher popup
- Zsh: `git-prune` alias to delete local branches removed from remote
- Tmux: `is_pane_running()` helper in common.sh for checking active foreground processes in a pane (excludes suspended)

### Fixed
- Neovim: Filtered out Roslyn IDE0079 false-positive diagnostic ("Remove unnecessary suppression")

## [0.2.13] - 2026-02-06

### Changed
- Zsh: Inverted config architecture — `~/.zshrc` is now your personal file (not a symlink), sourcing `dotfiles.zsh` as a framework
- Zsh: Removed `local-aliases.zsh` system — personal config goes directly in `~/.zshrc`
- Installer: Migrates existing symlink users automatically, preserving `local-aliases.zsh` content

### Added
- `zsh/dotfiles.zsh` — shared framework extracted from the old `zshrc`
- `zsh/zshrc.template` — template for creating user's personal `~/.zshrc`
- `zsh/zshrc` — backwards-compat wrapper for unmigrated symlink users

### Fixed
- Installer: `DOTFILES_DIR` resolution now always produces absolute paths, preventing broken relative symlinks

## [0.2.12] - 2026-02-05

### Changed
- Installer: Claude Code now installed natively via `claude.ai/install.sh` instead of Homebrew cask — automatically uninstalls brew version if present
- Neovim: Added `<leader>lr` keybinding for LSP restart

### Fixed
- Neovim: mkdnflow to-do config uses correct `marker` field (renamed from `symbol` in upstream API)
- Tmux: list-nvim script no longer exits early when grep/ps/lsof return no matches (`|| true` guards)

## [0.2.11] - 2026-02-05

### Added
- Neovim: Octo PR review keybindings — `<leader>pe` (resume), `<leader>pm` (submit), `<leader>pp` (approve), `<leader>pa` (add comment)

### Fixed
- Neovim: Neo-tree crash on deleted files in git status — runtime patch via `debug.setupvalue` handles missing parent directories gracefully
- Neovim: Markdown list renumbering now uses `undojoin` so renumbering and the preceding edit are a single undo step

## [0.2.1] - 2026-02-05

### Added
- Neovim: Fugitive integration with custom status workflow — `<leader>vs` (status), `<leader>vb` (blame), `<leader>vd` (diff split)
- Neovim: Fugitive review mode with gitsigns line/number highlighting for changed files
- Neovim: .NET development via easy-dotnet.nvim with Roslyn LSP (replaces OmniSharp)
- Neovim: Neotest test runner with .NET adapter and `.slnx` support
- Neovim: Window resize keybindings (`<leader>wh/wl/wj/wk`)
- Neovim: `<leader>v` (VCS) and `<leader>w` (Window resize) which-key groups
- Neovim: Maple colourscheme — custom autumn-inspired theme with full treesitter/telescope/neo-tree support
- Themes: Maple theme definition for tmux, ghostty, and neovim
- Neovim: Telescope path display shows `parent/file.ext` instead of truncated paths
- Neovim: Statusline branch name truncated to ticket ID (e.g. `DANA-123`)
- Neovim: Octo `]f`/`[f` navigation auto-marks files as viewed
- Karabiner: Right Option → Control scoped to Ghostty and JetBrains IDEs only
- Installer: `gh-dash` extension installed automatically
- Zsh: `.dotnet/tools` added to PATH for .NET global tools

### Changed
- Neovim: Nerd Font enabled by default (`have_nerd_font = true`)
- Neovim: Gitsigns hunk navigation no longer wraps around buffer
- Neovim: Gitsigns `<leader>hu` now correctly calls `undo_stage_hunk` instead of `stage_hunk`
- Neovim: Gitsigns highlight colours explicitly set (resilient to colourscheme changes)
- Neovim: Which-key loads immediately instead of on VimEnter for reliable leader preview
- Neovim: Removed jsonls LSP server
- Neovim: Diffview patched to guard against invalid window IDs (upstream bug workaround)
- Neovim: Octo patched to pass buffer context to mappings (upstream bug workaround)
- Karabiner: Right Option → Control changed from global simple modification to app-scoped complex rule
- Tmux: New sessions now name first window "zsh" instead of default
- Neovim: Disabled swap files for Octo buffers

### Removed
- Neovim: difi.nvim (replaced by fugitive review mode)
- Neovim: OmniSharp LSP (replaced by Roslyn via easy-dotnet.nvim)

## [0.2.0] - 2026-02-03

### Added
- Neovim: PR review workflow — diffview.nvim (side-by-side diffs), octo.nvim (GitHub PRs), difi.nvim (inline overlay)
- Neovim: Markdown editing with mkdnflow.nvim (list continuation, todo toggles, table formatting)
- Neovim: `<leader>d` keybinding group for diff operations, `<leader>p` for PR review
- Neovim: Comprehensive cheatsheet covering all keybindings (git, diff, PR, debug, markdown, theme)
- Brewfile: difi CLI (oug-t/difi tap) for inline diff TUI

### Changed
- Neovim: Cheatsheet now uses `<leader>` notation consistently instead of mixed `Space`/`<leader>`

## [0.1.17] - 2026-01-28

### Added
- Tmux: Nvim instance picker (`prefix + n`) with buffer sync integration
- Tmux: `list-nvim.sh` - Lists all running nvim instances with working directories
- Tmux: `connect-nvim.sh` - Connects nvim to a Claude pane for buffer sync
- Hooks: `nvim-buffer-sync.sh` - Claude Code hook that adds edited files to paired nvim's buffer list
- Neovim: Auto-cleanup of unnamed empty buffers on BufEnter
- Tests: `test-nvim-sync.sh` - E2E tests for nvim buffer sync flow

### Fixed
- Tests: `test-session-management.sh` now uses colours from test helpers (fixes readonly variable error)
- Tests: `test-tmux-libs.sh` shellcheck exclusions now match CI configuration

## [0.1.16] - 2026-01-28

### Added
- Neovim: `Space sl` keymap for "go to line" functionality
- Tests: Session renaming test suite (`test-rename-session.sh`)
- Tests: Assertion helpers in test framework (assert_equals, assert_success, assert_failure)
- README: btop configuration directory documented in Contents section

### Changed
- Neovim: Replaced eslint_d linter with ESLint LSP server for improved integration
- Neovim: Updated cheatsheet keybinding from `Space sk` to `Space ?` in help text
- Tmux: Session rename script now outputs new session name for better script integration

### Fixed
- Scripts: Colours library now guards against multiple sourcing to prevent readonly variable errors
- Tmux: Alert library improved with safer grep operations and ALERTS_FILE guard

## [0.1.15] - 2026-01-26

### Added
- Launchers: Template file (`launcher.template`) for creating new project launchers
- Neovim: Custom gruvbox-dark colourscheme matching terminal theme exactly
- Dana launcher: Now reads `DANA_ROOT` from local aliases (falls back to `~/src/dana`)
- Neovim: Custom cheatsheet.txt for `Space ?` with actual keybindings
- Neovim: Auto-save on text change with auto-reload for external changes
- Neovim: `Space cc` and `Space cu` keymaps for Claude comment snippets
- Neovim: C# syntax highlighting support (treesitter parser alias)
- Neovim: LSP hover and signature help now use bordered windows
- Neovim: 10 new theme plugins (gruvbox, solarized, one-dark, monokai, ayu, everforest, kanagawa, rose-pine, nightfox, synthwave)
- Themes: 10 new theme definitions with full tmux/ghostty/nvim/fzf support
- Themes: README.md documenting theme system architecture and how to add themes
- Themes: `theme-defaults.sh` for automatic derivation of status bar, pane borders, and FZF colours from base colours
- btop: System monitor configuration (htop replacement)

### Changed
- Agent alerts: Aggregates alerts per session instead of per window for cleaner status bar display
- Neovim: Cheatsheet plugin now reads from custom cheatsheet.txt instead of bundled defaults
- Neovim: Improved formatting for `claudecomment` snippet (proper newlines)
- **Theme architecture**: Refactored to use automatic defaults instead of duplicating colours across files
  - Theme files now only define base colours and accents
  - Status bar, pane borders, FZF colours automatically derived via `theme-defaults.sh`
  - Reduced duplication and ensured consistency across all themes
  - Each theme specifies active accent colour (purple, cyan, or green)
- Tmux: Window rename alert updates now use file locking to prevent race conditions
- Tmux: Removed redundant alert clearing from `rename-window.sh` (handled by hook)
- **Directory structure**: Simplified by removing nested dotfile prefixes
  - `zsh/.zshrc` → `zsh/zshrc`, `zsh/.zprofile` → `zsh/zprofile`, etc.
  - `zsh/.zsh/` directory removed (templates now in `zsh/`)
  - `tmux/.tmux/` → `tmux/` (flattened)
  - `tmux/.tmux.conf.template` → `tmux/tmux.conf.template`
- User secrets and local aliases now use XDG location (`~/.config/zsh/`)
  - `~/.zsh/.secrets.zsh` → `~/.config/zsh/secrets.zsh`
  - `~/.zsh/.local-aliases.zsh` → `~/.config/zsh/local-aliases.zsh`
- Ghostty config is now generated (removed from repo, created by `theme-switch`)
- Tmux symlink now points to entire `tmux/` directory instead of nested `.tmux/`

### Fixed
- Agent alerts: Stricter validation for alert entries to prevent malformed data
- Tmux: Window rename alert updates now properly handle concurrent rename operations
- Tmux: Improved session restoration error handling in `restore-resurrect.sh` (suppressed spurious errors, added verification)
- Themes: Fixed colour harmony issues across multiple themes
  - Rose Pine: Corrected green/cyan swap (green was blue `#31748f`, now proper teal `#9ccfd8`)
  - Ayu Dark, Monokai, Nord, One Dark: Differentiated pink and red accent colours (were identical)
  - Gruvbox: Separated pink from red using proper Gruvbox purple/pink distinction
  - Solarized Dark: Fixed autocomplete visibility (palette 8 was same as background)
  - Solarized Dark: Corrected bright palette to match canonical Solarized specification
- Themes: Updated `theme-defaults.sh` to support `pink`, `yellow`, and `red` as active accents
- Themes: Adjusted default active accents for better visual appeal per theme
- Themes: Bell/alert colour now uses theme's active accent instead of hardcoded pink
- Themes: Tmux session name colour now follows theme accent for visual consistency

### Removed
- `ghostty/config` - now generated by theme-switch to XDG location
- `tmux/.tmux.conf` - replaced by template-based generation

### Documentation
- Neovim README: Added snippets directory, LuaSnip, and cheatsheet plugin
- Themes: Comprehensive README.md documenting how to add new themes
- README.md: Added themes directory to repository structure

## [0.1.14] - 2026-01-25

### Added
- Resurrect restore: Pane contents restoration (scrollback history)
- Resurrect restore: Command/process restoration for configured processes
- Resurrect restore: Restore-all functionality for batch session restoration
- Resurrect restore: Field validation and duplicate detection for malformed backups
- Resurrect restore: Pane readiness polling to prevent race conditions
- Theme system: XDG-compliant tmux config location (`~/.config/tmux/tmux.conf`)
- Theme system: Template processing to prevent git conflicts from theme switching
- Theme system: Migration script (`scripts/migrate-tmux-config.sh`) for existing users
- Tests: Comprehensive resurrect restore test suite (14 test functions)
- Tests: Fuzzy process matching tests for tilde prefix patterns
- Zsh: Tab completion for `trestore` CLI options

### Changed
- Tmux config: Now uses XDG location with backwards-compatible symlink
- Test helpers: Consolidated into `_test-helpers.sh` (removed duplication)
- Create-symlinks: TTY check for non-interactive environments (CI)

### Fixed
- Security: Path traversal validation for session names in resurrect-restore
- Security: Command sanitisation before `tmux send-keys` (prevents injection)
- Security: Quote escaping in pane creation commands
- Theme-switch: Quiet mode now suppresses error messages
- Window-move: Input format validation for session:window argument
- Test: Theme-switch ghostty process check (case-insensitive)

## [0.1.13] - 2026-01-22

### Added
- ASCII logo displayed at start/end of installation and in CLI tools
- Local aliases system: Machine-specific project aliases via `.local-aliases.zsh`
- Template file `.local-aliases.zsh.template` for easy customisation
- Installer prompt to create local aliases from template
- Comprehensive local aliases documentation in `zsh/.zsh/README.md`
- Neovim: Custom Copilot suggestion highlighting (italic, subdued colour matching Comment highlight)
- Neovim: `:CopilotHighlightFix` command to manually fix Copilot highlighting if needed

### Changed
- Dotfiles CLI: Prettier status/update output with improved formatting
- All installation scripts now use `printf` for coloured output instead of `echo`
- Installer checks for local aliases configuration during symlink creation
- Theme-switch: Shows informational message when not in tmux
- Tmux: Updated theme colours from Tokyo Night to Catppuccin Mocha for improved visual consistency
- Neovim: Copilot suggestions now use distinct italic styling to differentiate from regular code

### Fixed
- Tmux: FZF label colour updated for Catppuccin theme consistency
- Neovim: Copilot suggestions now properly styled across all colourschemes with fallback grey colour

### Removed
- Brewfile: Removed Docker cask (now managed separately)

## [0.1.12] - 2026-01-22

### Added
- Theme system: Coordinated colour schemes across tmux, ghostty, and neovim
- Themes: Four built-in themes (Dracula, Catppuccin Mocha, Tokyo Night, Nord)
- `theme-switch` CLI tool for switching themes with live reload
- Tmux: Theme picker (`prefix + t`) with fzf interface and vim-style navigation
- Tmux: Template-based configuration (`.tmux.conf.template`) for dynamic theming
- Ghostty: Template-based configuration (`config.template`) for dynamic theming
- Neovim: Theme module (`lua/custom/core/theme.lua`) with file watcher for automatic reload
- Scripts: `colours.sh` library for consistent colour definitions across scripts
- Scripts: `fzf-theme.sh` for applying theme colours to fzf interfaces
- Scripts: `ghostty-reload.sh` for live ghostty config reload on theme change
- Scripts: `fzf-reload.sh` for live fzf theme reload in tmux
- Tmux: OpenCode instance picker (`prefix + o`) matching Claude picker functionality
- Tmux: FZF theme integration across all pickers (sessions, windows, Claude, OpenCode, URLs, themes)
- Tests: Comprehensive theme validation suite (`test-theme-validation.sh`, `test-theme-switch.sh`, `test-fzf-theming.sh`, `test-theme-installation.sh`)
- Tests: Ghostty reload tests (`test-ghostty-reload.sh`)
- Tests: Theme picker tests (`test-theme-picker.sh`)
- `Makefile` with shortcuts for common tasks (test, lint, install, clean)
- Dotfiles CLI: `theme-switch` integration for centralized theme management

### Changed
- Tmux: Unbound `prefix + t` (clock) to make room for theme picker
- Tmux: All fzf popups now source `fzf-theme.sh` for consistent theming
- Tmux: Window/session rename dialogs now source fzf theme
- Common library: Refactored colour definitions to use central `colours.sh`
- Neovim: `auto-dark-mode.nvim` plugin disabled when dotfiles theme is active
- Neovim: TreeSitter configuration updated for new API
- UI library: Updated to use `printf` for coloured output (not `echo`)

### Fixed
- Theme-switch: Function name conflict with tmux `info` command (renamed to `print_info`)
- Theme-switch: Unbound variable error when called with no arguments
- Test suite: GREY colour variable conflict (now sourced from colours.sh)
- Test suite: Theme name expectations made flexible for different active themes

## [0.1.11] - 2026-01-14

### Added
- Tmux: `cleanup-tests.sh` script to clean up orphaned test servers and session backups
- Tmux: `tcleanup` shell alias for test cleanup script
- Tmux: trap handlers in test scripts for automatic cleanup on exit/interrupt
- Scripts: `run-tests.sh` - dynamic test discovery runner with per-suite summaries
- CI: ShellCheck now lints test scripts in `tmux/.tmux/scripts/tests/` and `scripts/tests/`
- CI: Dynamic test discovery automatically finds and runs all test files
- Ghostty: `opt+up` and `opt+down` keybindings for terminal navigation
- Karabiner: Caps Lock → Escape mappings for JetBrains IDEs (Rider, WebStorm, GoLand)
- Tmux: `Opt+=` keybinding to split pane upward (complements `Opt+-` for split down)

### Changed
- CI: Replaced manual test execution with dynamic discovery via `run-tests.sh`
- CI: Renamed "Library Tests" job to "All Tests" to reflect comprehensive coverage
- Tests: Standardised patterns in test runner (boolean comparisons, counter management, skip handling)
- Tmux: Reformatted help popup (`prefix+h`) with cleaner layout and adjusted dimensions (74x41)
- Tmux: Simplified fzf session/window switcher keybindings - removed page navigation (`f`/`b`) and half-page (`d`/`u`) keys, now use only `j`/`k` for navigation
- Tmux: Changed kill/undo keybindings from `alt+x`/`alt+u` to `x`/`u` in fzf switchers for better ergonomics
- Tmux: Updated border labels and keybinding hints in session and window switchers to reflect simplified navigation
- Tmux: Renamed scripts for better organisation and consistency:
  - Session management: `list-sessions.sh` → `session-list.sh`, `new-session.sh` → `session-new.sh`, `rename-session.sh` → `session-rename.sh`
  - Window management: `list-windows.sh` → `window-list.sh`, `rename-window.sh` → `window-rename.sh`, `duplicate-window.sh` → `window-duplicate.sh`, `move-window.sh` → `window-move.sh`
  - Utilities: `timestamp.sh` → `update-timestamp.sh`, `tmux-confirm.sh` → `fzf-confirm.sh`, `agent-alert-clear.sh` → `agent-alerts-clear.sh` (plural)
- Tmux: Deleted `clear-claude-alert.sh` (functionality consolidated into `agent-alerts-clear.sh`)
- Tmux: Renamed test file `test-fzf-confirm-kill.sh` → `test-kill-confirmations.sh` for clarity
- Tmux: Updated all script references in `.tmux.conf` and hooks to use new filenames
- Docs: Updated README file structure listing to reflect renamed scripts

### Fixed
- Tmux: test scripts now properly clean up resources even when interrupted
- CI: Now runs all 12 tests instead of only 4 (discovered 8 previously uncovered tests)
- Tmux: unbind default `prefix+x` keybinding to prevent accidental pane kills (use `Opt+s` for kill-pane, `Opt+x` for kill-window)

### Added
- Tmux: Comprehensive resurrect testing suite covering path discovery, split operations, restore operations, and edge cases
- Scripts: Documentation for SCRIPT_DIR pattern standardization across shell scripts
- CI: Resurrect tests now run automatically via dynamic test discovery

### Changed
- Tmux: Migrated undo file storage from `/tmp/tmux-undo-*` to XDG-compliant `${XDG_CACHE_HOME}/tmux/undo/` with automatic migration
- Tmux: Standardized session validation error handling across `new-session.sh` and `rename-session.sh`
- Scripts: Updated `new-session.sh` to use production SCRIPT_DIR pattern (`${BASH_SOURCE%/*}`)
- Tests: Updated test expectations to match XDG-compliant undo paths
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
