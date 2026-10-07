return {
  {
    'mfussenegger/nvim-lint',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local lint = require 'lint'
      lint.linters_by_ft = {
        swift = { 'swiftlint' },
      }

      local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
      vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
        group = lint_augroup,
        callback = function()
          -- skips LSP hover pop-ups
          if not vim.bo.modifiable then
            return
          end
          local runnable = {}
          for _, name in ipairs(lint.linters_by_ft[vim.bo.filetype] or {}) do
            -- a linter module is the spec table or a factory returning one
            -- (swiftlint), and `cmd` only exists on the table
            local linter = lint.linters[name]
            if type(linter) == 'function' then
              linter = linter()
            end
            local cmd = type(linter) == 'table' and (type(linter.cmd) == 'function' and linter.cmd() or linter.cmd)
            if cmd and vim.fn.executable(cmd) == 1 then
              table.insert(runnable, name)
            end
          end
          if #runnable > 0 then
            lint.try_lint(runnable)
          end
        end,
      })

      require('features.sqlc-lint').setup()
    end,
  },
}
