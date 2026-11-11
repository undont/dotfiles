-- browser-style back/forward through the tabs recent.lua's history records,
-- on any host, skipping tabs that have since closed and hosts that don't
-- answer. run by the nav_back/nav_forward actions, on the machine running the app

local common = require("common")

local M = {}

local NAV = common.CACHE .. "/nav"

-- "host<tab>session<tab>window"
local function parse(line)
    return line:match("^([^\t]*)\t([^\t]*)\t(.*)$")
end

-- hosts that didn't answer this step, so their other entries don't each wait
local down = {}

local function tab_exists(host, session_id, window_id)
    if down[host] then
        return false
    end
    local ok, attached = pcall(function()
        return common.api(host).session.attach({ session_id = session_id })
    end)
    if not ok and host ~= "" then
        down[host] = true
    end
    local view = ok and attached and attached.view
    return view ~= nil and common.find_window(view, window_id) ~= nil
end

-- step through the history, oldest first; positions count back from the
-- newest entry
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
        local host, session_id, window_id = parse(entry)
        if session_id and tab_exists(host, session_id, window_id) then
            -- recent.lua skips the visit this jump causes
            common.write_file(NAV .. "/skip", host .. "\t" .. session_id .. "\t" .. window_id)
            common.write_file(NAV .. "/position", tostring(target))
            common.show_in_client(session_id, window_id, host)
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
