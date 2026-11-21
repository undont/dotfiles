-- keybindings migrated from tmux (prefix `) and ghostty, with rex's native closes.
-- the custom floats (pickers, y/n kills) are in lua/.
-- ctrl+s and ctrl+o are zle widgets in ~/.zshrc

package.path = os.getenv("HOME") .. "/.config/rex/lua/?.lua;" .. package.path

-- rex encodes modified enter as \e[27;<mod>;13~, which zsh leaks as text
rex.bind("shift+enter", "com.superlogical.terminal.write", { data = "\27\r" })
rex.bind("ctrl+enter", "com.superlogical.terminal.write", { data = "\27[13;5u" })
rex.bind("ctrl+shift+enter", "com.superlogical.terminal.write", { data = "\27[13;6u" })
-- rex's default sends ctrl+u, which scrolls claude code; this is ghostty's ctrl+backspace
rex.bind("cmd+backspace", "com.superlogical.terminal.write", { data = "\27[127;5u" })
-- ghostty's ctrl+home/end, which zsh binds to line start/end
rex.bind("cmd+up", "com.superlogical.terminal.write", { data = "\27[1;5H" })
rex.bind("cmd+down", "com.superlogical.terminal.write", { data = "\27[1;5F" })
-- the prompt marks come from POWERLEVEL9K_TERM_SHELL_INTEGRATION in ~/.p10k.zsh
rex.bind("cmd+shift+up", "client.prompt.previous")
rex.bind("cmd+shift+down", "client.prompt.next")

rex.bind("`>`", "pane.send_key", { key = "`" })
rex.bind("`>ctrl+b", "pane.send_key", { key = "ctrl+b" })

-- tabs
rex.bind("alt+[", "client.tab.move", { direction = "backward" })
rex.bind("alt+]", "client.tab.move", { direction = "forward" })
rex.bind("alt+shift+[", "client.tab.move", { direction = "backward" })
rex.bind("alt+shift+]", "client.tab.move", { direction = "forward" })

-- panes
for key, direction in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
    rex.bind("alt+" .. key, "pane.focus", { direction = direction })
    rex.bind("shift+cmd+" .. key, "pane.focus", { direction = direction })
    rex.bind("alt+shift+cmd+" .. key, "pane.move", { direction = direction })
    rex.bind("alt+shift+" .. key, "pane.resize", { amount = 5, direction = direction })
end

rex.bind("ctrl+,", "pane.focus", { direction = "left" })
rex.bind("ctrl+.", "pane.focus", { direction = "down" })

rex.bind("alt+\\", "pane.split", { direction = "right" })
rex.bind("alt+'", "pane.split", { direction = "left" })
rex.bind("alt+-", "pane.split", { direction = "down" })
rex.bind("alt+=", "pane.split", { direction = "up" })

rex.bind("`>shift+e", "pane.move_to_new_tab")
rex.bind("alt+shift+0", "pane.balance")

rex.bind("cmd+\\", "client.sidebar.toggle")
rex.bind("cmd+shift+\\", "client.sidebar.toggle")
rex.bind("cmd+shift+/", "client.sidebar.toggle")

rex.bind("cmd+p", "session.switch")
rex.bind("cmd+j", "session.switch")
rex.bind("cmd+k", "pane.go_to")
rex.bind("cmd+l", "pane.view_activity")

rex.bind("cmd+[", "client.tab.previous")
rex.bind("cmd+]", "client.tab.next")

-- works alongside default cmd+shift+c
-- enter copy-mode bind
rex.bind("`>v", "pane.copy_mode.enter")
rex.bind("copy/m", "pane.copy_mode.move", { to = "line_first_non_blank" })
rex.bind("copy/shift+m", "pane.copy_mode.move", { to = "line_end" })
rex.bind("copy/u", "pane.copy_mode.move", { to = "half_page_up" })
rex.bind("copy/d", "pane.copy_mode.move", { to = "half_page_down" })

require("nav")
require("actions")
require("marks")
require("app-actions")

local overrides = {}
local local_path = os.getenv("HOME") .. "/.config/rex/local.lua"
local f = io.open(local_path, "r")
if f then
    f:close()
    overrides = dofile(local_path) or {}
end

local font_size = overrides.font_size or 17

-- resize all terminals in the client with cmd+/-
rex.bind("cmd+=", "client.setting.terminal.typography.size", { increase = 1 })
rex.bind("cmd+-", "client.setting.terminal.typography.size", { decrease = 1 })
rex.bind("cmd+0", "client.setting.terminal.typography.size", { value = font_size })

rex.bind("cmd+shift+r", "client.config.reload")
