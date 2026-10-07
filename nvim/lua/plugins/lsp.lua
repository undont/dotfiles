-- LSP servers, mason and formatting

local lsp_nav = require 'features.lsp-navigation'
local lsp_fix_all = require 'features.lsp-fix-all'
local lsp_patches = require 'features.lsp-patches'

--- true for ordinary on-disk file buffers. plugin buffers carry a `scheme://`
--- name or a non-empty `buftype`, and csharpier crashes resolving a config
--- directory from such a name
local function is_real_file(bufnr)
  if vim.bo[bufnr].buftype ~= '' then
    return false
  end
  return vim.api.nvim_buf_get_name(bufnr):match '^%w+://' == nil
end

local function restart_lsp_clients(bufnr)
  local clients = vim.lsp.get_clients { bufnr = bufnr }

  -- roslyn's on_exit nils vim.g.roslyn_nvim_selected_solution, so the
  -- restarted client's on_init misses the lock_target fast path and stops at
  -- the multi-target prompt (filtered by features/notify-filter). LspDetach
  -- fires after on_exit and before the new client's on_init, so the solution
  -- is restored there
  local has_roslyn = false
  for _, c in ipairs(clients) do
    if c.name == 'roslyn' then
      has_roslyn = true
      break
    end
  end
  if has_roslyn and vim.g.roslyn_nvim_selected_solution then
    local saved = vim.g.roslyn_nvim_selected_solution
    local id
    id = vim.api.nvim_create_autocmd('LspDetach', {
      callback = function(ev)
        local detached = vim.lsp.get_client_by_id(ev.data.client_id)
        if detached and detached.name == 'roslyn' then
          vim.g.roslyn_nvim_selected_solution = saved
          vim.api.nvim_del_autocmd(id)
        end
      end,
    })
  end

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

--- rename handler that writes the files it touched. the default handler
--- leaves files that weren't open as unsaved background buffers, which never
--- fire the autosave
local function rename_and_save(_, result, ctx)
  if not result then
    vim.notify("Language server couldn't provide rename result", vim.log.levels.INFO)
    return
  end
  local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
  vim.lsp.util.apply_workspace_edit(result, client.offset_encoding)

  -- documentChanges is an array of edits; changes is a map keyed by URI
  local uris = {}
  if result.documentChanges then
    for _, change in ipairs(result.documentChanges) do
      -- skip create/rename/delete resource ops, which have no textDocument
      if change.textDocument and change.textDocument.uri then
        uris[change.textDocument.uri] = true
      end
    end
  elseif result.changes then
    for uri in pairs(result.changes) do
      uris[uri] = true
    end
  end

  for uri in pairs(uris) do
    local buf = vim.uri_to_bufnr(uri)
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified and vim.bo[buf].modifiable and vim.bo[buf].buftype == '' then
      vim.api.nvim_buf_call(buf, function()
        vim.cmd 'silent! write'
      end)
    end
  end
end

return {
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
      'b0o/SchemaStore.nvim',
    },
    config = function()
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          map('K', vim.lsp.buf.hover, 'Hover')
          map('grn', vim.lsp.buf.rename, 'Re[n]ame')
          map('gra', lsp_fix_all.code_action_with_refresh, 'Code [A]ction', { 'n', 'x' })
          map('grf', lsp_fix_all.fix_all_in_file, '[F]ix all in file')
          map('grr', lsp_nav.dedup 'references', '[R]eferences')
          map('gri', lsp_nav.dedup 'implementation', '[I]mplementation')
          map('grd', lsp_nav.dedup 'definition', '[D]efinition')
          map('gd', lsp_nav.dedup 'definition', '[D]efinition')
          map('grD', vim.lsp.buf.declaration, '[D]eclaration')
          map('gO', function()
            Snacks.picker.lsp_symbols()
          end, 'Document symbols')
          map('gW', function()
            Snacks.picker.lsp_workspace_symbols {
              filter = {
                cwd = true,
                -- lua_ls reports local functions as `Variable`
                lua = { 'Class', 'Constructor', 'Enum', 'Field', 'Function', 'Interface', 'Method', 'Module', 'Namespace', 'Property', 'Struct', 'Trait', 'Variable' },
              },
              -- the lsp finders never apply `filter.cwd` themselves
              transform = function(item, ctx)
                return ctx.filter:match(item)
              end,
            }
          end, 'Workspace symbols')
          map('grt', lsp_nav.dedup 'type_definition', '[T]ype definition')
          map('<leader>lr', function()
            restart_lsp_clients(event.buf)
          end, '[R]estart')

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

          if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
            map('<leader>lh', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, 'Inlay [H]ints')
          end

          -- code lens for gopls only
          if client and client.name == 'gopls' and client:supports_method(vim.lsp.protocol.Methods.textDocument_codeLens, event.buf) then
            vim.lsp.codelens.enable(true, { bufnr = event.buf })
            map('<leader>ll', vim.lsp.codelens.run, 'Code [L]ens run')
            map('<leader>lL', function()
              vim.lsp.codelens.enable(true, { bufnr = event.buf })
            end, 'Code [L]ens refresh')
          end
        end,
      })

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
        -- tiny-inline-diagnostic draws the message (see plugins/diagnostics.lua)
        virtual_text = false,
        virtual_lines = false,
      }

      vim.lsp.handlers['textDocument/rename'] = rename_and_save

      -- blink only provides completion capabilities, so they merge over nvim's defaults
      local caps = vim.tbl_deep_extend('force', vim.lsp.protocol.make_client_capabilities(), require('blink.cmp').get_lsp_capabilities())
      -- document_color asserts on a stale client id
      vim.lsp.document_color.enable(false)
      vim.lsp.config('*', { capabilities = caps })

      lsp_patches.patch_lsp_start()
      lsp_patches.patch_show_document()

      vim.lsp.config('cssls', {
        settings = {
          css = { lint = { unknownAtRules = 'ignore' } },
        },
      })

      -- the SchemaStore catalogue loads when the server starts. before_init
      -- mutates `settings` in place: the client keeps that table by reference
      vim.lsp.config('jsonls', {
        settings = { json = { validate = { enable = true } } },
        before_init = function(_, config)
          config.settings.json.schemas = require('schemastore').json.schemas()
        end,
      })

      -- `url = ''` avoids a TypeError in yamlls when its own store is disabled
      vim.lsp.config('yamlls', {
        settings = { yaml = { schemaStore = { enable = false, url = '' } } },
        before_init = function(_, config)
          config.settings.yaml.schemas = require('schemastore').yaml.schemas()
        end,
      })

      vim.lsp.config('lua_ls', {
        settings = {
          Lua = {
            completion = { callSnippet = 'Replace' },
          },
        },
      })

      vim.lsp.config('roslyn', {
        -- force-terminates after `shutdown`, so `:lsp restart roslyn` cannot stall on an unresponsive server
        exit_timeout = 5000,
        -- roslyn.nvim's cmd carries `--daemon-mode`: one detached server shared
        -- by every client, which keeps the launching nvim's cwd. if that cwd
        -- is a git worktree later removed, project loads fail in getcwd().
        -- the solution arrives as an absolute path, so $HOME works as cwd
        cmd_cwd = vim.env.HOME,
      })

      -- every server is terminated on nvim exit. nvim's VimLeavePre handler
      -- waits up to the max `exit_timeout` across clients; ExitPre runs before
      -- it, and `stop(true)` terminates synchronously (rpc.terminate).
      -- runtime restarts keep the per-client timeouts above
      vim.api.nvim_create_autocmd('ExitPre', {
        desc = 'force-kill LSP servers so nvim does not wait on exit',
        callback = function()
          for _, c in pairs(vim.lsp.get_clients()) do
            c.exit_timeout = 0
            c:stop(true)
          end
        end,
      })

      vim.lsp.config('gopls', {
        settings = {
          gopls = {
            -- workspace/symbol covers workspace modules, not deps in ~/go/pkg/mod
            symbolScope = 'workspace',
            -- gopls sends one `string` token per literal, which outranks
            -- treesitter's @string.escape and @string.regexp. its only extra is
            -- a `format` modifier on printf verbs, which
            -- features.go-format-verbs marks
            semanticTokenTypes = { string = false },
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

      -- golangci-lint's default linters repeat what gopls reports, so it only
      -- starts in projects with a golangci config. a `root_dir` function that
      -- skips `on_dir` decides activation (`:h lsp-root_dir()`);
      -- `root_markers` can't, since vim.lsp.config deep-merges lists by index
      -- and lspconfig's trailing entries would remain.
      -- `-nolintername` keeps the linter name out of the message text; it is
      -- already in the `source` field
      vim.lsp.config('golangci_lint_ls', {
        cmd = { 'golangci-lint-langserver', '-nolintername' },
        root_dir = function(bufnr, on_dir)
          local root = vim.fs.root(bufnr, { '.golangci.yml', '.golangci.yaml', '.golangci.toml', '.golangci.json' })
          if root then
            on_dir(root)
          end
        end,
      })

      -- sourcekit-lsp ships with the swift toolchain, not mason, so it is
      -- enabled directly: via `xcrun` on macOS (the active toolchain), the
      -- PATH binary on Linux. filetypes are `swift` only: lspconfig's default
      -- also claims c/cpp/objc/objcpp, which clangd serves
      local sourcekit_cmd = vim.fn.has 'mac' == 1 and { 'xcrun', 'sourcekit-lsp' } or { 'sourcekit-lsp' }
      if vim.fn.executable(sourcekit_cmd[1]) == 1 then
        vim.lsp.config('sourcekit', {
          cmd = sourcekit_cmd,
          filetypes = { 'swift' },
        })
        vim.lsp.enable 'sourcekit'
      end

      -- basedpyright's default `recommended` reports the inferred-Any rules
      -- on untyped code; `standard` is pyright's mode. the rest of the
      -- settings table comes from lspconfig
      vim.lsp.config('basedpyright', {
        settings = {
          basedpyright = {
            analysis = {
              typeCheckingMode = 'standard',
            },
          },
        },
      })

      -- ruff's F821 duplicates basedpyright's reportUndefinedVariable.
      -- mason-lspconfig enables the ruff server off the installed `ruff`
      -- package, so it is configured here, not in the table below. client
      -- settings win over pyproject.toml under ruff's default `editorFirst`
      vim.lsp.config('ruff', {
        init_options = {
          settings = {
            lint = {
              ignore = { 'F821' },
            },
          },
        },
      })

      -- sqruff's tokens are coarser than the sql treesitter captures they would
      -- outrank: table names come through as `variable`, not `type`
      vim.lsp.config('sqruff', {
        on_init = function(client)
          client.server_capabilities.semanticTokensProvider = nil
        end,
      })

      local servers = {
        astro = {},
        basedpyright = {},
        bashls = {},
        clangd = {},
        cssls = {},
        eslint = {},
        gopls = {},
        html = {},
        jsonls = {},
        lua_ls = {},
        sqruff = {},
        tailwindcss = {},
        ts_ls = {},
        yamlls = {},
      }

      -- scheduled: the mason `setup{}` calls are slow on cold start and would block the triggering buffer
      vim.schedule(function()
        -- `vim.g.disable_mason_auto_install = true` in local.lua skips
        -- auto-install on machines without the runtimes mason needs;
        -- installed servers still attach
        local mason_auto_install = not vim.g.disable_mason_auto_install

        require('mason-lspconfig').setup {
          ensure_installed = mason_auto_install and vim.tbl_keys(servers or {}) or {},
          automatic_installation = false,
          automatic_enable = {
            exclude = { 'omnisharp' }, -- roslyn.nvim serves C#
          },
        }

        require('mason-tool-installer').setup {
          ensure_installed = mason_auto_install and {
            'astro',
            'basedpyright',
            'bashls',
            'clangd',
            'cssls',
            'eslint',
            'gopls',
            'html',
            'jsonls',
            'lua_ls',
            'sqruff',
            'tailwindcss',
            'ts_ls',
            'rust_analyzer',
            'yamlls',
            -- zls only attaches to its own zig minor series, and the servers
            -- list above takes no version, so zls is pinned here.
            -- mason-lspconfig enables it off the installed package
            { 'zls', version = '0.15.1' },
            -- from Crashdummyy/mason-registry
            'roslyn',
            -- configured in plugins/sonarlint.lua
            'sonarlint-language-server',
            'clang-format', -- c / cpp / objc
            'csharpier',
            'gofumpt',
            'goimports',
            'prettier',
            'shfmt',
            'stylua',
            'golangci-lint-langserver',
            'ruff',
            -- go codegen helpers (struct tags, iferr); wired in features/go.lua
            'gomodifytags',
            'iferr',
          } or {},
        }
      end)
    end,
  },

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
          if not is_real_file(0) then
            vim.notify('Not a file buffer; nothing to format', vim.log.levels.WARN)
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
        if not is_real_file(bufnr) then
          return
        end
        -- per-buffer / global opt-out (conform's convention); differ's merge tool
        -- sets the buffer flag so :w doesn't format over conflict markers
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
          return
        end
        -- node-based formatters are slow to start
        local slow_ft = {
          astro = true,
          javascript = true,
          javascriptreact = true,
          json = true,
          typescript = true,
          typescriptreact = true,
          yaml = true,
          cs = true,
          swift = true,
        }
        return {
          timeout_ms = slow_ft[vim.bo[bufnr].filetype] and 3000 or 500,
          lsp_format = 'fallback',
        }
      end,
      formatters_by_ft = {
        astro = { 'prettier' },
        c = { 'clang_format' },
        cpp = { 'clang_format' },
        cs = { 'csharpier' },
        objc = { 'clang_format' },
        objcpp = { 'clang_format' },
        swift = { 'swift_format' },
        go = { 'goimports', 'gofumpt' },
        javascript = { 'prettier' },
        javascriptreact = { 'prettier' },
        json = { 'prettier' },
        lua = { 'stylua' },
        python = { 'ruff_organize_imports', 'ruff_format' },
        sh = { 'shfmt' },
        sql = { 'sqruff' },
        bash = { 'shfmt' },
        rust = { 'rustfmt' },
        zsh = { 'shfmt' },
        typescript = { 'prettier' },
        typescriptreact = { 'prettier' },
        yaml = { 'prettier' },
      },
      formatters = {
        -- `-ci` keeps case bodies indented
        shfmt = {
          -- shfmt indents with tabs by default
          args = { '-i', '4', '-ci', '-filename', '$FILENAME' },
        },
        goimports = {
          command = vim.fn.stdpath 'data' .. '/mason/bin/goimports',
        },
        rustfmt = {
          -- stable rustfmt skips every unstable option, so a project that opts
          -- into them formats with nightly; never `+nightly` without one
          -- installed, rustup would download the toolchain mid-format
          prepend_args = function(_, ctx)
            local config = vim.fs.find({ 'rustfmt.toml', '.rustfmt.toml' }, { path = ctx.dirname, upward = true })[1]
            if not config then
              return {}
            end
            local unstable = false
            for line in io.lines(config) do
              if line:match '^%s*unstable_features%s*=%s*true' then
                unstable = true
                break
              end
            end
            local rustup_home = vim.env.RUSTUP_HOME or vim.fs.joinpath(vim.env.HOME, '.rustup')
            if not unstable or vim.fn.glob(vim.fs.joinpath(rustup_home, 'toolchains', 'nightly-*')) == '' then
              return {}
            end
            return { '+nightly' }
          end,
        },
        csharpier = {
          -- conform's default args are for `dotnet csharpier`; mason's
          -- standalone binary takes the `format` subcommand directly
          command = vim.fn.stdpath 'data' .. '/mason/bin/csharpier',
          args = { 'format', '--stdin-path', '$FILENAME' },
          stdin = true,
        },
        prettier = {
          -- the project's local prettier resolves .prettierrc plugins against
          -- the project's node_modules; mason's prettier is the fallback
          prefer_local = 'node_modules/.bin',
        },
      },
    },
  },
}
