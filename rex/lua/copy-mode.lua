-- copy mode: nvim on the pane's scrollback, in a layer over that pane

local layers = require("layers")

-- floats over exactly the pane it reads, so the pane is never resized
local function copy_mode(ctx)
    if not ctx.block_id then
        return
    end
    local win = layers.active_window()
    local bounds = { 0, 0, 1, 1 }
    if win.zoomed_block_id ~= ctx.block_id then
        bounds = layers.block_rect(win, ctx.block_id) or bounds
    end
    layers.open(ctx, "copy-mode.sh", bounds)
end

rex.action({ name = "copy_mode", title = "Copy Mode (nvim)", run = copy_mode })
rex.bind("`>v", "copy_mode")
