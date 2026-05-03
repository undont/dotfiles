---
paths:
  - "nvim/**/*.lua"
  - "nvim/**"
---

# Neovim Configuration

Based on kickstart.nvim with modular organisation:
- `lua/custom/core/`: autocmds.lua, build.lua, diff-highlights.lua, folding.lua, keymaps.lua, lists.lua, macos-nav.lua, options.lua, refresh.lua, scan_runner.lua, spellcheck.lua, tag-rename.lua, theme.lua, windows.lua
- `lua/custom/plugins/`: init.lua, buffers.lua, claude-prompt.lua, codecompanion.lua, completion.lua, copilot.lua, dashboard.lua, dial.lua, dotnet.lua, git.lua, lsp.lua, markdown-ui.lua, mini.lua, multi-cursor.lua, music.lua, navigation.lua, obsidian.lua, paste.lua, pr-review.lua, search.lua, sonarlint.lua, telescope.lua, test.lua, tpope.lua, treesitter.lua, ui.lua
- `lua/kickstart/plugins/`: neo-tree.lua, gitsigns.lua, autopairs.lua, debug.lua, lint.lua, indent_line.lua

`core/keymaps.lua` is a slim entry point: it defines a few fundamental
editing tweaks (`<Esc>` hl-clear, `dd`/`dy`, smart `i`/`a`, `m`/`M`/`gm`
line nav, terminal escape, `<leader>by`/`<leader>e`/`<leader>g`/`<leader>u`)
and then calls `setup()` on the focused core modules (folding, lists,
windows, macos-nav, refresh, spellcheck, build). Each focused module owns
its own keymaps — add new ones where they belong rather than letting
`keymaps.lua` regrow into a grab-bag.

## lua_ls Workspace Config (`.luarc.json`)

`.luarc.json` at the repo root is the authoritative config for lua-language-server — it
overrides anything set via `vim.lsp.config` in lua. It declares custom globals (`Snacks`,
`MiniIcons`, etc.), disables noisy diagnostic categories, and points `workspace.library`
at the neovim runtime so hover/completion works for `vim.keymap.set`, `vim.api.*`, etc.

The file is **gitignored** because `workspace.library` contains an absolute path that
differs by OS/install (`/opt/homebrew/...` vs `/usr/share/...`). It is generated from
`.luarc.json.template` during `dotfiles install` / `dotfiles update` by
`scripts/install/create-symlinks.sh`, which detects the current VIMRUNTIME via
`nvim --clean --headless` and substitutes the `{{NVIM_RUNTIME_LUA}}` placeholder. To edit
the workspace config, update the template — the generated file will be refreshed on the
next install run.

## Linting

```bash
luacheck nvim/lua/ --config nvim/.luacheckrc
```
