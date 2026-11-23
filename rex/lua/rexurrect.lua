-- restores the latest rexurrect snapshot when the server starts. `auto-restore`
-- returns at once and restores at most once per server instance

local bins = {
    "/opt/homebrew/bin/rexurrect",
    "/usr/local/bin/rexurrect",
    "/home/linuxbrew/.linuxbrew/bin/rexurrect",
}

for _, bin in ipairs(bins) do
    local f = io.open(bin)
    if f then
        f:close()
        local result = rex.exec({ bin, "auto-restore" })
        if result then
            io.stderr:write(result.stderr)
        end
        break
    end
end
