# Tmux Configuration

A modern tmux setup with ergonomic keybindings, Dracula theme, and per-session backup/restore.

## Quick Reference

| Action                | Keybinding / Command              |
| --------------------- | --------------------------------- |
| **Prefix**            | `` ` `` (backtick)                |
| **Start dev session** | `dev` (from any directory)       |
| Help popup            | `prefix + h`                      |
| Launcher picker       | `prefix + p`                      |
| Theme picker          | `prefix + t`                      |
| Save sessions         | `prefix + w` (like vim :w)        |
| List backups          | `prefix + S` or `tls`             |
| Restore all sessions  | `trestore`                        |
| Restore one session   | `trestore -s <name>`              |
| List Claude instances | `prefix + c`                      |
| List OpenCode instances | `prefix + o`                    |
| List Copilot instances | `prefix + a`                    |
| List nvim instances   | `prefix + n`                      |
| Reload local overrides | `prefix + r`                     |

## Setup Guide (New Machine)

### 1. Install tmux

```bash
brew install tmux
```

### 2. Configuration files

The installer handles config generation. Key locations:

```
~/.config/tmux/tmux.conf        # Generated config (XDG location)
~/.tmux.conf                    # Compatibility symlink → above
~/.tmux/
├── scripts/                    # Symlinked to dotfiles/tmux/scripts
└── resurrect/                  # Session backup storage
~/.local/launchers/
└── dev                         # Dev session launcher
```

### 3. Install TPM (Tmux Plugin Manager)

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

### 4. Install plugins

Start tmux and press `prefix + I` (that's `` ` `` then `Shift+i`) to install plugins.

### 5. Add shell aliases

Add to your `~/.zshrc`:

```bash
# tmux session management
alias tls="~/.tmux/scripts/resurrect/restore.sh --list"
alias trestore="~/.tmux/scripts/resurrect/restore.sh"
alias tkill="tmux kill-server; rm -rf ~/.tmux/resurrect/*"

# Smart attach: connects to running session, or restores from backup
tattach() {
  if tmux a -t "$1" 2>/dev/null; then return 0; fi
  local backup="${HOME}/.tmux/resurrect/sessions/$1.txt"
  if [[ -f "$backup" ]]; then
    echo "Restoring '$1' from backup..."
    if ~/.tmux/scripts/resurrect/restore.sh --session "$1" && tmux a -t "$1"; then
      return 0
    fi
    echo "Backup stale, removing: $1"
    rm -f "$backup"
    return 1
  fi
  echo "No session or backup found: $1"
  return 1
}
```

Then reload: `source ~/.zshrc`

---

## Keybindings

### Prefix

The prefix key is **`` ` ``** (backtick - double-tap for literal).

### Theme Picker

Press `prefix + t` to switch between colour themes (Dracula, Catppuccin, Tokyo Night, Nord). The picker uses vim-style navigation with `j`/`k` to move up/down and `Enter` to select. Theme changes apply immediately to tmux, ghostty, and neovim.

### Launcher Picker

Press `prefix + p` to open the session launcher picker. Lists available launchers from the repo (`launchers/`) and user directory (`~/.config/dotfiles/launchers/`), with user launchers taking priority by name.

| Action              | Key                      |
| ------------------- | ------------------------ |
| Move down/up        | `j` / `k`                |
| Half-page down/up   | `d` / `u`                |
| First/last item     | `g` / `G`                |
| Select              | `Space` or `Enter`       |
| Start searching     | `/`                      |
| New launcher        | `n` (opens wizard)       |
| Edit launcher       | `e` (opens wizard with current values) |
| Delete launcher     | `x` (user launchers only)|
| Quit                | `q` or `Esc`             |

**Fixed-session launchers** (with `SESSION=`) show an instance picker when selected — attach to running instances or create new ones. **Parameterised launchers** (like `dev`) show a directory picker.

### Windows (Tabs)

| Action           | Keybinding                    |
| ---------------- | ----------------------------- |
| Next window      | `Opt/Alt+]` or `Ctrl+Enter`       |
| Previous window  | `Opt/Alt+[` or `Ctrl+Shift+Enter` |
| New window       | `Opt/Alt+t`                       |
| Go to window 1-5 | `prefix + 1-5`                |
| Rename window    | `Opt/Alt+r`                       |
| Swap window left | `Opt/Alt+Shift+[`                 |
| Swap window right| `Opt/Alt+Shift+]`                 |
| Kill window      | `Opt/Alt+x`                       |
| Undo kill        | `Opt/Alt+u`                       |

**Note:** Killing the last window in a session will prompt for confirmation.

### Panes

| Action            | Keybinding          |
| ----------------- | ------------------- |
| Navigate left     | `Opt/Alt+h` or `Ctrl+,` |
| Navigate down     | `Opt/Alt+j` or `Ctrl+.` |
| Navigate up       | `Opt/Alt+k`             |
| Navigate right    | `Opt/Alt+l`             |
| Split left        | `Opt/Alt+'`             |
| Split right       | `Opt/Alt+\`             |
| Split down        | `Opt/Alt+-`             |
| Split up          | `Opt/Alt+=`             |
| Close pane        | `Opt/Alt+s`             |
| Undo close        | `Opt/Alt+u`             |
| Zoom (fullscreen) | `Opt/Alt+z`             |
| Previous layout   | `` `+[ ``           |
| Next layout       | `` `+] ``           |
| Equalise sizes    | `Opt/Alt+Shift+0`       |

| Resize left       | `Opt/Alt+Shift+h`       |
| Resize down       | `Opt/Alt+Shift+j`       |
| Resize up         | `Opt/Alt+Shift+k`       |
| Resize right      | `Opt/Alt+Shift+l`       |

**Note:** Closing the last pane in the last window or the last window in a session will prompt for confirmation.

### URL Picker

| Action    | Keybinding   |
| --------- | ------------ |
| Open URLs | `prefix + u` |

Opens a fzf popup with all URLs from the current pane's scrollback. Uses the same vim-style navigation as other switchers (j/k, g/G, f/b, d/u). Press `o`, `Space`, or `Enter` to open, `y` to yank to clipboard.

### Undo

| Action              | Keybinding |
| ------------------- | ---------- |
| Undo last kill      | `Opt/Alt+u`    |

Restores the last closed pane or window (whichever was killed most recently). Restores directory, layout, and scrollback contents. Works with both `Opt/Alt+s` (close pane) and `Opt/Alt+x` (kill window). Session kill (`Opt/Alt+q`) also supports undo.

### Scroll Mode (Copy Mode)

| Action            | Keybinding            |
| ----------------- | --------------------- |
| Enter scroll mode | `Opt/Alt+v` or `prefix+v` |
| Navigate          | `h` / `j` / `k` / `l` |
| First non-blank   | `m`                   |
| End of line       | `M`                   |
| Page down/up      | `Ctrl+f` / `Ctrl+b`    |
| Half-page down/up | `d` / `u` (cursor moves to screen edge) |
| Top of history    | `g`                   |
| Bottom of history | `G`                   |
| Search down/up    | `/` / `?`             |
| Next/prev match   | `n` / `N`             |
| Select chars      | `v`                   |
| Select line       | `V`                   |
| Yank selection    | `y`                   |
| Yank line         | `Y`                   |
| Exit scroll mode  | `q` or `Esc`          |

**Note:** `Ctrl+f`/`Ctrl+b` also work for page navigation.

**Vim-style yank:** To yank from cursor to top/bottom of history, use visual mode: `v` → `g` (or `G`) → `y`.

### Sessions

| Action                   | Keybinding                     |
| ------------------------ | ------------------------------ |
| Switch window (fzf)      | `prefix + f`                   |
| Switch session (fzf)     | `prefix + s` or click session name |
| Save all sessions        | `prefix + w` or `prefix + Ctrl+s` |
| Restore all sessions     | `prefix + Ctrl+r`              |
| List saved backups       | `prefix + S`                   |
| Restore specific session | `prefix + R`                   |
| Kill session             | `Opt/Alt+q`                    |

### Session/Window Switchers (Vim-Style Navigation)

Both `prefix + s` (sessions) and `prefix + f` (windows) use vim-style navigation.

**Sorting:** Lists are automatically sorted by recently accessed, with the most recently used items at the top.
- **Sessions:** Sorted by `#{session_activity}` (built-in tmux variable)
- **Windows:** Sorted by custom `@last-viewed` timestamp updated via `after-select-window` hook

| Action              | Key                      |
| ------------------- | ------------------------ |
| Move down/up        | `j` / `k`                |
| First/last item     | `g` / `G`                |
| Select              | `Space` or `Enter`       |
| Start searching     | `/`                      |
| Quit                | `q` (nav mode) or `Esc`  |
| Clear line          | `Ctrl+w` (in search mode)|
| Delete line         | `Ctrl+k`                 |
| Toggle all sessions | `a` (windows only)       |
| Kill session/window | `x`                      |
| Undo kill           | `u`                      |
| Move window         | `m` (windows only)       |
| New session         | `n` (sessions only)      |
| Rename              | `r`                      |

**Toggle all sessions:** In the window switcher (`prefix + f`), press `a` to toggle between showing windows from the current session only (`:` prompt) and windows from all sessions (`*` prompt). When viewing all sessions, selecting a window will switch to that session and window.

**New session:** Press `n` to open a dialog to create a new session. Type the name and press `Enter` to create (starts at `~`), or `Esc` to cancel. If a session with that name already exists, it will switch to it instead.

**Rename:** Press `r` to open a rename dialog with the current name pre-filled. Edit the name and press `Enter` to confirm, or `Esc` to cancel. Works in both session and window switchers — the list reloads after renaming so you stay in the picker.

**Modes:** Switchers start in navigation mode (`:` prompt). Press `/` to search (`>` prompt), `Esc` to return.

Navigation keys (`j`, `k`, `g`, `G`) are automatically unbound in search mode so you can type them normally, then rebound when you exit search mode.

**Undo:** When you kill a session or window with `x`, press `u` to restore it. Sessions are restored with all windows and panes; windows are restored with layout and scrollback contents.

**Agent Alerts:** Sessions and windows with pending agent alerts display coloured icons (⚡ yellow for Claude, 🔮 purple for OpenCode, ✦ blue for Copilot). Press `prefix + c` to open an fzf picker showing all running agent instances across all sessions, with alerts highlighted. Alerts are automatically cleared when you switch to that window via the picker. Window renames automatically update alert tracking to prevent stale alerts.

**Command Exit Alerts:** When you run a command and switch away, a ✓ (green) or ✗ (red) alert appears automatically when it finishes — no wrapping needed. The window tab highlights in the pass/fail colour, and the status bar shows `session:command` for commands in other sessions. Alerts clear automatically when you switch back to the window. Only fires if you switched away before the command finished, and the command ran for at least 1 second. See [docs/CMD-ALERTS.md](../docs/CMD-ALERTS.md) for details.

**Instance Management:** The Claude (`prefix + c`), OpenCode (`prefix + o`), Copilot (`prefix + a`), and nvim (`prefix + n`) pickers support inline instance management:
- Press `n` to create a new instance (opens a new window in the current session and launches the process)
- Press `x` to kill the selected instance (sends SIGTERM with graceful shutdown, confirms before killing)

**Nvim Picker:** Press `prefix + n` to list all running nvim instances with their working directories. Select an instance with `Space`/`Enter` to jump to it, or press `c` to connect it to another pane (copies `export NVIM_SOCKET='...' && claude` to clipboard and switches to the target pane). This enables the nvim buffer sync hook - files edited by Claude Code are automatically added to the paired nvim's buffer list.

### Navigation History

Browser-style back/forward navigation across tmux windows and sessions.

| Action          | Keybinding   |
| --------------- | ------------ |
| Navigate back   | `prefix + -` |
| Navigate forward| `prefix + =` |

History is recorded automatically via tmux hooks (`after-select-window`, `client-session-changed`, `after-new-session`). Stale entries (closed windows) are pruned on navigation. Forward history is truncated when you navigate to a new window after going back (same as browser behaviour).

### Plugins (TPM)

| Action          | Keybinding       |
| --------------- | ---------------- |
| Install plugins | `prefix + I`     |
| Update plugins  | `prefix + U`     |
| Clean unused    | `prefix + Alt+u` |

### Local Overrides

`~/.config/tmux/local.conf` is your personal override file — sourced after the base config so your settings take priority. It is created from a template on first install and never overwritten by `dotfiles theme` or `dotfiles update`.

Use it for cursor style, extra keybindings, plugin additions, or any other personal tweaks. After editing, reload with `prefix + r`.

---

## Shell Commands & Aliases

### `dev` - Dev Session Launcher

Start a tmux dev session named after the current directory:

```bash
cd ~/src/myproject
dev
```

This creates a session called `myproject` with:

- **Window 1 (dev):** Claude Code + terminal (side-by-side split panes)
- **Window 2 (edit):** neovim

If a session with that name already exists, `dev` attaches to it instead of creating a new one.

Location: `~/.local/launchers/dev`

### Aliases

Shell aliases for tmux session management (`tls`, `trestore`, `tkill`, `tattach`, `tcleanup`) are defined in `zsh/dotfiles.zsh` and documented in the [Zsh README](../zsh/README.md#aliases).

---

## Session Management

This setup extends tmux-resurrect with custom per-session backup and restore.

### How Saving Works

1. Press `prefix + w` to save all sessions
2. tmux-resurrect saves everything to a single timestamped file
3. The post-save hook (`split-resurrect.sh`) automatically splits this into individual per-session files
4. Each session gets its own backup file in `sessions/` directory

**Auto-cleanup:** When you kill a session (e.g., with `Opt/Alt+q` or `x` in the session switcher), a save is automatically triggered to update the backup files. The killed session is removed from `tls` listings.

### How Restoring Works

**Restore all sessions (built-in):**

- Press `prefix + Ctrl+r`
- Restores everything from the last combined save

**Restore all sessions (custom):**

- Run `trestore` from the shell (skips already running sessions)
- Shows summary: restored/skipped/failed counts

**Restore a single session (custom):**

- Press `prefix + R` and enter the session name, OR
- Run `trestore --session <name>` from the shell
- Only that specific session is restored

### What Gets Restored

The custom restore script (`trestore`) restores:

- **Session structure:** Windows, panes, and layouts
- **Working directories:** Each pane's `pwd`
- **Scrollback history:** Terminal contents (if `@resurrect-capture-pane-contents` is enabled)
- **Running commands:** Processes like vim, ssh, htop (if `@resurrect-processes` is configured)

Configuration options (in `.tmux.conf`):

```bash
set -g @resurrect-capture-pane-contents 'on'    # Enable scrollback restore
set -g @resurrect-processes 'ssh vim htop'      # Commands to restore
set -g @resurrect-processes ':all:'             # Restore all commands
```

### Storage Location

```
~/.tmux/resurrect/
├── last                        # Symlink to latest combined save
├── tmux_resurrect_*.txt        # Timestamped combined saves
├── pane_contents.tar.gz        # Terminal contents (optional)
└── sessions/
    ├── myproject.txt           # Per-session backup
    └── another-session.txt
```

### Listing Backups

```bash
$ tls

Available session backups:

  dana                  5 windows,  6 panes  (2025-12-29 23:08) [ACTIVE]
  supplyscan-mcp        2 windows,  3 panes  (2025-12-29 23:08)
```

---

## File Structure

```
~/.config/tmux/tmux.conf                  # Generated config (XDG location)
~/.tmux.conf                              # Compatibility symlink → above
~/.tmux/
├── plugins/
│   ├── tpm/                              # Tmux Plugin Manager
│   ├── tmux-resurrect/                   # Session save/restore
│   ├── tmux-continuum/                   # Auto-save (every 1 min)
│   ├── tmux-cpu/                         # CPU/RAM monitoring
│   ├── tmux-battery/                     # Battery monitoring
│   └── tmux-open/                        # Open highlighted selection
├── resurrect/
│   ├── sessions/                         # Per-session backup files
│   └── last                              # Symlink to latest save
├── scripts/
│   ├── _lib/                             # Shared utility libraries
│   │   ├── alerts.sh                     # Agent + command exit alert utilities
│   │   ├── common.sh                     # Error handling, validation
│   │   ├── paths.sh                      # Undo file path definitions
│   │   ├── session.sh                    # Session management utilities
│   │   ├── test-tmux-libs.sh              # Test suite for libraries
│   │   └── ui.sh                         # Terminal UI (dialogs, prompts)
│   ├── tests/                            # Test suites
│   │   ├── _test-helpers.sh              # Shared test framework helpers
│   │   ├── cleanup-tests.sh              # Clean up orphaned test resources
│   │   ├── test-agent-alert-hooks.sh     # Agent alert hook tests
│   │   ├── test-cmd-alert-hooks.sh       # Command exit alert tests
│   │   ├── test-dotfiles-status.sh       # Dotfiles sync indicator tests
│   │   ├── test-kill-confirm-patterns.sh # Kill confirmation pattern tests
│   │   ├── test-kill-confirmations.sh    # Kill confirmation flow tests
│   │   ├── test-launchers.sh             # Launcher system tests
│   │   ├── test-list-claude.sh           # Claude instance listing tests
│   │   ├── test-nav-history.sh           # Navigation history tests
│   │   ├── test-nvim-sync.sh             # Nvim buffer sync tests
│   │   ├── test-pick-theme.sh            # Theme picker tests
│   │   ├── test-pick-url.sh              # URL picker tests
│   │   ├── test-reload-ghostty.sh        # Ghostty reload tests
│   │   ├── test-rename-session.sh        # Session rename tests
│   │   ├── test-resurrect.sh             # Resurrect backup/restore tests
│   │   ├── test-session-find-logic.sh    # Session find logic tests
│   │   ├── test-session-kill-logic.sh    # Session kill logic tests
│   │   ├── test-session-management.sh    # Session management tests
│   │   ├── test-theme-reload.sh          # Theme reload tests
│   │   ├── test-undo-dispatch.sh         # Undo dispatcher tests
│   │   ├── test-undo-operations.sh       # Undo operation tests
│   │   └── test-window-kill.sh           # Window kill tests
│   ├── instances/                        # Process instance management (list, create, kill)
│   │   ├── claude.sh                     # List Claude Code instances
│   │   ├── opencode.sh                   # List OpenCode instances
│   │   ├── copilot.sh                    # List GitHub Copilot instances
│   │   ├── nvim.sh                       # List nvim instances for buffer sync
│   │   ├── new.sh                        # Create new process window
│   │   ├── kill.sh                       # Kill process instance (with confirm)
│   │   └── connect-nvim.sh               # Connect nvim to Claude pane
│   ├── alerts/                           # Agent + command exit alert system
│   │   ├── show.sh                       # Status bar: agent alerts (⚡ 🔮 ✦) + exit alerts (✓ ✗)
│   │   ├── clear.sh                      # Clear alerts for window
│   │   ├── cleanup.sh                    # Clean up stale alerts (dead sessions/windows)
│   │   └── update-timestamp.sh           # Window access tracking hook
│   ├── launchers/                        # Session launcher system
│   │   ├── list.sh                       # List session launchers (for picker)
│   │   ├── picker.sh                     # Launcher picker loop (prefix + p)
│   │   ├── run.sh                        # Run selected launcher (instance/dir picker)
│   │   ├── prompt.sh                     # Prompt for launcher name (from picker)
│   │   ├── new.sh                        # New launcher wizard (create/edit)
│   │   ├── new-dir.sh                    # New directory picker
│   │   ├── settings.sh                   # Launcher settings (configure roots)
│   │   └── delete.sh                     # Delete user launcher (with confirm)
│   ├── sessions/                         # Session management
│   │   ├── list.sh                       # Session listing with alert indicators
│   │   ├── new.sh                        # Create new session dialog
│   │   ├── rename.sh                     # Rename session dialog
│   │   ├── kill.sh                       # Kill session (picker, with confirm)
│   │   └── undo.sh                       # Restore killed session
│   ├── windows/                          # Window operations
│   │   ├── list.sh                       # Window listing with alert indicators
│   │   ├── rename.sh                     # Rename window dialog
│   │   ├── kill.sh                       # Kill window (Opt+x, saves state)
│   │   ├── undo.sh                       # Restore killed window
│   │   ├── duplicate.sh                  # Duplicate window (Opt+Shift+d)
│   │   └── move.sh                       # Move window to another session
│   ├── panes/                            # Pane management
│   │   ├── kill.sh                       # Kill pane (Opt+s, saves state)
│   │   └── undo.sh                       # Restore killed pane
│   ├── resurrect/                        # Per-session tmux-resurrect extensions
│   │   ├── split.sh                      # Post-save hook (splits backups)
│   │   ├── restore.sh                    # Individual session restore
│   │   └── delete.sh                     # Delete session backup
│   ├── themes/                           # Runtime theme switching
│   │   ├── pick.sh                       # Theme picker (prefix + t)
│   │   ├── reload-fzf.sh                 # Reload fzf theme colours
│   │   └── reload-ghostty.sh             # Reload Ghostty terminal theme
│   └── utils/                            # Shared utilities
│       ├── nav.sh                        # Browser-style back/forward history
│       ├── undo-dispatch.sh              # Undo dispatcher (Opt+u)
│       ├── pick-url.sh                   # URL picker (prefix + u)
│       └── dotfiles-status.sh            # Status bar: sync indicator (↓↑↕)
└── README.md                             # This file

~/.local/launchers/
└── dev                                  # Dev session launcher
```

---

## Plugins

### TPM (Tmux Plugin Manager)

Manages plugin installation and updates.

- Repository: https://github.com/tmux-plugins/tpm
- Location: `~/.tmux/plugins/tpm/`

### tmux-resurrect

Saves and restores tmux sessions (windows, panes, working directories).

- Repository: https://github.com/tmux-plugins/tmux-resurrect
- Save: `prefix + w` (or `prefix + Ctrl+s`)
- Restore: `prefix + Ctrl+r`

### tmux-continuum

Automatic background saving every 1 minute.

- Repository: https://github.com/tmux-plugins/tmux-continuum
- Save interval: 1 minute (configured via `@continuum-save-interval`)
- Auto-restore on tmux start is **disabled** (manual restore preferred)

### tmux-cpu

Displays CPU and RAM usage in the status bar.

- Repository: https://github.com/tmux-plugins/tmux-cpu
- Shows icons that change based on load level (=, ≡, ≣)
- CPU colours: cyan (low) → purple (medium) → pink (high)
- RAM colours: green (low) → teal (medium) → purple (high)

### tmux-battery

Displays battery percentage in the status bar.

- Repository: https://github.com/tmux-plugins/tmux-battery
- Shows percentage with colour-coded background
- Green when above 20%, red when 20% or below

### tmux-open

Opens highlighted file/URL from copy mode.

- Repository: https://github.com/tmux-plugins/tmux-open
- In copy mode: `o` opens selection, `Ctrl+o` opens in `$EDITOR`
- `Shift+s` searches selection with default search engine

### tmux-yank

System clipboard integration for copying text.

- Repository: https://github.com/tmux-plugins/tmux-yank
- In copy mode: `y` copies selection to system clipboard
- `prefix + y` copies current command line to clipboard
- `prefix + Y` copies current working directory to clipboard

---

## Themes

Supports multiple coordinated colour schemes that apply across tmux, ghostty, and neovim:

15 hand-crafted themes are available: Ayu Dark, Catppuccin Mocha, Dracula, Everforest, Gruvbox Dark, Kanagawa, Maple, Monokai, Nightfox, Nord, One Dark, Rosé Pine, Solarized Dark, Synthwave, and Tokyo Night.

Switch themes with `prefix + t` (tmux picker) or `dotfiles theme <name>` (CLI). The current theme is saved to `~/.config/dotfiles/current-theme` and automatically applied on startup. Run `dotfiles theme list` to see all available themes.

---

## Configuration

Main config file: `~/.tmux.conf`

Key settings:

- Prefix: `` ` `` (backtick)
- Mouse: enabled
- Base index: 1 (windows and panes start at 1)
- History: 50,000 lines
- Escape time: 0 (no delay for vim)
- Auto-rename: shows directory name or running command
- Auto-save: every 1 minute
- Status refresh: every 2 seconds
- Status bar: shows dotfiles sync indicator (↓↑↕ cyan), agent alerts (⚡ yellow for Claude, 🔮 purple for OpenCode), command exit alerts (✓/✗ with `session:command` label, theme-aware green/red), zoom indicator (`Z` in accent colour), CPU (⚙), RAM (☰), and battery % with themed colour indicators
- Status bar time: background aligned with powerlevel10k right prompt edge
- Bell monitoring: windows are highlighted in red when they send a bell (used by Claude Code hooks to signal when attention is needed)

---

## Troubleshooting

### Plugins not working

Run `prefix + I` to install plugins, then restart tmux.

### Session restore fails

Check that the session backup exists:

```bash
ls ~/.tmux/resurrect/sessions/
```

### Keybindings not working

Reload the config:

```bash
tmux source ~/.tmux.conf
```

### Clear all saved sessions

```bash
tkill
# or manually:
rm -rf ~/.tmux/resurrect/{sessions/*,last,*.txt,*.tar.gz}
```
