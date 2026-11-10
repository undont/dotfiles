-- client capabilities for every server: nvim's defaults plus what blink.cmp's
-- get_lsp_capabilities() adds, so servers get them without blink loading at startup

local M = {}

local blink_completion = {
  textDocument = {
    completion = {
      completionItem = {
        resolveSupport = { properties = { 'documentation', 'detail', 'additionalTextEdits', 'command', 'data' } },
        insertTextModeSupport = { valueSet = { 1 } },
      },
      completionList = {
        itemDefaults = { 'commitCharacters', 'editRange', 'insertTextFormat', 'insertTextMode', 'data' },
      },
      insertTextMode = 1,
    },
  },
}

function M.get()
  return vim.tbl_deep_extend('force', vim.lsp.protocol.make_client_capabilities(), blink_completion)
end

-- every value here is in blink's table; list entries match in any order
local function covered(mine, theirs)
  if type(mine) ~= 'table' or type(theirs) ~= 'table' then
    return mine == theirs
  end
  if vim.islist(mine) then
    for _, item in ipairs(mine) do
      if not vim.list_contains(theirs, item) then
        return false
      end
    end
    return true
  end
  for key, value in pairs(mine) do
    if not covered(value, theirs[key]) then
      return false
    end
  end
  return true
end

-- run from blink's config, once it has loaded. blink merges its own additions
-- into vim.lsp.config('*') when it loads, but these values override its own
function M.check_blink()
  if not covered(blink_completion, require('blink.cmp').get_lsp_capabilities()) then
    vim.notify('blink.cmp no longer advertises some lsp capabilities in features/lsp-capabilities.lua', vim.log.levels.WARN)
  end
end

return M
