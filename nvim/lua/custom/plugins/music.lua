return {
  {
    'seanhalberthal/music.nvim',
    config = function()
      require('music').setup {
        position = 'top-right',
      }
    end,
  },
}
