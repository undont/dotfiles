-- log which session, tab and pane you look at, for the pickers' most-recent
-- order. rex has no "session switched" event, but the app resizes the panes of
-- the session it shows, so a size change marks that session as viewed; within
-- it, view changes carry tab and pane focus
-- it also keeps the tab history nav.lua steps back and forward through, one
-- history across hosts: the machine running the app runs one of these per
-- server, all writing its own cache (start_recent in lua/layers.lua)
-- run with: rex [-S HOST] do --all recent.lua [host=HOST]

package.path = os.getenv("HOME") .. "/.config/rex/do/?.lua;" .. package.path
local procs = require("procs")

local cache = (os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") .. "/.cache")) .. "/rex"
-- the server this watcher listens to: "" for the home server, else its rex
-- hosts label. only the home server's visits feed the pickers' recent order
local host = rex.args.host and tostring(rex.args.host) or ""
local log_path = cache .. "/recent"
-- lines are session, tab, pane. the log only needs each entry's latest line,
-- so it's compacted once it grows past this
local MAX_LINES = 1000

local last_entry = ""
local last_session, last_seen = "", 0
local appended = 0

-- back/forward history: "host<tab>session<tab>window" lines, oldest first, plus
-- how many entries back from the newest nav.lua has stepped (0 = at the
-- newest). skip holds the tab a nav.lua jump is landing on, so the jump isn't
-- a new visit. current holds the host and session on screen, which every
-- watcher reads, since each only sees its own server's switches
local nav_history = cache .. "/nav/history"
local nav_position = cache .. "/nav/position"
local nav_skip = cache .. "/nav/skip"
local nav_current = cache .. "/nav/current"
local NAV_MAX = 100
rex.exec({ "mkdir", "-p", cache .. "/nav" })
local last_tab = ""

local function read_file(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local text = f:read("*a")
    f:close()
    return text
end

local function write_file(path, text)
    local f = io.open(path, "w")
    if f then
        f:write(text)
        f:close()
    end
end

local function read_lines(path)
    local lines = {}
    local f = io.open(path, "r")
    if not f then
        return lines
    end
    for line in f:lines() do
        table.insert(lines, line)
    end
    f:close()
    return lines
end

-- a visit after stepping back drops the forward entries, as in a browser
local function nav_visit(tab)
    if tab == last_tab then
        return
    end
    last_tab = tab
    local skip = read_file(nav_skip)
    os.remove(nav_skip)
    if skip == tab then
        return
    end
    local lines = read_lines(nav_history)
    local position = tonumber(read_file(nav_position)) or 0
    for _ = 1, position do
        table.remove(lines)
    end
    if lines[#lines] ~= tab then
        table.insert(lines, tab)
    end
    while #lines > NAV_MAX do
        table.remove(lines, 1)
    end
    -- another host's watcher writes the same file, so it's replaced whole
    write_file(nav_history .. ".tmp", table.concat(lines, "\n") .. "\n")
    os.rename(nav_history .. ".tmp", nav_history)
    write_file(nav_position, "0")
end

-- rewrite the log keeping only the latest line for each entry, in order
local function compact()
    local lines, latest = {}, {}
    for line in io.lines(log_path) do
        table.insert(lines, line)
        latest[line] = #lines
    end
    local tmp = log_path .. ".tmp"
    local out = assert(io.open(tmp, "w"))
    for i, line in ipairs(lines) do
        if latest[line] == i then
            out:write(line, "\n")
        end
    end
    out:close()
    os.rename(tmp, log_path)
    appended = 0
end

-- the active tab and its focused pane, skipping a picker popup, which takes
-- focus while it's open
local function focus_of(session)
    -- some builds' --all delivers every session's events without attaching to
    -- them, and reading a view needs the attachment; attaching returns the view
    local ok, attached = pcall(rex.session.attach, { session_id = session })
    local view = ok and attached and attached.view
    if not view then
        return nil, nil
    end
    for _, win in ipairs(view.windows) do
        if win.window_id == view.active_window_id then
            for _, layer in ipairs(win.layers) do
                for _, block in ipairs(layer.blocks) do
                    if block.block_id == win.focused_block_id and block.label == "picker" then
                        return nil, nil
                    end
                end
            end
            return win.window_id, win.focused_block_id
        end
    end
    return nil, nil
end

local function record(session)
    local window, block = focus_of(session)
    if not window then
        return
    end
    nav_visit(host .. "\t" .. session .. "\t" .. window)
    if host ~= "" then
        return
    end
    local entry = session .. "\t" .. window .. "\t" .. (block or "")
    if entry == last_entry then
        return
    end
    last_entry = entry
    if block then
        procs.clear_block(block)
    end
    local out = io.open(log_path, "a")
    if not out then
        return
    end
    out:write(entry, "\n")
    out:close()
    appended = appended + 1
    if appended >= MAX_LINES then
        compact()
    end
end

rex.on("terminal.size_changed", function(_, ev)
    -- a switch resizes every pane in the session at once; one visit is enough
    local now = os.time()
    if ev.session_id == last_session and now - last_seen < 2 then
        return
    end
    last_session, last_seen = ev.session_id, now
    write_file(nav_current, host .. "\t" .. ev.session_id)
    record(ev.session_id)
end)

-- tab and pane focus changes; only for the session on screen, on whichever
-- host, since any session's view changes when something in it does, seen or not
rex.on("session_view_changed", function(_, ev)
    if read_file(nav_current) == host .. "\t" .. ev.session_id then
        record(ev.session_id)
    end
end)

-- the home server's watcher starts one for each other host that has none, and
-- checks again every SUPERVISE_SECONDS: one for a host that doesn't answer
-- exits, and comes back once the host does
local SUPERVISE_SECONDS = 30
local SELF = os.getenv("HOME") .. "/.config/rex/do/recent.lua"

local function supervise()
    for _, label in ipairs(rex.servers()) do
        local pattern = "do --all .*/rex/do/recent\\.lua host=" .. label .. "$"
        local running = rex.exec({ "/usr/bin/pgrep", "-f", pattern })
        if not (running and running.ok) then
            rex.exec.start(
                { tostring(rex.args.rex), "-S", label, "do", "--all", SELF, "host=" .. label },
                { detach = true, stdout = false, stderr = false }
            )
        end
    end
end

if host == "" and rex.args.rex then
    supervise()
    rex.every(SUPERVISE_SECONDS, supervise)
end
