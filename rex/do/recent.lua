-- log which session, tab and pane you look at, for the pickers' most-recent
-- order. rex has no "session switched" event, but the app resizes the panes of
-- the session it shows, so a size change marks that session as viewed; within
-- it, view changes carry tab and pane focus
-- it also keeps the tab history nav.lua steps back and forward through
-- run with: rex do --all recent.lua   (start_recent in lua/layers.lua keeps one running)

package.path = os.getenv("HOME") .. "/.config/rex/do/?.lua;" .. package.path
local procs = require("procs")

local cache = (os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") .. "/.cache")) .. "/rex"
local log_path = cache .. "/recent"
-- lines are session, tab, pane. the log only needs each entry's latest line,
-- so it's compacted once it grows past this
local MAX_LINES = 1000

local last_entry = ""
local last_session, last_seen = "", 0
local appended = 0

-- back/forward history: "session<tab>window" lines, oldest first, plus how many
-- entries back from the newest nav.lua has stepped (0 = at the newest). skip
-- holds the tab a nav.lua jump is landing on, so the jump isn't a new visit
local nav_history = cache .. "/nav/history"
local nav_position = cache .. "/nav/position"
local nav_skip = cache .. "/nav/skip"
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
    write_file(nav_history, table.concat(lines, "\n") .. "\n")
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
    local ok, view = pcall(rex.call, "session.view", { session_id = session })
    if not ok then
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
    nav_visit(session .. "\t" .. window)
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
    record(ev.session_id)
end)

-- tab and pane focus changes; only for the session on screen, since any
-- session's view changes when something in it does, seen or not
rex.on("session_view_changed", function(_, ev)
    if ev.session_id == last_session then
        record(ev.session_id)
    end
end)
