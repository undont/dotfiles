-- drops qf/loclist entries once the diagnostic behind them is fixed, for
-- lists whose title carries a known "<Kind>:" prefix, and closes a list
-- that empties

local M = {}

local scan_runner = require 'features.scan-runner'

--- qf/loclist titles starting "<Kind>:" are pruned on DiagnosticChanged.
--- 'line' drops an item when its line has no live diagnostic (Build items come
--- from compiler output and lack the `[source]` text prefix). 'line_text' drops
--- it unless a live diagnostic has the same (lnum, text), the shape
--- scan_runner.diag_to_item builds. `Diagnostics: all` is absent: lists.lua's
--- debounced rebuild owns that list
local AUTO_CLEAR_KINDS = {
  Build = { label = 'Build errors resolved', match = 'line' },
  Sonar = { label = 'Sonar issues resolved', match = 'line_text' },
  Modified = { label = 'Modified file diagnostics resolved', match = 'line_text' },
  Branch = { label = 'Branch diagnostics resolved', match = 'line_text' },
  Ticket = { label = 'Ticket diagnostics resolved', match = 'line_text' },
  Project = { label = 'Project diagnostics resolved', match = 'line_text' },
  Buffer = { label = 'Buffer diagnostics resolved', match = 'line_text' },
}

--- returns (kind, label) when the list ends up empty, nil when nothing was
--- dropped or the title isn't in AUTO_CLEAR_KINDS. the current entry stays
--- current when it survives, otherwise idx moves to the nearest surviving
--- predecessor (setqflist resets idx to the first entry on replace)
local function prune_diag_list(list, replace, set_idx, bufnr, lookups)
  if not list.title then
    return
  end
  local kind = list.title:match '^(%w+):'
  local info = kind and AUTO_CLEAR_KINDS[kind]
  if not info then
    return
  end
  local lookup = lookups[info.match]

  local kept = {}
  local old_to_new = {}
  local dropped = 0
  for i, item in ipairs(list.items) do
    local key = info.match == 'line_text' and (item.lnum .. '\0' .. (item.text or '')) or item.lnum
    if item.bufnr == bufnr and item.valid == 1 and not lookup[key] then
      dropped = dropped + 1
    else
      table.insert(kept, item)
      old_to_new[i] = #kept
    end
  end

  if dropped == 0 then
    return
  end

  replace { title = list.title, items = kept }

  if #kept == 0 then
    return kind, info.label
  end

  if list.idx and list.idx > 0 then
    local new_idx = old_to_new[list.idx]
    if not new_idx then
      for i = list.idx - 1, 1, -1 do
        if old_to_new[i] then
          new_idx = old_to_new[i]
          break
        end
      end
    end
    if new_idx then
      set_idx(new_idx)
    end
  end
end

-- `changedtick` at the first DiagnosticChanged seen per buffer. pruning waits
-- for the tick to advance past it: the LSP's initial publish on a `]q` jump
-- into a fresh buffer need not cover the lines the qf entries came from
local first_seen_tick = {}

function M.setup()
  local group = vim.api.nvim_create_augroup('QfAutoClear', { clear = true })

  vim.api.nvim_create_autocmd({ 'BufWipeout', 'BufDelete' }, {
    group = group,
    callback = function(args)
      first_seen_tick[args.buf] = nil
    end,
  })

  vim.api.nvim_create_autocmd('DiagnosticChanged', {
    group = group,
    callback = function(args)
      local bufnr = args.buf
      if not vim.api.nvim_buf_is_loaded(bufnr) then
        return
      end
      if #vim.lsp.get_clients { bufnr = bufnr } == 0 then
        return
      end

      local tick = vim.b[bufnr].changedtick
      local baseline = first_seen_tick[bufnr]
      if baseline == nil then
        first_seen_tick[bufnr] = tick
        return
      end
      if tick <= baseline then
        return
      end

      local lines_with_diag = {}
      local diag_keys = {}
      for _, d in ipairs(vim.diagnostic.get(bufnr)) do
        local lnum = d.lnum + 1
        lines_with_diag[lnum] = true
        diag_keys[lnum .. '\0' .. scan_runner.qf_text(d)] = true
      end
      local lookups = { line = lines_with_diag, line_text = diag_keys }

      local qf = vim.fn.getqflist { title = 0, items = 0, idx = 0 }
      local qf_kind, qf_label = prune_diag_list(qf, function(d)
        vim.fn.setqflist({}, 'r', d)
      end, function(idx)
        vim.fn.setqflist({}, 'a', { idx = idx })
      end, bufnr, lookups)
      if qf_kind then
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local b = vim.api.nvim_win_get_buf(win)
          local info = vim.fn.getwininfo(win)[1]
          if vim.bo[b].buftype == 'quickfix' and info and info.loclist == 0 then
            vim.api.nvim_win_close(win, true)
          end
        end
        vim.notify(qf_label, vim.log.levels.INFO, { title = qf_kind, timeout = 3000 })
      end

      -- qf/loclist windows are skipped: their getloclist points back to the parent
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local b = vim.api.nvim_win_get_buf(win)
        if vim.bo[b].buftype ~= 'quickfix' then
          local loc = vim.fn.getloclist(win, { title = 0, items = 0, idx = 0 })
          local loc_kind, loc_label = prune_diag_list(loc, function(d)
            vim.fn.setloclist(win, {}, 'r', d)
          end, function(idx)
            vim.fn.setloclist(win, {}, 'a', { idx = idx })
          end, bufnr, lookups)
          if loc_kind then
            vim.api.nvim_win_call(win, function()
              vim.cmd 'lclose'
            end)
            vim.notify(loc_label, vim.log.levels.INFO, { title = loc_kind, timeout = 3000 })
          end
        end
      end
    end,
  })
end

return M
