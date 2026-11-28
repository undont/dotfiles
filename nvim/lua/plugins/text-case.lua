-- text-case.nvim. the `:S` command is features/text-case-substitute

return {
  {
    'johmsalas/text-case.nvim',
    event = 'VeryLazy',
    config = function()
      require('textcase').setup { default_keymappings_enabled = false }
      require('features.text-case-substitute').setup()
    end,
  },
}
