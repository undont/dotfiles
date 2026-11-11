-- running rex against a host: the app's rex binary, background `rex do` runs
-- on the session's host, the recent.lua watcher, and the app's client label

local M = {}

local do_scripts = os.getenv("HOME") .. "/.config/rex/do/"
-- the macOS server's PATH has no rex
local rex_bin = "rex"
local app_rex = os.getenv("HOME")
    .. "/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex"
local app_file = io.open(app_rex)
-- the machine running the app, which keeps the back/forward history
local has_app = app_file ~= nil
if app_file then
    app_file:close()
    rex_bin = app_rex
end

-- run a script in the background. the server's PATH has no homebrew (no jq, and
-- /usr/bin/env bash finds bash 3.2), so the user's login shell loads it, as
-- popup shells do. the server's environment may not set SHELL, and on linux
-- the shell can live outside /bin (linuxbrew's zsh)
local LOGIN_SHELL = 's=${SHELL:-$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)}; '
    .. "exec \"${s:-/bin/zsh}\" -lc 'exec \"$@\"' sh \"$@\""

---@param argv string[]
local function run_script(argv)
    local command = { "/bin/sh", "-c", LOGIN_SHELL, "sh" }
    for _, arg in ipairs(argv) do
        table.insert(command, arg)
    end
    rex.exec.start(command, { detach = true })
end

-- the label the app gave its client, which names the same app on every host
---@param client_id string
---@return string
function M.client_label(client_id)
    local list = rex.call("client.list", {})
    for _, client in ipairs(list and list.clients or {}) do
        if client.client_id == client_id then
            return client.info and client.info.label or ""
        end
    end
    return ""
end

-- run pick.lua with KEY=VALUE args in the background, against the session's
-- host when it isn't this one. the server's PATH has no rex, so it's called by
-- its installed path
---@param args string[]
---@param server? string ctx.server
function M.run_pick(args, server)
    local command = { rex_bin, "--timeout", "3s" }
    if server then
        table.insert(command, "-S")
        table.insert(command, server)
    end
    table.insert(command, "do")
    table.insert(command, do_scripts .. "pick.lua")
    for _, arg in ipairs(args) do
        table.insert(command, arg)
    end
    run_script(command)
end

-- start the recent.lua watcher unless one is running, so a config reload
-- doesn't start a second; it starts the other hosts' watchers itself, since
-- rex.servers() is empty while the config loads. only on the machine running
-- the app, which keeps the history. rex's own path has a space in it, so the
-- match is on the arguments
function M.start_recent()
    if not has_app then
        return
    end
    local running = rex.exec({ "/usr/bin/pgrep", "-f", "do --all .*/rex/do/recent\\.lua rex=" })
    if running and running.ok then
        return
    end
    rex.exec.start(
        { rex_bin, "do", "--all", do_scripts .. "recent.lua", "rex=" .. rex_bin },
        { detach = true, stdout = false, stderr = false }
    )
end

return M
