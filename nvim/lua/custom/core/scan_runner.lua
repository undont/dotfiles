-- Shared diagnostic-scan state machine. Wraps the common pattern of:
--   open a set of buffers, debounce on DiagnosticChanged, snapshot
--   diagnostics into a titled quickfix, finalise.
-- Used by sonarlint project-scan and the git-modified scan in core/lists.lua.
--
-- Single global singleton: only one scan can be active at a time. Callers
-- check `is_active()` and reject (or merge) if a scan is already running --
-- this is the desired mutual exclusion since both flows write to the same
-- quickfix list.

local M = {}

local state = nil

local function clear_timer(t)
  if t then
    pcall(function()
      t:stop()
      t:close()
    end)
  end
end

--- @class ScanOpts
--- @field bufnrs integer[]                                       buffers whose diagnostics drive the debounce
--- @field collect_bufnrs? integer[]                              extra buffers to fold into the final qf (default = bufnrs)
--- @field get_diagnostics? fun(integer): vim.Diagnostic[]        defaults to vim.diagnostic.get
--- @field debounce_ms integer
--- @field hard_timeout_ms integer
--- @field qf_title string
--- @field qf_label string                                        shown in finalise notify ("X: clean" / "X: N issue(s)")
--- @field augroup_name string                                    unique per caller (e.g. "SonarlintScan")
--- @field on_finalise? fun(items: table[])                       post-collection hook (e.g. unload created buffers)
--- @field progress? { finish: fun() }                            optional fidget-shaped handle (must expose :finish())
--- @field hard_timeout_message? string                           shown on hard-timeout fire (default: no notify)

--- @param opts ScanOpts
--- @return boolean started — false if another scan is already active
function M.start(opts)
  if state then
    return false
  end
  local get_diagnostics = opts.get_diagnostics or vim.diagnostic.get
  local watched = {}
  for _, bufnr in ipairs(opts.bufnrs) do
    watched[bufnr] = true
  end

  -- Convert bufnr -> filename so qf entries survive any buffer-unload the
  -- caller does in on_finalise. Items keyed only by bufnr would crash
  -- setqflist ("E92: Buffer N not found") once the underlying buffer is gone.
  local function collect()
    local items = {}
    local seen_bufnr = {}
    local function pull(bufnr)
      if seen_bufnr[bufnr] or not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end
      seen_bufnr[bufnr] = true
      local fname = vim.api.nvim_buf_get_name(bufnr)
      local out = vim.diagnostic.toqflist(get_diagnostics(bufnr))
      for _, item in ipairs(out) do
        if fname ~= '' then
          item.filename = fname
        end
        item.bufnr = nil
      end
      vim.list_extend(items, out)
    end
    for _, bufnr in ipairs(opts.collect_bufnrs or opts.bufnrs) do
      pull(bufnr)
    end
    return items
  end

  local function finalise()
    if not state then
      return
    end
    clear_timer(state.debounce)
    clear_timer(state.hard_timeout)
    pcall(vim.api.nvim_del_augroup_by_id, state.augroup)

    local items = collect()
    if opts.on_finalise then
      pcall(opts.on_finalise, items)
    end

    vim.fn.setqflist({}, 'r', { title = opts.qf_title, items = items })

    if opts.progress then
      pcall(function()
        opts.progress:finish()
      end)
    end

    state = nil

    if #items > 0 then
      vim.notify(opts.qf_label .. ': ' .. #items .. ' issue(s)', vim.log.levels.WARN)
      vim.cmd 'botright copen'
    else
      vim.notify(opts.qf_label .. ': clean', vim.log.levels.INFO)
    end
  end

  local function reset_debounce()
    clear_timer(state.debounce)
    state.debounce = vim.uv.new_timer()
    state.debounce:start(opts.debounce_ms, 0, vim.schedule_wrap(finalise))
  end

  state = {
    augroup = vim.api.nvim_create_augroup(opts.augroup_name, { clear = true }),
    debounce = nil,
    hard_timeout = nil,
  }

  vim.api.nvim_create_autocmd('DiagnosticChanged', {
    group = state.augroup,
    callback = function(args)
      if state and watched[args.buf] then
        reset_debounce()
      end
    end,
  })

  reset_debounce()

  state.hard_timeout = vim.uv.new_timer()
  state.hard_timeout:start(
    opts.hard_timeout_ms,
    0,
    vim.schedule_wrap(function()
      if state then
        if opts.hard_timeout_message then
          vim.notify(opts.hard_timeout_message, vim.log.levels.WARN)
        end
        finalise()
      end
    end)
  )

  return true
end

function M.is_active()
  return state ~= nil
end

return M
