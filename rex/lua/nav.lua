-- browser-style back/forward through visited tabs, from the history do/recent.lua keeps

local layers = require("layers")
local run_pick = layers.run_pick

layers.start_recent()

---@param direction "back"|"forward"
local function nav(direction)
    return function(ctx)
        run_pick({ "cmd=nav." .. direction, "client=" .. ctx.client_id })
    end
end

rex.action({ name = "nav_back", title = "Go Back (tab history)", run = nav("back") })
rex.action({ name = "nav_forward", title = "Go Forward (tab history)", run = nav("forward") })
rex.bind("`>-", "nav_back")
rex.bind("`>=", "nav_forward")
