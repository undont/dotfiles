-- inline diagnostic messages, overlaid as virtual text rather than inserted
-- as virtual lines

-- neotest's diagnostic consumer namespace, resolved by name so it doesn't pull
-- neotest in (as features/statusline.lua and features/lists.lua do)
local neotest_ns = vim.api.nvim_create_namespace 'neotest'

local function without_neotest(diagnostics)
  if not diagnostics then
    return diagnostics
  end
  local kept = {}
  for _, diag in ipairs(diagnostics) do
    if diag.namespace ~= neotest_ns then
      kept[#kept + 1] = diag
    end
  end
  return kept
end

-- the renderer reads every namespace and offers no way to exclude one, so a
-- failing test drew its assertion message inline on top of neotest's own output
-- float. filter at the cache instead: the namespace stays populated for the
-- statusline's ✗N count and for ]t/[t. `update_from_event` resyncs through
-- `M.update` on an empty payload, so wrapping both covers that path too
local function drop_neotest_diagnostics()
  local cache = require 'tiny-inline-diagnostic.cache'
  local update, update_from_event = cache.update, cache.update_from_event
  cache.update = function(bufnr, diagnostics)
    return update(bufnr, without_neotest(diagnostics))
  end
  cache.update_from_event = function(bufnr, event_diags)
    return update_from_event(bufnr, without_neotest(event_diags))
  end
end

return {
  {
    'rachartier/tiny-inline-diagnostic.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function(_, opts)
      drop_neotest_diagnostics()
      require('tiny-inline-diagnostic').setup(opts)
    end,
    opts = {
      preset = 'classic',
      options = {
        -- `format` replaces the whole message rather than wrapping it, so it
        -- owns the code prefix that `show_code` would otherwise append. gopls
        -- labels every analyzer finding with the placeholder "default"
        show_code = false,
        format = function(diag)
          if diag.code and diag.code ~= 'default' then
            return string.format('%s: %s', diag.code, diag.message)
          end
          return diag.message
        end,
        -- the cursor line renders every diagnostic on it, not only the one
        -- spanning the cursor column
        show_all_diags_on_cursorline = true,
        -- errors render on every line they mark; warnings, info and hints wait
        -- for the cursor. `always_show` and its severity filter are both inert
        -- unless `enabled` is set
        multilines = {
          enabled = true,
          always_show = true,
          severity = { vim.diagnostic.severity.ERROR },
        },
      },
    },
  },
}
