-- tmux's marked pane: ` m toggles the mark, ` j moves the marked pane into a
-- split right of the focused one. rex only moves blocks within a session, and
-- the mark lives in memory, so a config reload clears it

---@type { session_id: string, block_id: string }?
local marked = nil

rex.action({
    name = "mark_pane",
    title = "Mark Pane (for join)",
    run = function(ctx)
        if not ctx.block_id then
            return
        end
        if marked and marked.block_id == ctx.block_id then
            marked = nil
            return
        end
        marked = { session_id = ctx.session_id, block_id = ctx.block_id }
    end,
})

rex.action({
    name = "join_marked_pane",
    title = "Join Marked Pane",
    run = function(ctx)
        if not marked or not ctx.block_id or marked.block_id == ctx.block_id then
            return
        end
        if marked.session_id ~= ctx.session_id then
            rex.log("warn", "join_marked_pane: the marked pane is in another session")
            return
        end
        local ok, err = pcall(rex.call, "session.move_block", {
            session_id = ctx.session_id,
            block_id = marked.block_id,
            anchor_block_id = ctx.block_id,
            direction = "horizontal",
            side = "after",
        })
        if not ok then
            rex.log("warn", "join_marked_pane: " .. tostring(err))
        end
        marked = nil
    end,
})

rex.bind("`>m", "mark_pane")
rex.bind("`>j", "join_marked_pane")
