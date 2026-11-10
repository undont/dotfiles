-- entry point for the pickers' rows, previews and actions
-- run with: rex do pick.lua cmd=MODULE.COMMAND [KEY=VALUE...]
--   modules are beside it: sessions, tabs, panes (agents and nvim), procs
--   shared: cmd=restore, cmd=undo (the last kill), cmd=preview session=ID block=ID

package.path = os.getenv("HOME") .. "/.config/rex/do/?.lua;" .. package.path

local common = require("common")

-- fzf only renders SGR, so vt cursor-forward runs (\e[nC) become spaces.
-- anchored to the bottom of the preview window
local function preview(args)
    if not args.session or args.session == "" or not args.block or args.block == "" then
        return
    end
    common.view(args.session)
    local content = common.capture(args.session, args.block):gsub("\27%[(%d*)C", function(n)
        return string.rep(" ", tonumber(n) or 1)
    end)
    io.write(common.last_lines(content, tonumber(os.getenv("FZF_PREVIEW_LINES")) or 40), "\n")
end

-- rex do types KEY=VALUE pairs (all=1 arrives as a number), so every value is
-- read back as a string; typed names come through PICK_NAME, not an argument
-- whichever was killed last, a session or a tab, from its undo snapshot
local function undo_last()
    local sessions, tabs = require("sessions"), require("tabs")
    local function mtime(path)
        local stat = rex.exec({ "stat", "-f", "%m", path })
        return stat.ok and tonumber(stat.stdout) or nil
    end
    local session_time, tab_time = mtime(sessions.UNDO_FILE), mtime(tabs.UNDO_FILE)
    if session_time and (not tab_time or session_time > tab_time) then
        sessions.undo()
    elseif tab_time then
        tabs.undo()
    end
end

local args = {}
for key, value in pairs(rex.args) do
    args[key] = tostring(value)
end
args.name = os.getenv("PICK_NAME")
local cmd = args.cmd or ""
if cmd == "restore" then
    common.restore_focus()
    return
end
if cmd == "undo" then
    undo_last()
    return
end
if cmd == "preview" then
    preview(args)
    return
end

local module, command = cmd:match("^(%w+)%.([%w_]+)$")
if not module then
    error("unknown command: " .. cmd)
end
local picker = require(module)
if type(picker[command]) ~= "function" then
    error("unknown command: " .. cmd)
end
picker[command](args)
