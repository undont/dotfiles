-- LSP configuration

--- Deduplicate LSP results and display with Telescope.
--- Drives the request directly (instead of `vim.lsp.buf.<method>`) so empty
--- results reach our on_list path; the built-in handlers short-circuit on
--- empty (references notifies `No references found`, the location methods
--- return silently) before on_list would ever run.
local lsp_dedup_methods = {
  references = { lsp = 'textDocument/references', label = 'references' },
  implementation = { lsp = 'textDocument/implementation', label = 'implementations' },
  definition = { lsp = 'textDocument/definition', label = 'definitions' },
  type_definition = { lsp = 'textDocument/typeDefinition', label = 'type definitions' },
}

local function lsp_dedup(method)
  local spec = assert(lsp_dedup_methods[method], 'unsupported lsp_dedup method: ' .. method)
  return function()
    local bufnr = vim.api.nvim_get_current_buf()
    local clients = vim.lsp.get_clients { bufnr = bufnr, method = spec.lsp }
    if #clients == 0 then
      vim.notify('No LSP client supports ' .. spec.label, vim.log.levels.WARN)
      return
    end

    -- Build params per-client so mixed-encoding setups (e.g. utf-8 + utf-16
    -- LSPs on the same buffer) get correctly aligned column offsets. The
    -- response side already does this correctly via `client.offset_encoding`.
    local function make_params(client)
      local p = vim.lsp.util.make_position_params(0, client.offset_encoding or 'utf-16')
      if method == 'references' then
        -- Exclude the declaration so `grr` on a symbol with no callers triggers
        -- the `No references found` warning instead of jumping to the decl itself.
        p.context = { includeDeclaration = false }
      end
      return p
    end

    vim.lsp.buf_request_all(bufnr, spec.lsp, make_params, function(responses)
      local seen = {}
      local items = {}
      for client_id, response in pairs(responses) do
        local result = response.result
        if result and not vim.tbl_isempty(result) then
          local client = vim.lsp.get_client_by_id(client_id)
          local enc = (client and client.offset_encoding) or 'utf-16'
          -- Location methods can return a single Location; wrap into a list.
          if not vim.islist(result) then
            result = { result }
          end
          for _, item in ipairs(vim.lsp.util.locations_to_items(result, enc)) do
            local key = item.filename .. ':' .. item.lnum .. ':' .. item.col
            if not seen[key] then
              seen[key] = true
              table.insert(items, item)
            end
          end
        end
      end

      if #items == 0 then
        vim.notify('No ' .. spec.label .. ' found', vim.log.levels.WARN)
        return
      end

      vim.fn.setqflist({}, ' ', { title = spec.label, items = items })
      if #items == 1 then
        vim.cmd.cfirst()
      else
        require('telescope.builtin').quickfix()
      end
    end)
  end
end

--- Collect, deduplicate, and sort diagnostics for fix-all-in-file.
--- Returns items sorted bottom-up so line shifts don't affect earlier fixes.
local function collect_fixable_diagnostics(bufnr)
  local diagnostics = vim.diagnostic.get(bufnr)
  if #diagnostics == 0 then
    return {}
  end

  local seen = {}
  local items = {}
  for _, d in ipairs(diagnostics) do
    local key = d.lnum .. ':' .. d.col .. ':' .. (d.message or '')
    if not seen[key] then
      seen[key] = true
      local lsp_diag = d.user_data and d.user_data.lsp
        or {
          range = {
            start = { line = d.lnum, character = d.col },
            ['end'] = { line = d.end_lnum or d.lnum, character = d.end_col or d.col },
          },
          message = d.message,
          severity = d.severity,
          source = d.source,
          code = d.code,
        }
      table.insert(items, { lnum = d.lnum, col = d.col, lsp = lsp_diag })
    end
  end

  table.sort(items, function(a, b)
    if a.lnum == b.lnum then
      return a.col > b.col
    end
    return a.lnum > b.lnum
  end)

  return items
end

--- Resolve a code action if needed, then apply it.
--- Some servers (Roslyn) return lazy actions that need codeAction/resolve.
local function resolve_and_apply(bufnr, action, client, on_done)
  local function apply(a)
    if a.edit then
      vim.lsp.util.apply_workspace_edit(a.edit, 'utf-8')
      return true
    elseif a.command and client then
      client:exec_cmd(a.command)
      return true
    end
    return false
  end

  if action.edit or action.command then
    local applied = apply(action)
    on_done(applied)
  else
    vim.lsp.buf_request(bufnr, 'codeAction/resolve', action, function(err, resolved)
      local applied = not err and resolved and apply(resolved) or false
      on_done(applied)
    end)
  end
end

--- Apply all quickfix code actions for every diagnostic in the current buffer.
--- Processes bottom-up so line shifts from earlier fixes don't break later ones.
local function fix_all_in_file()
  local bufnr = vim.api.nvim_get_current_buf()
  local items = collect_fixable_diagnostics(bufnr)
  if #items == 0 then
    vim.notify('No diagnostics in file', vim.log.levels.INFO)
    return
  end

  local applied = 0
  local function apply_next(idx)
    if idx > #items then
      vim.notify(string.format('Applied %d fix%s', applied, applied == 1 and '' or 'es'), vim.log.levels.INFO)
      return
    end

    local item = items[idx]
    local range = item.lsp.range
      or {
        start = { line = item.lnum, character = item.col },
        ['end'] = { line = item.lnum, character = item.col },
      }
    local params = {
      textDocument = vim.lsp.util.make_text_document_params(bufnr),
      range = range,
      context = { diagnostics = { item.lsp } },
    }

    local handled = false
    vim.lsp.buf_request(bufnr, 'textDocument/codeAction', params, function(err, result, ctx)
      if handled then
        return
      end
      handled = true

      if err or not result or #result == 0 then
        vim.defer_fn(function()
          apply_next(idx + 1)
        end, 50)
        return
      end

      -- Prefer quickfix kind, fall back to first action
      local action
      for _, a in ipairs(result) do
        if a.kind and a.kind:find '^quickfix' then
          action = a
          break
        end
      end
      action = action or result[1]

      local client = vim.lsp.get_client_by_id(ctx.client_id)
      resolve_and_apply(bufnr, action, client, function(was_applied)
        if was_applied then
          applied = applied + 1
        end
        vim.defer_fn(function()
          apply_next(idx + 1)
        end, 50)
      end)
    end)
  end

  apply_next(1)
end

--- Restart all LSP servers attached to the given buffer.
local function restart_lsp_clients(bufnr)
  local clients = vim.lsp.get_clients { bufnr = bufnr }
  local count = 0
  for _, client in ipairs(clients) do
    if client.server_capabilities then
      vim.cmd('lsp restart ' .. client.name)
      count = count + 1
    end
  end
  if count > 0 then
    vim.notify(string.format('Restarted %d LSP server(s)', count), vim.log.levels.INFO)
  else
    vim.notify('No LSP servers attached to buffer', vim.log.levels.WARN)
  end
end

--- Prevent LSP servers from attaching to non-file:// buffers (diffview://,
--- octo://, fugitive://, etc.). Without this, servers like gopls log JSON-RPC
--- parse errors when nvim sends didOpen with a non-file URI.
local function patch_lsp_start()
  local orig_start = vim.lsp.start
  vim.lsp.start = function(config, opts)
    opts = opts or {}
    local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name:match '^%w[%w+.-]*://' and not name:match '^file://' then
      return nil
    end
    return orig_start(config, opts)
  end
end

--- Override show_document to handle cursor-position-outside-buffer errors
--- from LSP servers that report invalid ranges.
local function patch_show_document()
  local orig = vim.lsp.util.show_document
  vim.lsp.util.show_document = function(location, offset_encoding, opts)
    local ok, ret = pcall(orig, location, offset_encoding, opts)
    if ok then
      return ret
    end
    if ret:match 'Cursor position outside buffer' then
      local uri = location.uri or location.targetUri
      if uri then
        vim.cmd('edit ' .. vim.uri_to_fname(uri))
        vim.notify('Jumped to file (cursor position was invalid)', vim.log.levels.WARN)
        return true
      end
    end
    error(ret)
  end
end

return {
  -- Main LSP Configuration
  {
    'neovim/nvim-lspconfig',
    event = { 'BufReadPre', 'BufNewFile' },
    cmd = { 'Mason', 'MasonInstall', 'MasonUninstall', 'MasonUninstallAll', 'MasonLog', 'MasonUpdate', 'MasonToolsInstall', 'MasonToolsUpdate' },
    dependencies = {
      {
        'mason-org/mason.nvim',
        opts = {
          registries = {
            'github:mason-org/mason-registry',
            'github:Crashdummyy/mason-registry', -- roslyn LSP server
          },
        },
      },
      'mason-org/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      'saghen/blink.cmp',
    },
    config = function()
      -- LSP attach autocmd
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          -- LSP keymaps
          map('K', function()
            pcall(vim.api.nvim_win_close, vim.b[event.buf]._diag_float_win or -1, true)
            vim.b._hover_open = true
            vim.lsp.buf.hover()
          end, 'Hover')
          map('grn', vim.lsp.buf.rename, 'Re[n]ame')
          map('gra', vim.lsp.buf.code_action, 'Code [A]ction', { 'n', 'x' })
          map('grf', fix_all_in_file, '[F]ix all in file')
          map('grr', lsp_dedup 'references', '[R]eferences')
          map('gri', lsp_dedup 'implementation', '[I]mplementation')
          map('grd', lsp_dedup 'definition', '[D]efinition')
          map('grD', vim.lsp.buf.declaration, '[D]eclaration')
          map('gO', require('telescope.builtin').lsp_document_symbols, 'Document symbols')
          map('gW', require('telescope.builtin').lsp_dynamic_workspace_symbols, 'Workspace symbols')
          map('grt', lsp_dedup 'type_definition', '[T]ype definition')
          map('<leader>lr', function()
            restart_lsp_clients(event.buf)
          end, '[R]estart')

          -- Document highlight on cursor hold
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          -- Inlay hints toggle
          if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
            map('<leader>lh', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, 'Inlay [H]ints')
          end

          -- Code lens (gopls only; other languages render above-line which clashes
          -- with deeply-nested declarations and adds noise).
          if client and client.name == 'gopls' and client:supports_method(vim.lsp.protocol.Methods.textDocument_codeLens, event.buf) then
            vim.lsp.codelens.enable(true, { bufnr = event.buf })
            map('<leader>ll', vim.lsp.codelens.run, 'Code [L]ens run')
            map('<leader>lL', function()
              vim.lsp.codelens.enable(true, { bufnr = event.buf })
            end, 'Code [L]ens refresh')
          end
        end,
      })

      -- Diagnostic Config
      vim.diagnostic.config {
        severity_sort = true,
        float = { border = 'rounded', source = 'if_many' },
        underline = { severity = vim.diagnostic.severity.ERROR },
        signs = vim.g.have_nerd_font and {
          text = {
            [vim.diagnostic.severity.ERROR] = '󰅚 ',
            [vim.diagnostic.severity.WARN] = '󰀪 ',
            [vim.diagnostic.severity.INFO] = '󰋽 ',
            [vim.diagnostic.severity.HINT] = '󰌶 ',
          },
        } or {},
        virtual_text = {
          source = 'if_many',
          spacing = 2,
        },
      }

      -- Hover, signature help, and markdown rendering are handled by noice.nvim (see ui.lua)

      -- Merge blink.cmp completion capabilities with Neovim defaults so that
      -- semantic tokens, document highlights, and other standard capabilities
      -- aren't dropped (blink only provides completion-related caps).
      local caps = vim.tbl_deep_extend('force', vim.lsp.protocol.make_client_capabilities(), require('blink.cmp').get_lsp_capabilities())
      -- Remove colorProvider to prevent nvim 0.12 document_color assertion bug
      caps.textDocument.colorProvider = nil
      vim.lsp.config('*', { capabilities = caps })

      patch_lsp_start()
      patch_show_document()

      vim.lsp.config('cssls', {
        settings = {
          css = { lint = { unknownAtRules = 'ignore' } },
        },
      })

      vim.lsp.config('lua_ls', {
        settings = {
          Lua = {
            completion = { callSnippet = 'Replace' },
          },
        },
      })

      vim.lsp.config('gopls', {
        settings = {
          gopls = {
            codelenses = {
              generate = true,
              regenerate_cgo = true,
              test = true,
              tidy = true,
              upgrade_dependency = true,
              vendor = true,
              run_govulncheck = true,
            },
          },
        },
      })

      -- Server configurations
      local servers = {
        bashls = {},
        clangd = {},
        cssls = {},
        eslint = {},
        gopls = {},
        html = {},
        lua_ls = {},
        pyright = {},
        tailwindcss = {},
        ts_ls = {},
        yamlls = {},
      }

      require('mason-lspconfig').setup {
        ensure_installed = vim.tbl_keys(servers or {}),
        automatic_installation = false,
        automatic_enable = {
          exclude = { 'omnisharp' }, -- Using roslyn.nvim instead
        },
      }

      require('mason-tool-installer').setup {
        ensure_installed = {
          -- LSP servers
          'bashls',
          'clangd',
          'cssls',
          'eslint',
          'gopls',
          'html',
          'lua_ls',
          'pyright',
          'tailwindcss',
          'ts_ls',
          'yamlls',
          -- Roslyn (C# LSP, from Crashdummyy/mason-registry)
          'roslyn',
          -- SonarLint LSP (analyzers + bundled omnisharp for C#); driven by sonarlint.lua
          'sonarlint-language-server',
          -- Formatters
          'csharpier',
          'gofumpt',
          'goimports',
          'prettier',
          'stylua',
          -- Linters
          'golangci-lint',
        },
      }
    end,
  },

  -- Formatting
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function()
          if not vim.bo.modifiable then
            vim.notify('Buffer is not modifiable', vim.log.levels.WARN)
            return
          end
          require('conform').format { async = true, lsp_format = 'fallback' }
        end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    opts = {
      notify_on_error = true,
      format_on_save = function(bufnr)
        local disable_filetypes = { c = true, cpp = true }
        if disable_filetypes[vim.bo[bufnr].filetype] then
          return nil
        end
        return {
          timeout_ms = 500,
          lsp_format = 'fallback',
        }
      end,
      formatters_by_ft = {
        cs = { 'csharpier' },
        go = { 'goimports', 'gofumpt' },
        javascript = { 'prettier' },
        javascriptreact = { 'prettier' },
        json = { 'prettier' },
        lua = { 'stylua' },
        typescript = { 'prettier' },
        typescriptreact = { 'prettier' },
        yaml = { 'prettier' },
      },
      formatters = {
        goimports = {
          command = vim.fn.stdpath 'data' .. '/mason/bin/goimports',
        },
        csharpier = {
          command = vim.fn.stdpath 'data' .. '/mason/bin/csharpier',
        },
      },
    },
  },
}
