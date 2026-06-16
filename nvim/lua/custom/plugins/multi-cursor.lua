-- multiple cursors via vim-visual-multi

return {
  {
    'mg979/vim-visual-multi',
    lazy = false,
    init = function()
      vim.g.VM_silent_exit = 1
      vim.g.VM_maps = {
        ['Add Cursor Up'] = '<M-Up>',
        ['Add Cursor Down'] = '<M-Down>',
        -- disable motions that conflict with buffer-local maps (markdown gj/gk,
        -- mkdnflow o/O/<Del>) and insert maps (blink.cmp) to avoid startup stutter
        ['Motion j'] = '',
        ['Motion k'] = '',
        ['o'] = '',
        ['O'] = '',
        ['Del'] = '',
        ['I CtrlB'] = '',
        ['I CtrlD'] = '',
        ['I CtrlF'] = '',
        ['I Return'] = '',
        ['I Down Arrow'] = '',
        ['I Up Arrow'] = '',
        ['Goto Prev'] = '',
        ['Goto Next'] = '',
      }
    end,
  },
}
