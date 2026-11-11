-- entry point for the pickers' rows, previews and actions
-- run with: rex do pick.lua cmd=MODULE.COMMAND [KEY=VALUE...]
--   modules are beside it: sessions, tabs, panes (agents and nvim), procs, urls, nav
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

-- whichever was killed last, a session or a tab, from its undo snapshot,
-- shown in the client; the pickers' u restores without switching
local function undo_last(args)
    common.client = args.client or ""
    local sessions, tabs = require("sessions"), require("tabs")
    local session, tab = common.read_undo(sessions.UNDO_FILE), common.read_undo(tabs.UNDO_FILE)
    local session_id, window_id
    if session and (not tab or session.killed_at > tab.killed_at) then
        session_id = sessions.undo()
    elseif tab then
        session_id, window_id = tabs.undo()
    end
    if session_id then
        common.show_in_client(session_id, window_id)
    end
end

-- rex do types KEY=VALUE pairs (all=1 arrives as a number), so every value is
-- read back as a string; typed names come through PICK_NAME, not an argument
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
    undo_last(args)
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
