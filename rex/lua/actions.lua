-- custom actions and their keys: pickers, y/n kills, duplicate tab, undo

local layers = require("layers")
local picker, run_pick = layers.picker, layers.run_pick

---@param key string
---@param name string
---@param title string
---@param run fun(ctx: table)
local function action(key, name, title, run)
    rex.action({ name = name, title = title, run = run })
    rex.bind(key, name)
end

action("`>s", "pick_session", "Pick Session (fzf)", picker("pick-session.sh", 0.9))
action("`>f", "pick_window", "Pick Tab (fzf)", picker("pick-window.sh", 0.9))
action("`>p", "pick_launcher", "Pick Launcher (fzf)", picker("pick-launcher.sh", 0.6))
action("`>u", "pick_url", "Open URL from Scrollback (fzf)", picker("pick-url.sh", 0.9))
action("`>n", "pick_nvim", "Pick Nvim (fzf)", picker("pick-agents.sh", 0.9, { "nvim" }))
action("`>c", "pick_claude", "Pick Claude (fzf)", picker("pick-agents.sh", 0.9, { "claude" }))
action("`>x", "pick_codex", "Pick Codex (fzf)", picker("pick-agents.sh", 0.9, { "codex" }))
action("`>o", "pick_opencode", "Pick OpenCode (fzf)", picker("pick-agents.sh", 0.9, { "opencode" }))
action("`>a", "pick_copilot", "Pick Copilot (fzf)", picker("pick-agents.sh", 0.9, { "copilot" }))
action("`>t", "pick_theme", "Pick Theme (fzf)", picker("pick-theme.sh", { 0.5, 0.6 }))
action("`>shift+p", "pick_procs", "Process List (fzf)", picker("pick-procs.sh", 0.9))

require("copy-mode")

require("nav")

-- a copy of the current tab: layout, directories and scrollback
action("alt+shift+d", "duplicate_tab", "Duplicate Tab", function(ctx)
    if not ctx.block_id or layers.is_picker(ctx.block_id) then
        return
    end
    run_pick({
        "cmd=tabs.duplicate",
        "client=" .. ctx.client_id,
        "session=" .. ctx.session_id,
        "block=" .. ctx.block_id,
    })
end)

-- restores the session or tab killed last, from the kill keys or the pickers
action("alt+u", "undo_kill", "Undo Last Kill", function()
    run_pick({ "cmd=undo" })
end)

-- kills ask y/n first, like the tmux binds. the last session and a session's
-- last tab can't be killed, so those keys do nothing rather than open a popup
local confirm = { 0.35, 0.20 }

---@param allowed fun(): boolean
---@param run fun(ctx: table)
local function only_if(allowed, run)
    return function(ctx)
        if allowed() then
            run(ctx)
        end
    end
end

local function several_sessions()
    return #rex.call("session.list", {}).sessions > 1
end

local function several_tabs()
    return #rex.session.view({}).windows > 1
end

action(
    "alt+q",
    "kill_session",
    "Kill Session…",
    only_if(several_sessions, picker("confirm-kill.sh", confirm, { "session" }))
)
action("alt+x", "kill_tab", "Kill Tab…", only_if(several_tabs, picker("confirm-kill.sh", confirm, { "tab" })))
action("alt+s", "kill_pane", "Kill Pane…", picker("confirm-kill.sh", confirm, { "pane" }))
