-- Core keymaps (non-plugin specific)
-- Plugin-specific keymaps are defined with their plugins

local M = {}

function M.setup()
  local spellcheck = require 'custom.core.spellcheck'

  -- Clear search highlight
  vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

  -- dd deletes without yanking; dy yanks and deletes (original dd behaviour).
  -- The operator-pending 'y' motion means "current line" (like _), so dy = d + line.
  vim.keymap.set('n', 'dd', '"_dd')
  vim.keymap.set('o', 'y', '_')

  -- Build
  vim.keymap.set('n', '<leader>q', function()
    require('custom.core.build').run()
  end, { desc = 'Build project or pick Make target' })

  -- Copy buffer path to clipboard
  vim.keymap.set('n', '<leader>by', function()
    local path = vim.fn.expand '%:p'
    vim.fn.setreg('+', path)
    vim.notify(path, vim.log.levels.INFO)
  end, { desc = '[Y]ank file path' })

  -- File explorer
  vim.keymap.set('n', '<leader>e', ':Neotree toggle<CR>', { desc = 'File [E]xplorer' })

  -- Git UI
  vim.keymap.set('n', '<leader>g', '<cmd>LazyGit<CR>', { desc = 'Lazy[G]it' })

  -- Undo tree
  vim.keymap.set('n', '<leader>u', function()
    vim.cmd 'packadd nvim.undotree'
    require('undotree').open { command = '60vnew' }
  end, { desc = '[U]ndo tree' })

  -- Shift+Enter → Enter (Ghostty sends Alt+Enter / \x1b\r)
  vim.keymap.set({ 'i', 'n', 'v', 'c' }, '<M-CR>', '<CR>')

  -- Insert space at cursor without leaving normal mode
  vim.keymap.set('n', '<leader>i', 'i<Space><Esc>', { desc = '[I]nsert space' })

  -- Terminal mode escape
  vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

  -- Window navigation
  vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
  vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
  vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
  vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

  -- Window zoom (toggle via tab)
  vim.keymap.set('n', '<leader>z', function()
    if vim.t.zoomed then
      vim.cmd 'tab close'
    elseif vim.fn.winnr '$' > 1 then
      vim.cmd 'tab split'
      vim.t.zoomed = true
    end
  end, { desc = 'Toggle [Z]oom' })

  -- Window resize (small increments)
  vim.keymap.set('n', '<leader>wh', '<cmd>vertical resize -5<CR>', { desc = 'Resize [H] left' })
  vim.keymap.set('n', '<leader>wl', '<cmd>vertical resize +5<CR>', { desc = 'Resize [L] right' })
  vim.keymap.set('n', '<leader>wj', '<cmd>resize -5<CR>', { desc = 'Resize [J] down' })
  vim.keymap.set('n', '<leader>wk', '<cmd>resize +5<CR>', { desc = 'Resize [K] up' })

  -- Window resize (maximise in a direction)
  vim.keymap.set('n', '<leader>wH', '<cmd>vertical resize 1<CR>', { desc = 'Maximise [H] left (shrink width)' })
  vim.keymap.set('n', '<leader>wL', '<cmd>vertical resize 999<CR>', { desc = 'Maximise [L] right (expand width)' })
  vim.keymap.set('n', '<leader>wJ', '<cmd>resize 1<CR>', { desc = 'Maximise [J] down (shrink height)' })
  vim.keymap.set('n', '<leader>wK', '<cmd>resize 999<CR>', { desc = 'Maximise [K] up (expand height)' })

  -- Window resize (equalise)
  vim.keymap.set('n', '<leader>w=', '<C-w>=', { desc = '[=] Equalise window sizes' })

  -- Line navigation: m/M for beginning/end of line, gm for marks
  vim.keymap.set({ 'n', 'v', 'o' }, 'm', '^', { desc = 'First non-blank character' })
  vim.keymap.set({ 'n', 'v', 'o' }, 'M', '$', { desc = 'End of line' })
  vim.keymap.set('n', 'gm', 'm', { desc = 'Set mark' })

  -- macOS-style navigation (Opt+arrows = word, Cmd+arrows = line)
  vim.keymap.set({ 'i', 'c' }, '<M-BS>', '<C-w>', { desc = 'Delete word backward (Opt+Backspace)' })
  vim.keymap.set('i', '<D-BS>', '<C-u>', { desc = 'Delete to beginning of line (Cmd+Backspace)' })
  vim.keymap.set({ 'n', 'v' }, '<M-Right>', 'w', { desc = 'Move word right (Opt+Right)' })
  vim.keymap.set({ 'n', 'v' }, '<M-Left>', 'b', { desc = 'Move word left (Opt+Left)' })
  vim.keymap.set({ 'n', 'v' }, '<M-f>', 'w', { desc = 'Move word right (Opt+Right)' })
  vim.keymap.set({ 'n', 'v' }, '<M-b>', 'b', { desc = 'Move word left (Opt+Left)' })
  vim.keymap.set('i', '<M-Left>', '<C-o>b', { desc = 'Move word left (Opt+Left)' })
  vim.keymap.set('i', '<M-Right>', '<C-o>w', { desc = 'Move word right (Opt+Right)' })
  vim.keymap.set('i', '<M-b>', '<C-o>b', { desc = 'Move word left (Opt+Left)' })
  vim.keymap.set('i', '<M-f>', '<C-o>w', { desc = 'Move word right (Opt+Right)' })
  vim.keymap.set('i', '<Home>', '<C-o>0', { desc = 'Beginning of line (Cmd+Left)' })
  vim.keymap.set('i', '<End>', '<C-o>$', { desc = 'End of line (Cmd+Right)' })

  -- Spelling
  vim.keymap.set('n', '<leader>St', '<cmd>set spell!<CR>', { desc = '[T]oggle spellcheck' })
  vim.keymap.set('n', '<leader>Sc', function()
    if not spellcheck.apply_first_suggestion() then
      vim.notify('No misspelled word under cursor', vim.log.levels.WARN)
    end
  end, { desc = 'Auto-[C]orrect word' })
  vim.keymap.set('n', '<leader>Sl', function()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local fixed = spellcheck.autocorrect_range(row, row)
    vim.notify(('Autocorrected %d word%s on this line'):format(fixed, fixed == 1 and '' or 's'))
  end, { desc = 'Auto-correct current [L]ine' })
  vim.keymap.set('n', '<leader>SB', function()
    local fixed = spellcheck.autocorrect_range(1, vim.api.nvim_buf_line_count(0))
    vim.notify(('Autocorrected %d word%s in buffer'):format(fixed, fixed == 1 and '' or 's'))
  end, { desc = 'Auto-correct [B]uffer' })
  vim.keymap.set('n', '<leader>Ss', function()
    require('telescope.builtin').spell_suggest(require('telescope.themes').get_cursor())
  end, { desc = '[S]uggest corrections' })
  vim.keymap.set('n', '<leader>Sa', 'zg', { desc = '[A]dd word to dictionary' })
  vim.keymap.set('n', '<leader>Sr', function()
    local word = vim.fn.expand '<cword>'
    if word == nil or word == '' then
      vim.notify('No word under cursor', vim.log.levels.WARN)
      return
    end

    local choice = vim.fn.confirm(('Mark "%s" as misspelled?'):format(word), '&Yes\n&No', 2)
    if choice == 1 then
      vim.cmd 'normal! zw'
    end
  end, { desc = '[R]emove word from dictionary' })
  vim.keymap.set('n', '<leader>S?', 'z=', { desc = 'Full suggestion list' })
  vim.keymap.set('n', '<leader>Sd', function()
    vim.cmd('edit ' .. vim.fn.stdpath 'data' .. '/spell/en.utf-8.add')
  end, { desc = '[D]ictionary (personal)' })

  -- Refresh: wipe all buffers, restart LSP, re-source config, reset layout
  vim.keymap.set('n', '<leader>lR', function()
    -- Close stateful plugins cleanly before wiping buffers
    pcall(vim.cmd, 'Neotree close')
    pcall(vim.cmd, 'DiffviewClose')
    pcall(vim.cmd, 'Trouble close')

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

    -- Stop all LSP clients
    for _, client in ipairs(vim.lsp.get_clients()) do
      client:stop(true)
    end

    -- Wipe all buffers (closes diffview, stale scratch buffers, etc.)
    local bufs = vim.api.nvim_list_bufs()
    for _, buf in ipairs(bufs) do
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end

    -- Re-source config
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
  end, { desc = '[R]efresh Neovim (clear buffers, restart LSP, reset layout)' })

  vim.keymap.set('n', '<leader>lt', function()
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
  end, { desc = 'Refresh [T]reesitter' })

  -- LuaSnip navigation keymaps
  vim.keymap.set({ 'i', 's' }, '<C-k>', function()
    local ls = require 'luasnip'
    if ls.expand_or_jumpable() then
      ls.expand_or_jump()
    end
  end, { desc = 'LuaSnip: Expand or jump to next placeholder' })

  vim.keymap.set({ 'i', 's' }, '<C-j>', function()
    local ls = require 'luasnip'
    if ls.jumpable(-1) then
      ls.jump(-1)
    end
  end, { desc = 'LuaSnip: Jump to previous placeholder' })
end

return M
