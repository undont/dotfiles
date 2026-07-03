---
paths:
  - "install.sh"
  - "scripts/install/**"
  - "scripts/_lib/**"
  - "scripts/migrations/**"
  - "Brewfile"
---

# Installation System

## Install Presets

The installer uses presets to filter `Brewfile` packages and symlinks:

- **minimal**: zsh, tmux (marked with `# @preset: minimal`)
- **core**: + nvim, ghostty, AI tools, launchers (marked with `# @preset: core`)
- **full**: + Hammerspoon, Karabiner (marked with `# @preset: full`)

Preset is saved to `~/.config/dotfiles/preset` and used by `dotfiles update`. Updates are incremental by default -- only installer steps relevant to changed files are re-run. Use `--force` to re-run all steps. See [docs/INSTALLATION-GUIDE.md](docs/INSTALLATION-GUIDE.md) for detailed walkthrough of each installation step.

## Install Slices

Slices are individual components installable on top of a preset, e.g.
`./install.sh --minimal nvim zoxide nerd-fonts`. Each slice is a standalone,
idempotent script under `scripts/install/slices/<name>.sh` that owns one
component and can also be run directly.

- **Framework**: `scripts/_lib/slices.sh` (discovery, dependency resolution,
  `@slice` Brewfile extraction, the `slice_main` dispatcher). Link helpers live
  in `scripts/_lib/symlink.sh` (shared with `create-symlinks.sh`).
- **A slice** sets `SLICE_NAME`/`SLICE_DESC`/`SLICE_PRESET`/`SLICE_REQUIRES`,
  optionally overrides `slice_link`/`slice_postinstall`/`slice_packages`, then
  calls `slice_main "$@"`. Subcommands: `meta`, `packages`, `install-packages`,
  `link`, `postinstall`, `all` (default).
- **Packages are single-sourced**: tag a Brewfile line with `@slice: <name>`
  (inside its comment) and the slice's default `slice_packages` reads it. A line
  may list several, e.g. `@slice: nvim, search`. Tags do not affect preset
  filtering.
- **Dependencies**: `SLICE_REQUIRES` is resolved transitively, dependency-first
  (e.g. `nvim` pulls in `nerd-fonts`).
- **Persistence**: requested slices are saved to `~/.config/dotfiles/slices`
  (`get_slices` in `cli.sh`) and replayed by `dotfiles update`. The
  `dotfiles slice` subcommand (`cmd_slice`) manages them post-install:
  `list`/`add`/`remove`, backed by `slices_add_saved`/`slices_remove_saved`/
  `slice_is_saved` in `cli.sh`.
- **Adding a slice**: create `scripts/install/slices/<name>.sh` (chmod +x), tag
  its Brewfile packages, and it is auto-discovered by `--list-slices` and the
  test suite. Preset config blocks in `create-symlinks.sh` should delegate to
  the slice's `link` step (`slice_run <name> link`) to avoid duplicating logic.

## Versioning

The version is read at runtime from `CHANGELOG.md` -- there is **no hardcoded version string** anywhere in the codebase. When bumping the version, only update `CHANGELOG.md`. Do not search for or try to update a version constant in scripts.

## Migrations

Version-gated scripts in `scripts/migrations/` run automatically during `dotfiles update`. They handle one-off changes that can't be done by the normal installer (e.g. converting a symlink to a user-owned copy, moving files to new locations).

**Naming convention:** `<version>-<description>.sh` -- the version prefix determines when the migration runs. It executes for users upgrading through that version (range: `(old_version, new_version]`).

**How to create a migration:**
1. Create `scripts/migrations/<version>-<description>.sh` (use the CHANGELOG version being released)
2. Use `set -euo pipefail`, keep it idempotent (safe to run twice)
3. Use `echo` for status messages (indented with 4 spaces to align with the migration runner output)
4. Make it executable (`chmod +x`)

**Example:** `0.2.57-unlink-p10k.sh` -- converts `~/.p10k.zsh` from a symlink pointing into the repo to a standalone user-owned copy.

**Tracking:** Applied migrations are recorded in `~/.config/dotfiles/.state/applied-migrations` so they only run once.
