-- floating layers that run the scripts in bash/, the view lookups they need,
-- and the key + action helper

local hosts = require("hosts")

local M = {}

local PICKER_LABEL = "picker"

---@param key string
---@param name string
---@param title string
---@param run fun(ctx: table)
function M.action(key, name, title, run)
    rex.action({ name = name, title = title, run = run })
    rex.bind(key, name)
end

function M.active_window()
    local view = rex.session.view({})
    for _, win in ipairs(view.windows) do
        if win.window_id == view.active_window_id then
            return win
        end
    end
end

function M.is_picker(block_id)
    return rex.session.describe_block({ block_id = block_id }).block.label == PICKER_LABEL
end

-- the { x, y, w, h } a tiled block fills in its window, or nil for a floating one
function M.block_rect(win, block_id)
    local function find(node)
        if node.block_id == block_id then
            return node.rect
        end
        if not node.split then
            return nil
        end
        return find(node.split.before) or find(node.split.after)
    end
    for _, layer in ipairs(win.layers) do
        if layer.kind == "tiled" then
            return find(layer.layout)
        end
    end
end

-- the rect a pane fills: the whole window when it's zoomed
function M.pane_rect(win, block_id)
    if win.zoomed_block_id == block_id then
        return { 0, 0, 1, 1 }
    end
    return M.block_rect(win, block_id)
end

-- popup sizes the app gave before, one "key columns rows" line each. the app
-- sizes a layer from pixels, so the size is learned here, not computed;
-- wait_for_resize in bash/_lib.sh reports it through save_popup_size
-- (lua/app-actions.lua), on the home server even when the popup is on another host
M.POPUP_SIZES = (os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") .. "/.cache")) .. "/rex/popup-sizes"

-- the popup's bounds and its window's size in cells, read from the origin
-- block's size and the fraction of the window it fills
---@return string|nil
local function popup_size_key(ctx, win, bounds)
    if not ctx.block_id then
        return nil
    end
    local rect = M.pane_rect(win, ctx.block_id)
    if not rect then
        return nil
    end
    local ok, size = pcall(rex.block.call, "com.superlogical.terminal", "size", {
        session_id = ctx.session_id,
        block_id = ctx.block_id,
    })
    if not ok or not size then
        return nil
    end
    local columns = math.floor(size.columns / rect[3] + 0.5)
    local rows = math.floor(size.rows / rect[4] + 0.5)
    return string.format("%dx%d@%gx%g", columns, rows, bounds[3], bounds[4])
end

---@return integer|nil columns, integer|nil rows
local function cached_popup_size(key)
    local f = io.open(M.POPUP_SIZES, "r")
    if not f then
        return nil
    end
    for line in f:lines() do
        local k, columns, rows = line:match("^(%S+) (%d+) (%d+)$")
        if k == key then
            f:close()
            return tonumber(columns), tonumber(rows)
        end
    end
    f:close()
end

-- a script in a floating layer, which closes when the script exits
---@param ctx table
---@param script string
---@param bounds number[] { x, y, w, h } fractions of the window
---@param args? string[] passed after the client, session and block ids
function M.open(ctx, script, bounds, args)
    -- a key pressed inside a picker would open another one over it
    if ctx.block_id and M.is_picker(ctx.block_id) then
        return
    end
    -- focusing the popup undoes a zoom, so the script re-zooms the pane on exit
    local win = M.active_window()
    local zoomed = ""
    if ctx.block_id and win.zoomed_block_id == ctx.block_id then
        zoomed = "1"
    end
    -- the pickers sort by the visits recent.lua logs
    hosts.start_recent()
    -- the layer's terminal runs on the session's host, which may not be the one
    -- running this action, so its own shell resolves $HOME
    local command = {
        "/bin/sh",
        "-c",
        'exec "$HOME/.config/rex/bash/$0" "$@"',
        script,
        ctx.client_id,
        ctx.session_id,
        ctx.block_id or "",
        zoomed,
    }
    for _, arg in ipairs(args or {}) do
        table.insert(command, arg)
    end
    -- the script matches the label to the app's client on the session's host
    local env = { "/usr/bin/env", "PICK_CLIENT_LABEL=" .. hosts.client_label(ctx.client_id) }
    local key = popup_size_key(ctx, win, bounds)
    if key then
        table.insert(env, "PICK_SIZE_KEY=" .. key)
    end
    for i, arg in ipairs(env) do
        table.insert(command, i, arg)
    end
    local layer = rex.session.new_layer({
        bounds = bounds,
        focus = true,
        layout = rex.layout.block({
            flavor = "com.superlogical.terminal.shell",
            label = PICKER_LABEL,
            options = { command = command },
        }),
    })
    -- sized before the script reads it, so wait_for_resize returns at once
    local columns, rows = cached_popup_size(key)
    if columns and layer and layer.block_ids then
        pcall(rex.block.call, "com.superlogical.terminal", "resize", {
            session_id = ctx.session_id,
            block_id = layer.block_ids[1],
            columns = columns,
            rows = rows,
        })
    end
end

-- an action opening a script in a centred floating layer
---@param script string
---@param size number|number[] fraction of the window, or { width, height }
---@param args? string[]
---@return fun(ctx: table)
function M.picker(script, size, args)
    local w, h = size, size
    if type(size) == "table" then
        w, h = size[1], size[2]
    end
    return function(ctx)
        M.open(ctx, script, { (1 - w) / 2, (1 - h) / 2, w, h }, args)
    end
end

return M
