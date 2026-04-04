# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.2.79] - 2026-04-04

### Added
- Nvim: replaced easy-dotnet LSP with roslyn.nvim for C# diagnostics — real-time inline diagnostics, pull diagnostic support, cross-namespace dedup, false positive filtering (IDE0005, IDE0079, CA1825)
- Nvim: .NET tests now use easy-dotnet.nvim's built-in test runner — gutter signs, run/debug from buffer (`<leader>tr`/`<leader>td`), test explorer (`<leader>te`), peek stacktrace (`<leader>tp`)
- Nvim: roslyn auto-suppression during Octo PR review and diffview — re-enables when opening a real .cs file
- Nvim: replaced fidget.nvim with nvim-notify for LSP progress, build status, and refresh messages
- Nvim: Octo improvements — review thread navigation (`]C`/`[C`), viewed file tracking (`<Tab>`, `]u`/`[u`), file panel `l` keymap, left-side diff highlight fix, `BufModifiedSet` save guard
- Nvim: which-key tiered display — leader popup shows only category groups; context groups gated to relevant filetypes; PR Review always visible; consistent icon colour scheme (blue=navigation, green=tooling, red=editor, purple=AI, yellow=misc)
- Nvim: which-key Claude icon uses custom orange highlight (`#ff9e64`) distinct from yellow `DiagnosticWarn`; `<leader>b` label updated to `[B]reakpoint / Buffer`
- Nvim: neotest-vitest monorepo support — resolves vitest binary from nearest `node_modules` with cached subdirectory fallback
- Nvim: statusline — `~/` relative paths, compact diff (`+N -N`), mini.icons for filetype/git icons, removed LSP server count
- Nvim: editable breakpoint list (`<leader>bl`), `<leader>by` yank buffer path, Flash treesitter (`S`)
- Nvim: VimLeavePre cleanup — stops LSP clients, terminates DAP, closes terminal buffers to prevent orphaned processes
- Nvim: test explorer nav trapping — `<C-h/j/k/l>` blocked in floating windows, `<Esc>` closes peek floats
- Zsh: `nuke-nvim`, `nuke-dotnet` aliases; `MSBUILDDISABLENODEREUSE=1`; `btop`, `lazydocker`, `dash` aliases

### Changed
- Nvim: `dd` deletes without yanking (black hole register); `dy` yanks and deletes (original `dd` via operator-pending `y` = current line motion)
- Nvim: diffview — instant tab close, `]f`/`[f` as buffer-local keymaps, disabled `<leader>` defaults that stole which-key prefix, treesitter pre-warming on `<leader>de` for instant highlighting
- Nvim: which-key `BufEnter` caches visibility state and skips `buftype ~= ''` buffers to avoid trigger removal during rapid transitions
- Nvim: `<leader>lR` refresh noise suppressed via timestamp-based filter
- Nvim: smart-paste, conform, dial.nvim guarded against non-modifiable buffers
- Nvim: neotest — summary keymaps (`o` expand, `p` output), output preview UX, keymaps skip `.cs` files
- Nvim: mini.icons setup with YAML, `.template` icons; `.template` filetype detection
- Nvim: Neo-tree `o` opens immediately (order-by moved to `O` prefix)
- Nvim: markdown-preview — removed `ft` trigger to prevent eager loading
- Nvim: cmdline completion hidden by default, Tab triggers and cycles, Ctrl+Space as alternative
- Nvim: notification history viewer — dynamic height and line wrapping
- Nvim: Mason custom registry (Crashdummyy) for Roslyn LSP auto-install

### Fixed
- Nvim: roslyn semantic tokens flashing/disappearing — Neovim 0.12's `semanticTokens/range` requests caused viewport-only responses to replace full-document tokens; fixed by intercepting `client/registerCapability` to strip range registrations
- Nvim: roslyn semantic tokens on first load — refreshes tokens on `RoslynInitialized` event (project init complete) since roslyn doesn't send `workspace/semanticTokens/refresh` after solution loads
- Nvim: roslyn not restoring after diffview close — uses `diffview.lib.get_current_view()` instead of buffer filetype scanning (lingering buffers blocked restore)
- Nvim: which-key intermittently not showing in diffview panels — permanent `<Space>` keymap bypasses which-key's trigger suspension windows
- Nvim: roslyn diagnostic dedup — ignores message variations across push/pull channels and multi-project contexts
- Nvim: neotest-golang — unpinned from v1.15.1 to v2+ (supports current Go treesitter parser)
- Tmux: alert picker same-session navigation fix

### Removed
- Nvim: neotest-dotnet adapter and monkey-patch workaround
- Nvim: `<leader>ni` add missing imports (roslyn.nvim handles Fix All natively)
- Nvim: fidget.nvim (replaced by nvim-notify)
- Nvim: easy-dotnet.nvim `^M` strip monkey-patch — merged upstream (GustavEikaas/easy-dotnet.nvim#883)

## [0.2.78] - 2026-04-01

### Added
- Nvim: harpoon2 for quick file slot navigation (`<leader>1`–`4` to jump, `<leader>ha` to add, `<leader>hh` to toggle menu)
- Nvim: `<leader>dt` diff-by-branch command — diffs all commits since branching from main using `git merge-base`
- Tmux: alert picker (`prefix+A` / click status-right) with fzf integration — jump to alerting windows, `x` to clear individual alerts, search with `/`
- Ghostty: custom shader collection (bloom, CRT, cursor-trail, galaxy, matrix, retro, starfield) with examples in local template

### Changed
- Nvim: LSP modernised — mason-lspconfig v2 `automatic_enable`, `vim.lsp.config` for global capabilities, cssls Tailwind v4 at-rules support
- Nvim: switched from mini.notify to nvim-notify for notification handling
- Nvim: .NET diagnostics — Roslyn pull diagnostic workaround with workspace diagnostics on save, csharpier/gofumpt formatters added
- Nvim: `C-j`/`C-k` navigation added to Telescope results, completion menu, cmdline completion, and Neo-tree (file browser + fuzzy finder)
- Nvim: git hunk prefix moved from `<leader>h` to `<leader>H` (freeing `h` for harpoon)
- Nvim: pr-review diffview auto-closes existing view before opening a new one
- Nvim: `<C-BS>` mapped to delete-word-back in command mode
- Ghostty: keybindings moved from `theme-switch` into `config.template` using `{{PLATFORM_MOD}}` placeholder
- Ghostty: added `super+backspace` keybind (kill line) and `window-theme = ghostty`
- Tmux: responsive popup sizing for rename and kill windows (fixed size on wide terminals, 95% on narrow)
- Tmux: Claude instance logo colour changed to pink (`#D78787`)
- Lazydocker: fixed YAML structure — `returnImmediately` moved to correct nesting level, added `commandTemplates` with timestamps for log views, added `logs.timestamps` setting

### Fixed
- Lazydocker: migration script (`0.2.78`) to fix broken config nesting for existing installs

## [0.2.77] - 2026-03-30

### Changed
- Nvim: compatibility updates for Neovim 0.12.0 — LSP `execute_command` migrated to `client:exec_cmd`, dropped `supports_method` nvim 0.10 compat shim, bundled treesitter parser cleanup now checks both site and Lazy plugin dirs
- Nvim: LSP hover (`K`) now closes diagnostic float to prevent overlap; diagnostic float suppressed while hover is open
- Nvim: `@` file reference in claude-prompt uses saved cursor position, fixing off-by-one after Telescope closes
- Zsh: `WORDCHARS` set so Opt+Backspace/Ctrl+W deletes one segment at a time for kebab-case, paths, and dotted names
- CLAUDE.md trimmed to essentials; detailed guidance moved to `.claude/rules/`

### Fixed
- Nvim: treesitter swap-parameter guard now checks for nil parser (not just pcall failure)
- Nvim: codecompanion `build = false` to prevent unnecessary build step

## [0.2.76] - 2026-03-29

### Added
- Tmux: `prefix + R` re-sources `~/.zshrc` in all zsh panes across all sessions (with skip count for non-zsh panes)

### Changed
- CLI: `print_logo` gradient is now theme-aware — sources active theme accent colours and interpolates dynamically (sage → forest default fallback)
- Tmux: responsive popup sizing for kill confirmations (Opt+q/s/x) and help (prefix+h) — fixed size on wide terminals, 95% width on narrow/mobile
- Tmux: help template updated to show `prefix + r / R` (reload / re-source) instead of old reload-locals label

## [0.2.75] - 2026-03-27

### Changed
- Nvim: refresh command (`<leader>lR`) now closes Neo-tree, Diffview, and Trouble before wiping buffers; dashboard opens in current window instead of as a float
- Tmux: nvim instance picker uses compact braille-font header with theme-aware colour (matches nvim Keyword highlight); opencode picker colours now derived from theme cyan accent
- Tmux: `hex_fg` / `hex_dim` colour helpers added to tmux scripts library for truecolour theming
- Zsh: `_cached_eval` now validates cache files are non-empty (`-s`) before sourcing; removes empty cache files to prevent stale blanks
- Zsh: fzf ZLE widget wrapping guarded with `zle -l` check to avoid errors when widgets are not yet registered

### Fixed
- Agent alert hooks (`agent-alert.sh`, `agent-alert-clear.sh`) now exit early when not running inside tmux

## [0.2.74] - 2026-03-25

### Added
- Nvim: PR review enhancements — "diff edit" and smart "diff open" actions in `pr-review.lua`
- Tmux: `_lib/process.sh` — shared graceful process termination utilities (recursive PID tree walker, SIGTERM → 2s wait → SIGKILL)
- Zsh: `nuke-node` alias for force-stopping leaked node processes

### Changed
- Nvim: migrated from copilot.vim to copilot.lua (zbirenbaum/copilot.lua) with blink-cmp integration — ghost text with auto-trigger, `blink-cmp-copilot` completion source (score_offset 100), Tab priority, filetype filtering via opts, sensitive file detection via `should_attach` callback
- Nvim: dashboard simplified to single-pane layout with compact smblock font header (removed git log/status terminal sections)
- Tmux: pane, window, and session kill scripts now use graceful process termination via `_lib/process.sh` (previously relied on SIGHUP only)
- Tmux: instances `kill.sh` consolidated to reuse `graceful_kill_pids` instead of inlining signal sequence
- Zsh: `v` alias moved to Editor section; `cl` alias fixed with `|| true` to not fail outside tmux

### Fixed
- Nvim: NVIM logo block character alignment corrected in instance listing (6-row fix)
- Nvim: opencode instance listing now shows full "OPEN CODE" text instead of truncated "O CODE"

### Removed
- Tmux: `prefix+S` (list saved backups) and `prefix+R` (restore session) resurrect keybindings — resurrect is accessed via the session picker

## [0.2.73] - 2026-03-22

### Added
- CLI: `dotfiles sync` command — sync copy-on-install configs from repo on demand (`--force` to overwrite)
- Nvim: snacks.nvim dashboard with single-pane layout (recent files, projects, git log)
- Nvim: .NET debugging support via easy-dotnet + nvim-dap (`<leader>nd`)
- Nvim: testing & debugging documentation in nvim/README.md
- Brewfile: Raycast cask
- Zsh: `secrets`, `config`, `zshrc` quick-edit aliases
- Zsh: `make` wrapper — auto-forwards to repo root Makefile when none in current directory
- Installer: gpk (glazepkg) and gh-bench extension

### Changed
- Karabiner: Caps Lock → Escape is now global (was per-app), added Raycast to Right Option → Control
- Nvim: `<leader>lR` refresh now opens the dashboard instead of reopening the previous file
- CLI: `dotfiles diff` no longer shows zshrc.template (user-owned, differences always expected)
- CLI: extracted shared `_copy_pairs()` helper for diff and sync commands
- Tmux: navigation hint formatting — arrow icons (↓/↑) and top/bottom instead of words
- Tmux: fzf border labels use "search" instead of "srch" abbreviation
- btop: update interval 500ms → 200ms
- lazydocker: `returnImmediately: true` for confirmations
- Nvim: stylua formatting on debug.lua and test.lua

### Removed
- Installer: openapi-tui (removed from install, migration cleans up existing binary)

## [0.2.72] - 2026-03-20

### Added
- Launchers: duplicate launcher action (`D`) in picker — copies launcher to user directory with `-copy` suffix
- Zsh: `ralph` and `ralf` aliases (clear scrollback + launch)
- Ghostty: `Super+Up` / `Super+Down` keybindings mapped to Home/End
- Brewfile: `lazycron` (cron job manager TUI), `jiru` (Jira TUI)

### Changed
- Fzf pickers: use exact substring matching (`--exact`) across all tmux fzf pickers for better search results
- Launcher picker: name matches now rank above description matches via hidden search field and `--tiebreak=begin`
- Brewfile: alignment cleanup, added supplyscan comment
- Nvim: Discord presence uses repo URL from opts instead of hardcoded fallback

## [0.2.71] - 2026-03-19

### Fixed
- CI: stabilise zsh startup benchmark — increase hyperfine runs (30→100), warmup (3→5), pin runner to `macos-15`
- Tmux: random theme picker no longer re-picks the current theme

### Changed
- Nvim: mini.surround keybindings remapped from `s` to `gs` prefix to avoid clash with flash.nvim (`gsa`, `gsd`, `gsr`, etc.)

### Added
- Nvim: `<leader>i` to insert space at cursor without leaving normal mode
- Zsh: `Cmd+Up` / `Cmd+Down` keybindings for beginning/end of line (via Ghostty `super+up/down → Ctrl+Home/End`)

## [0.2.70] - 2026-03-18

### Fixed
- Nvim: diffview/octo diff buffers missing treesitter syntax highlighting — generated colourschemes loaded via `dofile()` didn't fire `ColorScheme` autocmd, so `diff-highlights` never applied bg-only overrides

### Added
- Launchers: `docker` session launcher for lazydocker

## [0.2.69] - 2026-03-17

### Fixed
- Tmux: session/pane kill not clearing alerts — backgrounded `clear_session_alerts` was SIGHUP-killed when popup exited; now runs synchronously
- Tmux: instance picker "n" (new) key silently failing — fzf `become()` is unreliable in pipelines; replaced with `execute-silent()+abort` across all instance pickers

### Added
- Nvim: `grf` keymap — fix all diagnostics in current file (applies quickfix code actions bottom-up, supports `codeAction/resolve`)
- Nvim: `q` keymap to close oil.nvim file explorer
- Tmux: regression tests for synchronous alert cleanup and no-`become()`-in-pipeline guards

### Changed
- Nvim: comment block navigation (`[c`/`]c`) skips closed blocks correctly

## [0.2.68] - 2026-03-17

### Fixed
- Tmux: alerts lost on session/window rename — rename scripts now update the alerts file in-place (`update_session_name_in_alerts`, `update_window_name_in_alerts`) instead of clearing, with rollback on rename failure
- Tmux: dots in session/window names matched as regex wildcards in grep patterns — `my.project` could match `myXproject`; names are now escaped in list scripts and copilot picker
- Tmux: killing the last pane in a window/session now correctly clears alerts for the destroyed resource (previously leaked stale entries)

### Added
- Tmux: `update_window_name_in_alerts` and `update_session_name_in_alerts` functions in alerts library for rename tracking
- Tmux: `alerts/cleanup.sh` — stale alert cleanup script called by `session-closed`, `session-renamed`, and `after-rename-window` hooks
- Tmux: `build_alert_icons` tests including dot-in-name regression coverage
- Tmux: parameterised launcher collision handler — attach/new prompt when target session already exists (fzf picker with suffix input)
- Tmux: `session-renamed` hook for alert cleanup on native tmux renames

### Changed
- Zsh: `bindkey -e` (emacs mode) and `KEYTIMEOUT=1` moved before plugin loading to prevent fzf and ZLE widget bindings from being wiped
- Tmux: dev launcher appends `-dev` suffix to session names and supports `SESSION_NAME` override for collision handler
- Tmux: window move alert tracking simplified to single sed pass (was read-clear-rewrite loop)

## [0.2.67] - 2026-03-17

### Fixed
- Tmux: launcher wizard `tr` error when generating session variable name — `tr '-.'` was interpreted as option flags, silently crashing the wizard (regression from 0.2.64)

## [0.2.66] - 2026-03-15

### Fixed
- Tmux: alerts not clearing when switching sessions via fzf picker — `client-session-changed` hook was missing `clear.sh` call (regression from 0.2.65 performance fix)

### Added
- Tmux: regression test ensuring both `after-select-window` and `client-session-changed` hooks call `clear.sh`
- Zsh: `ac` shorthand alias for `alerts-clear`

### Changed
- Zsh: unbind `Alt+C` (`fzf-cd-widget`) — terminals send the same escape sequence for Esc+c and Alt+C, causing accidental triggers; `Opt+A` directory history picker is the replacement
- Zsh: `font-preview` now passes terminal width to figlet/toilet for proper column wrapping, disables fzf mouse mode

## [0.2.65] - 2026-03-15

### Fixed
- Tmux: fzf picker performance regression — session/window list scripts now read alerts file instead of per-window `tmux show-options` calls (O(1) file read vs O(sessions × windows) tmux round-trips)
- Tmux: removed blocking `clear.sh` calls from all picker pipelines — alert clearing now handled exclusively by the `after-select-window` hook
- Tmux: removed redundant `clear_window_alerts` from `update-timestamp.sh` and `update-timestamp.sh` subprocess from `clear.sh` — eliminated duplicate work on every window switch
- Tmux: simplified instance picker (claude/opencode/copilot) post-selection to direct `tmux switch-client` instead of inline shell with extra tmux lookups

### Added
- Tmux: `build_alert_icons` shared function in alerts library for file-based alert icon rendering
- Tmux: `test-list-performance.sh` regression test to guard against per-window tmux call patterns in list scripts

### Changed
- Nvim: set `tabstop = 4` for consistent indentation display
- Nvim: indent-blankline scope guides brightened relative to base whitespace colour for visual distinction

## [0.2.64] - 2026-03-15

### Added
- Zsh: `font-preview` function — fzf-powered figlet/toilet font browser with live preview
- Brewfile: `figlet` and `toilet` packages for ASCII art text banners

### Changed
- gh-dash: `m` keybinding defaults to squash & merge with branch deletion (`--squash --delete-branch`)
- Tmux: kill session keybinding changed from `Opt+Shift+x` to `Opt+q` for easier access
- Tmux: `kill.sh` defaults to current session when no argument provided
- Zsh: `Opt+A` directory history widget rewritten inline (follows fzf's Alt-C pattern) for better reliability
- Nvim: disable additional which-key mappings for cleaner popup; update markview.nvim `cmp` → `completion` module key

## [0.2.63] - 2026-03-14

### Added
- Tmux: GitHub Copilot instance management — `prefix + a` opens fzf picker to list, create (`n`), and kill (`x`) Copilot CLI instances with alert integration
- Tmux: Copilot agent alerts (✦ blue icon) in status bar and session lists, with hook wrappers for auto-alerting
- Zsh: `copilot` alias clears scrollback before launch
- Nvim: music.nvim plugin for now playing indicator (Apple Music, Spotify)
- Brewfile: `chafa` terminal image renderer (used by music.nvim)

### Changed
- Zsh: `gds` alias changed from `git diff --staged` to `git diff --stat`
- gh-dash: `gh enhance` action uses `--repo` flag for cross-repo support

### Removed
- Zsh: `demo-rec` alias (asciinema recording)

## [0.2.62] - 2026-03-13

### Added
- Zsh: `ff` alias for `fastfetch` (system info); `dash` alias clears scrollback and opens `gh dash`
- Nvim: `<leader>sG` fixed-string grep, `<leader>lR` refresh Neovim, `<leader>Nn`/`<leader>Na` filtered/all notification history, `<leader>c]`/`<leader>c[` next/prev comment block, `<leader>psm` squash-merge PR, `<leader>mp` markdown preview in browser, `<leader>ni` add missing imports, `<leader>ba` delete all other buffers (cheatsheet updated)

### Fixed
- Tmux/Launchers: session names now disallow dots — tmux uses `.` as pane separator in target syntax (`session:window.pane`), causing ambiguous targeting with dotted names (e.g. `music.nvim`)

## [0.2.61] - 2026-03-12

### Added
- Zsh: `claude`, `gemini`, `opencode` aliases clear scrollback before launch; `grmc` (`git rm --cached`) and `gca` (`git commit --amend`) aliases
- Tmux: session kill now captures live state for undo (no longer relies on stale auto-save)
- Tmux: resurrect restore `--file` flag for direct file path
- Nvim: diffview guard prevents opening multiple views simultaneously
- Theme generator: CopilotSuggestion, indent-blankline, neotest, flash, and fidget highlight groups in generated themes

### Changed
- Nvim: diff highlights use theme palette colours (from GitSigns) instead of hardcoded values
- Nvim: Copilot suggestion highlight blends Comment fg towards Normal bg; skips if theme already defines it
- Tmux: fzf picker scroll keys changed from `Ctrl+d`/`Ctrl+u` to `d`/`u`
- Tmux: fzf session/window popups unbind `u` key in search mode (undo key conflict)

### Fixed
- Nvim: BufEnter empty-buffer cleanup deferred via `vim.schedule` to avoid interfering with diffview layout
- Nvim: JSON sort pipeline now uses `set -o pipefail` for proper error detection
- Tmux: session undo race condition — undo backup no longer deleted by split.sh orphan cleanup
- Tmux: undo cleanup only runs on successful restore (preserves backup for retry on failure)
- Tmux: undo cache directory created with mode 700
- Tmux: suppress send-keys errors during restore when pane is already gone

## [0.2.60] - 2026-03-11

### Changed
- Neovim: C# formatting now uses Roslyn LSP instead of CSharpier — respects `.editorconfig` rules with no extra tooling
- Install: global `.editorconfig` symlinked from `formatters/editorconfig` to `~/.editorconfig`
- Install: formatter symlinks grouped under "Formatters" section (was "Prettier")

### Fixed
- Install: `uninstall.sh` missing symlinks for `.prettierrc`, `.editorconfig`, `dash-repo-sync`, `lazygit/config.yml`, and `hammerspoon/init.lua`
- Neovim: vim-visual-multi motion conflicts with markdown keymaps and blink.cmp

### Removed
- CSharpier — no longer installed via Mason; migration auto-removes it

## [0.2.59] - 2026-03-11

### Added
- Neovim: `Space ba` keymap to delete all other buffers (keep current)
- Neovim: disable completion popup in grug-far search buffers

### Changed
- Zsh: `v` alias now clears the terminal before opening nvim
- Zsh: gcloud SDK path uses Homebrew prefix (supports `brew install google-cloud-sdk`)

### Fixed
- Neovim: conform.nvim csharpier formatter mapped to correct `cs` filetype

### Removed
- cronboard and posting — replaced by other tools; migration auto-uninstalls them

## [0.2.58] - 2026-03-09

### Added
- Neovim: layered spell dictionaries — personal (`~/.local/share/nvim/spell/`) and repo-shared (`nvim/spell/`); `zg` adds to personal dictionary
- Neovim: `Space Sd` keymap to edit personal dictionary
- `dotfiles update`: confirmation prompt before applying changes

### Changed
- Neovim: smart Tab in insert mode — accepts Copilot ghost text when visible, falls through to blink.cmp completion otherwise
- CI benchmark: uses median instead of min for startup badge, increased to 30 runs for stability
- Cleaned repo spell dictionary — moved personal words to user dictionary

## [0.2.57] - 2026-03-09

### Added
- Neovim: built-in spellcheck with en_gb, camelCase support, Telescope suggestions, and custom dictionary (`nvim/spell/en.utf-8.add`)
- Neovim: spell keymaps under `Space S` — toggle, suggest, add/remove words
- Neovim: which-key Spell group
- Zsh: `Opt+A` keybinding for directory history picker (replaces `cdl` command)

## [0.2.56] - 2026-03-09

### Added
- Incremental updates: `dotfiles update` now skips unchanged installer steps (use `--force` to re-run all)
- Version-gated migration system: scripts in `scripts/migrations/` run automatically during updates
- `--skip-steps` validation in installer (rejects unknown step names)
- Installer remembers whether project directory prompts have been asked (won't re-ask on updates)
- Brewfile: `monolith`, `gotermsql`, `lazyssh`, `cronboard`, `snitch`
- Installer: `posting` (HTTP client TUI via pipx) and `openapi-tui` (OpenAPI spec browser via GitHub releases)
- Zsh: `$HOME/.cargo/bin` added to PATH for Rust/Cargo binaries

### Changed
- `dotfiles update --dry-run`/`-n` renamed to `--preview`/`-p`
- Installer step labels extracted into variables (shorter verbs in update mode)
- Internal state files moved to `~/.config/dotfiles/.state/` (migrations, prompted)
- Brewfile: replaced `lazysql` with `gotermsql` (database TUI)

## [0.2.55] - 2026-03-08

### Changed
- Ghostty (Linux): replaced `curl | bash` install with deferred next-steps message (pinned commit SHA for review)
- Ghostty (Linux): removed `--nogpgcheck` from dnf Terra install; imports GPG key explicitly
- Ghostty (Linux): removed stderr suppression from pacman/dnf installs so errors are visible
- Ghostty keybindings: deduplicated macOS/Linux blocks using `${mod}` variable (opt vs alt)
- Ghostty config: platform-specific settings now injected via `{{PLATFORM_CONFIG}}` template placeholder
- Tmux config: clipboard command injected via `{{CLIPBOARD_CMD}}` template placeholder

### Fixed
- Temp file handling in theme-switch Ghostty block (uses `mktemp` instead of PID-suffixed files)
- Backup-file check in `test-linux-compat.sh` (was testing empty string, now uses `find`)
- Neo-tree filter popup border cutoff (`popup_border_style = 'rounded'`)
- Theme validation test now skips runtime placeholders (`CLIPBOARD_CMD`, `PLATFORM_CONFIG`)
- `update_zshrc_export` rejects values containing newlines (prevents sed injection)

### Removed
- Speculative snap path from `find_ghostty_themes` (no snap Ghostty packages exist)

## [0.2.54] - 2026-03-07

### Added
- Tmux: cross-platform helpers (`mod_key`, `clipboard_copy_cmd`) in tmux common.sh
- Tmux: dynamic help renderer (`show-help.sh`) replaces static `tmux-help.txt` with platform-aware modifier keys
- Tests for cross-platform helpers and show-help template rendering

### Changed
- Tmux: URL picker rebound from `prefix+y` to `prefix+u`; "no URLs" notification reduced to 1s
- Zsh: moved Homebrew environment setup to `zprofile` (login shell) for correct load order
- Zsh: added `gh` CLI completion fix for compdef conflict
- Tmux: `reverse_lines` removed broken `tail -r` fallback (now `tac` → `awk`)

## [0.2.53] - 2026-03-07

### Added
- Nvim: noice.nvim for enhanced LSP hover and signature help rendering (replaces lsp_signature.nvim and manual hover handler)
- Nvim: suppress diagnostics on decompiled .NET metadata source buffers (MetadataAsSource)
- Installer: `--no-logo` flag to suppress ASCII logo (used by `dotfiles update`)

### Changed
- `dotfiles update` runs installer with `--no-logo` and quiet git pull for cleaner output

## [0.2.52] - 2026-03-07

### Added
- Theme generation: create dotfiles themes from Ghostty's 300+ built-in themes via `dotfiles theme generate <name>`
- Theme deletion: remove generated themes via `dotfiles theme delete <name|all>`
- Lua colour utilities library (`scripts/_lib/colour-utils.lua`) for HSL conversion and contrast calculations
- Lua theme generator (`scripts/_lib/generate-theme.lua`) produces tmux, ghostty, nvim, and fzf configs
- Nvim: generated colourscheme loader in `theme.lua` with path traversal validation
- CI: shellcheck for theme tools, luacheck for Lua modules (now enforced, not advisory)
- Tests for colour utils, theme generation, theme deletion, symlinks, ghdash merge, health check, and uninstall
- Sandbox helpers in test framework for isolated test environments

### Changed
- Theme picker (`tmux/scripts/themes/pick.sh`) shows both hand-crafted and generated themes
- `theme-switch` sources `common.sh` instead of duplicating colour definitions; extended for generated themes
- `fzf-theme.sh` updated for generated theme support with path traversal guard
- Zsh tab completion updated with `generate` and `delete` subcommands
- Hardened input validation: hex colour checks in theme generator, variable name and sed escaping in `update_zshrc_export`, shell-escaped launcher names
- Temp files use `mktemp` instead of predictable PID-based names in alerts
- Deduplicated test boilerplate across tmux tests via shared `_test-helpers.sh`
- Collapsed `paths.sh` undo migration functions into single `_migrate_flat_undo_file()` helper
- Moved `sanitise_launcher_name` to `tmux/scripts/_lib/common.sh` (where it's used)
- Install scripts derive `DOTFILES_DIR` from script location instead of assuming `$HOME/dotfiles`
- Platform-aware `stat` in `paths.sh` for Linux compatibility
- `set-default-shell.sh` uses `tee -a` instead of `sudo bash -c`
- Documentation updates across theme system, installation guide, and component READMEs

### Fixed
- `tls` alias and `tattach` function path corrected to `resurrect/restore.sh`
- Theme picker `get_current_position()` generates list internally instead of reading from stdin
- `sessions/kill.sh` uses `$DOTFILES_ROOT` paths and guards resurrect plugin existence

### Removed
- `tmux/scripts/utils/confirm.sh` (unused)

## [0.2.51] - 2026-03-06

### Added
- keyd: Linux keyboard remapping (Karabiner equivalent) with per-device Apple keyboard support
- Installer: system gcc auto-install on Linux for native builds (tree-sitter, etc.)
- Installer: `cc` symlink prefers system gcc over Homebrew's on Linux
- Installer: `install_system_package` helper in common.sh for cross-distro package installs
- Installer: set-default-shell step ensures zsh is the login shell
- Installer: Ghostty and fnm Linux install hints in prerequisites and post-install
- Installer: dnf support in Homebrew prerequisite installation

### Changed
- Installer: Brewfile filters macOS-only formulas (fnm, swift-format) on Linux
- Installer: Linux prerequisite hints now suggest brew or system package manager
- Installer: full preset description is platform-aware (Karabiner on macOS, keyd on Linux)
- Nvim: CodeCompanion chat window width set to 40%
- Nvim: mkdnflow disabled MkdnNextLink/MkdnPrevLink mappings (frees C-i for jumplist)

## [0.2.50] - 2026-03-05

### Added
- Nvim: window zoom toggle (`<leader>z`) with statusline indicator
- Nvim: mkdnflow table alignment keybindings (`<leader>mA{c,l,r,x}`)

### Changed
- Nvim: blink.cmp Tab key now accepts completion when menu is visible (select_and_accept)
- Nvim: treesitter indentexpr only set when indent queries exist for the language (fixes C# column-0 issue)
- Nvim: discord presence idle timeout set to 10 minutes with hidden status
- gh-dash: removed lazygit universal keybinding (conflicts resolved)

## [0.2.49] - 2026-03-04

### Added
- Nvim: dial.nvim for enhanced increment/decrement (dates, semver, booleans, hex)
- Nvim: tailwindcss-dial.nvim to cycle Tailwind CSS classes with `Ctrl+a`/`Ctrl+x`
- Nvim: smart-paste.nvim for auto-adjusted indentation on paste
- Cheatsheet: increment-decrement section documenting `Ctrl+a`/`Ctrl+x` bindings

### Changed
- Brewfile: moved tmux-fingers from minimal preset to build tools section (requires gcc on Linux)
- CLI: added `ls`, `rg`, and `help` entries to `dotfiles aliases` output
- CLI: converted tmux aliases section from array-based to inline `_2col` for consistency

## [0.2.48] - 2026-03-03

### Changed
- CLI: `dotfiles notes` fetches changelog from remote so users can see unreceived changes above the `★ current` marker

## [0.2.47] - 2026-03-03

### Added
- Nvim: codecompanion.nvim with copilot (default), anthropic, and opencode ACP adapters
- Nvim: markdown-preview.nvim browser preview (`<leader>mp`)
- Health check: environment variable checks for plugin API keys (informational)

### Changed
- Nvim: swap parameter keymaps moved from `<leader>a`/`<leader>A` to `>p`/`<p` (frees `<leader>a` for AI group)
- Nvim: codecompanion default adapter changed from anthropic to copilot (no API key required)
- Nvim: blink.cmp sort config migrated from `sort.comparators` to `fuzzy.sorts`

### Fixed
- Nvim: markdown-preview.nvim build failure (`mkdp#util#install` not available during lazy.nvim build)
- Nvim: treesitter swap crash on buffers without a parser (now shows notification via mini.notify)
- Alerts: opencode hook wrappers skip when running as ACP subprocess inside Neovim

## [0.2.46] - 2026-03-03

### Added
- CLI: `dotfiles version` / `dot -v` command — shows version, preset, theme, branch, and path with gradient logo
- CLI: `dotfiles notes` highlights the current version with a magenta `★ current` marker
- Installer: Step 10 prompts for `DEV_ROOT` and `PROJECTS_ROOT` project directories during installation
- Installer: Smart post-install "next steps" that detect what's already configured and only show relevant items
- Zsh: fzf theme auto-refresh — `Ctrl+R`, `Ctrl+T`, `Alt+C`, and `cdl` pick up theme changes without restarting the shell

## [0.2.45] - 2026-03-02

### Added
- Nvim: mini.bufremove for buffer deletion without closing windows (`<leader>bd`, `<leader>bD`)
- Nvim: mini.pairs replaces nvim-autopairs (consolidated into mini.nvim)
- Nvim: mini.hipatterns for inline hex colour highlighting

### Changed
- Nvim: NeoTree reveal key changed from `\` to `|`
- Nvim: Breakpoint keybindings moved to `<leader>Bt` / `<leader>Bc` to free `<leader>b` for buffer group

## [0.2.44] - 2026-03-02

### Added
- Nvim: Discord Rich Presence via cord.nvim (catppuccin theme, repo link button)
- Health check: generated config validation, TPM plugin checks, alert hook executability, local override status, PATH/tools verification

### Fixed
- Nvim: Deduplicate .NET diagnostics reported from multiple .csproj contexts (Roslyn multi-project)
- Nvim: Diffview `]f`/`[f` navigation uses proper `DiffviewViewOpened`/`DiffviewViewClosed` user events instead of `FileType` autocmds
- Nvim: Guard mini.bracketed file navigation against empty/invalid directories

## [0.2.43] - 2026-03-02

### Added
- CLI: `dotfiles notes` / `dot -n` command — browse the full changelog in a pager (uses `bat` if available, falls back to colorised `less`)
- CLI: Changelog preview during `dotfiles update` and `dotfiles status` — shows incoming release notes when new versions are available
- Zsh: `cl` alias — clears screen, scrollback buffer, and tmux history in one keystroke

### Changed
- Nvim: vim-visual-multi Add Cursor Up/Down remapped to `<M-Up>` / `<M-Down>`
- README: CLI examples use `dotfiles` (full command name) with note that `dot` is a shorthand alias

## [0.2.42] - 2026-02-28

### Added
- Tmux: Browser-style navigation history — `prefix + -` (back) and `prefix + =` (forward) navigate between previously visited windows across sessions
- Tmux: `nav.sh` utility tracks window visits via hooks, prunes stale entries, and truncates forward history on new navigation (browser behaviour)
- Tmux: Navigation history tests (`test-nav-history.sh`)

### Changed
- gh-dash: `dash-repo-sync` detects and removes stale repo entries (paths that no longer exist on disk), with dry-run support
- gh-dash: `ghdash.sh` merge now starts from a clean `config.base.yml` to prevent array duplication from repeated `*+` merges
- gh-dash: `theme-switch` writes to `config.base.yml` instead of `config.yml` directly
- Nvim: Simplified `vim-visual-multi` plugin config (removed custom init, use `lazy = false`)
- Zsh: Swallow Ctrl+-/Ctrl+= escape codes to prevent raw output in terminals with `modifyOtherKeys`

## [0.2.41] - 2026-02-27

### Changed
- Alerts: `show.sh` rewritten to use parallel arrays for bash 3.2 (macOS stock) compatibility — removes `declare -A` dependency
- Alerts: Extracted `_acquire_alerts_lock` / `_release_alerts_lock` helpers with stale-PID recovery; shared by `clear_window_alerts`, `cleanup_stale_alerts`, `clear_session_alerts`, and `update-rename.sh`
- Alerts: `cleanup_stale_alerts` now correctly parses 5-field exit alert lines instead of splitting on 3 fields

### Fixed
- Cmd alerts: Label sanitisation — strip colons (alerts file delimiter), escape `#` (tmux format injection), and cap length at 80 chars
- Cmd alerts: Window-switch guard — only fire alert if user has switched away from the origin pane; commands finishing in the active pane are silently ignored
- Alerts: Agent name whitelist in `set_window_alert` prevents arbitrary values
- Alerts: `grep -vF` (fixed-string) in clear/rename operations prevents regex injection from session or window names
- Tests: Fix `_CMD_ALERT_THRESHOLD` → `_CMD_ALERT_MIN_SECONDS` rename and add `_CMD_ALERT_EXCLUDE=()` for test isolation

## [0.2.40] - 2026-02-26

### Added
- Zsh: Command exit alerts — automatically notifies when a command finishes in another tmux window (✓/✗ icon in status bar + window tab highlight), no wrapping required
- Tmux: `@exit_alert` / `@exit_alert_colour` window options for per-window exit state; `@exit_pass_colour` / `@exit_fail_colour` global options sourced from theme
- Alerts: `set_exit_alert` function in `alerts.sh` library; session and window list pickers show exit alert icons with ANSI colour
- Theme: `TMUX_EXIT_PASS_COLOUR` / `TMUX_EXIT_FAIL_COLOUR` derived variables (green/red) added to `theme-defaults.sh` and `theme-switch`
- Docs: `docs/CMD-ALERTS.md` — detailed guide for the command exit alert system
- Nvim: `<leader>wH/wL/wJ/wK` maximise-direction window resize keymaps (shift variants of small-increment maps)

### Changed
- Alerts: `show.sh` now handles both agent alerts (3-field) and exit alerts (5-field) in the same alerts file
- Alerts: Session and window list pickers handle mixed alert types with correct icons and colours
- Tmux: Zoom indicator uses `TMUX_STATUS_BELL_FG` (theme accent) instead of hardcoded cyan; clock background uses `TMUX_BG_SECONDARY`
- Theme: `TMUX_STATUS_BELL_FG` uses `${VAR:-fallback}` to allow per-theme overrides without clobbering explicit values set in the theme file
- Nvim: `<leader>lR` refresh runs `only` before wiping buffers and `wincmd =` after, resetting the layout cleanly

## [0.2.39] - 2026-02-26

### Added
- Launchers: `github` (gh-dash session) and `btop` (system monitor session)
- gh-dash: `dash-repo-sync` utility syncs local repo paths into gh-dash config (`drs` alias)
- gh-dash: Keybindings — `g` (lazygit), `C` (Octo code review), `D` (diffnav), `A` (actions)
- gh-dash: `local.yml` template for personal overrides (deep-merged via `yq` on theme-switch)
- Hammerspoon: `local.lua` override support via `pcall(require, "local")`
- LazyGit: `local.yml` template for personal overrides (loaded via `LG_CONFIG_FILE`)
- Brewfile: `yq` (YAML processor), `diffnav` (diff navigator), `gh-enhance` extension

### Changed
- Launchers: Renamed `tnew` to `dev` (same 3-window layout: zsh + nvim + claude)
- Install: Extracted `install_local()` and `migrate_to_symlink()` helpers in create-symlinks
- Install: Hammerspoon migrates from directory symlink to owned dir with file symlinks
- Install: LazyGit uses XDG path on all platforms via `LG_CONFIG_FILE` env var
- CLI: Simplified `dotfiles links` — removed stale btop, karabiner, lazydocker sections
- Docs: Expanded config ownership to three patterns (symlinked, layered, copy-on-install)

### Removed
- Install: Claude/OpenCode config symlinks (managed separately)

## [0.2.38] - 2026-02-25

### Changed
- Install: btop, karabiner, lazygit, lazydocker, hammerspoon configs use copy-on-install pattern — personal edits now survive `dotfiles update`
- Install: Uninstall preserves user-owned configs with warning instead of deleting
- Hooks: `nvim --server` commands use `--headless` flag to prevent terminal flicker
- Alerts: Storage path moved from `~/.claude/alerts` to `~/.config/agent-alerts/alerts` (XDG compliant)
- Docs: OpenCode hooks updated to use published `opencode-tmux-alert` plugin
- CLI: Added missing aliases (`alerts-clear`, `oc`, `dot`) to `dotfiles aliases` output

### Removed
- Tmux: Gemini agent support — removed instance picker, alert hooks, status bar integration, and resurrect process

### Added
- Docs: `docs/AGENT-HOOKS.md` — setup guide for agent alert hooks (Claude Code, OpenCode)
- Zsh: `OPENCODE_ALERT_SCRIPT` and `OPENCODE_CLEAR_SCRIPT` env vars for opencode-tmux-alert plugin

## [0.2.37] - 2026-02-24

### Added
- Tmux: `m` / `M` in copy-mode for first non-blank / end of line (matches nvim keymaps)

### Fixed
- Nvim: `<leader>cd` delete comment block preserves spacing when blank lines exist on both sides

## [0.2.36] - 2026-02-24

### Added
- Tmux: `r` rename binding in window switcher (`prefix + f`) — rename windows inline without leaving the picker
- Nvim: `<leader>c]` / `<leader>c[` to navigate between comment blocks
- Nvim: `<leader>cu` inside a `<comment>` block inserts a new exchange before `</comment>`
- Brewfile: `asciinema` terminal recorder, `tmux-fingers` tap fix
- Install: `.prettierrc` symlink for global Prettier config

### Changed
- Tmux: Session rename (`r`) in session switcher now stays in picker instead of switching to renamed session
- Tmux: URL picker (`prefix + y`) improved URL extraction — strips trailing punctuation and balances parens/brackets
- Nvim: Snippet insertion uses smart spacing (blank lines only where needed, no trailing blank)
- Nvim: `<leader>cd` delete comment block now removes surrounding blank lines
- Nvim: `mini.bracketed` `]f`/`[f` file navigation restored when diffview closes (was previously deleted)
- btop: Default process sort changed from threads to memory

## [0.2.35] - 2026-02-23

### Added
- Nvim: `<leader>pq` keymap to quit Octo (closes review layout and all octo buffers)
- Nvim: Octo `runs` mappings to fix workflow runs telescope picker crash

### Changed
- Nvim: Widened telescope ui-select dropdown to 0.9

## [0.2.34] - 2026-02-23

### Added
- Nvim: `m`/`M` keymaps for line start/end (`^`/`$`), marks relocated to `gm`
- Tmux: `` `+[ `` / `` `+] `` for previous/next pane layout cycling

## [0.2.33] - 2026-02-22

### Added
- CLI: `dot links` command — shows all managed symlinks and their status (OK/broken/absent), filtered by preset
- Zsh: `cdl` function — pick from directory history with fzf (browser-style, most recent first)
- Zsh: Tab completion for `dotfiles theme` subcommands (lists available themes)
- CI: Zsh startup benchmark job using hyperfine with benchmark-action trend tracking
- Launchers: `config` and `dotfiles` session launchers for tnew
- Zsh: `fnm` init is now guarded with command check (prevents errors when fnm is absent)

### Changed
- FZF: Collapsed multi-line `FZF_DEFAULT_OPTS` colour string into single-line format (avoids whitespace issues)

## [0.2.32] - 2026-02-22

### Added
- Zsh: `cdb`/`cdf` browser-style directory back/forward navigation
- CLI: `tnew` now shown in `dot aliases` when installed
- gh-dash: Integrated into theme system — `theme-switch` now generates a themed `~/.config/gh-dash/config.yml` with 17 colour keys

### Changed
- CLI: Fixed column overflow in `dot aliases` for FILES, TMUX, and PROFILING sections

### Removed
- Brewfile: Removed unused `oug-t/difi` tap

## [0.2.31] - 2026-02-21

### Added
- Tmux: `tmux-fingers` plugin for quick pattern copy (prefix + Space) — flash.nvim-like hint labels over URLs, paths, SHAs, IPs, Jira keys, emails, and more
- Tmux: Custom finger patterns for file paths, Jira keys, emails, connection strings, hex colours, and shell commands

### Changed
- Tmux: Removed Gemini instance picker (prefix + g)
- Tmux: Search highlight current match now uses pink with underscore for better contrast
- Tmux: `pick-url.sh` captures 50k lines instead of 5k for deeper URL history
- Tmux: `theme-switch` now substitutes `TMUX_ACCENT_GREEN` and `TMUX_BG_SECONDARY` placeholders

### Fixed
- Docs: Updated all three docs files (INSTALLATION-GUIDE, THEME-SYSTEM, TROUBLESHOOTING) with current codebase state — fixed stale paths, step counts, symlink lists, prerequisites, and XDG locations

## [0.2.30] - 2026-02-20

### Added
- Neovim: `http` treesitter parser
- Neovim: Auto-purge compiled treesitter parsers on plugin update to prevent ABI crashes

### Changed
- Neovim: Disable swap files entirely (undo + autoread + git make them redundant)
- Neovim: Removed SwapExists autocommand (no longer needed without swap files)
- Neovim: Gitsigns priority raised to 30 (above easy-dotnet test signs at 20)

### Fixed
- Neovim: dotnet build now uses `--no-incremental` to report errors from the entire solution

## [0.2.29] - 2026-02-19

### Added
- Neovim: SwapExists autocommand to auto-delete stale swap files (fixes E325 prompt spam)
- Installation: TTY detection for confirmation prompt to prevent hang in non-interactive environments
- Installation: Per-file symlink source validation during installation
- Backup directory: Set permissions to 700 to protect old configs containing secrets

### Changed
- Installation: Improved TPM clone error handling with explicit network error messaging
- Installation: Health check failures now display warnings instead of being silently suppressed
- Neovim build detection: Skip special buffers (neo-tree, terminal, etc.) when walking up to find build markers
- Neovim dotnet plugin: Refactored add_missing_imports logic into separate module for maintainability
- Theme switching: XDG_CONFIG_HOME compliance fixes throughout theme-switch
- Test runner: Removed permanently-skipped broken tests (test-kill-undo, test-show-dotfiles-status)

### Fixed
- Installation backup race condition on concurrent installations
- Backup directory creation now uses secure permissions
- Better build detection avoids nonsensical paths from special buffer types
- Various shell script quality improvements (shellcheck, error handling)

### Removed
- CODE_REVIEW.md — detailed code review analysis (addressed issues incorporated into codebase)
- Permanently-skipped broken test files that undermined test suite credibility

## [0.2.28] - 2026-02-19

### Changed
- Neovim: removed vim-fugitive — LazyGit and gitsigns cover all git workflows
- Neovim: `]f`/`[f` file navigation moved from fugitive to diffview
- Neovim: `<leader>dh` file history now falls back to repo history when no file is open
- Neovim: diffview `file_panel` config updated to `win_config` structure
- Neovim: patched diffview `init_layout` to guard against invalid window IDs (upstream bug)
- Neovim: gitsigns blame keybindings moved under `<leader>d` prefix — `<leader>db` toggle inline blame, `<leader>dB` blame popup (aligned with diffview group)
- Neovim: mini.bracketed `comment` and `treesitter` suffixes disabled (reserved for gitsigns `]c`/`[c` and neotest `]t`/`[t`)
- Ghostty: added `Opt+Shift+H/J/K/L/D/0` keybinds for escape sequence passthrough

### Added
- Zsh: `nvim-sync` function for headless Lazy.nvim plugin sync

## [0.2.27] - 2026-02-18

### Fixed
- `prefix+I` now correctly installs TPM plugins (non-interactive) and shows a completion message, instead of incorrectly overriding to config reload
- Added `prefix+r` reload hint to local override templates (tmux, Ghostty, Neovim)

### Changed
- Docs updated to reflect recent changes: new plugins, local override files, removed `Space h` help popup, removed `dana` references, corrected Ghostty setup instructions

## [0.2.26] - 2026-02-18

### Added
- Local override files for personal settings that survive theme changes and `dotfiles update`: `~/.config/tmux/local.conf`, `~/.config/ghostty/local`, `~/.config/nvim/local.lua` — created from templates on install, never overwritten
- `scripts/reload-locals.sh`: reload tmux, Ghostty, and all live Neovim instances after editing local overrides
- Tmux: `prefix + r` reloads all local overrides (tmux + Ghostty + nvim); `prefix + I` reloads tmux config only
- Tmux: `cursor-style block` default (overridable in `local.conf`)
- Ghostty: `shift+backspace` and `shift+space` keybinds for correct terminal passthrough
- ShellCheck: `.shellcheckrc` project-wide config to document and centralise suppressed codes

### Changed
- Ghostty: removed macOS Application Support symlink — Ghostty reads `~/.config/ghostty/config` natively on all platforms; no symlink needed
- Shell scripts: fixed `printf` format strings to use `%s` placeholders instead of inline ANSI colour variables (ShellCheck SC2059)
- Neovim: markdown-ui todo status config updated to new named-table API with `status_order`
- Neovim: diffview file panel positioned at bottom with height 10

## [0.2.25] - 2026-02-18

### Added
- Neovim: vim-visual-multi plugin for multiple cursors (`Ctrl+n` select word, `Alt+Down/Up` add cursor, `\A` select all)
- Neovim: mini.notify for drop-in `vim.notify` replacement with notification history (`<leader>Nn` filtered, `<leader>Na` all)
- Neovim: mini.bracketed for `]`/`[` navigation (buffers, comments, diagnostics, files, jumps, quickfix, treesitter, undo, windows, conflicts, yanks)
- Neovim: mini.splitjoin for splitting/joining code constructs (`gS` to split, `gJ` to join)
- Neovim: `<leader>cd` keymap to delete `<comment>` block under cursor
- Neovim: auto-show diagnostic float on `CursorHold`, suppressing virtual text while float is open
- Ghostty: `Ctrl+Enter` and `Ctrl+Shift+Enter` keybinds (kitty protocol) passed through to terminal apps
- Ghostty: `Opt+Shift+[` / `Opt+Shift+]` keybinds for escape bracket sequences
- Zsh: `Ctrl+Enter` and `Ctrl+Shift+Enter` bound to `accept-line` for correct behaviour in zsh

### Changed
- Neovim: dotnet build now resolves the best target (prefers `.slnx`/`.sln` over `.csproj`, skips build-variant solution files)
- Neovim: simplified `vim.diagnostic` virtual text config (removed redundant format function)
- Ghostty: `Opt+Up`/`Opt+Down` updated to send modifier-qualified cursor sequences
- Tmux: enabled `extended-keys always` for full kitty keyboard protocol support

### Fixed
- Zsh: added `shellcheck shell=zsh` declaration and suppressed SC1009/SC1036/SC1072/SC1073 on zsh glob qualifier syntax

## [0.2.24] - 2026-02-18

### Added
- Neovim: `<leader>cr` keymap to toggle `<comment>` block state between open and resolved

### Changed
- Neovim: claude-prompt `@` file picker now activates for any `.md` file under a `.claude/` directory (not just `claude-prompt-*.md`)
- Neovim: `@@` inserts a literal `@` in claude-prompt files (single `@` opens file picker)
- Neovim: mkdnflow table config updated to `auto_extend_rows`/`auto_extend_cols` API

### Removed
- Neovim: custom claude-diff plugin and associated hook scripts (`nvim-diff-checkpoint.sh`, `nvim-diff-permission.sh`, `nvim-diff-sync.sh`)
- Tmux: `test-claude-diff.sh` integration tests

## [0.2.23] - 2026-02-17

### Added
- Neovim: flash.nvim for jump/motion with search labels (`s`/`S` keys)
- Neovim: nvim-treesitter-textobjects for structural selection (`am`/`im`, `aC`/`iC`), motion (`]m`/`[m`), and parameter swapping (`<leader>a`/`A`)
- Neovim: grug-far.nvim for project-wide search and replace (`<leader>sR`)
- Neovim: oil.nvim for filesystem-as-buffer editing (`-` key)
- Neovim: trouble.nvim for better diagnostics lists (`<leader>xx`, `<leader>xX`, `<leader>xq`, `<leader>xl`)
- Neovim: which-key group icons for all leader key groups
- Neovim: Treesitter parsers for `dockerfile` and `make`
- Brewfile: ollama (local LLM runner), build tools (binutils, gcc, nasm, nano), lazysql, cloudflared, lazydocker
- Tmux: Gemini agent icon and colour support in alerts system
- Zsh: `alerts-clear` alias to clear Claude agent alerts

### Changed
- Neovim: Shortened keymap descriptions across all plugins for cleaner which-key display
- Neovim: Improved Roslyn solution filtering — patches `root_finder.find_solutions_from_file` instead of glob-based approach
- Neovim: Removed `<leader>h` help popup (use `<leader>?` cheatsheet instead)
- Neovim: Removed global fugitive keymaps (`<leader>vs/vb/vd`) — use LazyGit or gitsigns instead
- Neovim: Removed which-key non-Nerd-Font icon fallbacks (Nerd Font assumed)

### Removed
- Brewfile: difi (inline diff TUI)

## [0.2.22] - 2026-02-16

### Added
- Neovim: `JsonSort` command and `json.sort` LSP command for sorting JSON keys (strips trailing commas, sorts with jq, reformats with prettier)
- Neovim: Octo review diff scroll keymaps — `f`/`b` quarter-page, `d`/`u` half-page scrolling in review buffers

### Fixed
- Neovim: `LspRestart` uses `client.name` instead of `client.id` for correct server targeting
- Neovim: Disabled mkdnflow `MkdnEnter` and `MkdnNewListItem` keymaps that were mangling numbered lists and links on `<CR>`
- Tmux: Gemini instance switcher template binding was missing from previous release

## [0.2.21] - 2026-02-12

### Added
- Launcher picker: Settings panel (`s` key) to configure `DEV_ROOT` and `PROJECTS_ROOT` from within the picker
- Neovim: `<leader>pC` to close Octo review, `<leader>pX` to close PR
- Neovim: Expanded Octo PR keybindings — browser, URL yank, CI checks, changed files, checkout, ready/draft, thread resolve, suggest comment, reviewer/label management
- Neovim: Diffview scroll keymaps (`f`/`b`) for quarter-page scrolling in view, file panel, and history panel
- Zsh: `nvim-clear` alias to clear Neovim bytecode cache
- Launcher picker: New directory helper (`new-dir.sh`) with root picker for `DEV_ROOT`, `PROJECTS_ROOT`, or custom path
- `dotfiles set dev|projects <dir>` CLI command with zsh tab completion
- `scripts/_lib/common.sh`: `update_zshrc_export()` helper for safe `~/.zshrc` export updates
- `tmux/scripts/_lib/common.sh`: `list_project_dirs()` shared helper for `PROJECT_DIRS` listing
- Neovim: Telescope `find_files`, `live_grep`, and `grep_string` now search hidden files (excluding `.git/`)
- Gemini instance switcher (`prefix + g`) with fzf picker, alert integration, and inline instance management
- Gemini agent support in alert system (💎 cyan icon and colour)
- Zsh: `alerts-clear` alias to clear agent alerts directory

### Fixed
- Launcher test: corrected sanitisation assertion to match actual hyphen replacement character

### Changed
- `tnew` launcher: 3 separate windows (zsh, nvim, code) instead of 2 windows with split pane; directory argument is now required; offers to create directory if it doesn't exist
- Launcher picker: `n` (new directory) action uses dedicated root picker (`new-dir.sh`) instead of inline fzf path prompt
- `scripts/_lib/common.sh`: `update_zshrc_export()` auto-updates `PROJECT_DIRS` when `DEV_ROOT` or `PROJECTS_ROOT` changes
- Neovim: Cheatsheet updated with expanded PR review keybindings (browser, URL yank, CI checks, checkout, ready/draft, thread resolve)
- Launcher wizard (`new-launcher.sh`) moved from `scripts/` to `tmux/scripts/launchers/new.sh`
- Neovim: Theme setup runs before plugin load (ensures gitsigns, diffview pick up correct highlight groups)
- Neovim: IDE0079 diagnostic filter scoped to C# filetype in `dotnet.lua` (was global in `lsp.lua`)
- Neovim: Roslyn LSP `auto_refresh_codelens` disabled
- Neovim: PR review keybinding `<leader>ps` → `<leader>pf` (Find), added `<leader>psm` (squash merge)
- Neovim: Octo uses standard side-by-side diff (removed custom unified diff mode)
- Neovim: Octo `enable_builtin` disabled, `mappings_disable_default` enabled for cleaner keybinding control
- Neovim: Diff highlights no longer set Octo-specific highlight groups (uses core Vim diff groups)

### Removed
- `scripts/new-launcher.sh` (moved to `tmux/scripts/launchers/new.sh`)
- Health check: Removed `dana` command check
- Neovim: Custom unified review mode (toggle, hunk navigation, patch highlight parsing)
- Neovim: `<localleader>u` unified diff toggle and `]c`/`[c` hunk navigation in Octo reviews

## [0.2.20] - 2026-02-10

### Added
- Neovim: Dynamic diff highlights module (`diff-highlights.lua`) — computes tinted backgrounds from the active theme's Normal bg, consistent across fugitive, diffview, and octo
- Tmux: Window name restoration tests (custom names preserved, automatic-rename race condition covered)
- Brewfile: `luacheck` added as a Homebrew dependency
- Installer: `luacheck` added to core prerequisites check

### Changed
- Neovim: Removed hardcoded `Diff*` and `GitSigns*Ln/Nr` highlights from all 15 colourscheme files (now computed dynamically)
- Neovim: Moved Octo review highlight setup from `pr-review.lua` to shared `diff-highlights.lua`
- Makefile: `luacheck` target adds `--globals vim bit` for Neovim/LuaJIT compatibility
- Zsh: Shell startup performance — cached eval for direnv and fzf hooks, git branch caching for terminal titles, PATH deduplication via `typeset -U`
- Tmux: Status bar performance — inlined agent display function to avoid subshell forks, added 30s result cache for dotfiles sync status
- Neovim: Lazy-loading for guess-indent (`BufReadPost`), cheatsheet (`cmd`/`keys`), and fidget.nvim (`LspAttach`)
- Neovim: Migrated nvim-treesitter from deprecated `master` branch (`require('nvim-treesitter.configs').setup`) to new `main` branch API (`require('nvim-treesitter').install`, `vim.treesitter.start()`)
- Brewfile: Added `tree-sitter-cli` as a dependency (required by new nvim-treesitter for parser compilation)
- Brewfile: Updated Neovim version requirement comment from >= 0.9 to >= 0.11
- Installer: Added `tree-sitter-cli` to core prerequisites check
- Neovim: Markdown ordered list renumbering uses `CursorHold` (debounced) instead of `TextChanged` to avoid interference during edits

### Fixed
- Neovim: Dotnet solution filter now excludes all build variant solutions (`.ci.sln`, `.build.slnx`, `.test.sln`) instead of only `.ci.sln`
- Tmux: Alert show script used unreliable line count for empty check — replaced with `-n` string test
- Tmux: Window names overwritten by `automatic-rename` during resurrect restore — disabled per-window in Pass 1 before names are applied in Pass 2

## [0.2.19] - 2026-02-10

### Added
- Neovim: Custom colourscheme files in `nvim/colors/` for all 16 themes — removes dependency on 12 colourscheme plugins
- Theme contrast checker script (`scripts/theme-contrast-check`) — validates WCAG contrast ratios for theme files
- LazyGit and LazyDocker config files with reverse-video selection styling (works with any theme)
- Neovim: Vite/esbuild build config detection in quickfix build picker (`vite.config.*` marker)
- Launcher wizard: Worktree awareness step — optional worktree directory resolution for session launchers

### Changed
- Neovim: Quickfix Vite/esbuild config runs `check` (eslint + tsc) instead of `build` — finds more errors without producing artifacts
- Theme files: Refined accent colours and secondary foreground values across all themes for better contrast
- Neovim: Removed all colourscheme plugin dependencies from `ui.lua` — themes are now self-contained
- Gitsigns: Simplified highlight configuration to use built-in groups
- Themes README: Streamlined documentation to match simplified theme variable format
- Neovim: Quickfix window uses `botright` with `winfixheight` to prevent layout disruption when opening
- Neovim: Quickfix `<CR>` mapping preserves quickfix height after jumping to error location
- Neovim: Go `vet` errorformat handles `vet:` prefix and module comment lines
- Neovim: Makefile build targets use combined errorformat from all build configs

### Fixed
- `git-prune` alias uses `-D` (force delete) instead of `-d` — squash-merged branches weren't recognised as fully merged, causing "not fully merged" errors
- Neovim: Treesitter injection highlighting for markdown code blocks — use `nvim-treesitter.configs` module for proper language injection support
- Neovim: Treesitter `auto_install` disabled to prevent race condition — concurrent Neovim instances (e.g. neotest subprocess) would race to create the same tmp directory, causing `mkdir: tree-sitter-*-tmp: File exists` errors
- Neovim: C# syntax highlighting in markdown code fences — registered `csharp`/`cs` as aliases for the `c_sharp` treesitter parser
- Neovim: Quickfix build opens empty on success when tool output doesn't match errorformat — now validates parsed entries before opening
- Neovim: `grr` (LSP references) broken on Neovim 0.11 — `on_list` handler was passed as LSP context instead of options, causing "Cannot serialise function" error

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
