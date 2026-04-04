# Neovim Configuration

Customised Neovim setup based on [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) with modular plugin configuration and extended features.

## Features

- **Modular Structure** - Organised into `lua/custom/core/` and `lua/custom/plugins/`
- **LSP Support** - Language servers via Mason with auto-configuration
- **Completion** - Fast completion with blink.cmp and snippets
- **AI Assistance** - GitHub Copilot inline suggestions + CodeCompanion chat/inline/actions (Anthropic & Copilot)
- **Git Integration** - LazyGit for git operations, gitsigns for inline decorations
- **PR Review** - Octo.nvim for GitHub PRs, diffview for side-by-side diffs
- **.NET Development** - easy-dotnet.nvim for project management with Roslyn LSP
- **Fuzzy Finding** - Telescope for files, buffers, grep, and more
- **File Explorer** - Neo-tree sidebar navigation
- **Navigation** - Flash.nvim for jump/motion, treesitter textobjects for structural selection
- **Search & Replace** - Grug-far for project-wide search and replace
- **Diagnostics** - Trouble.nvim for better diagnostics lists
- **File Editing** - Oil.nvim for filesystem-as-buffer editing
- **UI Enhancements** - Auto dark/light mode (Dracula/Catppuccin), statusline, indent guides
- **Debugging** - DAP integration for debugging support
- **Formatting & Linting** - Conform for formatting, nvim-lint for linting
- **Spellcheck** - Built-in spell with en_gb, camelCase support, Telescope suggestions, and layered dictionaries (user + repo)

## Installation

This configuration is part of the dotfiles repository and is symlinked during installation:

```bash
# From dotfiles root
./install.sh

# Or manually symlink
ln -sf ~/dotfiles/nvim ~/.config/nvim
```

### First Launch

**Prerequisites:** Neovim >= 0.11, `tree-sitter-cli` (`brew install tree-sitter-cli`)

On first launch, lazy.nvim will automatically:
1. Install itself (bootstrapped by `lazy-bootstrap.lua`)
2. Install all configured plugins
3. Compile treesitter parsers (requires `tree-sitter` CLI)
4. Set up Mason for LSP servers

This may take a few minutes. Press `Space` to see lazy.nvim status.

## File Structure

```
nvim/
├── init.lua                           # Entry point - loads core config and plugins
├── colors/                            # 15 self-contained colourschemes (no plugin deps)
├── cheatsheet.txt                     # Custom cheatsheet for Space ? (searchable)
├── snippets/                          # Custom LuaSnip snippets
│   └── all.lua                        # Snippets available in all filetypes
└── lua/
    ├── custom/                        # Custom configuration
    │   ├── core/
    │   │   ├── options.lua            # Neovim options (line numbers, tabs, etc.)
    │   │   ├── keymaps.lua            # Custom keybindings
    │   │   ├── autocmds.lua           # Autocommands (highlighting on yank, etc.)
    │   │   ├── theme.lua              # Theme integration (file watcher, auto-reload)
    │   │   ├── quickfix.lua           # Build picker and quickfix helpers
    │   │   └── diff-highlights.lua    # Dynamic diff/gitsigns tinted backgrounds
    │   ├── plugins/
    │   │   ├── init.lua               # Plugin loader
    │   │   ├── ui.lua                 # Theme, statusline, which-key, todo-comments, noice
    │   │   ├── lsp.lua                # LSP configuration, Mason, conform (formatting)
    │   │   ├── completion.lua         # blink.cmp completion setup
    │   │   ├── telescope.lua          # Fuzzy finder configuration
    │   │   ├── editor.lua             # Treesitter, flash, textobjects, grug-far, oil, dial, smart-paste
    │   │   ├── copilot.lua            # GitHub Copilot integration
    │   │   ├── git.lua                # Git plugins (LazyGit)
    │   │   ├── pr-review.lua          # PR review (diffview, octo)
    │   │   ├── dotnet.lua             # .NET development (easy-dotnet)
    │   │   ├── test.lua               # Test runner (neotest)
    │   │   ├── markdown-ui.lua        # Markdown editing (mkdnflow) + browser preview
    │   │   ├── codecompanion.lua      # AI chat, inline assist, actions (Anthropic/Copilot)
    │   │   ├── claude-prompt.lua      # Claude prompt file utilities
    │   │   └── discord.lua            # Discord Rich Presence (cord.nvim)
    │   └── lazy-bootstrap.lua         # Lazy.nvim auto-installer
    └── kickstart/                     # Kickstart-provided plugins
        ├── health.lua                 # Health checks
        └── plugins/
            ├── neo-tree.lua           # File explorer
            ├── gitsigns.lua           # Git signs in gutter
            ├── autopairs.lua          # Disabled (using mini.pairs)
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
| Custom colourschemes (`nvim/colors/`) | 15 themes matching dotfiles theme system |
| [auto-dark-mode.nvim](https://github.com/f-person/auto-dark-mode.nvim) | Follows system theme |
| [mini.nvim](https://github.com/echasnovski/mini.nvim) | Statusline, surround, bracketed navigation, splitjoin, pairs, hipatterns |
| [nvim-notify](https://github.com/rcarriga/nvim-notify) | Notification manager with LSP progress routing |
| [indent-blankline](https://github.com/lukas-reineke/indent-blankline.nvim) | Indent guides |
| [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim) | File explorer sidebar |
| [which-key.nvim](https://github.com/folke/which-key.nvim) | Tiered keybinding popup — context groups shown by filetype |
| [cheatsheet.nvim](https://github.com/sudormrfbin/cheatsheet.nvim) | Searchable keybinding/command cheatsheet |
| [todo-comments.nvim](https://github.com/folke/todo-comments.nvim) | Highlight TODO/FIXME comments |
| [trouble.nvim](https://github.com/folke/trouble.nvim) | Better diagnostics list and quickfix |

### Editing & Navigation

| Plugin | Purpose |
|--------|---------|
| [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) | Fuzzy finder (files, buffers, grep) |
| [mini.bufremove](https://github.com/echasnovski/mini.bufremove) | Delete buffers without closing windows |
| [flash.nvim](https://github.com/folke/flash.nvim) | Jump/motion with search labels |
| [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects) | Structural selection and motion |
| [grug-far.nvim](https://github.com/MagicDuck/grug-far.nvim) | Project-wide search and replace |
| [oil.nvim](https://github.com/stevearc/oil.nvim) | Filesystem-as-buffer editing |
| [vim-visual-multi](https://github.com/mg979/vim-visual-multi) | Multiple cursors (`Ctrl+n`, `Alt+Down/Up`) |
| [smart-paste.nvim](https://github.com/nemanjamalesija/smart-paste.nvim) | Auto-adjust indentation when pasting |
| [dial.nvim](https://github.com/monaqa/dial.nvim) | Enhanced increment/decrement (dates, semver, booleans) |
| [tailwindcss-dial.nvim](https://github.com/ruicsh/tailwindcss-dial.nvim) | Cycle Tailwind CSS classes with Ctrl+a/Ctrl+x |
| [guess-indent.nvim](https://github.com/NMAC427/guess-indent.nvim) | Auto-detect indentation |
| [lazydev.nvim](https://github.com/folke/lazydev.nvim) | Lua development for Neovim |
| [noice.nvim](https://github.com/folke/noice.nvim) | Enhanced LSP hover and signature help rendering |


### Git Integration

| Plugin | Purpose |
|--------|---------|
| [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) | Git decorations and hunks |
| [lazygit.nvim](https://github.com/kdheepak/lazygit.nvim) | LazyGit integration |

### PR Review & Diff

| Plugin | Purpose |
|--------|---------|
| [diffview.nvim](https://github.com/sindrets/diffview.nvim) | Side-by-side diff tab, file history, merge conflicts, `]f`/`[f` file navigation |
| [octo.nvim](https://github.com/pwntester/octo.nvim) | GitHub PR review with side-by-side diffs |

### .NET Development

| Plugin | Purpose |
|--------|---------|
| [easy-dotnet.nvim](https://github.com/GustavEikaas/easy-dotnet.nvim) | .NET project management (build, run, secrets, watch) |

### Markdown

| Plugin | Purpose |
|--------|---------|
| [mkdnflow.nvim](https://github.com/jakewvincent/mkdnflow.nvim) | List continuation, todo toggles, table formatting |
| [markdown-preview.nvim](https://github.com/iamcco/markdown-preview.nvim) | Live browser preview with KaTeX, Mermaid, PlantUML |

### Testing

| Plugin | Purpose |
|--------|---------|
| [neotest](https://github.com/nvim-neotest/neotest) | Test runner framework with summary panel and diagnostics |
| [easy-dotnet.nvim](https://github.com/GustavEikaas/easy-dotnet.nvim) | .NET test runner with gutter signs, debug, and explorer UI |
| [neotest-golang](https://github.com/fredrikaverpil/neotest-golang) | Go adapter (v2+) |
| [neotest-vitest](https://github.com/marilari88/neotest-vitest) | Vitest/Bun adapter (`bun run test`) |

### Debugging

| Plugin | Purpose |
|--------|---------|
| [nvim-dap](https://github.com/mfussenegger/nvim-dap) | Debug Adapter Protocol client |
| [nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui) | Debugger UI (scopes, stacks, watches, REPL, console) |
| [nvim-dap-virtual-text](https://github.com/theHamsta/nvim-dap-virtual-text) | Inline variable values next to code |
| [nvim-dap-go](https://github.com/leoluz/nvim-dap-go) | Go debug configs via Delve |
| [mason-nvim-dap](https://github.com/jay-babu/mason-nvim-dap.nvim) | Auto-installs debug adapters (Delve, netcoredbg) |

### Media

| Plugin | Purpose |
|--------|---------|
| [music.nvim](https://github.com/seanhalberthal/music.nvim) | Now playing indicator (Apple Music, Spotify) |

### Social

| Plugin | Purpose |
|--------|---------|
| [cord.nvim](https://github.com/vyfor/cord.nvim) | Discord Rich Presence with catppuccin theme |

### AI & Development

| Plugin | Purpose |
|--------|---------|
| [copilot.lua](https://github.com/zbirenbaum/copilot.lua) | GitHub Copilot completion via blink.cmp |
| [codecompanion.nvim](https://github.com/olimorris/codecompanion.nvim) | AI chat, inline editing, actions (Anthropic/Copilot) |
| [nvim-lint](https://github.com/mfussenegger/nvim-lint) | Linting framework |
| [nvim-dap](https://github.com/mfussenegger/nvim-dap) | Debug Adapter Protocol |

## Keybindings

### Quick Reference

Press **`Space ?`** in normal mode to open the searchable cheatsheet.

### Essential Keybindings

| Mode | Keybinding | Action |
|------|------------|--------|
| Normal | `Space ?` | Open searchable cheatsheet |
| Normal | `Space Space` | Find existing buffers |
| Normal | `Space sf` | Search files (Telescope) |
| Normal | `Space sg` | Search by grep (Telescope) |
| Normal | `Space /` | Fuzzy search in current buffer |
| Normal | `grd` | Go to definition (LSP) |
| Normal | `grr` | Go to references (LSP) |
| Normal | `grn` | Rename symbol (LSP) |
| Normal | `gra` | Code action (LSP) |
| Normal | `grf` | Fix all diagnostics in file (LSP) |
| Normal | `K` | Hover documentation (LSP) |
| Normal | `m` / `M` | First non-blank / end of line (`^`/`$`) |
| Normal | `gm` | Set mark (original `m`) |
| Normal | `Space e` | Toggle file explorer (Neo-tree) |
| Normal | `Space g` | Open LazyGit |
| Normal | `Space z` | Zoom toggle (tab split/close) |
| Normal | `Space f` | Format buffer |
| Insert | `Ctrl+Space` | Trigger completion |
| Insert | `Tab` | Smart accept (Copilot suggestion if visible, else completion) |
| Normal | `Space ac` | AI chat toggle (CodeCompanion) |
| Normal | `Space ai` | AI inline assist |
| Normal | `Space aa` | AI action palette |
| Normal | `Space mp` | Markdown preview in browser |
| Normal | `Space St` | Toggle spellcheck |
| Normal | `Space Ss` | Spell suggest corrections (Telescope) |
| Normal | `Space Sa` | Add word to dictionary |
| Normal | `Space Sr` | Remove word from dictionary |
| Normal | `Space Sd` | Edit personal dictionary |

**Full keybinding reference**: Press `Space ?` or see `lua/custom/core/keymaps.lua`

## Testing & Debugging

### Running Tests (neotest)

All languages use the same keybindings via neotest:

| Keybinding | Action |
|------------|--------|
| `Space tt` | Run nearest test |
| `Space tf` | Run all tests in file |
| `Space ta` | Run entire test suite |
| `Space tl` | Re-run last test |
| `Space ts` | Toggle test summary panel |
| `Space to` | Show test output |
| `Space tO` | Toggle output panel |
| `Space tS` | Stop running test |
| `Space tw` | Toggle file watch (re-runs on save) |
| `]t` / `[t` | Jump to next/prev failed test |

### Debugging

#### Breakpoints

Set breakpoints before starting a debug session. They appear as icons in the sign column.

| Keybinding | Action |
|------------|--------|
| `Space bb` | Toggle breakpoint |
| `Space bc` | Conditional breakpoint (prompts for expression) |
| `Space bL` | Logpoint (logs message without stopping) |
| `Space bl` | List all breakpoints (editable float) |

#### Stepping

| Keybinding | Action |
|------------|--------|
| `F5` | Start debug session / Continue to next breakpoint |
| `F1` | Step into |
| `F2` | Step over |
| `F3` | Step out |
| `F7` | Toggle debug UI panels |

#### Debug UI Layout

When a debug session starts, the UI opens automatically:

- **Left sidebar** — Scopes (variable inspection), Stacks (call stack), Breakpoints, Watches
- **Bottom panel** — REPL (evaluate expressions) and Console (debugger output)
- **Inline virtual text** — Variable values displayed next to code as comments

Expand variables in the Scopes panel with `Enter`. Type expressions in the REPL panel to evaluate them at the current breakpoint.

#### Go

1. Set breakpoints in your code (`Space bb`)
2. Navigate to a `main.go` or test file
3. `F5` → select "Debug" (for main) or "Debug test" (for nearest test)
4. `Space td` also works for debugging the nearest test via neotest

#### C# / .NET

**Debugging a project:**

1. Set breakpoints in your code (`Space bb`)
2. `Space nd` (`:Dotnet debug`) → pick the project to debug
3. easy-dotnet builds, finds the DLL, and launches netcoredbg

**Debugging tests:**

1. Set breakpoints in the code under test (`Space bb`)
2. `Space nd` → pick the **test project**
3. The debugger attaches and hits your breakpoints

> **Note:** .NET tests use easy-dotnet.nvim's built-in test runner (not neotest).
> Use `Space tr` to run a test from the buffer, `Space td` to debug, and
> `Space te` to open the test explorer. Gutter signs show pass/fail status.
> Use `Space tt` to run individual tests without debugging.

#### .NET Keybindings

| Keybinding | Action |
|------------|--------|
| `Space nd` | Debug project |
| `Space nr` | Run project |
| `Space nb` | Build project |
| `Space nc` | Clean project |
| `Space ns` | Manage secrets |
| `Space nw` | Watch project |
| `Space nn` | New item |
| `Space no` | Outdated packages |
| `Space ni` | Add missing imports (solution) |

## LSP Servers

LSP servers are managed by Mason. The following are configured:

- **Bash** - bashls
- **C/C++** - clangd
- **C#** - Roslyn via roslyn.nvim (replaces OmniSharp)
- **CSS** - cssls
- **Go** - gopls
- **HTML** - html
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
- Roslyn LSP (C# — uses `.editorconfig` rules via `lsp_format = 'fallback'`)

**Linters:**
- ESLint via LSP (JavaScript/TypeScript)
- golangci-lint (Go)

### Installing Additional LSP Servers

```vim
:Mason
```

Search and install servers from the Mason UI, or add them to `lua/custom/plugins/lsp.lua`.

## Customisation

### Personal Overrides

`~/.config/nvim/local.lua` is your personal override file — loaded after all plugins so your settings take priority. It is created from a template on first install and never overwritten by `dotfiles update`.

Use it for cursor style, personal keymaps, option overrides, or any other local settings. After editing, reload with `prefix + r` (in tmux).

### Changing Colourscheme

Themes are managed by the dotfiles theme system. Run `dotfiles theme <theme>` to change — Neovim picks up the colourscheme automatically from `nvim/colors/`. No plugin installation needed.

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

- **Neovim >= 0.11** - Earlier versions not supported
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
