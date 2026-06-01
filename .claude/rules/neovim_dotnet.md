---
paths:
  - "nvim/lua/custom/plugins/dotnet.lua"
---

# C# / Roslyn LSP — Architecture & Debugging

## Why both roslyn.nvim and easy-dotnet

roslyn.nvim drives the LSP; easy-dotnet drives build/run/test/debug with its own
LSP disabled (`lsp.enabled = false`). easy-dotnet ships a bundled Roslyn LSP now,
but it is NOT a drop-in replacement for roslyn.nvim here: it has no
`ignore_target` / `lock_target` / `choose_target` / `broad_search`, so it cannot
exclude build-variant solutions (`*.ci.slnx`) or pin a target in multi-solution
repos — exactly what this config depends on. Both wrap the same Microsoft
`Microsoft.CodeAnalysis.LanguageServer`, so enabling easy-dotnet's LSP alongside
roslyn.nvim would attach two roslyn servers to every `.cs` buffer (duplicate
diagnostics/completion). `lsp.enabled = false` is therefore load-bearing, not
cruft. Re-evaluate only if easy-dotnet gains target-exclusion/locking.

## Diagnostic Filtering

Roslyn diagnostics are post-processed in `patch_diagnostic_set()` in
`dotnet.lua` before they reach Neovim. This wrapper exists because raw Roslyn
output is too noisy in a few repo-specific ways.

Current filtering behavior:

- **Known false positives are dropped by code**: `IDE0005`, `IDE0079`,
  `CA1825`.
- **Metadata-as-source buffers are silenced entirely**: if the buffer path
  contains `MetadataAsSource`, diagnostics are replaced with an empty list
  because read-only decompiled framework code is not actionable.
- **Suggestion-level XML doc comment style hints are dropped**: Roslyn can emit
  simplification-style IDE diagnostics on XML doc comment symbol references such
  as `<see cref="...">`. If the diagnostic severity is `HINT` or `INFO`, the
  line starts with `///`, and the diagnostic looks style-related (`IDE*`, source
  `Style`, or a message containing `simplif`), we suppress it. This keeps
  "Name can be simplified" noise out of doc comments while preserving real
  warnings/errors for malformed XML docs or compiler issues.
- **Cross-project duplicates are deduped**: Roslyn can report the same problem
  from multiple `.csproj` contexts. We key diagnostics by `lnum:col:code` when
  code is present, otherwise `lnum:col:message`, so message wording differences
  across push/pull channels do not create duplicates.

## Semantic Token Flow

Roslyn semantic tokens require careful orchestration on Neovim 0.12+. The setup
lives in `setup_semantic_token_fix()` in `dotnet.lua` and handles three issues:

### 1. Range request filtering

Neovim 0.12 added `textDocument/semanticTokens/range` (viewport-only tokens).
Roslyn 5.8.0 declares `semanticTokensProvider.range` statically in its
`initialize` response, so `STHighlighter:on_attach` caches `supports_range = true`
before our config runs. During warmup the range responses arrive with
stale/partial classifications and replace the full-document tokens, causing
visible flicker on `.cs` open.

We disable it by setting `server_capabilities.semanticTokensProvider.range =
false` in an `LspAttach` autocmd for the roslyn client. `LspAttach` is the
correct hook: Neovim's `Client:on_attach` schedules `STHighlighter:on_attach`
*after* the `LspAttach` callbacks finish (`client.lua:1159`), so the capability
is flipped before the semantic-token handler reads it.

**Why other approaches don't work:**
- A client-level `capabilities` override at config time — the shallow merge on
  `textDocument` wipes sibling capabilities (completion, hover, etc.) and breaks
  the LSP entirely.
- Mutating `server_capabilities` in `on_init` — fragile relative to when the
  handler caches caps; `LspAttach` (above) is the reliable opt-out point.

### 2. Token refresh after background analysis

Neovim requests tokens on attach (before the solution loads) and gets
empty/stale tokens; Roslyn never sends `workspace/semanticTokens/refresh` when
analysis completes. `workspace/projectInitializationComplete` (the
`RoslynInitialized` user event) fires *before* per-file semantic analysis is
done, so refreshing there lands stale and needs a manual `<leader>lt` a second
later to settle. Instead we debounce-refresh (300ms) all `.cs` buffers on
Roslyn's LSP progress `end` notifications, which fire as each background-analysis
chunk finishes. The debounce bounds cost during warmup (many `end` events
cluster) while still catching later analyses (branch switches, dependency
restores).

### 3. Token classification fixes

Roslyn misclassifies a few C# tokens, so an `LspTokenUpdate` autocmd applies
targeted overrides:

- `using Foo;` unresolved identifiers reported as `variable` are remapped to
  `@type` so they render like namespaces/types instead of plain variables.
- Built-in C# types such as `string`, `int`, `bool`, `object`, etc. reported as
  `keyword` are remapped to `@type.builtin` so they don't override TreeSitter's
  built-in type highlighting.
- Attribute names such as `Required` in `[Required]` or `[property: Required]`
  reported as `class` are remapped to `@attribute` when they appear inside an
  active attribute bracket context.

## Roslyn Deferred Loading

Roslyn's plugin file is blocked during startup (`vim.g.loaded_roslyn_plugin = true`
in `init`) to prevent `vim.lsp.enable` firing before `lock_target` and
`ignore_target` are configured. The loading sequence on first `.cs` file:

1. `resolve_solution_target()` — finds `.sln` via upward search
2. `vim.lsp.config('roslyn', ...)` — applies settings
3. `require('roslyn').setup(opts)` — stores roslyn.nvim config
4. `source_deferred_plugin()` — clears the block, `dofile(plugin/roslyn.lua)`
   which calls `vim.lsp.enable('roslyn')`

**Load-bearing on Neovim 0.12 — do not remove (verified 2026-06-01).** It looks
like the 0.12 lazy native-config model makes this redundant; it does not.
lazy.nvim sources a plugin's `plugin/*.lua` *before* running its `config`
(`loader.lua` `_load`: `packadd` then `config`), so without the
`vim.g.loaded_roslyn_plugin` block, `vim.lsp.enable('roslyn')` fires before
`resolve_solution_target()` / `setup(opts)` / `vim.lsp.config()`. And because we
load on `User RealDotnetFile` (the `.cs` buffer already exists), `vim.lsp.enable`
synchronously runs `doautoall('nvim.lsp.enable FileType')` (`lsp.lua`, gated by
`did_filetype()`), which deep-copies the config and resolves `root_dir` right
then — with roslyn's defaults (`lock_target = false`, `ignore_target = nil`) and
no `csharp|...` settings. Result: wrong solution target (or a multi-solution
picker) and an unconfigured client. The deferred `dofile` is what forces
`vim.lsp.enable` to run *after* our config.

## Roslyn During Diffview / Octo

**Roslyn is NOT suppressed during review.** Earlier iterations called
`vim.lsp.enable('roslyn', false)` on review entry to block new attaches, but
that API also stops every running roslyn client (see `lsp.lua` source:
`"stops related LSP clients and servers"`), forcing a multi-second cold-restart
on every review entry/exit cycle. Each restart triggered the
`RoslynInitialized` autocmd which `force_refresh`es semantic tokens on every
loaded `.cs` buffer — that's what produced the post-`<leader>de` editor freeze.

Why we don't need to block attaches: Neovim's built-in `lsp_enable_callback`
skips buffers whose `buftype` isn't `''` or `'help'`. Octo review buffers use
`buftype=nofile`, diffview file diff buffers use `buftype=nowrite`. So roslyn
doesn't auto-attach to them anyway. The "hundreds of diff buffers freezing
roslyn" concern is handled by Neovim itself.

What we do keep:
- **`vim.g.roslyn_suppressed` flag** — set on `FileType octo`/`DiffviewFiles`/
  `DiffviewFileHistory`, cleared by `maybe_clear_roslyn_flag` (deferred 500ms
  on `BufEnter *.cs`) once `diffview.lib.get_current_view()` is nil and no
  `octo` buffers remain.
- **Notify filtering** lives in the wrap inside `ui.lua`'s fidget config (NOT
  here). Fidget's `override_vim_notify = true` overwrites `vim.notify` at
  setup time, blowing away wraps installed at module load — so the single
  source of truth has to live after fidget setup. The wrap consults
  `vim.g.roslyn_suppressed` and drops messages matching `[Rr]oslyn` (body) or
  `roslyn` (title, case-insensitive) while the flag is set.
- **Initial `source_deferred_plugin()`** in `config()` — still needed to
  unblock roslyn.nvim's plugin file (gated by `vim.g.loaded_roslyn_plugin`)
  after our `lock_target` / `ignore_target` config is applied.

## Diffview Edit (`<leader>de`) — No Treesitter Pre-warming

`edit_diff_file()` in `pr-review.lua` used to pre-load the target buffer and
force a synchronous Treesitter parse before leaving diffview.

That made highlighting feel instant after the switch, but it also blocked the
editor for large `.cs`, `.ts`, and `.tsx` files because the parse happened on
the hot path for `<leader>de`.

Current behavior: no pre-warm. `<leader>de` closes diffview and edits the file
immediately, leaving Treesitter to initialize on the normal buffer-open path.
This trades "instant highlighting" for a responsive editor, which is the
correct default for large projects.

## Which-Key in Diffview

Which-key's trigger system has brief suspension windows (`ModeChanged`, `BufNew`)
where the `<Space>` trigger keymap is absent. In diffview panels, a permanent
buffer-local `<Space>` keymap calls `require('which-key').show(' ')` directly,
bypassing the fragile trigger system. This is set via `FileType` autocmd for
`DiffviewFiles`/`DiffviewFileHistory` in `pr-review.lua`.

The `wk.add` BufEnter callback in `ui.lua` also skips `buftype ~= ''` buffers
(diffview, telescope, neo-tree) and caches visibility state to avoid unnecessary
`Buf.clear()` calls that remove all triggers globally.
