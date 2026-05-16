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

-- vim.diagnostic.severity values (1=ERROR, 2=WARN, 3=INFO, 4=HINT) → qf type letters.
local SEVERITY_TYPE = { 'E', 'W', 'I', 'N' }

-- Map raw `d.source` strings (what each LSP reports) to short labels used
-- as the `[label]` prefix in qf text. Unmapped sources fall through to the
-- raw value, so new LSPs degrade gracefully — add an entry here if a fresh
-- one shows up with a noisy label.
local SOURCE_LABEL = {
  sonarlint = 'sonar',
  sonarqube = 'sonar',
  typescript = 'ts',
  tsserver = 'ts',
  ['typescript-eslint'] = 'eslint',
  eslint = 'eslint',
  ['Lua Diagnostics.'] = 'lua',
  ['Lua Syntax Check.'] = 'lua',
  ['Lua Type Check.'] = 'lua',
  lua_ls = 'lua',
  luacheck = 'lua',
  roslyn = 'cs',
  omnisharp = 'cs',
  rust_analyzer = 'rust',
  rustc = 'rust',
  pyright = 'py',
  pylsp = 'py',
  ruff = 'py',
  pylint = 'py',
  gopls = 'go',
  golangci_lint = 'go',
  clangd = 'c',
  ['clang-tidy'] = 'c',
}

--- Short label for a diagnostic's source — looked up in SOURCE_LABEL, with
--- the raw source as fallback. Returns nil when the diagnostic carries no
--- source.
function M.source_label(d)
  local src = d.source
  if not src or src == '' then
    return nil
  end
  return SOURCE_LABEL[src] or src
end

--- Render a diagnostic's text with a `[label] ` prefix when the source is
--- known, so qf entries surface which LSP each warning came from
--- (sonar, ts, roslyn, …). build.lua's auto-clear keys its live-diagnostic
--- lookups by this same function so prune matches stay consistent with
--- what's displayed.
function M.qf_text(d)
  local label = M.source_label(d)
  if label then
    return '[' .. label .. '] ' .. (d.message or '')
  end
  return d.message or ''
end

--- Convert a vim.Diagnostic into a qf item. Used in place of
--- vim.diagnostic.toqflist so we can inject the source prefix into `text`.
function M.diag_to_item(d)
  return {
    bufnr = d.bufnr,
    lnum = (d.lnum or 0) + 1,
    end_lnum = (d.end_lnum or d.lnum or 0) + 1,
    col = d.col and (d.col + 1) or nil,
    end_col = d.end_col and (d.end_col + 1) or nil,
    text = M.qf_text(d),
    type = SEVERITY_TYPE[d.severity] or 'E',
  }
end

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
      for _, d in ipairs(get_diagnostics(bufnr)) do
        if d.lnum then
          local item = M.diag_to_item(d)
          if fname ~= '' then
            item.filename = fname
          end
          item.bufnr = nil
          table.insert(items, item)
        end
      end
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
