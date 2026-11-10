-- browser-style back/forward through the tabs recent.lua's history records,
-- skipping tabs that have since closed. run by the nav_back/nav_forward actions

local common = require("common")

local M = {}

local NAV = common.CACHE .. "/nav"

local function tab_exists(session_id, window_id)
    local view = common.view(session_id)
    return view ~= nil and common.find_window(view, window_id) ~= nil
end

-- step through the history, which lists "session<tab>window" oldest first;
-- positions count back from the newest entry
local function go(args, step)
    common.client = args.client
    local entries = {}
    for line in ((common.read_file(NAV .. "/history") or "") .. "\n"):gmatch("([^\n]*)\n") do
        if line ~= "" then
            table.insert(entries, line)
        end
    end
    local target = (tonumber(common.read_file(NAV .. "/position")) or 0) + step
    while target >= 0 and target < #entries do
        local entry = entries[#entries - target]
        local session_id, window_id = entry:match("^([^\t]*)\t(.*)$")
        if session_id and tab_exists(session_id, window_id) then
            -- recent.lua skips the visit this jump causes
            common.write_file(NAV .. "/skip", entry)
            common.write_file(NAV .. "/position", tostring(target))
            common.show_in_client(session_id, window_id)
            return
        end
        target = target + step
    end
end

function M.back(args)
    go(args, 1)
end

function M.forward(args)
    go(args, -1)
end

return M
