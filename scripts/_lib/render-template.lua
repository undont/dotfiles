-- writes a template to stdout with each {{KEY}} replaced by the environment
-- variable KEY, exiting 1 and naming every placeholder whose variable is unset
-- usage: render-template.lua <template>

local path = arg[1]
local f = assert(io.open(path, "rb"))
local text = f:read("*a")
f:close()

local missing, seen = {}, {}
local rendered = text:gsub("{{([A-Z0-9_]+)}}", function(key)
    local value = os.getenv(key)
    if value == nil and not seen[key] then
        seen[key] = true
        missing[#missing + 1] = key
    end
    -- nil keeps the placeholder; a string return is inserted literally
    return value
end)

if #missing > 0 then
    io.stderr:write(string.format("%s: no value for %s\n", path:match("[^/]+$"), table.concat(missing, " ")))
    os.exit(1)
end

io.write(rendered)
