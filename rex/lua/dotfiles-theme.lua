-- dotfiles_theme: switches this host's dotfiles theme for another host's
-- `dotfiles theme switch` (tmux/scripts/themes/reload-rex.sh). the .theme
-- contents come with the call, since a generated theme may exist only there

local home = os.getenv("HOME")

---@return string
local function dotfiles_root()
    local result, err = rex.exec({ "realpath", home .. "/.local/bin/dotfiles" })
    if not result or not result.ok then
        error("dotfiles CLI not found: " .. (err or result.stderr), 0)
    end
    local root = result.stdout:gsub("\n$", ""):gsub("/scripts/dotfiles$", "")
    return root
end

---@param path string
---@param contents string
local function write_file(path, contents)
    local file, err = io.open(path, "w")
    if not file then
        error(err, 0)
    end
    file:write(contents)
    file:close()
end

rex.action({
    name = "dotfiles_theme",
    title = "Switch Dotfiles Theme",
    args = { name = "string", theme = "string", nvim = "string?" },
    run = function(_, args)
        if not args.name:match("^[%w._-]+$") then
            error("invalid theme name: " .. args.name, 0)
        end
        local root = dotfiles_root()
        local themes = root .. "/themes/"

        -- a tracked theme of that name is kept as it is here
        local tracked = io.open(themes .. args.name .. ".theme")
        if tracked then
            tracked:close()
        else
            -- the sender's $(<file) strips the final newline
            write_file(themes .. "generated/" .. args.name .. ".theme", (args.theme:gsub("\n*$", "\n")))
        end
        -- generate-theme's nvim scheme, which needs ghostty's theme sources to build
        if args.nvim then
            write_file(root .. "/nvim/colors/generated/" .. args.name .. ".lua", (args.nvim:gsub("\n*$", "\n")))
        end

        -- the server's PATH lacks homebrew, so a login shell runs theme-switch
        local shell = os.getenv("SHELL") or "/bin/sh"
        local result, err = rex.exec(
            { shell, "-lc", 'exec "$@"', "sh", root .. "/scripts/theme-switch", args.name, "--quiet" },
            { env = { DOTFILES_THEME_FROM_HOST = "1" }, timeout = 30 }
        )
        if not result or not result.ok then
            error("theme-switch failed: " .. (err or result.stderr), 0)
        end
    end,
})
