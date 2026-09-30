-- Roslyn semantic-token orchestration: disables nvim's viewport range
-- requests, refreshes tokens after background analysis (project-wide on
-- progress 'end', per-file on DiagnosticChanged) and remaps a few misclassified
-- tokens

local M = {}

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

  -- Roslyn declares semanticTokensProvider.range statically, and during warmup
  -- its range responses replace the full-document tokens with partial ones.
  -- nvim's Client:on_attach schedules STHighlighter:on_attach after the
  -- LspAttach callbacks, so server_capabilities is mutated here
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

  -- workspace/projectInitializationComplete fires before per-file semantic
  -- analysis is done, and Roslyn sends no semanticTokens/refresh. tokens are
  -- refreshed, debounced, on the LSP progress 'end' notifications its
  -- background analysis emits
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

  -- the progress-'end' refresh can precede a given buffer's analysis. roslyn
  -- publishes a file's diagnostics once it has a semantic model for it, so
  -- DiagnosticChanged triggers a per-buffer debounced refresh, limited to
  -- visible roslyn .cs buffers so scans don't refresh hidden ones
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
        -- superseded by a later DiagnosticChanged for this buffer
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
