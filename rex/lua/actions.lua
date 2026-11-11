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

-- pickers that list this server's sessions only, so they do nothing over a
-- session on another host (ctx.server set)
---@param run fun(ctx: table)
local function home_only(run)
    return function(ctx)
        if not ctx.server then
            run(ctx)
        end
    end
end

action("`>s", "pick_session", "Pick Session (fzf)", home_only(picker("pick-session.sh", 0.9)))
action("`>f", "pick_window", "Pick Tab (fzf)", home_only(picker("pick-window.sh", 0.9)))
action("`>p", "pick_launcher", "Pick Launcher (fzf)", picker("pick-launcher.sh", 0.6))
action("`>u", "pick_url", "Open URL from Scrollback (fzf)", picker("pick-url.sh", 0.9))

-- opens a URL on this machine, where the app runs; a URL picked in a popup on
-- another host's session comes here (open_in_app in bash/_lib.sh)
rex.action({
    name = "open_url",
    title = "Open URL",
    args = { url = "string" },
    run = function(_, args)
        if not args.url:match("^https?://") then
            error("not an http(s) URL: " .. args.url, 0)
        end
        rex.exec({ "open", args.url })
    end,
})

-- copies text to this machine's clipboard, for a yank on another host's
-- session (bash/copy-in-app.sh), whose OSC 52 the app ignores
rex.action({
    name = "copy_text",
    title = "Copy Text",
    args = { text = "string" },
    run = function(_, args)
        -- pbcopy reads stdin in the locale's encoding, and the server's
        -- environment has none, which reads UTF-8 as Mac Roman
        rex.exec({ "pbcopy" }, { stdin = args.text, env = { LANG = "en_US.UTF-8" } })
    end,
})
action("`>n", "pick_nvim", "Pick Nvim (fzf)", home_only(picker("pick-agents.sh", 0.9, { "nvim" })))
action("`>c", "pick_claude", "Pick Claude (fzf)", home_only(picker("pick-agents.sh", 0.9, { "claude" })))
action("`>x", "pick_codex", "Pick Codex (fzf)", home_only(picker("pick-agents.sh", 0.9, { "codex" })))
action("`>o", "pick_opencode", "Pick OpenCode (fzf)", home_only(picker("pick-agents.sh", 0.9, { "opencode" })))
action("`>a", "pick_copilot", "Pick Copilot (fzf)", home_only(picker("pick-agents.sh", 0.9, { "copilot" })))
action("`>t", "pick_theme", "Pick Theme (fzf)", picker("pick-theme.sh", { 0.5, 0.6 }))
action("`>shift+p", "pick_procs", "Process List (fzf)", home_only(picker("pick-procs.sh", 0.9)))

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
    }, ctx.server)
end)

-- restores the session or tab killed last, from the kill keys or the pickers.
-- a kill over another host's session saved its snapshot on that host, so that
-- host's own undo_kill runs there
action("alt+u", "undo_kill", "Undo Last Kill", function(ctx)
    if ctx.server then
        rex.server(ctx.server).call("client.action", { action = "undo_kill" })
        return
    end
    run_pick({ "cmd=undo" })
end)

-- kills ask y/n first, like the tmux binds. the last session and a session's
-- last tab can't be killed, so those keys do nothing rather than open a popup
local confirm = { 0.35, 0.20 }

---@param allowed fun(ctx: table): boolean
---@param run fun(ctx: table)
local function only_if(allowed, run)
    return function(ctx)
        if allowed(ctx) then
            run(ctx)
        end
    end
end

-- the session's own host: rex.call alone lists this server's sessions
local function several_sessions(ctx)
    local server = rex
    if ctx.server then
        server = rex.server(ctx.server)
    end
    return #server.call("session.list", {}).sessions > 1
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
