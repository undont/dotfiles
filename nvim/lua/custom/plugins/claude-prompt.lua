-- Claude Code prompt editing support
-- For any markdown file:
--   - <leader>c* keymaps for comment block management (insert, navigate, toggle, delete)
-- For Claude prompt files (claude-prompt-*.md, or any .md under .claude/ or .plans/):
--   - @ in insert mode opens Telescope file finder for project file references
--   - @@ inserts a literal @ character
-- The bespoke pieces live in features/claude-comments and features/prompt-file-ref.

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
          -- Comment block keymaps apply to every markdown file
          require('custom.features.claude-comments').setup(ev.buf)

          -- @ file picker is scoped to Claude Code prompt files, .claude/, and .plans/
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
