# CLAUDE.md

Personal dotfiles for macOS/Linux development environment. Manages configuration for zsh, tmux, neovim, hammerspoon, ghostty, and karabiner.

## Quick Reference

```bash
make              # Show all available targets
make test         # Run all tests
make lint         # Run all linters (shell + lua)
```

## Config Ownership Patterns

Three patterns are used for configuration files. Choose based on whether the tool
supports a local override mechanism and how personal the config tends to be.

### 1. Symlinked

Config lives in the repo. The installed path is a symlink. Changes committed to
the repo propagate on next `dotfiles update`.

**Used for:** zprofile, tmux scripts, nvim plugins, launchers, the statusline
theme resolver (`scripts/_lib/statusline-theme.sh` -> `~/.config/dotfiles/statusline-theme.sh`).

yazi is symlinked **per file** (`yazi/yazi.toml`, `yazi/keymap.toml` ->
`~/.config/yazi/`), not as a whole directory, so theme-switch can write a
generated `~/.config/yazi/theme.toml` alongside without it landing back in the
repo. The 0.2.109 migration converts older whole-dir symlinks. See the theme
flavour note under Layered + the theme system.

### 2. Layered (symlink + local override)

Base config is symlinked, but the tool also loads a user-owned local file on top.
The local file is created from a `*.template` on first install and never
overwritten by `dotfiles update`.

**Used for:** tmux, ghostty, nvim, lazygit, hammerspoon, gh-dash.

| Tool | Local override | Mechanism |
|---|---|---|
| tmux | `~/.config/tmux/local.conf` | `source-file -q` at end of config |
| ghostty | `~/.config/ghostty/local` | `config-file =` at end of config |
| nvim | `~/.config/nvim/local.lua` | `dofile(local_config)` in init.lua |
| lazygit | `~/.config/lazygit/local.yml` | `LG_CONFIG_FILE="base,local"` env var |
| hammerspoon | `~/.hammerspoon/local.lua` | `pcall(require, "local")` at end of init.lua |
| gh-dash | `~/.config/gh-dash/local.yml` | `yq` deep-merge after `dotfiles theme` generation |

### 3. Copy-on-install

Config is copied on first install, then becomes fully user-owned. Repo changes do
**not** propagate. If you improve a copy-on-install config, document the change in
`CHANGELOG.md` so users know to apply it manually.

**Used for:** btop, lazydocker, karabiner, zshrc.

## Change Guidelines

- **Don't change aliases or keybindings without asking.** They reflect personal preference, not bugs. An alias that looks "wrong" (e.g. `gds="git diff --stat"` instead of `--staged`) is intentional.
- **ZLE widgets and tmux keybindings are interactive code.** Don't extract or refactor them mechanically -- they have specific requirements around terminal I/O, fzf integration, and prompt redrawing that can't be verified by reading alone.
