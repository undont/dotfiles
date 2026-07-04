# Contributing

Thanks for contributing. This repo ships configuration to real machines via
`dotfiles update`, and releases are cut automatically from `CHANGELOG.md`. The
convention that matters most: **every user-facing change needs its own dated
changelog heading**, because that heading is what gets tagged and shown to users
on update. CI enforces it — a push or PR that adds commits without one fails the
`release-guard` check, unless the change is explicitly marked `[skip release]`.

## Before you start

Run the test and lint suites locally before pushing — CI runs the same checks:

```bash
make test    # all tests (auto-discovered)
make lint    # shellcheck + luacheck + theme contrast
```

`make` on its own lists every target.

## Branching

- Branch off `main` with a descriptive kebab-case name: `add-fzf-aliases`,
  `fix-tmux-help-popup`.
- **No version numbers in branch names.** The version lives only in
  `CHANGELOG.md` and the auto-generated tag — never in a branch, commit subject,
  or PR title.

## Changelog and releases

Releases are not cut by hand. The `auto-tag` CI job runs on every push to `main`,
reads the **topmost dated `## [X.Y.Z]` heading** in `CHANGELOG.md` (it ignores
`## [Unreleased]`), and pushes a matching `vX.Y.Z` tag if one doesn't already
exist. `dotfiles update` then shows users everything newer than their installed
version — again skipping anything still under `[Unreleased]`.

So a user-facing change **must** add a new dated heading. Leaving the entry under
`[Unreleased]` means no tag is created and users never see it.

**Layout** — keep `## [Unreleased]` as an empty placeholder at the top and add
the new dated heading directly below it (don't rename `[Unreleased]`):

```markdown
## [Unreleased]

## [0.3.0] - 2026-06-01

### Added

- Tmux: new `@thing` option that does X (where it lives, how to enable it)

### Changed

- ...

### Fixed

- ...

### Removed

- ...
```

- Use today's date (`YYYY-MM-DD`) and a version that isn't already tagged
  (`git tag --list 'v*' | sort -V | tail -3`).
- Bump per [semver](https://semver.org): `PATCH` for fixes/small tweaks, `MINOR`
  for new features, `MAJOR` for breaking changes.
- Write entries the way the existing ones read: specific, naming the files and
  options touched, and explaining the _why_ where it isn't obvious. British
  English throughout.
- The changelog edit goes in the **same commit** as the change it documents — a
  follow-up `docs:` commit misses the auto-tag window.

### Changes that shouldn't cut a release

Docs-only edits, CI tweaks, and other repo-internal housekeeping don't warrant a
release. For those, skip the changelog bump and add `[skip release]` to a commit
message. A CI guard (`scripts/ci/check-release-version.sh`) fails any push or PR
that lands commits past the latest tag **without** either a new dated heading or
a `[skip release]` marker — so the choice is always explicit.

## Commits and pull requests

Commit subjects and PR titles use a lowercase prefix:

| Prefix      | For                                    |
| ----------- | -------------------------------------- |
| `add:`      | new config, scripts, or features       |
| `update:`   | changes to existing config             |
| `fix:`      | bug fixes                              |
| `refactor:` | restructuring with no behaviour change |
| `docs:`     | documentation only                     |
| `chore:`    | maintenance                            |

- Imperative mood, subject under ~72 characters.
- No version numbers in subjects or PR titles.
- Keep PRs focused; keep the description short and about the change.

## Migrations

When a change needs a one-off action on machines that already have the dotfiles
installed — converting a symlink to a user-owned copy, removing a deprecated
package, relocating a file — add a migration. It runs once during
`dotfiles update` for users crossing that version.

- Create `scripts/migrations/<version>-<description>.sh` using the CHANGELOG
  version being released (e.g. `0.3.0-relocate-foo.sh`).
- Start with `set -euo pipefail`, keep it **idempotent** (safe to run twice),
  and `chmod +x` it.
- Use `echo` for status, indented four spaces to align with the runner's output.

See `.claude/rules/install.md` for the full migration contract.

## Aliases and the cheatsheet

The `dotfiles aliases` cheatsheet is generated from source, so new entries must
be annotated or they're silently dropped:

- **New alias** → add the `alias` line in `zsh/dotfiles.zsh` with a trailing
  `# description` comment. Aliases without a description are skipped on purpose.
- **New function** for the cheatsheet → add `# @cheat: <description>` on the line
  directly above the function definition.
- **Free-form row** (a ZLE binding, external tool, or `dotfiles` subcommand) →
  `# @cheat: <name> | <description>`.
- **New section** → `# @section: <NAME>` before the block.

## Documentation

After a change, update the docs it affects — this is the last step, not done
mid-change:

- `README.md` for feature summaries, keybindings, and aliases.
- `CLAUDE.md` for architecture, conventions, and the
  [config ownership patterns](CLAUDE.md) (symlinked / layered / copy-on-install).
- `docs/` for the detailed guides (themes, installation, troubleshooting).

`.claude/rules/docs.md` lists exactly what to check.

## Code style

- Shell scripts pass ShellCheck with the standard exclusions and start with
  `set -euo pipefail`; source `scripts/_lib/common.sh` for shared helpers. See
  `.claude/rules/shell.md`.
- Lua passes `luacheck` (config in `nvim/.luacheckrc`) and is formatted with
  `stylua`.
- British English in code, comments, and docs (`colour`, `behaviour`, `centre`).
- Don't change aliases or keybindings without asking — they reflect personal
  preference, not bugs.
