-- the URLs in the origin pane's scrollback for the URL picker, newest first

local common = require("common")

local M = {}

-- drop trailing punctuation, and a trailing ) with no opening one in the URL
local function trim(url)
    url = url:gsub("[,.:;!?]+$", "")
    if not url:find("(", 1, true) then
        url = url:gsub("%)+$", "")
    end
    return url
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
    for i = #lines, 1, -1 do
        for url in lines[i]:gmatch("https?://[^%]%[%s\"'<>{}|\\%^]+") do
            url = trim(url)
            if url ~= "" and not seen[url] then
                seen[url] = true
                common.out(url)
            end
        end
    end
end

return M
