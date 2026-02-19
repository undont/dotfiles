# Code Review: dotfiles

**Date:** 2026-02-19
**Reviewer:** Claude (Opus 4.6)
**Commit:** HEAD of main at time of review

---

## Overview

Personal dotfiles repository managing configuration for zsh, tmux, neovim, hammerspoon, ghostty, and karabiner. Features a tiered preset installer (minimal/core/full), a 15-theme theming system, a CLI management tool, and an extensive tmux scripting layer with multi-agent support.

---

## Line Count Breakdown

**Grand Total: ~37,400 lines** across all tracked files.

### By Language

| Language | Lines | % of Total |
|----------|------:|:----------:|
| Shell (`.sh`) | 18,694 | 50% |
| Lua (`.lua`) | 7,015 | 19% |
| Markdown (`.md`) | 5,151 | 14% |
| Zsh config | 2,917 | 8% |
| Theme definitions (`.theme`) | 1,195 | 3% |
| Config templates | 1,010 | 3% |
| Other (JSON, YAML, Makefile, Brewfile) | ~1,400 | 3% |

### By Domain

| Domain | Lines | Breakdown |
|--------|------:|-----------|
| **Tmux scripts** | 11,897 | Functional: 4,785 / Tests: 5,219 / Libraries: 1,893 |
| **Scripts (install, CLI, utils)** | 7,033 | Install modules: 1,573 / Tests: 3,078 / Libraries: 1,071 / Hooks: 88 / CLI+theme+misc: ~1,200 |
| **Neovim** | 6,943 | Plugins: 1,948 / Core: 969 / Kickstart: 414 / Colorschemes+snippets: ~3,600 |
| **Zsh** | 2,917 | Config, templates, p10k |
| **Themes** | 1,195 | 15 theme definitions + defaults |
| **Tmux config template** | 636 | Status bar, keybindings |
| **Launchers** | 250 | Session creation scripts |
| **Karabiner** | 182 | Keyboard remapping JSON |
| **Ghostty** | 175 | Terminal config + template |
| **Hammerspoon** | 147 | macOS window automation |

Test code accounts for ~8,300 lines (22% of total).

---

## Strengths

### 1. Engineering Rigor Rare in Dotfiles Repos

Most dotfiles are a pile of symlinked configs. This has a proper installer with presets, rollback support, a state machine for error recovery, and a CLI management tool. The preset hierarchy (minimal/core/full) is a genuinely useful design for someone who works across servers, dev machines, and macOS workstations.

### 2. Substantial Tmux Scripting System

66 scripts organized into functional subdirectories with shared libraries, isolated test servers, and file locking for concurrent access. The multi-agent alert system (tracking Claude, OpenCode, Gemini instances via process tree walking) is inventive. The per-session resurrect splitting is a nice extension of tmux-resurrect that isn't seen elsewhere.

### 3. Solid Test Infrastructure

Dynamic test discovery, isolated tmux test servers via socket injection, proper assertion helpers, and CI that runs ShellCheck + tests + syntax checks + luacheck. The `tmux()` wrapper that respects `TMUX_TEST_SOCKET` is a clean pattern for testability.

### 4. Theme System That Avoids the Classic Dotfiles Problem

Templates + generated configs in XDG locations means no git conflicts when switching themes, and local override files that survive updates. 15 themes with consistent coverage across tmux, ghostty, and neovim is generous and well-considered.

### 5. Bash 3.2 Compatibility

No associative arrays, no modern bash-isms. This matters for macOS where `/bin/bash` is ancient. Shows attention to practical portability.

### 6. Notable Innovative Patterns

- **Multi-agent alert system** (`tmux/scripts/_lib/alerts.sh`): Tracks Claude, OpenCode, Gemini via process tree inspection with file locking to prevent corruption.
- **Per-session resurrect saves** (`tmux/scripts/resurrect/split.sh`): Post-save hook that splits monolithic resurrect files into per-session files.
- **Tmux test socket injection** (`tmux/scripts/_lib/common.sh`): All tmux calls go through a wrapper that respects `TMUX_TEST_SOCKET`, enabling fully isolated test servers.
- **Rollback state machine** (`scripts/_lib/rollback.sh`): Three files track install state, symlinks, and backup location with path traversal protection.
- **Preset-filtered Brewfile** (`scripts/_lib/brewfile.sh`): AWK-based filtering of Brewfile packages by preset markers.
- **File locking via `mkdir`** (`tmux/scripts/_lib/alerts.sh`): Atomic directory creation with 10 retries and 100ms backoff for concurrent access safety.

---

## Issues and Criticisms

### 1. Complexity vs. Maintenance (High-Level Concern)

~37,000 lines is substantial. The tmux scripts alone (11,900 lines) are larger than many standalone CLI tools. There's a rollback state machine, file locking with retry loops, process tree walking, preset-filtered Brewfile parsing via AWK, a migration system for zshrc symlinks... each piece is well-built, but the aggregate complexity creates a maintenance burden.

The question to ask: if you step away for 6 months, could you come back and understand the zshrc migration state machine in `create-symlinks.sh:66-152` without comments? The code quality is high, but the *volume* of code is the risk.

---

### 2. Install System Bugs

#### 2a. Missing Symlink Source Validation

**Location:** `scripts/install/create-symlinks.sh` - `ln -sf` calls
**Severity:** Medium

`create-symlinks.sh` creates symlinks without validating that the source file exists. A corrupted or incomplete clone creates broken symlinks silently.

**Fix:** Add `[[ -e "$source" ]] || error "Source not found: $source"` before each `ln -sf`.

#### 2b. Interactive Prompts Hang in Non-Interactive Environments

**Location:** `install.sh:148`, `scripts/install/create-symlinks.sh:72-74`
**Severity:** Medium

`read -r response` without a timeout or `[[ -t 0 ]]` check means piped input or CI runs can hang indefinitely. `read_with_timeout()` exists in `common.sh` but isn't used consistently.

**Fix:** Use `read_with_timeout()` consistently or add `[[ -t 0 ]]` guard for non-interactive detection.

#### 2c. Health Check Silenced

**Location:** `install.sh:279`
**Severity:** Low-Medium

The health check runs with `|| true`, ignoring failures. The install reports success even if symlinks are broken, defeating the purpose of having a health check.

**Fix:** At minimum, capture and display a summary of health check failures rather than silencing them entirely.

#### 2d. Backup Directory Permissions

**Location:** `scripts/install/backup-existing.sh:13`
**Severity:** Low

`~/.dotfiles-backup/` is created with default umask. The backup may contain secrets from old configs (e.g., old `.zshrc` with API keys).

**Fix:** Use `mkdir -p -m 700` for the backup directory.

#### 2e. Backup Timestamp Race Condition

**Location:** `scripts/install/backup-existing.sh:13`
**Severity:** Low

`BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)-$$"` uses PID for uniqueness, but concurrent installations could theoretically collide on the same second.

**Fix:** Use `mktemp -d` or append microseconds.

#### 2f. TPM Clone Failure is Opaque

**Location:** `install.sh:238`
**Severity:** Low

TPM git clone fails silently if GitHub is unreachable. The error trap catches it, but the user gets a generic "Installation failed at line 238" without knowing it was a network issue.

**Fix:** Add explicit error: `git clone ... || { error "Failed to clone TPM - check network"; exit 1; }`

---

### 3. Two Permanently-Skipped Broken Tests

**Location:** `scripts/run-tests.sh` - hardcoded skip list
**Severity:** Medium

`test-kill-undo.sh` and `test-show-dotfiles-status.sh` are hardcoded as skipped in the test runner. These are known failures that have been papered over rather than fixed. For a project that invests this heavily in testing, broken tests that stay broken undermine the value of the test suite.

**Fix:** Either fix the underlying issues or delete the tests. Permanently-skipped tests are worse than no tests -- they create a false sense of coverage.

---

### 4. Theme Substitution Pipeline Fragility

#### 4a. Sed Delimiter Collision

**Location:** `scripts/theme-switch` - sed substitution calls
**Severity:** Medium

`theme-switch` uses `|` as the sed delimiter. If any theme variable ever contains a `|` character, the substitution breaks silently and produces garbled config.

**Fix:** Escape theme variable values before substitution, or use a delimiter that's guaranteed not to appear in color codes (e.g., `\x01`).

#### 4b. No Theme Variable Validation

**Location:** `scripts/theme-switch:102-109`
**Severity:** Low-Medium

The script checks that the theme file exists but doesn't validate its contents. A corrupted or incomplete theme file (missing required variables) gets `source`'d, leaving variables undefined, and sed produces empty values in the generated config.

**Fix:** After sourcing a theme file, validate that all required variables are defined before proceeding with substitution.

#### 4c. Non-Atomic Config Writes

**Location:** `scripts/theme-switch:126-154`
**Severity:** Low

Tmux config is written first, then Ghostty config, then the current-theme marker. A failure mid-way leaves partial state (e.g., tmux themed but ghostty not).

**Fix:** Write to temp files, then atomic `mv` to final locations.

---

### 5. XDG Compliance Inconsistency

**Location:** `scripts/theme-switch:29` (and similar)
**Severity:** Low

Most scripts correctly use `${XDG_CONFIG_HOME:-$HOME/.config}`, but `theme-switch` hardcodes `$HOME/.config` for Ghostty output paths. If someone sets a custom `XDG_CONFIG_HOME`, the theme system writes to the wrong location.

**Fix:** Use `${XDG_CONFIG_HOME:-$HOME/.config}` consistently throughout.

---

### 6. Uninstall Package Removal Footgun

**Location:** `scripts/install/uninstall.sh:271-276`
**Severity:** Medium

`brew uninstall --ignore-dependencies` on all Brewfile packages could break non-dotfiles software that depends on shared packages. There's no dependency check or warning before removal.

**Fix:** At minimum, warn the user and list shared dependencies. Consider making package removal opt-in rather than automatic.

---

### 7. Documentation Gaps in Complex Code Paths

**Locations:**
- `scripts/install/create-symlinks.sh:66-152` (zshrc migration state machine)
- `scripts/_lib/brewfile.sh:44-68` (AWK filtering logic)
- `scripts/_lib/rollback.sh` (state machine protocol)
- `tmux/scripts/_lib/alerts.sh` (file locking protocol)

**Severity:** Low-Medium

These are the most intricate code paths in the project, and they have the fewest inline comments. The test files are better documented than the production code they test. Future maintenance (including by the author after time away) will be harder than it needs to be.

**Fix:** Add comments explaining the *why* at decision points in these files -- not line-by-line, but at the level of "what state are we handling here and why."

---

### 8. Rollback State Location

**Location:** `scripts/_lib/rollback.sh:7-10`
**Severity:** Low

Rollback state lives in `.install-state/` within the dotfiles directory itself. If the dotfiles directory is on a read-only filesystem or has restrictive permissions, rollback state can't be created, and the error handling for this case is minimal.

**Fix:** Consider using a temp directory (`mktemp -d`) with trap cleanup, or validate writability before attempting state creation.

---

### 9. Test Coverage Gaps

**Well-tested:**
- Installation libraries and symlink creation
- Theme system (switching, validation, consistency)
- Tmux libraries (validation, paths, sessions, alerts)
- Tmux functional scripts (instances, sessions, windows, launchers)
- dotfiles CLI (all subcommands)
- Brewfile preset filtering

**Not tested:**
- Hook scripts (`scripts/hooks/agent-alert.sh` and wrappers) -- 0 tests
- `install-packages.sh` and `install-homebrew.sh` -- structure only, no functional tests
- Launcher scripts (`launchers/`) -- no integration tests
- Error recovery scenarios (partial failures, disk full, permission errors)
- End-to-end installation flow (minimal -> core -> full)

---

### 10. Minor Issues

| Issue | Location | Note |
|-------|----------|------|
| Inconsistent SCRIPT_DIR pattern | Various production scripts | Some use `${BASH_SOURCE%/*}`, some use `cd`+`pwd` -- CLAUDE.md documents the convention but a few scripts don't follow it |
| Magic numbers in formatting | `scripts/install/health-check.sh:65`, `scripts/theme-switch:38` | Hardcoded alignment widths and color codes reduce maintainability |
| Function naming inconsistency | `scripts/dotfiles` vs `scripts/_lib/common.sh` | CLI uses `cmd_` prefix, libraries don't -- minor but adds cognitive load |
| `dotfiles set dev ~/nonexistent` succeeds | `scripts/dotfiles:252-258` | Expands `~` but doesn't validate the directory exists |
| Subshell PATH propagation | `install.sh:161-171` | Homebrew install in subshell; PATH recovery works but isn't validated |

---

## Summary

This is a well-crafted project that shows strong shell scripting fundamentals and thoughtful architecture. The preset system, test infrastructure, and theme pipeline are genuinely good ideas executed competently. The 22% test coverage ratio is healthy, and the CI pipeline covers linting, syntax, and functional tests across platforms.

The main risk is complexity. There's more code here than one person can realistically keep in their head, and the areas where documentation is thinnest are the areas where the logic is most intricate. The install system has a few real bugs (missing source validation, interactive hang risk, silenced health check) that are worth fixing. The two broken tests should be dealt with one way or another.

**Recommendation:** Resist the urge to add more. The foundation is solid. The value now is in hardening what exists -- fixing the bugs, documenting the complex paths, and pruning what isn't earning its keep.
