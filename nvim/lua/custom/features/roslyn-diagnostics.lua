-- Roslyn diagnostic post-processing. Extracted from plugins/dotnet.lua.
-- Wraps vim.diagnostic.set to drop known false positives, silence
-- simplification hints inside XML doc comments, blank out decompiled
-- metadata-source buffers, and dedupe diagnostics reported from multiple
-- .csproj contexts. See .claude/rules/neovim_dotnet.md.

local M = {}

--- Wrap vim.diagnostic.set to filter Roslyn false positives and deduplicate
--- diagnostics reported from multiple .csproj contexts (cross-namespace).
function M.patch_diagnostic_set()
  local orig = vim.diagnostic.set
  local false_positives = { IDE0005 = true, IDE0079 = true, CA1825 = true }
  local buf_owners = {} ---@type table<integer, table<string, integer>>

  --- Suppress Roslyn style/suggestion diagnostics whose span lands inside
  --- XML doc comments. Roslyn can report simplification-style IDE hints on
  --- `<see cref="...">` targets, which is technically analyzable but noisy.
  --- Keep warnings/errors so malformed XML docs and compiler diagnostics still
  --- surface normally.
  ---@param bufnr integer
  ---@param d vim.Diagnostic
  ---@return boolean
  local function is_doc_comment_style_hint(bufnr, d)
    if d.severity ~= vim.diagnostic.severity.HINT and d.severity ~= vim.diagnostic.severity.INFO then
      return false
    end
    if type(d.lnum) ~= 'number' then
      return false
    end

    local line = vim.api.nvim_buf_get_lines(bufnr, d.lnum, d.lnum + 1, false)[1]
    if not line or not line:match '^%s*///' then
      return false
    end

    local code = d.code and tostring(d.code) or ''
    return code:match '^IDE' or (d.source == 'Style') or ((d.message or ''):match 'simplif')
  end

  vim.diagnostic.set = function(namespace, bufnr, diagnostics, diag_opts)
    if not (bufnr and vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == 'cs') then
      return orig(namespace, bufnr, diagnostics, diag_opts)
    end

    -- Suppress diagnostics on decompiled metadata source (read-only library code)
    if vim.api.nvim_buf_get_name(bufnr):match 'MetadataAsSource' then
      return orig(namespace, bufnr, {}, diag_opts)
    end

    -- Clear this namespace's previous ownership claims
    if not buf_owners[bufnr] then
      buf_owners[bufnr] = {}
    end
    for key, ns in pairs(buf_owners[bufnr]) do
      if ns == namespace then
        buf_owners[bufnr][key] = nil
      end
    end

    -- Filter false positives and deduplicate across namespaces
    local deduped = {}
    for _, d in ipairs(diagnostics) do
      if not false_positives[d.code] and not is_doc_comment_style_hint(bufnr, d) then
        -- Use lnum:col:code when code is present (ignores message variations
        -- between push/pull channels or multi-project contexts).
        -- Fall back to message when code is absent.
        local key = d.code and (d.lnum .. ':' .. d.col .. ':' .. d.code) or (d.lnum .. ':' .. d.col .. ':' .. d.message)
        if not buf_owners[bufnr][key] then
          buf_owners[bufnr][key] = namespace
          table.insert(deduped, d)
        end
      end
    end

    return orig(namespace, bufnr, deduped, diag_opts)
  end

  vim.api.nvim_create_autocmd('BufWipeout', {
    callback = function(ev)
      buf_owners[ev.buf] = nil
    end,
  })
end

--- Guard the pull-diagnostics response handler against a missing bufstate.
--- roslyn.nvim's `workspace/projectInitializationComplete` handler calls
--- `vim.lsp.diagnostic._refresh()` with no bufnr; core resolves the nil to
--- the *current* buffer and sends a pull request keyed to it. If that buffer
--- was never pull-enabled (any non-C# buffer when roslyn finishes project
--- init), the response crashes with "attempt to index local 'bufstate'
--- (a nil value)" (diagnostic.lua:296). Enable pull state for the buffer
--- before delegating, mirroring what the LspAttach path does. Remove once
--- seblyng/roslyn.nvim#371 is fixed.
function M.patch_pull_diagnostics_bufstate()
  local orig = vim.lsp.diagnostic.on_diagnostic
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.lsp.diagnostic.on_diagnostic = function(err, result, ctx)
    if ctx and ctx.bufnr and vim.api.nvim_buf_is_valid(ctx.bufnr) then
      pcall(vim.lsp.diagnostic._enable, ctx.bufnr)
    end
    return orig(err, result, ctx)
  end
end

return M
