-- <leader>? picker over nvim/cheatsheet.txt: `## section @tag` headers, `description | keys` rows

local M = {}

local path = vim.fn.stdpath 'config' .. '/cheatsheet.txt'

---@return { section: string, desc: string, keys: string }[] entries, integer section_width, integer desc_width
local function read_entries()
  local entries = {}
  local section = ''
  local section_width, desc_width = 0, 0
  for _, line in ipairs(vim.fn.readfile(path)) do
    local header = line:match '^##%s*(.-)%s*@' or line:match '^##%s*(.-)%s*$'
    if header then
      section = header
    else
      local desc, keys = line:match '^(.-)%s*|%s*(.+)$'
      if desc then
        section_width = math.max(section_width, vim.fn.strdisplaywidth(section))
        desc_width = math.max(desc_width, vim.fn.strdisplaywidth(desc))
        table.insert(entries, { section = section, desc = desc, keys = keys })
      end
    end
  end
  return entries, section_width, desc_width
end

function M.open()
  local entries, section_width, desc_width = read_entries()

  local displayer = require('telescope.pickers.entry_display').create {
    separator = '  ',
    items = { { width = section_width }, { width = desc_width }, { remaining = true } },
  }

  require('telescope.pickers')
    .new({}, {
      prompt_title = 'Cheatsheet',
      finder = require('telescope.finders').new_table {
        results = entries,
        entry_maker = function(entry)
          return {
            value = entry,
            ordinal = entry.section .. ' ' .. entry.desc .. ' ' .. entry.keys,
            display = function(e)
              return displayer {
                { e.value.section, 'TelescopeResultsComment' },
                e.value.desc,
                { e.value.keys, 'TelescopeResultsIdentifier' },
              }
            end,
          }
        end,
      },
      sorter = require('telescope.config').values.generic_sorter {},
      attach_mappings = function(bufnr)
        local actions = require 'telescope.actions'
        actions.select_default:replace(function()
          actions.close(bufnr)
        end)
        return true
      end,
    })
    :find()
end

function M.setup()
  vim.keymap.set('n', '<leader>?', M.open, { desc = 'Open cheatsheet' })
end

return M
