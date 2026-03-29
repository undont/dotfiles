---
paths:
  - "nvim/**/*.lua"
  - "nvim/**"
---

# Neovim Configuration

Based on kickstart.nvim with modular organisation:
- `lua/custom/core/`: autocmds.lua, build.lua, diff-highlights.lua, keymaps.lua, options.lua, theme.lua
- `lua/custom/plugins/`: init.lua, ui.lua, lsp.lua, completion.lua, telescope.lua, editor.lua, copilot.lua, git.lua, pr-review.lua, dotnet.lua, test.lua, markdown-ui.lua, codecompanion.lua, claude-prompt.lua, discord.lua
- `lua/kickstart/plugins/`: neo-tree.lua, gitsigns.lua, autopairs.lua, debug.lua, lint.lua, indent_line.lua

## Linting

```bash
luacheck nvim/lua/ --config nvim/.luacheckrc
```
