-- keybindings migrated from tmux (prefix `) and ghostty, with rex's native closes.
-- the custom floats (pickers, copy mode, y/n kills) are in lua/actions.lua.
-- ctrl+s and ctrl+o are zle widgets in ~/.zshrc

package.path = os.getenv("HOME") .. "/.config/rex/lua/?.lua;" .. package.path

-- rex encodes modified enter as \e[27;<mod>;13~, which zsh leaks as text
rex.bind("shift+enter", "com.superlogical.terminal.write", { data = "\27\r" })
rex.bind("ctrl+enter", "com.superlogical.terminal.write", { data = "\27[13;5u" })
rex.bind("ctrl+shift+enter", "com.superlogical.terminal.write", { data = "\27[13;6u" })
-- rex's default sends ctrl+u, which scrolls claude code; this is ghostty's ctrl+backspace
rex.bind("cmd+backspace", "com.superlogical.terminal.write", { data = "\27[127;5u" })
-- rex's prompt jumps need OSC 133 shell integration rex doesn't inject into zsh;
-- these are ghostty's ctrl+home/end, which zsh binds to line start/end
rex.bind("cmd+up", "com.superlogical.terminal.write", { data = "\27[1;5H" })
rex.bind("cmd+down", "com.superlogical.terminal.write", { data = "\27[1;5F" })

rex.bind("`>`", "pane.send_key", { key = "`" })
rex.bind("`>ctrl+b", "pane.send_key", { key = "ctrl+b" })

-- tabs
rex.bind("alt+[", "client.tab.previous")
rex.bind("alt+]", "client.tab.next")
rex.bind("alt+t", "client.tab.new")
rex.bind("alt+shift+[", "client.tab.move", { direction = "backward" })
rex.bind("alt+shift+]", "client.tab.move", { direction = "forward" })
rex.bind("alt+r", "client.tab.rename")
rex.bind("alt+x", "client.tab.close")

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

rex.bind("alt+q", "session.close")

rex.bind("cmd+p", "session.switch")
rex.bind("cmd+j", "session.switch")
rex.bind("cmd+k", "pane.go_to")
rex.bind("cmd+l", "pane.view_activity")

require("nav")
require("copy-mode")
require("actions")
require("marks")
