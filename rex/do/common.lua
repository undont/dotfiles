-- helpers shared by the picker modules: env, view lookups, client focus,
-- recent order, undo snapshots

local M = {}

M.TERMINAL = "com.superlogical.terminal"
M.SHELL_FLAVOR = "com.superlogical.terminal.shell"
M.CACHE = (os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") .. "/.cache")) .. "/rex"
local UNDO_SCROLLBACK_LINES = 2000
local SHELLS = { zsh = true, bash = true, fish = true, sh = true }

-- set by picker_start in _lib.sh
M.client = os.getenv("PICK_CLIENT") or ""
M.origin_session = os.getenv("PICK_ORIGIN_SESSION") or ""
M.origin_block = os.getenv("PICK_ORIGIN_BLOCK") or ""
M.origin_zoomed = os.getenv("PICK_ORIGIN_ZOOMED") == "1"
-- the picker's own block, when this runs inside one
M.popup = os.getenv("REX_BLOCK") or ""

M.RESET = "\27[0m"

function M.out(line)
    io.write(line, "\n")
end

function M.hex_fg(hex)
    return string.format(
        "\27[38;2;%d;%d;%dm",
        tonumber(hex:sub(2, 3), 16),
        tonumber(hex:sub(4, 5), 16),
        tonumber(hex:sub(6, 7), 16)
    )
end

-- style is { text, hex colour }
function M.paint(style)
    return M.hex_fg(style[2]) .. style[1] .. M.RESET
end

-- 45s, 12m, 1h03m
function M.elapsed(seconds)
    if seconds < 60 then
        return string.format("%ds", seconds)
    elseif seconds < 3600 then
        return string.format("%dm", math.floor(seconds / 60))
    end
    return string.format("%dh%02dm", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
end

-- a hex colour at pct percent brightness
function M.hex_dim(hex, pct)
    local function channel(i)
        return math.floor(tonumber(hex:sub(i, i + 1), 16) * pct / 100)
    end
    return string.format("#%02x%02x%02x", channel(2), channel(4), channel(6))
end

local function accent(name, fallback)
    local hex = os.getenv(name)
    if not hex or not hex:match("^#%x%x%x%x%x%x$") then
        return fallback
    end
    return hex
end

-- print_dotfiles_logo in tmux/scripts/_lib/common.sh as header rows, led by
-- tabs so the logo lands in the displayed field
function M.logo_header(column)
    local from, to = accent("TMUX_ACCENT_CYAN", "#8baf9e"), accent("TMUX_ACCENT_PURPLE", "#38604a")
    local lines = {
        [[     _       _    __ _ _]],
        [[  __| | ___ | |_ / _(_) | ___  ___]],
        [[ / _` |/ _ \| __| |_| | |/ _ \/ __|]],
        [[| (_| | (_) | |_|  _| | |  __/\__ \]],
        [[ \__,_|\___/ \__|_| |_|_|\___||___/]],
    }
    local lead = string.rep("\t", column - 1)
    M.out(lead)
    for i, line in ipairs(lines) do
        local function mix(at)
            local a, b = tonumber(from:sub(at, at + 1), 16), tonumber(to:sub(at, at + 1), 16)
            return math.floor(a + (b - a) * (i - 1) / 4)
        end
        local colour = string.format("#%02x%02x%02x", mix(2), mix(4), mix(6))
        M.out(lead .. M.hex_fg(colour) .. line .. "\27[0m")
    end
    M.out(lead)
end

function M.sessions()
    return rex.call("session.list", {}).sessions
end

---@param host? string a rex.servers() label; nil or "" for the server this script calls
function M.api(host)
    if not host or host == "" then
        return rex
    end
    return rex.server(host)
end

-- a script only reads the sessions it's attached to; attaching returns the view
function M.view(session_id)
    local attached = rex.session.attach({ session_id = session_id })
    return attached and attached.view
end

function M.session_label(session_id)
    for _, session in ipairs(M.sessions()) do
        if session.session_id == session_id then
            return session.label
        end
    end
end

function M.find_window(view, window_id)
    for _, window in ipairs(view.windows) do
        if window.window_id == window_id then
            return window
        end
    end
end

function M.tiled_layout(window)
    for _, layer in ipairs(window.layers) do
        if layer.kind == "tiled" then
            return layer.layout
        end
    end
end

-- the tiled block ids in layout order (1 = top-left)
function M.layout_blocks(node, blocks)
    blocks = blocks or {}
    if node.split then
        M.layout_blocks(node.split.before, blocks)
        M.layout_blocks(node.split.after, blocks)
    else
        table.insert(blocks, node.block_id)
    end
    return blocks
end

-- a window's focused block; the popup's own resolves to the pane it opened over
function M.window_focus(window)
    local block = window.focused_block_id or ""
    if block ~= "" and block == M.popup then
        return M.origin_block
    end
    return block
end

function M.block_args(session_id, block_id)
    return { session_id = session_id, block_id = block_id }
end

function M.process(session_id, block_id)
    return rex.block.call(M.TERMINAL, "process", M.block_args(session_id, block_id))
end

-- "-zsh" or "/opt/homebrew/bin/nvim" -> "zsh", "nvim"
function M.program_name(fg)
    local name = (fg.argv0 or fg.name or ""):gsub("^%-", "")
    return name:match("([^/]*)$")
end

-- the program's name, or the directory's basename for a shell at its prompt
function M.pane_name(session_id, block_id)
    local process = M.process(session_id, block_id)
    local fg = process and process.foreground
    if not fg then
        return ""
    end
    local program = M.program_name(fg)
    if SHELLS[program] then
        return (fg.cwd or ""):match("([^/]*)$")
    end
    return program
end

function M.is_default_tab_label(label)
    return label:match("^Window %x%x%x%x%x%x%x%x$") ~= nil
end

-- a tab's label, or for rex's placeholder label its focused pane's name, as
-- tmux's automatic-rename-format names windows
function M.tab_name(session_id, window)
    local label = window.label or ""
    local block = M.window_focus(window)
    if not M.is_default_tab_label(label) or block == "" then
        return label
    end
    local name = M.pane_name(session_id, block)
    return name ~= "" and name or label
end

-- the app's client on a host: an action passes the app's id on the server
-- that ran it, and another host knows the same app by another id: the app with
-- the same label, else the app showing the session, else any app
-- (local_client in bash/_lib.sh picks the same way)
local clients = {}

---@param host? string
---@param session_id? string
function M.client_for(host, session_id)
    host = host or ""
    if clients[host] then
        return clients[host]
    end
    local label = os.getenv("PICK_CLIENT_LABEL") or ""
    for _, client in ipairs(rex.call("client.list", {}).clients or {}) do
        if client.client_id == M.client and client.info and client.info.label then
            label = client.info.label
        end
    end
    local list = M.api(host).call("client.list", {})
    local apps, found = {}, nil
    for _, client in ipairs(list and list.clients or {}) do
        if client.client_id == M.client then
            found = M.client
        elseif client.info and client.info.kind == "app" then
            table.insert(apps, client)
        end
    end
    for _, app in ipairs(apps) do
        if not found and label ~= "" and app.info.label == label then
            found = app.client_id
        end
    end
    for _, app in ipairs(apps) do
        for _, id in ipairs(app.session_ids or {}) do
            if not found and id == session_id then
                found = app.client_id
            end
        end
    end
    clients[host] = found or (apps[1] and apps[1].client_id) or M.client
    return clients[host]
end

-- show a session, and optionally one of its windows, in the client that opened the picker.
-- the app ignores the server-side focus of a new window, so the client is told
---@param host? string the session's host, when it isn't the server this script calls
function M.show_in_client(session_id, window_id, host)
    local args = { session_id = session_id, window_id = window_id }
    M.api(host)
        .call("client.perform", { client_id = M.client_for(host, session_id), action = "session.select", args = args })
end

-- focus the origin pane again: if the popup still has focus when its layer
-- closes, rex moves focus to another pane. focusing the popup also undoes a
-- zoom, so a zoomed origin is zoomed again (which focuses it too)
function M.restore_focus()
    if M.origin_block == "" then
        return
    end
    M.view(M.origin_session)
    if M.origin_zoomed then
        rex.session.zoom_block({ session_id = M.origin_session, block_id = M.origin_block, zoom = true })
        return
    end
    rex.session.focus_block({ session_id = M.origin_session, block_id = M.origin_block })
end

-- focus a block and show it, leaving the origin session as it was when the
-- block is elsewhere
function M.jump(session_id, window_id, block_id)
    if session_id ~= M.origin_session then
        M.restore_focus()
    end
    M.view(session_id)
    if block_id then
        rex.session.focus_block({ session_id = session_id, block_id = block_id })
    end
    M.show_in_client(session_id, window_id)
end

-- rows ordered most recently viewed first, by the visits recent.lua logs.
-- kind says which logged column (session, window or block) id(row) matches;
-- rows never viewed keep their order, after the rest
function M.sort_recent(rows, kind, id)
    local column = ({ session = 1, window = 2, block = 3 })[kind]
    local last, n = {}, 0
    local log = io.open(M.CACHE .. "/recent", "r")
    if log then
        for line in log:lines() do
            local fields = {}
            for field in (line .. "\t"):gmatch("([^\t]*)\t") do
                table.insert(fields, field)
            end
            if fields[column] and fields[column] ~= "" then
                n = n + 1
                last[fields[column]] = n
            end
        end
        log:close()
    end
    local keyed = {}
    for i, row in ipairs(rows) do
        local seen = last[id(row)]
        table.insert(keyed, { key = seen and n - seen or n + i, index = i, row = row })
    end
    table.sort(keyed, function(a, b)
        if a.key ~= b.key then
            return a.key < b.key
        end
        return a.index < b.index
    end)
    local sorted = {}
    for i, entry in ipairs(keyed) do
        sorted[i] = entry.row
    end
    return sorted
end

-- the block's screen and scrollback as vt sequences, trimmed
function M.capture(session_id, block_id)
    local args = M.block_args(session_id, block_id)
    args.format = "vt"
    args.trim = true
    local result = rex.block.call(M.TERMINAL, "format", args)
    return result and result.content or ""
end

function M.last_lines(text, count)
    local lines = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(lines, line)
    end
    if lines[#lines] == "" then
        table.remove(lines)
    end
    local first = math.max(1, #lines - count + 1)
    return table.concat(lines, "\n", first)
end

-- write text to a file only its owner can read
function M.write_private(path, text)
    rex.exec({ "/bin/sh", "-c", 'umask 077 && cat >"$1"', "sh", path }, { stdin = text })
end

-- undo files hold { killed_at, args }; a file without killed_at is from an
-- older format and reads as none
function M.write_undo(path, args)
    M.write_private(path, rex.json.encode({ killed_at = os.time(), args = args }))
end

function M.read_undo(path)
    local text = M.read_file(path)
    if not text or text == "" then
        return nil
    end
    local ok, undo = pcall(rex.json.decode, text)
    if not ok or type(undo) ~= "table" or not undo.killed_at then
        return nil
    end
    return undo
end

function M.write_file(path, text)
    local f = io.open(path, "w")
    if f then
        f:write(text)
        f:close()
    end
end

function M.read_file(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local text = f:read("*a")
    f:close()
    return text
end

-- linux caps one exec argument at 128 KiB, and a restored block's scrollback
-- is one argument of its command
local MAX_SCROLLBACK_BYTES = 100000

-- the tail of text, at most max bytes, starting on a line
local function tail_bytes(text, max)
    if #text <= max then
        return text
    end
    local cut = text:sub(-max)
    return cut:match("\n(.*)$") or cut
end

-- block_id -> { cwd, scrollback } for the tiled blocks of windows: the cwd of
-- each block's foreground process, and its last UNDO_SCROLLBACK_LINES of
-- screen and scrollback
local function snapshot_blocks(session_id, windows)
    local blocks = {}
    for _, window in ipairs(windows) do
        for _, block_id in ipairs(M.layout_blocks(M.tiled_layout(window))) do
            local process = M.process(session_id, block_id)
            local entry = { cwd = process and process.foreground and process.foreground.cwd }
            local content = M.capture(session_id, block_id)
            if content ~= "" then
                entry.scrollback = tail_bytes(M.last_lines(content, UNDO_SCROLLBACK_LINES), MAX_SCROLLBACK_BYTES)
            end
            blocks[block_id] = entry
        end
    end
    return blocks
end

-- prints the saved scrollback, then the login shell of the host the block
-- runs on, which may not be the one running this script
local RESTORE_SCRIPT = 'printf "%s\\n" "$1"; '
    .. 's=${SHELL:-$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)}; '
    .. 'exec "${s:-/bin/sh}" -l'

-- a session.create / new_window layout node rebuilding a view layout node:
-- each block a login shell in its saved cwd, printing its saved scrollback first
local function layout_node(node, blocks)
    if node.split then
        return {
            split = {
                direction = node.split.direction,
                ratio = node.split.ratio,
                before = layout_node(node.split.before, blocks),
                after = layout_node(node.split.after, blocks),
            },
        }
    end
    local saved = blocks[node.block_id] or {}
    local options = {}
    if saved.cwd then
        options.cwd = saved.cwd
    end
    if saved.scrollback then
        options.command = { "/bin/sh", "-c", RESTORE_SCRIPT, "sh", saved.scrollback }
    end
    local block = { flavor = M.SHELL_FLAVOR }
    if next(options) then
        block.options = options
    end
    return { block = block }
end

-- new_window args rebuilding each window's tiled layout, with its scrollback
function M.snapshot_windows(session_id, windows)
    local blocks = snapshot_blocks(session_id, windows)
    local snapshots = {}
    for _, window in ipairs(windows) do
        table.insert(snapshots, {
            window_label = window.label,
            layout = layout_node(M.tiled_layout(window), blocks),
        })
    end
    return snapshots
end

return M
