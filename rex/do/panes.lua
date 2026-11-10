-- the agent and nvim pickers' rows and actions: every tiled pane running one
-- program, in any session. agent state comes from rex's program status, which
-- the agent reports itself; a pane with no status still lists, as "none"

local common = require("common")

local M = {}

local GLYPHS = {
    working = { "●", "#d8a657" },
    blocked = { "◐", "#f1fa8c" }, -- waiting on you: permission, a question or auth
    done = { "✓", "#8a8f98" },
    idle = { "○", "#8a8f98" },
    error = { "✗", "#c07878" },
}
local NO_STATUS = { "·", "#6272a4" }
local AGENT_TITLES = { ["Claude Code"] = true, claude = true, codex = true, opencode = true, copilot = true }
local RESET = "\27[0m"

local function glyph(state)
    local style = GLYPHS[state] or NO_STATUS
    return common.hex_fg(style[2]) .. style[1] .. RESET
end

-- 45s, 12m, 1h03m
local function elapsed(seconds)
    if seconds < 60 then
        return string.format("%ds", seconds)
    elseif seconds < 3600 then
        return string.format("%dm", math.floor(seconds / 60))
    end
    return string.format("%dh%02dm", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
end

-- days from 1970-01-01 to a date in the proleptic gregorian calendar
local function days_from_civil(y, m, d)
    if m <= 2 then
        y = y - 1
    end
    local era = math.floor(y / 400)
    local yoe = y - era * 400
    local mp = (m + 9) % 12
    local doy = math.floor((153 * mp + 2) / 5) + d - 1
    local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
    return era * 146097 + doe - 719468
end

-- seconds since an RFC 3339 UTC timestamp, without the local timezone
local function age(timestamp)
    local y, mo, d, h, mi, s = timestamp:match("^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
    if not y then
        return nil
    end
    local days = days_from_civil(tonumber(y), tonumber(mo), tonumber(d))
    local epoch = days * 86400 + tonumber(h) * 3600 + tonumber(mi) * 60 + tonumber(s)
    return math.max(0, os.time() - epoch)
end

-- the state and update time of the last status record an app reported
local function last_status(args)
    local status = rex.block.call(common.TERMINAL, "program_status", args)
    local state, updated = "", ""
    for _, record in ipairs(status and status.records or {}) do
        if record.app or record.effective_app then
            state, updated = record.state or "", record.updated_at or ""
        end
    end
    return state, updated
end

-- the panes running program, in tab order then layout order
local function panes(program)
    local found = {}
    for _, session in ipairs(common.sessions()) do
        local view = common.view(session.session_id)
        for tab, window in ipairs(view and view.windows or {}) do
            for pane, block in ipairs(common.layout_blocks(common.tiled_layout(window))) do
                local process = common.process(session.session_id, block)
                local fg = process and process.foreground
                if fg and common.program_name(fg) == program then
                    table.insert(found, {
                        block = block,
                        session = session,
                        window = window,
                        target = session.label .. ":" .. tab .. "." .. pane,
                        cwd = fg.cwd or "",
                        home = process.home or "",
                    })
                end
            end
        end
    end
    return found
end

-- the pane's title (claude's is its conversation summary, behind a spinner
-- glyph), or the tab's label when the title says nothing beyond the agent
local function pane_label(pane, agent)
    local title = rex.block.call(common.TERMINAL, "title", common.block_args(pane.session.session_id, pane.block))
    local text = (title and title.title or ""):gsub("^[^%w]*", "")
    if text ~= "" and not AGENT_TITLES[text] then
        return text
    end
    -- rex's placeholder tab label names the tab after its program
    local label = pane.window.label or ""
    return common.is_default_tab_label(label) and agent or label
end

local function agent_display(pane, agent)
    local args = common.block_args(pane.session.session_id, pane.block)
    local state, updated = last_status(args)
    local row = glyph(state) .. "  " .. pane.target .. " " .. pane_label(pane, agent)
    -- the age is the wait for a finished or blocked agent; a working one updates constantly
    local seconds = updated ~= "" and age(updated)
    if state ~= "" and state ~= "working" and seconds then
        row = row .. "  " .. elapsed(seconds)
    end
    return row
end

local function nvim_display(pane)
    local cwd = pane.cwd
    if pane.home ~= "" and cwd:sub(1, #pane.home) == pane.home then
        cwd = "~" .. cwd:sub(#pane.home + 1)
    end
    return pane.target .. " " .. cwd
end

local function logo(program)
    local cyan = os.getenv("TMUX_ACCENT_CYAN") or "#8be9fd"
    local light_cyan, dark_cyan = common.hex_fg(cyan), common.hex_fg(common.hex_dim(cyan, 65))
    local green = common.hex_fg(os.getenv("TMUX_ACCENT_GREEN") or "#50fa7b")
    local clay, codex = "\27[38;2;215;119;87m", "\27[0;32m"
    local eyes, mouth, bar = "\27[38;5;147m", "\27[38;5;176m", "\27[38;5;107m"
    local logos = {
        claude = {
            clay .. " ▐▛███▛█" .. RESET,
            clay .. "▝▜██████▀" .. RESET,
            clay .. " ▝▝   ▝▝" .. RESET,
        },
        codex = {
            codex .. "█▀▀ █▀▀█ █▀▀▄ █▀▀ █ █" .. RESET,
            codex .. "█   █  █ █  █ █▀▀ ▄▀▄" .. RESET,
            codex .. "▀▀▀ ▀▀▀▀ ▀▀▀  ▀▀▀ ▀ ▀" .. RESET,
        },
        opencode = {
            "                                " .. light_cyan .. "▄" .. RESET,
            dark_cyan
                .. "█▀▀█ █▀▀█ █▀▀█ █▀▀▄"
                .. RESET
                .. " "
                .. light_cyan
                .. "█▀▀ █▀▀█ █▀▀█ █▀▀█"
                .. RESET,
            dark_cyan
                .. "█  █ █  █ █▀▀▀ █  █"
                .. RESET
                .. " "
                .. light_cyan
                .. "█   █  █ █  █ █▀▀▀"
                .. RESET,
            dark_cyan
                .. "▀▀▀▀ █▀▀▀ ▀▀▀▀ ▀  ▀"
                .. RESET
                .. " "
                .. light_cyan
                .. "▀▀▀ ▀▀▀▀ ▀▀▀▀ ▀▀▀▀"
                .. RESET,
        },
        copilot = {
            "   " .. eyes .. "╭─╮╭─╮" .. RESET,
            "   " .. eyes .. "╰─╯╰─╯" .. RESET,
            "   " .. mouth .. "█" .. RESET .. " " .. bar .. "▘▝" .. RESET .. " " .. mouth .. "█" .. RESET,
            "    " .. mouth .. "▔▔▔▔" .. RESET,
        },
        nvim = {
            green .. "            ▗" .. RESET,
            green .. "▛▀▖▞▀▖▞▀▖▌ ▌▄ ▛▚▀▖" .. RESET,
            green .. "▌ ▌▛▀ ▌ ▌▐▐ ▐ ▌▐ ▌" .. RESET,
            green .. "▘ ▘▝▀▘▝▀  ▘ ▀▘▘▝ ▘" .. RESET,
        },
    }
    return logos[program] or {}
end

local function legend()
    local line = ""
    for _, state in ipairs({ "working", "blocked", "done", "idle", "error" }) do
        line = line .. " " .. glyph(state) .. " " .. state
    end
    return " " .. line
end

-- the logo, and for an agent the state legend, with empty leading fields so
-- they land in the displayed column. rows starting with a tab are the header
local function header(program)
    local lines = { "" }
    for _, line in ipairs(logo(program)) do
        table.insert(lines, line)
    end
    table.insert(lines, "")
    if program ~= "nvim" then
        table.insert(lines, legend())
        table.insert(lines, "")
    end
    for _, line in ipairs(lines) do
        common.out("\t\t\t" .. line)
    end
end

-- rows are block_id, session_id, window_id, display, most recently viewed first
function M.list(args)
    local program = args.program
    header(program)
    local rows = {}
    for _, pane in ipairs(panes(program)) do
        local display = program == "nvim" and nvim_display(pane) or agent_display(pane, program)
        table.insert(rows, { pane = pane, display = display })
    end
    local sorted = common.sort_recent(rows, "block", function(r)
        return r.pane.block
    end)
    for _, row in ipairs(sorted) do
        local pane = row.pane
        common.out(table.concat({ pane.block, pane.session.session_id, pane.window.window_id, row.display }, "\t"))
    end
end

function M.select(args)
    common.jump(args.session, args.window, args.block)
end

-- a new tab in the origin session, in the origin pane's directory, with the
-- program's command typed into its shell
function M.new(args)
    local process = common.origin_block ~= "" and common.process(common.origin_session, common.origin_block)
    local cwd = process and process.foreground and process.foreground.cwd or os.getenv("HOME")
    common.view(common.origin_session)
    local created = rex.session.new_window({
        session_id = common.origin_session,
        focus = true,
        layout = {
            block = { flavor = common.SHELL_FLAVOR, options = { cwd = cwd, initial_input = args.program .. "\r" } },
        },
    })
    common.jump(common.origin_session, created.window_id, created.block_ids[1])
end

local function foreground(args)
    common.view(args.session)
    local process = common.process(args.session, args.block)
    return process and process.foreground
end

-- "ask", then the message, for the kill confirmation; nothing when no program runs
function M.kill_check(args)
    local fg = foreground(args)
    if not fg or not fg.pid then
        return
    end
    common.out("ask\tKill " .. common.program_name(fg) .. " (pid " .. fg.pid .. ")?")
end

-- SIGTERM so the program can exit cleanly, SIGKILL if it's still there
local function stop(pid)
    if not rex.exec({ "kill", "-TERM", pid }).ok then
        return
    end
    for _ = 1, 20 do
        if not rex.exec({ "kill", "-0", pid }).ok then
            return
        end
        rex.sleep(0.1)
    end
    rex.exec({ "kill", "-KILL", pid })
end

-- stop the program, then close its pane
function M.kill(args)
    local fg = foreground(args)
    if not fg or not fg.pid then
        return
    end
    stop(tostring(fg.pid))
    rex.call("block.close", { session_id = args.session, block_id = args.block })
end

return M
