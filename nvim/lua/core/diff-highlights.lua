-- diff highlights: backgrounds tinted from the active Normal bg, shared by
-- differ, native diff and gitsigns

local M = {}

--- blend `colour` towards the Normal background by `amount` (0 to 1)
function M.tint_bg(colour, amount)
  local normal_bg = vim.api.nvim_get_hl(0, { name = 'Normal', link = false }).bg or 0x1e1e2e
  local r1, g1, b1 = bit.rshift(normal_bg, 16), bit.band(bit.rshift(normal_bg, 8), 0xff), bit.band(normal_bg, 0xff)
  local r2, g2, b2 = bit.rshift(colour, 16), bit.band(bit.rshift(colour, 8), 0xff), bit.band(colour, 0xff)
  return bit.bor(bit.lshift(math.floor(r1 + (r2 - r1) * amount), 16), bit.lshift(math.floor(g1 + (g2 - g1) * amount), 8), math.floor(b1 + (b2 - b1) * amount))
end

local function get_fg(group, fallback)
  local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
  return hl.fg or fallback
end

function M.apply()
  local tint = M.tint_bg

  local green_fg = get_fg('GitSignsAdd', 0xa6e3a1)
  local yellow_fg = get_fg('GitSignsChange', 0xf9e2af)
  local red_fg = get_fg('GitSignsDelete', 0xf38ba8)

  local add_bg = tint(green_fg, 0.18)
  local change_bg = tint(yellow_fg, 0.18)
  local del_bg = tint(red_fg, 0.18)
  local text_bg = tint(yellow_fg, 0.30)

  vim.api.nvim_set_hl(0, 'DiffAdd', { bg = add_bg })
  vim.api.nvim_set_hl(0, 'DiffChange', { bg = change_bg })
  vim.api.nvim_set_hl(0, 'DiffDelete', { bg = del_bg })
  vim.api.nvim_set_hl(0, 'DiffText', { bg = text_bg, bold = true })

  vim.api.nvim_set_hl(0, 'GitSignsAddLn', { bg = add_bg })
  vim.api.nvim_set_hl(0, 'GitSignsChangeLn', { bg = change_bg })
  vim.api.nvim_set_hl(0, 'GitSignsDeleteLn', { bg = del_bg })

  vim.api.nvim_set_hl(0, 'GitSignsAddNr', { fg = green_fg, bg = add_bg })
  vim.api.nvim_set_hl(0, 'GitSignsChangeNr', { fg = yellow_fg, bg = change_bg })
  vim.api.nvim_set_hl(0, 'GitSignsDeleteNr', { fg = red_fg, bg = del_bg })
end

function M.setup()
  M.apply()
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('diff-highlights', { clear = true }),
    callback = M.apply,
  })
end

return M
