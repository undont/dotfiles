-- neo-tree set_parents crash patch. extracted from the neo-tree spec.
-- bug: when git reports deleted files whose parent dirs no longer exist,
-- set_parents crashes with "bad argument #1 to 'insert' (table expected, got
-- nil)" because it doesn't return after a pcall failure. apply() patches the
-- local function at runtime via debug.setupvalue so it survives plugin updates.

local M = {}

function M.apply()
  local ok, file_items = pcall(require, 'neo-tree.sources.common.file-items')
  if not ok then
    return
  end

  local create_item_fn = file_items.create_item

  -- find set_parents in create_item's upvalues (forward-declared local, shared slot)
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

  -- extract upvalues needed by set_parents
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

  -- patched set_parents: returns early when pcall fails instead of crashing
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

  -- replace in the shared upvalue slot (affects both create_item and set_parents)
  debug.setupvalue(create_item_fn, sp_idx, patched)
end

return M
