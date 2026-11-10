-- the tab picker's rows and actions, and duplicate tab

local common = require("common")

local M = {}

local UNDO_FILE = common.CACHE .. "/window-undo.json"
local UNDO_DIR = common.CACHE .. "/window-undo"

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
                display = prefix .. n .. "  " .. common.tab_name(session.session_id, window),
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
    for _, window in ipairs(view.windows) do
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

-- new_window args that rebuild the window, with its scrollback saved under dir
local function snapshot(session_id, window, dir)
    local args = common.snapshot_windows(session_id, { window }, dir)[1]
    args.session_id = session_id
    args.focus = false
    return args
end

function M.kill(args)
    local view, window = find(args)
    if not window or #view.windows <= 1 then
        return
    end
    common.write_private(UNDO_FILE, rex.json.encode(snapshot(args.session, window, UNDO_DIR)))
    -- killing the tab this picker floats over ends the picker too
    rex.session.close_window({ session_id = args.session, window_id = window.window_id })
end

function M.undo()
    local text = common.read_file(UNDO_FILE)
    if not text or text == "" then
        return
    end
    local args = rex.json.decode(text)
    if not common.session_label(args.session_id) then
        return
    end
    common.view(args.session_id)
    rex.session.new_window(args)
    os.remove(UNDO_FILE)
end

-- a copy of the tab holding block beside it: same layout, directories and
-- scrollback, and the copy becomes the active tab
function M.duplicate(args)
    common.client = args.client
    local _, window = find(args)
    if not window then
        return
    end
    local new = snapshot(args.session, window, common.CACHE .. "/window-duplicate")
    new.focus = true
    local created = rex.session.new_window(new)
    common.show_in_client(args.session, created.window_id)
end

M.UNDO_FILE = UNDO_FILE

return M
