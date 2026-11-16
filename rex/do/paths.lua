-- the file paths in the origin pane's scrollback for the path picker, newest first

local common = require("common")

local M = {}

local function clean(token)
    token = token:gsub("^[%(%[{<\"'`]+", ""):gsub("[%)%]}>\"'`,.;!?]+$", "")
    return (token:gsub(":%d+:?%d*$", ""))
end

local SEGMENT = "[%w_.@+-]+"

-- "sure": prefixed, or has an extension or a second slash. "maybe": a bare dir
-- or one-segment absolute (maps/geospatial, /tmp), which also matches JS/TS and
-- slash commands, so it is listed after the sure ones
local function classify(token)
    if token:find("://", 1, true) then
        return nil
    end
    if token:match("^~/.") or token:match("^%.%.?/.") then
        return "sure"
    end
    if token:match("^/" .. SEGMENT .. "/.") then
        return "sure"
    end
    if not token:match("^[%w_.@+/-]+$") then
        return nil
    end
    if not token:find("/", 1, true) or not token:match("%a%a") then
        return nil
    end
    local _, slashes = token:gsub("/", "")
    if slashes >= 2 or token:match("%.%w+$") then
        return "sure"
    end
    return "maybe"
end

function M.list()
    if common.origin_block == "" then
        return
    end
    common.view(common.origin_session)
    local args = common.block_args(common.origin_session, common.origin_block)
    args.format = "text"
    args.unwrap = true
    local result = rex.block.call(common.TERMINAL, "format", args)
    local lines = {}
    for line in ((result and result.content or "") .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(lines, line)
    end
    local seen = {}
    local maybe = {}
    for i = #lines, 1, -1 do
        for token in lines[i]:gmatch("%S+") do
            local path = clean(token)
            local kind = classify(path)
            if kind and not seen[path] then
                seen[path] = true
                if kind == "sure" then
                    common.out(path)
                else
                    table.insert(maybe, path)
                end
            end
        end
    end
    for _, path in ipairs(maybe) do
        common.out(path)
    end
end

return M
