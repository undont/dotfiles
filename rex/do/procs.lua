-- the process picker's rows and actions: commands running in rex panes, and
-- the last hour's finished ones, from what cmd-alert-hook.zsh records under
-- _CMD_REX_DIR (running/, finished, suppress/)

local common = require("common")

local M = {}

local DIR = common.CACHE .. "/procs"
local RUNNING = DIR .. "/running"
local FINISHED = DIR .. "/finished"
local SUPPRESS = DIR .. "/suppress"
local FINISHED_MAX_AGE = 3600
local FINISHED_MAX_SHOW = 20
local FINISHED_MAX_KEEP = 200
local RESET = "\27[0m"

-- glyphs and colours match tmux/scripts/_lib/alerts.sh
local RUNNING_STYLE = { "●", "#d8a657" }
local DONE_STYLE = { "✓", "#7aab88" }
local FAILED_STYLE = { "✗", "#c07878" }
local STOPPED_STYLE = { "⊘", "#8a8f98" }

local function paint(style)
    return common.hex_fg(style[2]) .. style[1] .. RESET
end

-- a shell reports a signal death as 128+N, an interruption rather than a failure
local function exit_style(code)
    if code > 128 then
        return STOPPED_STYLE
    end
    if code == 0 then
        return DONE_STYLE
    end
    return FAILED_STYLE
end

-- 45s, 12m, 1h03m
local function elapsed(seconds)
    if seconds < 60 then
        return string.format("%ds", seconds)
    elseif seconds < 3600 then
        return string.format("%dm", math.floor(seconds / 60))
    end
    return string.format("%dh%02dm", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
end

local function fields(line)
    local out = {}
    for field in (line .. "\t"):gmatch("([^\t]*)\t") do
        table.insert(out, field)
    end
    return out
end

local function lines(text)
    local out = {}
    for line in (text or ""):gmatch("[^\n]+") do
        table.insert(out, line)
    end
    return out
end

local function block_key(block)
    return (block:gsub("^block:", ""))
end

-- block_id -> { session, window, name }: where each tiled block is now.
-- name ("session:tab") is looked up on first use, since a tab's name can
-- cost a process call
local function places()
    local found = {}
    for _, session in ipairs(common.sessions()) do
        local view = common.view(session.session_id)
        for _, window in ipairs(view and view.windows or {}) do
            local place = { session = session.session_id, window = window.window_id }
            function place.name()
                place.cached = place.cached or (session.label .. ":" .. common.tab_name(session.session_id, window))
                return place.cached
            end
            for _, block in ipairs(common.layout_blocks(common.tiled_layout(window))) do
                found[block] = place
            end
        end
    end
    return found
end

-- rows from the running entries, most recently started first. an entry is
-- dropped when its pane is gone or its shell died before precmd could
local function running_rows(where, now)
    local listing = rex.exec({ "ls", RUNNING })
    local rows = {}
    for _, name in ipairs(lines(listing.ok and listing.stdout or "")) do
        local path = RUNNING .. "/" .. name
        local f = fields((common.read_file(path) or ""):gsub("\n$", ""))
        local block, start, shell, label = f[1], tonumber(f[3]) or 0, f[4], f[5] or ""
        local place = block and where[block]
        if not place or not shell or not rex.exec({ "kill", "-0", shell }).ok then
            os.remove(path)
        else
            local seconds = start > 0 and math.max(0, now - start) or 0
            local meta = start > 0 and elapsed(seconds) or "·"
            local display = paint(RUNNING_STYLE) .. "  " .. place.name() .. "  " .. label .. "  " .. meta
            table.insert(rows, {
                seconds = seconds,
                line = table.concat({ block, place.session, place.window, "run", "0", display }, "\t"),
            })
        end
    end
    table.sort(rows, function(a, b)
        return a.seconds < b.seconds
    end)
    return rows
end

-- the finished rows within FINISHED_MAX_AGE, newest first
local function finished_entries(now)
    local entries = {}
    for _, line in ipairs(lines(common.read_file(FINISHED))) do
        local f = fields(line)
        local epoch = tonumber(f[1])
        if epoch and now - epoch <= FINISHED_MAX_AGE then
            table.insert(entries, {
                epoch = epoch,
                exit = tonumber(f[2]) or 0,
                block = f[4] or "",
                label = f[5] or "",
                command = f[6] or "",
                line = line,
            })
        end
    end
    table.sort(entries, function(a, b)
        return a.epoch > b.epoch
    end)
    return entries
end

local function write_finished(entries)
    local kept = {}
    for _, entry in ipairs(entries) do
        table.insert(kept, entry.line .. "\n")
    end
    local tmp = FINISHED .. ".tmp"
    common.write_file(tmp, table.concat(kept))
    os.rename(tmp, FINISHED)
end

-- rows from the finished history; the file is trimmed to the newest
-- FINISHED_MAX_KEEP rows within the age limit whose pane is still open. an
-- empty view means the lookup failed, so nothing is shown or dropped
local function finished_rows(where, now)
    if next(where) == nil then
        return {}
    end
    local entries = {}
    for _, entry in ipairs(finished_entries(now)) do
        if where[entry.block] and #entries < FINISHED_MAX_KEEP then
            table.insert(entries, entry)
        end
    end
    if #entries ~= #lines(common.read_file(FINISHED)) then
        write_finished(entries)
    end
    local rows = {}
    for i = 1, math.min(#entries, FINISHED_MAX_SHOW) do
        local entry = entries[i]
        local place = where[entry.block]
        local display = paint(exit_style(entry.exit))
            .. "  "
            .. place.name()
            .. "  "
            .. entry.label
            .. "  ("
            .. elapsed(math.max(0, now - entry.epoch))
            .. " ago)"
        table.insert(
            rows,
            table.concat({ entry.block, place.session, place.window, "done", entry.epoch, display }, "\t")
        )
    end
    return rows
end

-- rows starting with a tab are the header
local function header()
    local legend = string.format(
        "  %s running  %s done  %s failed  %s stopped",
        paint(RUNNING_STYLE),
        paint(DONE_STYLE),
        paint(FAILED_STYLE),
        paint(STOPPED_STYLE)
    )
    for _, line in ipairs({ "", legend, "" }) do
        common.out("\t\t\t\t\t" .. line)
    end
end

-- rows are block_id, session_id, window_id, type (run or done), finish epoch
-- (0 for a running row) and display
function M.list()
    header()
    local where, now = places(), os.time()
    for _, row in ipairs(running_rows(where, now)) do
        common.out(row.line)
    end
    for _, line in ipairs(finished_rows(where, now)) do
        common.out(line)
    end
end

function M.select(args)
    if args.session == "" then
        return
    end
    common.jump(args.session, args.window, args.block)
end

local function write_to(session_id, block_id, data)
    common.view(session_id)
    local args = common.block_args(session_id, block_id)
    args.data = data
    rex.block.call(common.TERMINAL, "write", args)
end

-- x: interrupt a running command, or drop a finished row. the suppress marker
-- stops precmd recording the interrupted command as finished
function M.dismiss(args)
    local key = block_key(args.block)
    if args.type == "run" then
        if args.session == "" then
            return
        end
        rex.exec({ "mkdir", "-p", SUPPRESS })
        common.write_file(SUPPRESS .. "/" .. key, "")
        write_to(args.session, args.block, "\3")
        os.remove(RUNNING .. "/" .. key)
        return
    end
    local epoch, kept = tonumber(args.epoch), {}
    for _, entry in ipairs(finished_entries(os.time())) do
        if not (entry.epoch == epoch and entry.block == args.block) then
            table.insert(kept, entry)
        end
    end
    write_finished(kept)
end

-- drop a pane's finished rows once it's focused; called from recent.lua
function M.clear_block(block)
    local text = common.read_file(FINISHED)
    if not text or not text:find(block, 1, true) then
        return
    end
    local kept = {}
    for _, entry in ipairs(finished_entries(os.time())) do
        if entry.block ~= block then
            table.insert(kept, entry)
        end
    end
    write_finished(kept)
end

-- r/R: type a finished command into its pane, and with mode=exec run it
function M.rerun(args)
    if args.type ~= "done" or args.session == "" then
        return
    end
    local epoch = tonumber(args.epoch)
    for _, entry in ipairs(finished_entries(os.time())) do
        if entry.epoch == epoch and entry.block == args.block then
            if entry.command == "" then
                return
            end
            write_to(args.session, args.block, entry.command)
            if args.mode == "exec" then
                write_to(args.session, args.block, "\r")
            end
            return
        end
    end
end

return M
