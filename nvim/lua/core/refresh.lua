-- refresh workflows: wipe buffers + restart LSP + re-source config,
-- and a lighter refresh for treesitter + semantic tokens

local M = {}

local function refresh_nvim()
  pcall(function()
    vim.cmd 'Neotree close'
  end)
  pcall(function()
    vim.cmd 'Differ close'
  end)

  vim.cmd 'only'

  -- drops shutdown messages from force-stopped LSP clients. their exit
  -- callbacks arrive after the dashboard defer below
  local real_notify = vim.notify
  local suppressing = true
  vim.notify = function(msg, level, opts)
    if suppressing and type(msg) == 'string' then
      if msg:match 'quit with exit code' or msg:match 'server stopped' or msg:match 'Re%-sourcing' then
        return
      end
    end
    return real_notify(msg, level, opts)
  end

  for _, client in ipairs(vim.lsp.get_clients()) do
    client:stop(true)
  end

  local bufs = vim.api.nvim_list_bufs()
  for _, buf in ipairs(bufs) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end

  vim.cmd 'source $MYVIMRC'

  vim.defer_fn(function()
    -- copilot's lazy InsertEnter event does not fire again after a re-source
    pcall(function()
      require('copilot.command').enable()
    end)

    real_notify('Neovim refreshed', vim.log.levels.INFO)
    ---@diagnostic disable-next-line: missing-fields
    Snacks.dashboard.open { win = vim.api.nvim_get_current_win() }
  end, 200)

  -- restored once the exit callbacks have fired; left in place, a second
  -- <leader>lR would capture this wrapper as real_notify
  vim.defer_fn(function()
    vim.notify = real_notify
  end, 3000)
end

local function refresh_treesitter()
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype
  local lang = vim.treesitter.language.get_lang(ft) or ft

  if lang ~= '' and not pcall(vim.treesitter.language.inspect, lang) then
    vim.notify('Missing tree-sitter parser for ' .. lang .. '. Run :TSInstall ' .. lang, vim.log.levels.WARN)
    return
  end

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if ok and parser then
    parser:parse(true)
  end

  if vim.lsp.semantic_tokens then
    vim.lsp.semantic_tokens.force_refresh(bufnr)
  end

  vim.notify('Refreshed tree-sitter', vim.log.levels.INFO)
end

-- the buffer the dashboard toggle replaced, restored on the next toggle
local dashboard_prev_buf = nil

local function toggle_dashboard()
  if vim.bo.filetype == 'snacks_dashboard' then
    local target = dashboard_prev_buf
    if not (target and vim.api.nvim_buf_is_valid(target)) then
      local alt = vim.fn.bufnr '#'
      target = alt > 0 and vim.api.nvim_buf_is_valid(alt) and alt or nil
    end
    if target then
      vim.api.nvim_set_current_buf(target)
    end
    dashboard_prev_buf = nil
    return
  end

  dashboard_prev_buf = vim.api.nvim_get_current_buf()
  ---@diagnostic disable-next-line: missing-fields
  Snacks.dashboard.open { win = vim.api.nvim_get_current_win() }
end

function M.setup()
  vim.keymap.set('n', '<leader>lR', refresh_nvim, { desc = '[R]efresh Neovim (clear buffers, restart LSP, reset layout)' })
  vim.keymap.set('n', '<leader>lt', refresh_treesitter, { desc = 'Refresh [T]reesitter' })
  vim.keymap.set('n', '<leader>ld', toggle_dashboard, { desc = '[D]ashboard (toggle in current window)' })
end

return M
