# Neovim Configuration

Customised Neovim setup based on [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) with modular plugin configuration and extended features.

## Features

- **Modular Structure** - Organised into `lua/custom/core/` and `lua/custom/plugins/`
- **LSP Support** - Language servers via Mason with auto-configuration
- **Completion** - Fast completion with blink.cmp and snippets
- **AI Assistance** - GitHub Copilot integration
- **Git Integration** - LazyGit for git operations, gitsigns for inline decorations
- **PR Review** - Octo.nvim for GitHub PRs, diffview for side-by-side diffs, difi for inline overlays
- **Fuzzy Finding** - Telescope for files, buffers, grep, and more
- **File Explorer** - Neo-tree sidebar navigation
- **UI Enhancements** - Auto dark/light mode (Dracula/Catppuccin), statusline, indent guides
- **Debugging** - DAP integration for debugging support
- **Formatting & Linting** - Conform for formatting, nvim-lint for linting

## Installation

This configuration is part of the dotfiles repository and is symlinked during installation:

```bash
# From dotfiles root
./install.sh

# Or manually symlink
ln -sf ~/dotfiles/nvim ~/.config/nvim
```

### First Launch

On first launch, lazy.nvim will automatically:
1. Install itself (bootstrapped by `lazy-bootstrap.lua`)
2. Install all configured plugins
3. Set up Mason for LSP servers

This may take a few minutes. Press `Space` to see lazy.nvim status.

## File Structure

```
nvim/
├── init.lua                           # Entry point - loads core config and plugins
├── cheatsheet.txt                     # Custom cheatsheet for Space ? (searchable)
├── snippets/                          # Custom LuaSnip snippets
│   └── all.lua                        # Snippets available in all filetypes
└── lua/
    ├── custom/                        # Custom configuration
    │   ├── core/
    │   │   ├── options.lua            # Neovim options (line numbers, tabs, etc.)
    │   │   ├── keymaps.lua            # Custom keybindings and help popup
    │   │   └── autocmds.lua           # Autocommands (highlighting on yank, etc.)
    │   ├── plugins/
    │   │   ├── init.lua               # Plugin loader
    │   │   ├── ui.lua                 # Theme, statusline, which-key, todo-comments
    │   │   ├── lsp.lua                # LSP configuration, Mason, conform (formatting)
    │   │   ├── completion.lua         # blink.cmp completion setup
    │   │   ├── telescope.lua          # Fuzzy finder configuration
    │   │   ├── editor.lua             # Treesitter, guess-indent
    │   │   ├── copilot.lua            # GitHub Copilot integration
    │   │   ├── git.lua                # Git plugins (gitsigns, LazyGit)
    │   │   ├── pr-review.lua          # PR review (diffview, octo, difi)
    │   │   └── markdown-ui.lua        # Markdown editing (mkdnflow)
    │   ├── lazy-bootstrap.lua         # Lazy.nvim auto-installer
    │   └── nvim-help.txt              # Help popup content
    └── kickstart/                     # Kickstart-provided plugins
        ├── health.lua                 # Health checks
        └── plugins/
            ├── neo-tree.lua           # File explorer
            ├── gitsigns.lua           # Git signs in gutter
            ├── autopairs.lua          # Auto-close brackets
            ├── indent_line.lua        # Indent guides
            ├── debug.lua              # DAP debugging
            └── lint.lua               # Linting support
```

## Plugins

### Core Functionality

| Plugin | Purpose |
|--------|---------|
| [lazy.nvim](https://github.com/folke/lazy.nvim) | Plugin manager |
| [mason.nvim](https://github.com/williamboman/mason.nvim) | LSP/DAP/linter installer |
| [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) | LSP client configurations |
| [blink.cmp](https://github.com/saghen/blink.cmp) | Fast completion engine |
| [LuaSnip](https://github.com/L3MON4D3/LuaSnip) | Snippet engine with custom snippets |
| [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) | Syntax highlighting and parsing |
| [conform.nvim](https://github.com/stevearc/conform.nvim) | Code formatting |

### UI & Appearance

| Plugin | Purpose |
|--------|---------|
| [dracula.nvim](https://github.com/Mofiqul/dracula.nvim) | Dark colourscheme |
| [catppuccin](https://github.com/catppuccin/nvim) | Light colourscheme (latte variant) |
| [auto-dark-mode.nvim](https://github.com/f-person/auto-dark-mode.nvim) | Follows system theme |
| [mini.nvim](https://github.com/echasnovski/mini.nvim) | Statusline, surround, ai textobjects |
| [indent-blankline](https://github.com/lukas-reineke/indent-blankline.nvim) | Indent guides |
| [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim) | File explorer sidebar |
| [which-key.nvim](https://github.com/folke/which-key.nvim) | Keybinding popup hints |
| [cheatsheet.nvim](https://github.com/sudormrfbin/cheatsheet.nvim) | Searchable keybinding/command cheatsheet |
| [todo-comments.nvim](https://github.com/folke/todo-comments.nvim) | Highlight TODO/FIXME comments |

### Editing & Navigation

| Plugin | Purpose |
|--------|---------|
| [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) | Fuzzy finder (files, buffers, grep) |
| [nvim-autopairs](https://github.com/windwp/nvim-autopairs) | Auto-close brackets and quotes |
| [guess-indent.nvim](https://github.com/NMAC427/guess-indent.nvim) | Auto-detect indentation |
| [lazydev.nvim](https://github.com/folke/lazydev.nvim) | Lua development for Neovim |
| [fidget.nvim](https://github.com/j-hui/fidget.nvim) | LSP progress indicator |

### Git Integration

| Plugin | Purpose |
|--------|---------|
| [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) | Git decorations and hunks |
| [lazygit.nvim](https://github.com/kdheepak/lazygit.nvim) | LazyGit integration |

### PR Review & Diff

| Plugin | Purpose |
|--------|---------|
| [diffview.nvim](https://github.com/sindrets/diffview.nvim) | Side-by-side diff tab, file history, merge conflicts |
| [octo.nvim](https://github.com/pwntester/octo.nvim) | GitHub PR review from Neovim (list, comment, approve) |
| [difi.nvim](https://github.com/oug-t/difi.nvim) | Inline diff overlay |

### Markdown

| Plugin | Purpose |
|--------|---------|
| [mkdnflow.nvim](https://github.com/jakewvincent/mkdnflow.nvim) | List continuation, todo toggles, table formatting |

### AI & Development

| Plugin | Purpose |
|--------|---------|
| [copilot.vim](https://github.com/github/copilot.vim) | GitHub Copilot integration |
| [nvim-lint](https://github.com/mfussenegger/nvim-lint) | Linting framework |
| [nvim-dap](https://github.com/mfussenegger/nvim-dap) | Debug Adapter Protocol |

## Keybindings

### Quick Reference

Press **`Space h`** in normal mode to open the keybinding help popup.

### Essential Keybindings

| Mode | Keybinding | Action |
|------|------------|--------|
| Normal | `Space h` | Show keybinding help popup |
| Normal | `Space ?` | Open searchable cheatsheet |
| Normal | `Space Space` | Find existing buffers |
| Normal | `Space sf` | Search files (Telescope) |
| Normal | `Space sg` | Search by grep (Telescope) |
| Normal | `Space /` | Fuzzy search in current buffer |
| Normal | `grd` | Go to definition (LSP) |
| Normal | `grr` | Go to references (LSP) |
| Normal | `grn` | Rename symbol (LSP) |
| Normal | `gra` | Code action (LSP) |
| Normal | `K` | Hover documentation (LSP) |
| Normal | `Space e` | Toggle file explorer (Neo-tree) |
| Normal | `Space g` | Open LazyGit |
| Normal | `Space f` | Format buffer |
| Insert | `Ctrl+Space` | Trigger completion |
| Insert | `Tab` | Accept Copilot suggestion |

**Full keybinding reference**: Press `Space h` or see `lua/custom/core/keymaps.lua`

## LSP Servers

LSP servers are managed by Mason. The following are configured:

- **Bash** - bashls
- **C/C++** - clangd
- **C#** - omnisharp
- **CSS** - cssls
- **Go** - gopls
- **HTML** - html
- **JSON** - jsonls
- **Lua** - lua_ls (with Neovim API support)
- **Python** - pyright
- **JavaScript/TypeScript** - ts_ls
- **YAML** - yamlls

### Formatters & Linters

The following formatters and linters are automatically installed:

**Formatters:**
- stylua (Lua)
- prettier (JS/TS/JSON/YAML)
- goimports + gofmt (Go)
- csharpier (C#)

**Linters:**
- eslint_d (JavaScript/TypeScript)
- golangci-lint (Go)

### Installing Additional LSP Servers

```vim
:Mason
```

Search and install servers from the Mason UI, or add them to `lua/custom/plugins/lsp.lua`.

## Customisation

### Changing Colourscheme

Edit `lua/custom/plugins/ui.lua` to modify the auto-dark-mode settings or set a fixed theme:

```lua
-- For a fixed theme (disable auto-dark-mode first)
vim.cmd.colorscheme 'dracula'     -- Dark theme
vim.cmd.colorscheme 'catppuccin-latte'  -- Light theme
```

### Adding Keybindings

Edit `lua/custom/core/keymaps.lua` and add your keybindings:

```lua
-- Example: Add custom keybinding
vim.keymap.set('n', '<leader>w', '<cmd>write<cr>', { desc = '[W]rite file' })
```

### Adding Plugins

Create a new file in `lua/custom/plugins/` or add to an existing one:

```lua
-- lua/custom/plugins/your-plugin.lua
return {
  'author/plugin-name',
  config = function()
    -- Plugin configuration here
  end,
}
```

Restart Neovim and lazy.nvim will automatically install the new plugin.

## Dependencies

### Required

- **Neovim >= 0.9** - Earlier versions not supported
- **Git** - For lazy.nvim plugin management
- **Node.js** - For Copilot and some LSP servers
- **Ripgrep** - For Telescope live grep (`brew install ripgrep`)
- **fd** - For Telescope file finder (`brew install fd`)
- **make** - For building telescope-fzf-native
- **LazyGit** - For git UI (`brew install lazygit`)

### Optional but Recommended

- **Nerd Font** - For icons and glyphs (already configured in terminal)
- **Clipboard tool** - `pbcopy`/`pbpaste` (macOS) or `xclip` (Linux)

## Troubleshooting

### Plugins Not Installing

1. Ensure you have an internet connection
2. Check lazy.nvim status: `:Lazy`
3. Manually sync: `:Lazy sync`

### LSP Not Working

1. Check if server is installed: `:Mason`
2. Check LSP status: `:LspInfo`
3. View LSP logs: `:LspLog`

### Copilot Not Working

1. Authenticate: `:Copilot auth`
2. Check status: `:Copilot status`
3. Ensure Node.js is installed: `node --version`

### Copilot Suggestions Hard to See

If Copilot suggestions blend in too much with your code, run `:CopilotHighlightFix` to apply custom highlighting. The suggestions will appear in italic with a subdued colour matching your theme's comment style.

### LazyGit Not Opening

1. Ensure lazygit is installed: `lazygit --version`
2. Install if missing: `brew install lazygit`

### Slow Startup

Run `:Lazy profile` to identify slow plugins. Consider:
- Lazy-loading plugins
- Disabling unused plugins
- Checking autocommands in `lua/custom/core/autocmds.lua`

## Resources

- [Neovim Documentation](https://neovim.io/doc/)
- [Kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) - Base configuration
- [Lazy.nvim](https://github.com/folke/lazy.nvim) - Plugin manager docs
- [Mason.nvim](https://github.com/williamboman/mason.nvim) - LSP installer
- [Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) - Fuzzy finder

## Credits

Based on [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) by TJ DeVries.
