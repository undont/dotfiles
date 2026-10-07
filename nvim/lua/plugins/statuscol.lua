-- statuscolumn: test/diagnostic/dap signs, then git signs, then the line number,
-- each sign kind in a fixed cell so a line carrying both shows both

-- right-aligned to the buffer's digit count; builtin.lnumfunc pads to
-- 'numberwidth' on top of the trailing space, one cell wider than the native column
local function lnum(args)
  if args.virtnum ~= 0 or not (args.nu or args.rnu) then
    return '%='
  end
  local n = (args.rnu and (args.relnum > 0 or not args.nu)) and args.relnum or args.lnum
  local width = #tostring(vim.api.nvim_buf_line_count(args.buf))
  return '%=' .. (' '):rep(width - #tostring(n)) .. n
end

return {
  {
    'luukvbaal/statuscol.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      require('statuscol').setup {
        -- oil draws two git status columns in its own signcolumn (see plugins/oil.lua).
        -- the rest are ui2's cmdline and message windows, which exist before this loads
        ft_ignore = { 'oil', 'cmd', 'msg', 'pager', 'dialog', 'differpanel' },
        segments = {
          -- highest priority wins the cell: neotest, then dotnet, then diagnostics
          { sign = { name = { '.*' }, namespace = { '.*' }, colwidth = 2 }, click = 'v:lua.ScSa' },
          { sign = { namespace = { 'gitsigns' }, colwidth = 1 }, click = 'v:lua.ScSa' },
          { text = { ' ', lnum, ' ' }, click = 'v:lua.ScLa' },
        },
      }
    end,
  },
}
