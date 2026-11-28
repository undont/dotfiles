-- the tab picker's rows and actions, and duplicate tab

local common = require("common")

local M = {}

local UNDO_FILE = common.CACHE .. "/window-undo.json"

-- every pane's name in layout order, after the tab's own label when it has one
local function tab_title(session_id, window)
    local names = {}
    for _, block in ipairs(common.layout_blocks(common.tiled_layout(window))) do
        local name = common.pane_name(session_id, block)
        if name ~= "" then
            table.insert(names, name)
        end
    end
    local panes = table.concat(names, ", ")
    local label = window.label or ""
    if common.is_default_tab_label(label) then
        return panes ~= "" and panes or label
    end
    return panes ~= "" and label .. ": " .. panes or label
end

-- rows are window_id, block_id to preview, session_id, display. all=1 lists
-- every session's tabs, prefixed with the session's label
function M.list(args)
    common.logo_header(4)
    local sessions = { { session_id = common.origin_session } }
    if args.all == "1" then
        sessions = common.sessions()
    end
    local rows = {}
    for _, session in ipairs(sessions) do
        local prefix = session.label and session.label .. ":" or ""
        local view = common.view(session.session_id)
        for n, window in ipairs(view and view.windows or {}) do
            table.insert(rows, {
                window = window.window_id,
                block = common.window_focus(window),
                session = session.session_id,
                display = prefix .. n .. "  " .. tab_title(session.session_id, window),
            })
        end
    end
    local sorted = common.sort_recent(rows, "window", function(r)
        return r.window
    end)
    for _, row in ipairs(sorted) do
        common.out(table.concat({ row.window, row.block, row.session, row.display }, "\t"))
    end
end

function M.select(args)
    common.jump(args.session, args.window)
end

-- the session's view and the window args names, by window= or by a block= in it
local function find(args)
    local view = common.view(args.session)
    if not view then
        return nil, nil
    end
    if args.window then
        return view, common.find_window(view, args.window)
    end
    for _, window in ipairs(view.windows or {}) do
        for _, layer in ipairs(window.layers) do
            for _, block in ipairs(layer.blocks) do
                if block.block_id == args.block then
                    return view, window
                end
            end
        end
    end
    return view, nil
end

-- the label to edit: empty for rex's placeholder label
function M.label(args)
    local _, window = find(args)
    local label = window and window.label or ""
    common.out(common.is_default_tab_label(label) and "" or label)
end

function M.rename(args)
    common.view(args.session)
    rex.session.set_window_label({ session_id = args.session, window_id = args.window, label = args.name })
end

-- "ask" or "deny", then the message, for the kill confirmation
function M.kill_check(args)
    local view, window = find(args)
    if not window then
        return
    end
    local name = common.tab_name(args.session, window)
    if #view.windows <= 1 then
        common.out("deny\tCan't kill '" .. name .. "': it's the session's only tab. Kill the session instead.")
        return
    end
    common.out("ask\tKill tab '" .. name .. "'?")
end

-- "ask" or "deny", then the message, for the move prompt
function M.move_check(args)
    local view, window = find(args)
    if not window then
        return
    end
    local name = common.tab_name(args.session, window)
    if #view.windows <= 1 then
        common.out("deny\tCan't move '" .. name .. "': it's the session's only tab.")
        return
    end
    if #common.sessions() <= 1 then
        common.out("deny\tCan't move '" .. name .. "': there's no other session.")
        return
    end
    local from = common.session_label(args.session) or ""
    common.out("ask\tMove tab '" .. name .. "' from '" .. from .. "' to:")
end

-- rows are session_id, label: every session but the tab's own
function M.move_targets(args)
    local rows = {}
    for _, session in ipairs(common.sessions()) do
        if session.session_id ~= args.session then
            table.insert(rows, { id = session.session_id, label = session.label or "" })
        end
    end
    local sorted = common.sort_recent(rows, "session", function(r)
        return r.id
    end)
    for _, row in ipairs(sorted) do
        common.out(row.id .. "\t" .. row.label)
    end
end

function M.move(args)
    common.view(args.session)
    common.view(args.to)
    rex.call("session.transfer_window", { session_id = args.session, window_id = args.window, to_session_id = args.to })
end

-- 1 when the picker's own tab has left the origin session, taking the picker with it
function M.popup_moved()
    if common.popup == "" then
        return
    end
    local _, window = find({ session = common.origin_session, block = common.popup })
    if not window then
        common.out("1")
    end
end

-- new_window args that rebuild the window, with its scrollback
local function snapshot(session_id, window)
    local args = common.snapshot_windows(session_id, { window })[1]
    args.session_id = session_id
    args.focus = false
    return args
end

function M.kill(args)
    local view, window = find(args)
    if not window or #view.windows <= 1 then
        return
    end
    common.write_undo(UNDO_FILE, snapshot(args.session, window))
    -- killing the tab this picker floats over ends the picker too
    rex.session.close_window({ session_id = args.session, window_id = window.window_id })
end

---@return string|nil session_id, string|nil window_id
function M.undo()
    local undo = common.read_undo(UNDO_FILE)
    if not undo then
        return nil
    end
    local args = undo.args
    if not common.session_label(args.session_id) then
        return nil
    end
    common.view(args.session_id)
    local created = rex.session.new_window(args)
    os.remove(UNDO_FILE)
    return args.session_id, created.window_id
end

-- a copy of the tab holding block beside it: same layout, directories and
-- scrollback, and the copy becomes the active tab
function M.duplicate(args)
    common.client = args.client
    local _, window = find(args)
    if not window then
        return
    end
    local new = snapshot(args.session, window)
    new.focus = true
    local created = rex.session.new_window(new)
    common.show_in_client(args.session, created.window_id)
end

M.UNDO_FILE = UNDO_FILE

return M
