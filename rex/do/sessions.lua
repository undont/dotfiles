-- the session picker's rows and actions

local common = require("common")

local M = {}

local UNDO_FILE = common.CACHE .. "/session-undo.json"

-- rows are session_id, block_id to preview, label
function M.list()
    common.logo_header(3)
    local rows = {}
    for _, session in ipairs(common.sessions()) do
        local view = common.view(session.session_id)
        local block = ""
        for _, window in ipairs(view and view.windows or {}) do
            if window.window_id == view.active_window_id then
                block = common.window_focus(window)
            end
        end
        -- the origin session's focused block is the picker, so it previews the
        -- block focused before the picker opened
        if session.session_id == common.origin_session then
            block = common.origin_block
        end
        table.insert(rows, { id = session.session_id, block = block, label = session.label })
    end
    local sorted = common.sort_recent(rows, "session", function(r)
        return r.id
    end)
    for _, row in ipairs(sorted) do
        common.out(row.id .. "\t" .. row.block .. "\t" .. row.label)
    end
end

function M.select(args)
    common.jump(args.session)
end

function M.label(args)
    common.out(common.session_label(args.session) or "")
end

function M.rename(args)
    common.view(args.session)
    rex.call("session.set_label", { session_id = args.session, label = args.name })
end

-- an existing session with that label, or a new one in $HOME
function M.new(args)
    for _, session in ipairs(common.sessions()) do
        if session.label == args.name then
            common.show_in_client(session.session_id)
            return
        end
    end
    local window = {
        layout = { block = { flavor = common.SHELL_FLAVOR, options = { cwd = os.getenv("HOME") } } },
    }
    local created = rex.call("session.create", { label = args.name, initial_windows = { window } })
    common.show_in_client(created.session_id)
end

-- the most recently viewed session that isn't session_id
local function other_session(session_id)
    local sessions = common.sort_recent(common.sessions(), "session", function(session)
        return session.session_id
    end)
    for _, session in ipairs(sessions) do
        if session.session_id ~= session_id then
            return session.session_id
        end
    end
end

-- "ask" or "deny", then the message, for the kill confirmation
function M.kill_check(args)
    local label = common.session_label(args.session) or ""
    if not other_session(args.session) then
        common.out("deny\tCan't kill '" .. label .. "': it's the only session.")
        return
    end
    common.out("ask\tKill session '" .. label .. "'?")
end

function M.kill(args)
    local session_id = args.session
    local other = other_session(session_id)
    if not other then
        return
    end
    local view = common.view(session_id)
    local snapshot = {
        label = common.session_label(session_id),
        initial_windows = common.snapshot_windows(session_id, view.windows),
    }
    common.write_undo(UNDO_FILE, snapshot)
    -- this picker runs inside the origin session, so killing it ends the picker too
    if session_id == common.origin_session then
        common.show_in_client(other)
    end
    rex.call("session.destroy", { session_id = session_id })
end

---@return string|nil session_id
function M.undo()
    local undo = common.read_undo(UNDO_FILE)
    if not undo then
        return nil
    end
    local created = rex.call("session.create", undo.args)
    os.remove(UNDO_FILE)
    return created.session_id
end

M.UNDO_FILE = UNDO_FILE

return M
