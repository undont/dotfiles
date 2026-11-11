-- copy mode: nvim on the pane's scrollback, in a layer over that pane

local layers = require("layers")

-- floats over exactly the pane it reads, so the pane is never resized
local function copy_mode(ctx)
    if not ctx.block_id then
        return
    end
    local bounds = layers.pane_rect(layers.active_window(), ctx.block_id) or { 0, 0, 1, 1 }
    layers.open(ctx, "copy-mode.sh", bounds)
end

layers.action("`>v", "copy_mode", "Copy Mode (nvim)", copy_mode)
