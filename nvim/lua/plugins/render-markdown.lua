-- render-markdown: in-buffer rendering. lifts conceallevel to 3 while rendered

-- false for `cursorlineopt=number`, which only highlights the line number
local function cursorline_paints_row()
  if not vim.o.cursorline then
    return false
  end
  local opt = vim.o.cursorlineopt
  return opt:find('both', 1, true) ~= nil or opt:find('line', 1, true) ~= nil
end

return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = { 'markdown' },
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.nvim' },
    keys = {
      { '<leader>mr', '<cmd>RenderMarkdown buf_toggle<CR>', desc = 'Toggle markdown render', ft = 'markdown' },
    },
    opts = function()
      return {
        -- cursorline paints over the code background on the cursor row
        anti_conceal = { ignore = { code_background = not cursorline_paints_row() } },
        heading = {
          sign = false,
          icons = {},
          backgrounds = {},
          width = 'block',
        },
        bullet = { enabled = false },
        sign = { enabled = false },
      }
    end,
  },
}
