-- Dynamic diff highlights
-- Computes tinted backgrounds from the active Normal bg so diff colours
-- stay consistent across diffview and octo for every theme.

local M = {}

--- Blend `colour` towards the Normal background by `amount` (0–1).
function M.tint_bg(colour, amount)
  local normal_bg = vim.api.nvim_get_hl(0, { name = 'Normal', link = false }).bg or 0x1e1e2e
  local r1, g1, b1 = bit.rshift(normal_bg, 16), bit.band(bit.rshift(normal_bg, 8), 0xff), bit.band(normal_bg, 0xff)
  local r2, g2, b2 = bit.rshift(colour, 16), bit.band(bit.rshift(colour, 8), 0xff), bit.band(colour, 0xff)
  return bit.bor(bit.lshift(math.floor(r1 + (r2 - r1) * amount), 16), bit.lshift(math.floor(g1 + (g2 - g1) * amount), 8), math.floor(b1 + (b2 - b1) * amount))
end

--- Resolve the fg colour from a highlight group, with fallback.
local function get_fg(group, fallback)
  local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
  return hl.fg or fallback
end

function M.apply()
  local tint = M.tint_bg

  -- Use the theme's palette colours as tint sources (fall back to sensible defaults)
  local green_fg = get_fg('GitSignsAdd', 0xa6e3a1)
  local yellow_fg = get_fg('GitSignsChange', 0xf9e2af)
  local red_fg = get_fg('GitSignsDelete', 0xf38ba8)

  -- Diff* line backgrounds — blend theme colours towards Normal bg
  local add_bg = tint(green_fg, 0.18)
  local change_bg = tint(yellow_fg, 0.18)
  local del_bg = tint(red_fg, 0.18)
  local text_bg = tint(yellow_fg, 0.30)

  -- Core Vim diff groups (used by diffview, octo)
  vim.api.nvim_set_hl(0, 'DiffAdd', { bg = add_bg })
  vim.api.nvim_set_hl(0, 'DiffChange', { bg = change_bg })
  vim.api.nvim_set_hl(0, 'DiffDelete', { bg = del_bg })
  vim.api.nvim_set_hl(0, 'DiffText', { bg = text_bg, bold = true })

  -- Octo review inline word-change highlights (per-pane DiffText override).
  -- Octo links these from its left/right namespaces; we colour them from the
  -- theme palette so they match the rest of our diff tinting.
  vim.api.nvim_set_hl(0, 'OctoReviewDiffDeleteText', { bg = tint(red_fg, 0.35), bold = true })
  vim.api.nvim_set_hl(0, 'OctoReviewDiffAddText', { bg = tint(green_fg, 0.35), bold = true })

  -- GitSigns line highlights
  vim.api.nvim_set_hl(0, 'GitSignsAddLn', { bg = add_bg })
  vim.api.nvim_set_hl(0, 'GitSignsChangeLn', { bg = change_bg })
  vim.api.nvim_set_hl(0, 'GitSignsDeleteLn', { bg = del_bg })

  -- GitSigns number column highlights
  vim.api.nvim_set_hl(0, 'GitSignsAddNr', { fg = green_fg, bg = add_bg })
  vim.api.nvim_set_hl(0, 'GitSignsChangeNr', { fg = yellow_fg, bg = change_bg })
  vim.api.nvim_set_hl(0, 'GitSignsDeleteNr', { fg = red_fg, bg = del_bg })

  -- Diffview file panel: pin insertion/deletion counts to theme green/red
  -- regardless of how the theme defines diffAdded/diffRemoved.
  vim.api.nvim_set_hl(0, 'DiffviewFilePanelInsertions', { fg = green_fg })
  vim.api.nvim_set_hl(0, 'DiffviewFilePanelDeletions', { fg = red_fg })

  -- Octo: same treatment for review file panel + PR diffstats
  vim.api.nvim_set_hl(0, 'OctoDiffstatAdditions', { fg = green_fg })
  vim.api.nvim_set_hl(0, 'OctoDiffstatDeletions', { fg = red_fg })
  vim.api.nvim_set_hl(0, 'OctoPullAdditions', { fg = green_fg })
  vim.api.nvim_set_hl(0, 'OctoPullDeletions', { fg = red_fg })

  -- Status markers (A/D/M/?/R/C/U/T/X/B/!) → semantic git-status colours,
  -- shared across the diffview and octo file panels. Mirrors the diffstat-bar
  -- palette (green add / red delete) so the letter agrees with the bar:
  --   added/untracked → green, modified → yellow, renamed/copied/typechange →
  --   blue, deleted/broken → red, unmerged (conflict) → orange, unknown/ignored
  --   → grey.
  -- Note: both plugins render type-changes via `…StatusTypeChanged` (with a 'd')
  -- even though their defaults link the 'd'-less name, so we key off the former.
  local blue_fg = get_fg('Function', 0x89b4fa)
  local orange_fg = get_fg('Number', 0xfab387)
  local grey_fg = get_fg('Comment', 0x6c7086)

  local status_colours = {
    Added = green_fg,
    Untracked = green_fg,
    Modified = yellow_fg,
    Renamed = blue_fg,
    Copied = blue_fg,
    TypeChanged = blue_fg,
    Unmerged = orange_fg,
    Unknown = grey_fg,
    Deleted = red_fg,
    Broken = red_fg,
    Ignored = grey_fg,
  }
  for suffix, fg in pairs(status_colours) do
    vim.api.nvim_set_hl(0, 'DiffviewStatus' .. suffix, { fg = fg })
    vim.api.nvim_set_hl(0, 'OctoStatus' .. suffix, { fg = fg })
  end
end

function M.setup()
  M.apply()
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('diff-highlights', { clear = true }),
    callback = M.apply,
  })
end

return M
