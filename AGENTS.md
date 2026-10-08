# AGENTS.md

Personal dotfiles for macOS/Linux development environment. Manages configuration for zsh, tmux, neovim, zed, hammerspoon, ghostty, karabiner, and keyd.

## Quick Reference

```bash
make              # Show all available targets
make test         # Run all tests
make lint         # Run all linters (shell, zsh, lua, theme contrast)
```

## Config Ownership Patterns

Three patterns are used for configuration files. Choose based on whether the tool
supports a local override mechanism and how personal the config tends to be.
`scripts/manifest.conf` is the source of truth for which file uses which pattern:
one row per managed path (kind, preset, os, source, dest, local-layer key). The
installer, `dotfiles links`, `health-check`, `uninstall` and the local layer all
read it through `scripts/_lib/manifest.sh`, so a new managed file is one new row.
Changing preset on install removes the previous preset's links before creating
the new ones, so the saved preset always matches what is on disk.

### 1. Symlinked

Config lives in the repo. The installed path is a symlink. Changes committed to
the repo propagate on next `dotfiles update`.

**Used for:** zprofile, the whole `tmux/` dir (-> `~/.tmux`), the whole `nvim/`
dir (-> `~/.config/nvim`), the `dotfiles` CLI (`scripts/dotfiles` ->
`~/.local/bin/dotfiles`), the formatter configs (`formatters/prettierrc.json` ->
`~/.prettierrc`, `formatters/editorconfig` -> `~/.editorconfig`), the `dev`
launcher (`launchers/dev` -> `~/.local/launchers/dev`; the other files in
`launchers/` are not linked by the installer), `gh-dash/dash-repo-sync`,
`lazydocker/format-logs.awk`, the statusline theme resolver
(`scripts/_lib/statusline-theme.sh` -> `~/.config/dotfiles/statusline-theme.sh`),
the ImageMagick font map (`imagemagick/type.xml` -> `~/.config/ImageMagick/type.xml`,
macOS only; see the note below), zed's `keymap.json` and `tasks.json`.

Because `tmux/` and `nvim/` are linked as whole directories, files written under
the installed paths land inside the repo working tree and are gitignored there:
`~/.config/nvim/local.lua` is `nvim/local.lua`, and TPM plugins install into
`tmux/plugins/`.

Zed has no include/override mechanism for its config files (no
`include`/`import` directive in `settings.json` or `keymap.json`, and no
per-machine local file it auto-loads), so it can't use
the layered pattern below. `keymap.json`/`tasks.json` carry no personal or
machine-specific values, so they're plain symlinks. Zed's own writers are safe
to symlink under: the GUI keymap editor writes through the symlink with a
plain `fs::write` (no rename), and the settings editor canonicalises the path
before its atomic tempfile-rename, so it lands on the resolved repo file
rather than replacing the symlink. `settings.json` itself mixes shareable
prefs with per-machine ones (font size, theme) with no way to split them, so
it stays copy-on-install instead (see below).

yazi is symlinked **per file** (`yazi/yazi.toml`, `yazi/keymap.toml` ->
`~/.config/yazi/`), not as a whole directory, so theme-switch can write a
generated `~/.config/yazi/theme.toml` alongside without it landing back in the
repo. The 0.2.109 migration converts older whole-dir symlinks. The generated
theme file is described in `.claude/rules/themes.md`.

The ImageMagick font map (`imagemagick/type.xml`) only installs on macOS:
homebrew's imagemagick ships empty `type-*.xml` stubs whose glyph paths resolve
to nothing, so SVGs with text (image.nvim drawing a shields.io badge) fail
`identify` with "unable to read font". The map points real macOS system fonts at
the type cache. Linux imagemagick has a working fontconfig cache, so it is skipped
there. **Never put a backtick anywhere in this file**, even inside a comment:
imagemagick's config parser treats `` ` `` as command interpolation and silently
drops the entire type cache, which leaves imagemagick with zero fonts.

### 2. Layered (repo-owned base + local override)

The base config is owned by the repo and the tool also loads a user-owned local
file on top. The local file is created from a `*.template` on first install and
never overwritten by `dotfiles update`.

The base takes one of two forms:

- **Symlinked base** (nvim, lazygit, hammerspoon): the installed base is a
  symlink into the repo (`nvim/`, `lazygit/config.yml`, `hammerspoon/init.lua`),
  so a repo edit is live immediately.
- **Generated base** (tmux, ghostty, gh-dash): `scripts/theme-switch` renders the
  base from a repo `*.template` into the XDG location
  (`~/.config/tmux/tmux.conf`, `~/.config/ghostty/config`,
  `~/.config/gh-dash/config.yml`). Edit the template, never the generated file;
  a template edit reaches the installed config on the next theme generation
  (`dotfiles theme switch`, or the installer run).

**Used for:** tmux, ghostty, nvim, lazygit, hammerspoon, gh-dash.

| Tool        | Local override                | Mechanism                                         |
| ----------- | ----------------------------- | ------------------------------------------------- |
| tmux        | `~/.config/tmux/local.conf`   | `source-file -q` at end of config                 |
| ghostty     | `~/.config/ghostty/local`     | `config-file =` at end of config                  |
| nvim        | `~/.config/nvim/local.lua`    | `dofile(local_config)` in init.lua                |
| lazygit     | `~/.config/lazygit/local.yml` | `LG_CONFIG_FILE="base,local"` env var             |
| hammerspoon | `~/.hammerspoon/local.lua`    | `pcall(require, "local")` at end of init.lua      |
| gh-dash     | `~/.config/gh-dash/local.yml` | `yq` deep-merge after `dotfiles theme` generation |

### 3. Copy-on-install

Config is copied on first install, then becomes fully user-owned. Repo changes do
**not** propagate. If you improve a copy-on-install config, document the change in
`CHANGELOG.md` so users know to apply it manually.

**Used for:** btop, lazydocker's `config.yml`, karabiner, zshrc, zed's
`settings.json`, and the secrets file (`zsh/secrets.zsh.template` ->
`~/.config/zsh/secrets.zsh`, mode 600, created by `install.sh`).

### Outside the three patterns

- **`.luarc.json`** (lua_ls workspace config) is copied from
  `.luarc.json.template` to the repo root on every install run, overwriting the
  previous copy. Edit the template. See `.claude/rules/neovim.md`.
- **keyd** (Linux, `full` preset): `scripts/install/setup-keyd.sh` copies
  `keyd/default.conf` to `/etc/keyd/default.conf` with `sudo cp` on every run,
  overwriting it. A repo edit propagates on the next install run; a manual edit
  to the installed file does not survive one.

### Local layer sync (optional)

The user-owned local layer (patterns 2 and 3 above, plus `~/.zshrc` and
personal launchers) can be synced across a user's own machines via a private
git repo (`dotfiles local` / `export` / `import`).
The public repo never references it; the link is a machine-local pointer at
`~/.config/dotfiles/local-repo` (env override: `DOTFILES_LOCAL_DIR`). Logic
lives in `scripts/_lib/local-layer.sh`. The synced files are the manifest rows
with a local key; a `sync` row carries a purely-personal file the installer
never touches (e.g. `~/.ai/claude/CLAUDE.local.md`).
Secrets (`~/.config/zsh/secrets.zsh`), `.state/`, the saved preset file, and
the `current-theme` pointer are hard-excluded and must stay that way: theme is a
per-machine choice, so it is never synced. The `.gitignore` seeded into the
local repo also lists `statusline-theme.sh`. Launcher pruning on `import` is gated behind
`--prune` (not `--force`), so a launcher created on one machine survives an
overwrite import on another.

**For agents:** a private local-layer repo may exist on this machine (default
`~/.dotfiles-local`, or wherever `~/.config/dotfiles/local-repo` /
`DOTFILES_LOCAL_DIR` points). It holds the user's own copies of the local-override
and copy-on-install files and is **not** part of this public repo, so it won't show
up in `git status` here. Don't assume it exists or edit it as part of a change to
this repo; if you need to inspect or open it, `dotfiles local status` reports whether
one is configured and `dotfiles local edit` opens it in `$EDITOR`.

## Change Guidelines

- **Don't change aliases or keybindings without asking.** They reflect personal preference, not bugs. An alias that looks "wrong" (e.g. `gds="git diff --stat"` instead of `--staged`) is intentional.
- **ZLE widgets and tmux keybindings are interactive code.** Don't extract or refactor them mechanically -- they have specific requirements around terminal I/O, fzf integration, and prompt redrawing that can't be verified by reading alone.
