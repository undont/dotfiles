---
paths:
  - "themes/**"
  - "scripts/theme-switch"
  - "scripts/generate-theme"
  - "scripts/theme-delete"
  - "scripts/theme-contrast-check"
  - "tmux/tmux.conf.template"
  - "ghostty/config.template"
  - "yazi/theme.toml.template"
---

# Theme System

Theme configuration follows XDG Base Directory standard to avoid git conflicts.

## Configuration Flow

1. `themes/*.theme` - Theme definitions (in repo)
2. `tmux/tmux.conf.template` - Tmux template with `{{PLACEHOLDERS}}` (in repo)
3. `ghostty/config.template` - Ghostty template with `{{PLACEHOLDERS}}` (in repo)
4. `~/.config/tmux/tmux.conf` - Generated config (XDG location)
5. `~/.tmux.conf` - Compatibility symlink -> `~/.config/tmux/tmux.conf`
6. `~/.config/ghostty/config` - Generated ghostty config (XDG location, read natively on all platforms)
7. `yazi/theme.toml.template` - Yazi theme template with `{{PLACEHOLDERS}}` (in repo); reuses the `{{TMUX_*}}` palette vars
8. `~/.config/yazi/theme.toml` - Generated yazi theme (XDG location). yazi is symlinked per-file (`yazi.toml`, `keymap.toml`) so the generated theme can sit alongside without being tracked. theme-switch skips generation if the dir is still a legacy whole-dir symlink (the 0.2.109 migration converts it).

## Local Override Files (user-owned, survive theme changes)

- `~/.config/ghostty/local` -- appended to Ghostty config via `config-file` include
- `~/.config/tmux/local.conf` -- sourced at end of tmux config via `source-file -q`
- `~/.config/nvim/local.lua` -- personal Neovim settings via `dofile()` (cursor, options, keymaps)
- `~/.config/gh-dash/local.yml` -- deep-merged on top of generated config via `yq`
- `~/.config/lazygit/local.yml` -- loaded via `LG_CONFIG_FILE` env var
- `~/.hammerspoon/local.lua` -- loaded via `pcall(require, "local")` at end of init.lua

These files are created from templates on first install and never overwritten by `dotfiles theme` or `dotfiles update`.

## Theme Commands

```bash
dotfiles theme generate <ghostty-theme>  # Generate theme from Ghostty built-in
dotfiles theme delete <theme-name>       # Delete a generated theme
```

See [docs/THEME-SYSTEM.md](docs/THEME-SYSTEM.md) for the full command reference, generation pipeline, and architecture details.
