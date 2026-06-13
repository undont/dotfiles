-- Roslyn semantic-token orchestration. extracted from plugins/dotnet.lua.
-- three concerns: disable nvim 0.12 viewport range requests (flicker on .cs
-- open), refresh tokens after background analysis (project-wide on progress
-- 'end' + per-file on DiagnosticChanged), and fix a few token
-- misclassifications. see .claude/rules/neovim_dotnet.md

local M = {}

--- fix Roslyn misclassifying unresolved identifiers on using directives as
--- "variable" instead of "namespace". override to @type for proper styling
function M.setup()
  local builtin_types = {
    bool = true,
    byte = true,
    char = true,
    decimal = true,
    double = true,
    dynamic = true,
    float = true,
    int = true,
    long = true,
    nint = true,
    nuint = true,
    object = true,
    sbyte = true,
    short = true,
    string = true,
    uint = true,
    ulong = true,
    ushort = true,
    void = true,
  }

  local function in_attribute_context(line, start_col)
    local before = line:sub(1, start_col)
    local last_open = before:match '.*()%['
    if not last_open then
      return false
    end
    local last_close = before:match '.*()%]'
    return not last_close or last_open > last_close
  end

  -- disable nvim 0.12's viewport-only semantic token range requests.
  -- Roslyn 5.8.0 declares semanticTokensProvider.range statically in
  -- the initialize response, so STHighlighter:on_attach caches
  -- supports_range = true before our config runs. range responses arrive
  -- with stale/partial classifications during Roslyn warmup and replace
  -- the full-document tokens, causing visible flicker on .cs open.
  --
  -- nvim's Client:on_attach schedules STHighlighter:on_attach after
  -- LspAttach callbacks finish (client.lua:1159) precisely so we can
  -- mutate server_capabilities here as an opt-out hook
  vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if not (client and client.name == 'roslyn') then
        return
      end
      local stp = client.server_capabilities and client.server_capabilities.semanticTokensProvider
      if stp then
        stp.range = false
      end
    end,
  })

  vim.api.nvim_create_autocmd('LspTokenUpdate', {
    callback = function(ev)
      local token = ev.data.token
      local line = vim.api.nvim_buf_get_lines(ev.buf, token.line, token.line + 1, false)[1]
      if not line then
        return
      end
      if vim.bo[ev.buf].filetype ~= 'cs' then
        return
      end

      if token.type == 'variable' then
        if not line:match '^%s*using%s' or line:match '[%(=]' then
          return
        end
        vim.lsp.semantic_tokens.highlight_token(token, ev.buf, ev.data.client_id, '@type')
        return
      end

      if token.type == 'class' then
        if in_attribute_context(line, token.start_col) then
          vim.lsp.semantic_tokens.highlight_token(token, ev.buf, ev.data.client_id, '@attribute')
        end
        return
      end

      if token.type ~= 'keyword' then
        return
      end

      local text = line:sub(token.start_col + 1, token.end_col)
      if builtin_types[text] then
        vim.lsp.semantic_tokens.highlight_token(token, ev.buf, ev.data.client_id, '@type.builtin')
      end
    end,
  })

  -- refresh semantic tokens whenever Roslyn finishes a background task.
  -- workspace/projectInitializationComplete (RoslynInitialized) fires *before*
  -- per-file semantic analysis is done, so a single refresh there lands stale
  -- (requiring a manual <leader>lt ~1s later to settle). Roslyn emits LSP
  -- progress 'end' notifications when its background analysis chunks finish;
  -- a debounced refresh on those catches the moment fresh tokens are ready.
  -- debounce keeps cost bounded during warmup (many 'end' events fire close
  -- together) while still picking up post-warmup analyses (branch switches,
  -- dep restores, etc.)
  local refresh_pending = false
  vim.api.nvim_create_autocmd('LspProgress', {
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if not (client and client.name == 'roslyn') then
        return
      end
      local val = ev.data.params and ev.data.params.value
      if not (val and val.kind == 'end') then
        return
      end
      if refresh_pending then
        return
      end
      refresh_pending = true
      vim.defer_fn(function()
        refresh_pending = false
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == 'cs' then
            vim.lsp.semantic_tokens.force_refresh(buf)
          end
        end
      end, 300)
    end,
  })

  -- the progress-'end' refresh above is keyed to project-wide timing, which can
  -- race a given buffer's analysis: under fast warmup it fires before that
  -- buffer's semantic tokens are ready, leaving colours stale until a manual
  -- <leader>lt. a buffer's DiagnosticChanged is the per-file signal we actually
  -- want; roslyn publishes diagnostics (empty or not) once it has a semantic
  -- model for the file, which is exactly when its tokens are ready too. force a
  -- token refresh then, debounced per buffer (last-scheduled-wins) and gated to
  -- *visible* roslyn .cs buffers so a 100-file <leader>xm scan doesn't pile
  -- refreshes onto hidden buffers. re-requesting identical tokens is a no-op
  -- repaint, so this can't reintroduce flicker as DiagnosticChanged settles
  local token_refresh_seq = {}
  vim.api.nvim_create_autocmd('DiagnosticChanged', {
    callback = function(ev)
      local buf = ev.buf
      if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].filetype ~= 'cs' then
        return
      end
      local seq = (token_refresh_seq[buf] or 0) + 1
      token_refresh_seq[buf] = seq
      vim.defer_fn(function()
        -- superseded by a later DiagnosticChanged for this buffer; let the
        -- newest scheduled refresh win
        if token_refresh_seq[buf] ~= seq then
          return
        end
        token_refresh_seq[buf] = nil
        if
          vim.api.nvim_buf_is_valid(buf)
          and vim.bo[buf].filetype == 'cs'
          and vim.fn.bufwinid(buf) ~= -1
          and vim.lsp.get_clients({ bufnr = buf, name = 'roslyn' })[1]
        then
          pcall(vim.lsp.semantic_tokens.force_refresh, buf)
        end
      end, 250)
    end,
  })
end

return M
