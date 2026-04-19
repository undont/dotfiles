-- Buffer removal without closing windows (mini.bufremove).

return {
  {
    'echasnovski/mini.bufremove',
    keys = {
      {
        '<leader>bd',
        function()
          require('mini.bufremove').delete(0, false)
        end,
        desc = '[D]elete buffer',
      },
      {
        '<leader>bD',
        function()
          require('mini.bufremove').delete(0, true)
        end,
        desc = '[D]elete buffer (force)',
      },
      {
        '<leader>ba',
        function()
          local current = vim.api.nvim_get_current_buf()
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if buf ~= current and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
              require('mini.bufremove').delete(buf, true)
            end
          end
        end,
        desc = 'Delete [A]ll other buffers',
      },
    },
  },
}
