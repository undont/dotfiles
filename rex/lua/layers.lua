-- floating layers that run the scripts in bash/, and the view lookups they need

local M = {}

M.do_scripts = os.getenv("HOME") .. "/.config/rex/do/"
-- the macOS server's PATH has no rex
M.rex = "rex"
local app_rex = os.getenv("HOME")
    .. "/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex"
local app_file = io.open(app_rex)
-- the machine running the app, which keeps the back/forward history
M.has_app = app_file ~= nil
if app_file then
    app_file:close()
    M.rex = app_rex
end

local PICKER_LABEL = "picker"

-- run a script in the background. the server's PATH has no homebrew (no jq, and
-- /usr/bin/env bash finds bash 3.2), so the user's login shell loads it, as
-- popup shells do. the server's environment may not set SHELL, and on linux
-- the shell can live outside /bin (linuxbrew's zsh)
local LOGIN_SHELL = 's=${SHELL:-$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)}; '
    .. "exec \"${s:-/bin/zsh}\" -lc 'exec \"$@\"' sh \"$@\""

---@param argv string[]
function M.run_script(argv)
    local command = { "/bin/sh", "-c", LOGIN_SHELL, "sh" }
    for _, arg in ipairs(argv) do
        table.insert(command, arg)
    end
    rex.exec.start(command, { detach = true })
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

-- the label the app gave its client, which names the same app on every host
---@param client_id string
---@return string
function M.client_label(client_id)
    local list = rex.call("client.list", {})
    for _, client in ipairs(list and list.clients or {}) do
        if client.client_id == client_id then
            return client.info and client.info.label or ""
        end
    end
    return ""
end

-- run pick.lua with KEY=VALUE args in the background, against the session's
-- host when it isn't this one. the server's PATH has no rex, so it's called by
-- its installed path
---@param args string[]
---@param server? string ctx.server
function M.run_pick(args, server)
    local command = { M.rex, "--timeout", "3s" }
    if server then
        table.insert(command, "-S")
        table.insert(command, server)
    end
    table.insert(command, "do")
    table.insert(command, M.do_scripts .. "pick.lua")
    for _, arg in ipairs(args) do
        table.insert(command, arg)
    end
    M.run_script(command)
end

-- start the recent.lua watcher unless one is running, so a config reload
-- doesn't start a second; it starts the other hosts' watchers itself, since
-- rex.servers() is empty while the config loads. only on the machine running
-- the app, which keeps the history. rex's own path has a space in it, so the
-- match is on the arguments
function M.start_recent()
    if not M.has_app then
        return
    end
    local running = rex.exec({ "/usr/bin/pgrep", "-f", "do --all .*/rex/do/recent\\.lua rex=" })
    if running and running.ok then
        return
    end
    rex.exec.start(
        { M.rex, "do", "--all", M.do_scripts .. "recent.lua", "rex=" .. M.rex },
        { detach = true, stdout = false, stderr = false }
    )
end

-- popup sizes the app gave before, one "key columns rows" line each. the app
-- sizes a layer from pixels, so the size is learned here, not computed;
-- wait_for_resize in bash/_lib.sh reports it through save_popup_size, which
-- runs here even when the popup is on another host
local POPUP_SIZES = (os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") .. "/.cache")) .. "/rex/popup-sizes"

rex.action({
    name = "save_popup_size",
    title = "Save Popup Size",
    args = { key = "string", columns = "number", rows = "number" },
    run = function(_, args)
        local lines = {}
        local f = io.open(POPUP_SIZES, "r")
        if f then
            for line in f:lines() do
                if line:match("^(%S+)") ~= args.key then
                    table.insert(lines, line)
                end
            end
            f:close()
        end
        table.insert(lines, string.format("%s %d %d", args.key, args.columns, args.rows))
        local tmp = POPUP_SIZES .. ".tmp"
        local out = io.open(tmp, "w")
        if not out then
            return
        end
        out:write(table.concat(lines, "\n"), "\n")
        out:close()
        os.rename(tmp, POPUP_SIZES)
    end,
})

-- the popup's bounds and its window's size in cells, read from the origin
-- block's size and the fraction of the window it fills
---@return string|nil
local function popup_size_key(ctx, win, bounds)
    if not ctx.block_id then
        return nil
    end
    local rect = { 0, 0, 1, 1 }
    if win.zoomed_block_id ~= ctx.block_id then
        rect = M.block_rect(win, ctx.block_id)
    end
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
    local f = io.open(POPUP_SIZES, "r")
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
    M.start_recent()
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
    local env = { "/usr/bin/env", "PICK_CLIENT_LABEL=" .. M.client_label(ctx.client_id) }
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
