-- Refresh workflows: wipe buffers + restart LSP + re-source config,
-- and a lighter refresh for treesitter + semantic tokens.

local M = {}

local function refresh_nvim()
  -- Close stateful plugins cleanly before wiping buffers
  pcall(function()
    vim.cmd 'Neotree close'
  end)
  pcall(function()
    vim.cmd 'DiffviewClose'
  end)

  -- Close all splits so the window fills the terminal before wiping buffers
  vim.cmd 'only'

  -- Suppress shutdown noise from force-stopped LSP clients. Async exit
  -- callbacks (vim.schedule inside on_exit) arrive well after the defer
  -- below, so the wrapper must outlive the refresh sequence.
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

  -- Open the dashboard in the current window (not as a float) for a clean start
  vim.defer_fn(function()
    -- Restart Copilot — its lazy InsertEnter event won't re-fire after re-source
    pcall(function()
      require('copilot.command').enable()
    end)

    real_notify('Neovim refreshed', vim.log.levels.INFO)
    Snacks.dashboard.open { win = vim.api.nvim_get_current_win() }
  end, 200)

  -- Restore vim.notify after async LSP exit callbacks have had time to fire.
  -- Without this, repeated <leader>lR would chain wrappers (each capturing
  -- the previous wrapper as real_notify).
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

-- Re-render the dashboard in the current window without touching LSP/buffers.
local function open_dashboard()
  Snacks.dashboard.open { win = vim.api.nvim_get_current_win() }
end

function M.setup()
  vim.keymap.set('n', '<leader>lR', refresh_nvim, { desc = '[R]efresh Neovim (clear buffers, restart LSP, reset layout)' })
  vim.keymap.set('n', '<leader>lt', refresh_treesitter, { desc = 'Refresh [T]reesitter' })
  vim.keymap.set('n', '<leader>ld', open_dashboard, { desc = '[D]ashboard (re-render in current window)' })
end

return M
