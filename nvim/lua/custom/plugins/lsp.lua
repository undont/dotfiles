-- LSP configuration

return {
  -- Lua development for Neovim
  {
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },

  -- Main LSP Configuration
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      { 'mason-org/mason.nvim', opts = {} },
      'mason-org/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      { 'j-hui/fidget.nvim', event = 'LspAttach', opts = {} },
      'saghen/blink.cmp',
    },
    config = function()
      -- Deduplicate LSP results and display with Telescope
      local function lsp_dedup(method)
        return function()
          local on_list_opts = {
            on_list = function(options)
              local seen = {}
              local items = {}
              for _, item in ipairs(options.items) do
                local key = item.filename .. ':' .. item.lnum .. ':' .. item.col
                if not seen[key] then
                  seen[key] = true
                  table.insert(items, item)
                end
              end
              if #items == 0 then
                vim.notify('No results found', vim.log.levels.INFO)
                return
              end
              options.items = items
              vim.fn.setqflist({}, ' ', options)
              if #items == 1 then
                vim.cmd.cfirst()
              else
                require('telescope.builtin').quickfix()
              end
            end,
          }
          if method == 'references' then
            vim.lsp.buf[method](nil, on_list_opts)
          else
            vim.lsp.buf[method](on_list_opts)
          end
        end
      end

      -- LSP attach autocmd
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          -- LSP keymaps
          map('grn', vim.lsp.buf.rename, '[R]e[n]ame')
          map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })
          map('grr', lsp_dedup 'references', '[G]oto [R]eferences')
          map('gri', lsp_dedup 'implementation', '[G]oto [I]mplementation')
          map('grd', lsp_dedup 'definition', '[G]oto [D]efinition')
          map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
          map('gO', require('telescope.builtin').lsp_document_symbols, 'Open Document Symbols')
          map('gW', require('telescope.builtin').lsp_dynamic_workspace_symbols, 'Open Workspace Symbols')
          map('grt', lsp_dedup 'type_definition', '[G]oto [T]ype Definition')
          map('<leader>lr', function()
            -- Get all LSP clients attached to the current buffer
            local clients = vim.lsp.get_clients { bufnr = event.buf }
            local restarted_count = 0

            for _, client in ipairs(clients) do
              -- Only restart clients that have server_capabilities (actual LSP servers)
              -- This filters out non-LSP clients like Copilot
              if client.server_capabilities then
                vim.cmd('LspRestart ' .. client.name)
                restarted_count = restarted_count + 1
              end
            end

            if restarted_count > 0 then
              vim.notify(string.format('Restarted %d LSP server(s)', restarted_count), vim.log.levels.INFO)
            else
              vim.notify('No LSP servers attached to buffer', vim.log.levels.WARN)
            end
          end, '[L]SP [R]estart')

          -- Helper for checking client support
          ---@param client vim.lsp.Client
          ---@param method vim.lsp.protocol.Method
          ---@param bufnr? integer
          ---@return boolean
          local function client_supports_method(client, method, bufnr)
            if vim.fn.has 'nvim-0.11' == 1 then
              ---@diagnostic disable-next-line: undefined-field
              return client:supports_method(method, bufnr)
            else
              ---@diagnostic disable-next-line: undefined-field
              return client.supports_method(method, { bufnr = bufnr })
            end
          end

          -- Document highlight on cursor hold
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
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
          if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, '[T]oggle Inlay [H]ints')
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
          format = function(diagnostic)
            local diagnostic_message = {
              [vim.diagnostic.severity.ERROR] = diagnostic.message,
              [vim.diagnostic.severity.WARN] = diagnostic.message,
              [vim.diagnostic.severity.INFO] = diagnostic.message,
              [vim.diagnostic.severity.HINT] = diagnostic.message,
            }
            return diagnostic_message[diagnostic.severity]
          end,
        },
      }

      -- NOTE: IDE0079 (Remove unnecessary suppression) filtering is in dotnet.lua
      -- scoped to the Roslyn LSP client where the false positives originate

      -- Configure LSP hover to use bordered windows with proper syntax highlighting
      vim.lsp.handlers['textDocument/hover'] = vim.lsp.with(vim.lsp.handlers.hover, {
        border = 'rounded',
        -- Enable syntax highlighting in hover windows
        -- This ensures markdown code blocks in hover docs are properly highlighted
      })

      -- Configure signature help with bordered windows
      vim.lsp.handlers['textDocument/signatureHelp'] = vim.lsp.with(vim.lsp.handlers.signature_help, {
        border = 'rounded',
      })

      -- LSP capabilities with blink.cmp
      local capabilities = require('blink.cmp').get_lsp_capabilities()

      -- Override show_document to handle cursor position errors
      local show_document = vim.lsp.util.show_document
      vim.lsp.util.show_document = function(location, offset_encoding, opts)
        -- Try to show the document, catching cursor position errors
        local ok, ret = pcall(show_document, location, offset_encoding, opts)

        if not ok then
          -- If error contains "Cursor position outside buffer", try to handle it
          if ret:match 'Cursor position outside buffer' then
            -- Open the file without jumping to the position
            local uri = location.uri or location.targetUri
            if uri then
              vim.cmd('edit ' .. vim.uri_to_fname(uri))
              vim.notify('Jumped to file (cursor position was invalid)', vim.log.levels.WARN)
              return true
            end
          end
          -- Re-throw other errors
          error(ret)
        end

        return ret
      end

      -- Server configurations
      local servers = {
        bashls = {},
        clangd = {},
        cssls = {},
        eslint = {},
        gopls = {},
        html = {},
        lua_ls = {
          settings = {
            Lua = {
              completion = { callSnippet = 'Replace' },
            },
          },
        },
        pyright = {},
        ts_ls = {},
        yamlls = {},
      }

      -- Setup LSP servers with mason-lspconfig
      require('mason-lspconfig').setup {
        ensure_installed = vim.tbl_keys(servers or {}),
        automatic_installation = false,
        handlers = {
          function(server_name)
            -- Skip omnisharp (using easy-dotnet's Roslyn LSP instead)
            if server_name == 'omnisharp' then
              return
            end
            local server = servers[server_name] or {}
            server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
            require('lspconfig')[server_name].setup(server)
          end,
        },
      }

      -- Install additional tools (formatters, linters)
      -- Note: These are NOT LSP servers, just CLI tools
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
          'ts_ls',
          'yamlls',
          -- Formatters
          'csharpier',
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
          require('conform').format { async = true, lsp_format = 'fallback' }
        end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    opts = {
      notify_on_error = false,
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
        csharp = { 'csharpier' },
        go = { 'goimports', 'gofmt' },
        javascript = { 'prettier' },
        javascriptreact = { 'prettier' },
        json = { 'prettier' },
        lua = { 'stylua' },
        typescript = { 'prettier' },
        typescriptreact = { 'prettier' },
        yaml = { 'prettier' },
      },
      formatters = {
        csharpier = {
          command = vim.fn.stdpath 'data' .. '/mason/packages/csharpier/csharpier',
        },
        goimports = {
          command = vim.fn.stdpath 'data' .. '/mason/bin/goimports',
        },
      },
    },
  },
}
