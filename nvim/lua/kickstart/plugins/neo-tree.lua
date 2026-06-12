-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

--- Patch neo-tree set_parents to handle deleted files in git status.
--- Bug: when git reports deleted files whose parent dirs no longer exist,
--- set_parents crashes with "bad argument #1 to 'insert' (table expected, got nil)"
--- because it doesn't return after pcall failure. This patches the local function
--- at runtime via debug.setupvalue so it survives plugin updates.
local function patch_set_parents()
  local ok, file_items = pcall(require, 'neo-tree.sources.common.file-items')
  if not ok then
    return
  end

  local create_item_fn = file_items.create_item

  -- Find set_parents in create_item's upvalues (forward-declared local, shared slot)
  local sp_idx
  for i = 1, 30 do
    local name = debug.getupvalue(create_item_fn, i)
    if not name then
      break
    end
    if name == 'set_parents' then
      sp_idx = i
      break
    end
  end
  if not sp_idx then
    return
  end

  local _, orig_sp = debug.getupvalue(create_item_fn, sp_idx)

  -- Extract upvalues needed by set_parents
  local upvals = {}
  for i = 1, 30 do
    local name, val = debug.getupvalue(orig_sp, i)
    if not name then
      break
    end
    upvals[name] = val
  end

  local utils = upvals.utils
  local inner_create_item = upvals.create_item
  if not (utils and inner_create_item) then
    return
  end

  -- Patched set_parents: returns early when pcall fails instead of crashing
  local patched
  patched = function(context, item)
    if context.item_exists[item.id] then
      return
    end
    if not item.parent_path then
      return
    end
    local parent = context.folders[item.parent_path]
    if not utils.truthy(item.parent_path) then
      return
    end
    if parent == nil then
      local success
      success, parent = pcall(inner_create_item, context, item.parent_path)
      if not success then
        return
      end
      context.folders[parent.id] = parent
      patched(context, parent)
    end
    if not parent or not parent.children then
      return
    end
    table.insert(parent.children, item)
    context.item_exists[item.id] = item
    if not item.filtered_by and parent.filtered_by then
      item.filtered_by = { parent = parent.filtered_by }
    end
  end

  -- Replace in the shared upvalue slot (affects both create_item and set_parents)
  debug.setupvalue(create_item_fn, sp_idx, patched)
end

return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
  },
  lazy = false,
  keys = {
    { '|', ':Neotree reveal<CR>', desc = 'NeoTree reveal', silent = true },
  },
  opts = {
    popup_border_style = 'rounded',
    window = {
      mappings = {
        ['o'] = 'open',
        -- Move order_by prefix from o to O so o opens immediately
        ['oc'] = 'none',
        ['od'] = 'none',
        ['og'] = 'none',
        ['om'] = 'none',
        ['on'] = 'none',
        ['os'] = 'none',
        ['ot'] = 'none',
        ['O'] = { 'show_help', nowait = false, config = { title = 'Order by', prefix_key = 'O' } },
        ['Oc'] = { 'order_by_created', nowait = false },
        ['Od'] = { 'order_by_diagnostics', nowait = false },
        ['Og'] = { 'order_by_git_status', nowait = false },
        ['Om'] = { 'order_by_modified', nowait = false },
        ['On'] = { 'order_by_name', nowait = false },
        ['Os'] = { 'order_by_size', nowait = false },
        ['Ot'] = { 'order_by_type', nowait = false },
        ['<C-j>'] = function(state)
          vim.api.nvim_feedkeys('j', 'n', false)
        end,
        ['<C-k>'] = function(state)
          vim.api.nvim_feedkeys('k', 'n', false)
        end,
      },
    },
    filesystem = {
      -- Let oil.nvim own directory buffers (`nvim <dir>`, the `config`/`launchers`
      -- aliases). Neo-tree stays available on `|`; it just no longer hijacks netrw.
      hijack_netrw_behavior = 'disabled',
      filtered_items = {
        visible = true,
        hide_dotfiles = false,
        hide_gitignored = false,
        never_show = { '.DS_Store' },
      },
      window = {
        mappings = {
          ['|'] = 'close_window',
        },
        fuzzy_finder_mappings = {
          ['<C-j>'] = 'move_cursor_down',
          ['<C-k>'] = 'move_cursor_up',
        },
      },
    },
  },
  config = function(_, opts)
    require('neo-tree').setup(opts)
    patch_set_parents()
  end,
}
