-- deduplicated references/definitions/implementation/type-definition pickers.
-- extracted from plugins/lsp.lua. dedup(method) returns the keymap handler for
-- grr/gri/grd/grt: it drives the LSP request directly so empty results reach
-- our on_list path (the built-in handlers short-circuit on empty), dedupes
-- across mixed-encoding clients, jumps on a single hit, else opens telescope

local M = {}

local lsp_dedup_methods = {
  references = { lsp = 'textDocument/references', label = 'references' },
  implementation = { lsp = 'textDocument/implementation', label = 'implementations' },
  definition = { lsp = 'textDocument/definition', label = 'definitions' },
  type_definition = { lsp = 'textDocument/typeDefinition', label = 'type definitions' },
}

local function telescope_locations(title, items)
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local make_entry = require 'telescope.make_entry'
  local conf = require('telescope.config').values

  pickers
    .new({}, {
      prompt_title = title,
      finder = finders.new_table {
        results = items,
        entry_maker = make_entry.gen_from_quickfix {},
      },
      previewer = conf.qflist_previewer {},
      sorter = conf.generic_sorter {},
    })
    :find()
end

--- return the keymap handler for a dedup'd LSP location method
function M.dedup(method)
  local spec = assert(lsp_dedup_methods[method], 'unsupported lsp_dedup method: ' .. method)
  return function()
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local current_filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':p')
    local clients = vim.lsp.get_clients { bufnr = bufnr, method = spec.lsp }
    if #clients == 0 then
      vim.notify('No LSP client supports ' .. spec.label, vim.log.levels.WARN)
      return
    end

    -- build params per-client so mixed-encoding setups (e.g. utf-8 + utf-16
    -- LSPs on the same buffer) get correctly aligned column offsets. the
    -- response side already does this correctly via `client.offset_encoding`
    local function make_params(client)
      local p = vim.lsp.util.make_position_params(0, client.offset_encoding or 'utf-16')
      if method == 'references' then
        -- exclude the declaration so `grr` on a symbol with no callers triggers
        -- the `No references found` warning instead of jumping to the decl itself
        p.context = { includeDeclaration = false }
      end
      return p
    end

    vim.lsp.buf_request_all(bufnr, spec.lsp, make_params, function(responses)
      local seen = {}
      local items = {}
      for client_id, response in pairs(responses) do
        local result = response.result
        if result and not vim.tbl_isempty(result) then
          local client = vim.lsp.get_client_by_id(client_id)
          local enc = (client and client.offset_encoding) or 'utf-16'
          -- location methods can return a single Location; wrap into a list
          if not vim.islist(result) then
            result = { result }
          end
          for _, item in ipairs(vim.lsp.util.locations_to_items(result, enc)) do
            local key = item.filename .. ':' .. item.lnum .. ':' .. item.col
            local item_filename = vim.fn.fnamemodify(item.filename, ':p')
            local is_current_location = item_filename == current_filename and item.lnum == cursor[1] and item.col == (cursor[2] + 1)
            if not is_current_location and not seen[key] then
              seen[key] = true
              table.insert(items, item)
            end
          end
        end
      end

      if #items == 0 then
        vim.notify('No ' .. spec.label .. ' found', vim.log.levels.WARN)
        return
      end

      if #items == 1 then
        local line = items[1].lnum - 1
        local character = items[1].col - 1
        vim.lsp.util.show_document({
          uri = vim.uri_from_fname(items[1].filename),
          range = {
            start = { line = line, character = character },
            ['end'] = { line = line, character = character },
          },
        }, 'utf-8', { reuse_win = true, focus = true })
      else
        telescope_locations(spec.label, items)
      end
    end)
  end
end

return M
