-- must.nvim: rfc reader

-- true runs must from the ~/playground/must.nvim checkout (restart nvim).
-- falls back to the release when the checkout has no entry module
local MUST_DEV = true
local MUST_LOCAL = vim.fn.expand '~/playground/must.nvim'
local MUST_USE_DEV = MUST_DEV and vim.fn.filereadable(MUST_LOCAL .. '/lua/must/init.lua') == 1

return {
  {
    'undont/must.nvim',
    dir = MUST_USE_DEV and MUST_LOCAL or nil,
    cmd = 'Must',
  },
}
