---
paths:
  - "nvim/lua/custom/plugins/dotnet.lua"
---

# C# / Roslyn LSP — Architecture & Debugging

## Semantic Token Flow

Roslyn semantic tokens require careful orchestration on Neovim 0.12+. The setup
lives in `setup_semantic_token_fix()` in `dotnet.lua` and handles three issues:

### 1. Range request filtering

Neovim 0.12 added `textDocument/semanticTokens/range` (viewport-only tokens).
Roslyn dynamically registers range support via `client/registerCapability` AFTER
`on_init`, so modifying `server_capabilities` there doesn't stick. We intercept
the `client/registerCapability` handler and filter out range registrations for
roslyn. Without this, tokens flash then disappear as range responses replace
full-document responses.

**Why other approaches failed:**
- `on_init` with `caps.range = false` — roslyn re-registers range dynamically
- `LspAttach` — too late, semantic token handler already read capabilities
- Client `capabilities` override — shallow merge on `textDocument` wiped other
  capabilities (completion, hover, etc.), breaking LSP entirely

### 2. Token refresh on project init

Neovim requests tokens on attach (before the solution loads), gets empty/stale
tokens. Roslyn doesn't send `workspace/semanticTokens/refresh` when done loading.
We listen for the `RoslynInitialized` user event (fired by roslyn.nvim when
`workspace/projectInitializationComplete` arrives) and `force_refresh` all `.cs`
buffers.

### 3. Using directive fix

Roslyn misclassifies unresolved identifiers on `using` directives as `variable`
instead of `namespace`. An `LspTokenUpdate` autocmd overrides these to `@type`.

## Roslyn Deferred Loading

Roslyn's plugin file is blocked during startup (`vim.g.loaded_roslyn_plugin = true`
in `init`) to prevent `vim.lsp.enable` firing before `lock_target` and
`ignore_target` are configured. The loading sequence on first `.cs` file:

1. `resolve_solution_target()` — finds `.sln` via upward search
2. `vim.lsp.config('roslyn', ...)` — applies settings
3. `require('roslyn').setup(opts)` — stores roslyn.nvim config
4. `source_deferred_plugin()` — clears the block, `dofile(plugin/roslyn.lua)`
   which calls `vim.lsp.enable('roslyn')`

## Roslyn Suppress/Restore (Diffview & Octo)

Roslyn's solution analysis freezes navigation on large diffs. The suppress/restore
cycle:

- **Suppress:** `FileType` autocmd for `octo`/`DiffviewFiles`/`DiffviewFileHistory`
  → `vim.lsp.enable('roslyn', false)` + `client:stop(true)` + temporary
  `vim.notify` filter for exit messages (10s timeout for large solutions)
- **Restore:** `try_restore_roslyn()` checks `diffview.lib.get_current_view()`
  (NOT buffer filetypes — diffview buffers linger after close and would block
  restore). Then calls `source_deferred_plugin()` which re-enables roslyn.
- **Triggers:** `FileType cs` and `BufEnter *.cs` (2s defer) both call
  `try_restore_roslyn()` to catch different re-entry paths.

## Diffview Edit (`<leader>de`) — Treesitter Pre-warming

Opening a .cs file from diffview via `edit_diff_file()` in `pr-review.lua` used
to show an un-highlighted buffer for 2-5s while treesitter parsed the C# grammar.

Fix: before closing the diffview tab, `bufadd` + `bufload` the target file and
call `vim.treesitter.get_parser(buf):parse()` to force a synchronous full-tree
parse while diffview is still visible. When the tab closes and `:edit` switches
to the already-loaded buffer, highlighting is instant.

Roslyn restore is safe during pre-load — `try_restore_roslyn()` checks
`dv_lib.get_current_view()` and bails because diffview is still open.

## Which-Key in Diffview

Which-key's trigger system has brief suspension windows (`ModeChanged`, `BufNew`)
where the `<Space>` trigger keymap is absent. In diffview panels, a permanent
buffer-local `<Space>` keymap calls `require('which-key').show(' ')` directly,
bypassing the fragile trigger system. This is set via `FileType` autocmd for
`DiffviewFiles`/`DiffviewFileHistory` in `pr-review.lua`.

The `wk.add` BufEnter callback in `ui.lua` also skips `buftype ~= ''` buffers
(diffview, telescope, neo-tree) and caches visibility state to avoid unnecessary
`Buf.clear()` calls that remove all triggers globally.
