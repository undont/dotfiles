-- Claude Code prompt editing: <leader>c* comment block keymaps in any markdown
-- file, and an @ file picker in prompt files (claude-prompt-*.md, or any .md
-- under .claude/ or .plans/). see features/claude-comments and
-- features/prompt-file-ref

return {
  {
    dir = vim.fn.stdpath 'config',
    name = 'claude-prompt',
    enabled = true,
    ft = 'markdown',
    config = function()
      local group = vim.api.nvim_create_augroup('claude-prompt', { clear = true })

      vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
        pattern = '*.md',
        group = group,
        callback = function(ev)
          require('custom.features.claude-comments').setup(ev.buf)

          local filename = vim.fn.fnamemodify(ev.file, ':t')
          local abs_path = vim.fn.fnamemodify(ev.file, ':p')
          if not filename:match '^claude%-prompt%-.*%.md$' and not abs_path:match '/%.claude/' and not abs_path:match '/%.plans/' then
            return
          end

          require('custom.features.prompt-file-ref').setup(ev.buf)
        end,
      })
    end,
  },
}
