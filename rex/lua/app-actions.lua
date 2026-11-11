-- actions the other hosts call on the machine running the app: open a URL,
-- copy text, remember a popup's size, switch the dotfiles theme

local layers = require("layers")

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

rex.action({
    name = "save_popup_size",
    title = "Save Popup Size",
    args = { key = "string", columns = "number", rows = "number" },
    run = function(_, args)
        local lines = {}
        local f = io.open(layers.POPUP_SIZES, "r")
        if f then
            for line in f:lines() do
                if line:match("^(%S+)") ~= args.key then
                    table.insert(lines, line)
                end
            end
            f:close()
        end
        table.insert(lines, string.format("%s %d %d", args.key, args.columns, args.rows))
        local tmp = layers.POPUP_SIZES .. ".tmp"
        local out = io.open(tmp, "w")
        if not out then
            return
        end
        out:write(table.concat(lines, "\n"), "\n")
        out:close()
        os.rename(tmp, layers.POPUP_SIZES)
    end,
})

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
