-- conform: formatting on save

--- true for ordinary on-disk file buffers. plugin buffers carry a `scheme://`
--- name or a non-empty `buftype`, and csharpier crashes resolving a config
--- directory from such a name
local function is_real_file(bufnr)
  if vim.bo[bufnr].buftype ~= '' then
    return false
  end
  return vim.api.nvim_buf_get_name(bufnr):match '^%w+://' == nil
end

return {
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
