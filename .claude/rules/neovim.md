---
paths:
  - "nvim/**/*.lua"
  - "nvim/**"
---

# Neovim Configuration

Based on kickstart.nvim with modular organisation. Three-way split: `core/` =
editor settings + fundamental behaviour with no plugin coupling; `features/` =
self-contained bespoke features (each owns its keymaps via `setup()`);
`plugins/` = thin lazy specs that `require('custom.features.X')`. Only
`lua/kickstart/plugins/` (lint.lua, indent_line.lua) still tracks upstream
kickstart; the diverged debug/neo-tree/gitsigns specs moved to
`custom/plugins/`.

`core/keymaps.lua` is a slim entry point: it defines a few fundamental
editing tweaks (`<Esc>` hl-clear, `<leader>v` paste-last-yank, smart `i`/`a`,
`m`/`M`/`gm` line nav, terminal escape,
`<leader>by`/`<leader>e`/`<leader>g`/`<leader>u`)
and then calls `setup()` on the focused modules: core (folding, windows,
macos-nav, refresh, spellcheck) and features (lists, build, binary-view).
Each focused module owns its own keymaps — add new ones where they belong
rather than letting `keymaps.lua` regrow into a grab-bag.

## lua_ls Workspace Config (`.luarc.json`)

`.luarc.json` at the repo root is the authoritative config for lua-language-server — it
overrides anything set via `vim.lsp.config` in lua. It sets `runtime.version` (LuaJIT) and
disables noisy diagnostic categories.

Type libraries (the neovim runtime plus plugin types like `Snacks` and `Mini*`) are **not**
listed here — they are supplied on demand by `lazydev.nvim`
(`lua/custom/plugins/lazydev.lua`), which loads each plugin's annotations when its trigger
word appears in a lua buffer, giving `K` hover and completion for those globals. This is
why `.luarc.json` must **not** declare `workspace.library`: lua_ls treats `.luarc.json` as
authoritative, so a static `workspace.library` would override the libraries lazydev pushes
through the client and break hover (lazydev's own README recommends disabling it when a
`.luarc.json` with a library is present). To add hover for another plugin, add a
`{ path = '<plugin>', words = { '<Global>' } }` entry in `lazydev.lua` — not a library path
here. Partial plugin-opts tables that trip `missing-fields` (e.g. `Snacks.dashboard.open`)
get an inline `---@diagnostic disable-next-line: missing-fields` at the call site rather
than a blanket disable, so the check still catches real omissions elsewhere.

The file is **gitignored** and installed from `.luarc.json.template` during
`dotfiles install` / `dotfiles update` by `scripts/install/create-symlinks.sh` (a plain
copy — there is no longer a machine-specific path to substitute). To change the workspace
config, edit the template; the active file is refreshed on the next install run.

## Linting

```bash
luacheck nvim/lua/ --config nvim/.luacheckrc
```
