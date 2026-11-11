-- browser-style back/forward through visited tabs, from the history do/recent.lua keeps

local hosts = require("hosts")
local layers = require("layers")

hosts.start_recent()

---@param direction "back"|"forward"
local function nav(direction)
    return function(ctx)
        hosts.run_pick({ "cmd=nav." .. direction, "client=" .. ctx.client_id })
    end
end

layers.action("`>-", "nav_back", "Go Back (tab history)", nav("back"))
layers.action("`>=", "nav_forward", "Go Forward (tab history)", nav("forward"))
