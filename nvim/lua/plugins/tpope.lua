-- tpope utilities:
--   * vim-abolish:  `:Subvert/`, `:Abolish`, `cr*` case coercions
--   * vim-repeat:   `.` repeats plugin actions (fugitive, abolish coercions)
-- mini.surround, built-in `gc` and mini.bracketed cover surround, commentary
-- and unimpaired

return {
  {
    'tpope/vim-abolish',
    cmd = { 'Abolish', 'Subvert', 'S' },
    event = 'VeryLazy',
  },

  {
    'tpope/vim-repeat',
    event = 'VeryLazy',
  },
}
