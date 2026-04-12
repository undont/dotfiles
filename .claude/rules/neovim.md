---
paths:
  - "nvim/**/*.lua"
  - "nvim/**"
---

# Neovim Configuration

Based on kickstart.nvim with modular organisation:
- `lua/custom/core/`: autocmds.lua, build.lua, diff-highlights.lua, keymaps.lua, options.lua, theme.lua
- `lua/custom/plugins/`: init.lua, ui.lua, lsp.lua, completion.lua, telescope.lua, editor.lua, copilot.lua, git.lua, pr-review.lua, dotnet.lua, test.lua, markdown-ui.lua, codecompanion.lua, claude-prompt.lua
- `lua/kickstart/plugins/`: neo-tree.lua, gitsigns.lua, autopairs.lua, debug.lua, lint.lua, indent_line.lua

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
