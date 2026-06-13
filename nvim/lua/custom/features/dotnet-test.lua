-- easy-dotnet test-runner extras. Extracted from plugins/dotnet.lua's
-- easy-dotnet config: trap window-nav keys in the test-explorer / peek floats,
-- and a <leader>tf that runs only the current file's tests (upstream's
-- run_all_tests_from_buffer is project-wide). setup() is called from
-- easy-dotnet's config after its own setup().

local M = {}

function M.setup()
  -- Trap window-navigation keys in test explorer and peek stacktrace floats.
  -- Without this, <C-h/j/k/l> escapes to the main buffer and the float
  -- becomes unreachable.
  local nav_block_group = vim.api.nvim_create_augroup('dotnet-float-nav-block', { clear = true })
  local nav_keys = { '<C-h>', '<C-j>', '<C-k>', '<C-l>' }

  local function block_nav(buf)
    for _, key in ipairs(nav_keys) do
      vim.keymap.set('n', key, '<Nop>', { buffer = buf })
    end
  end

  -- Test explorer (easy-dotnet filetype)
  vim.api.nvim_create_autocmd('FileType', {
    group = nav_block_group,
    pattern = 'easy-dotnet',
    callback = function(args)
      block_nav(args.buf)
    end,
  })

  -- Peek stacktrace floats (winfixbuf scratch buffers created by easy-dotnet).
  -- Deferred via vim.schedule so winfixbuf is set by window.lua before we check.
  vim.api.nvim_create_autocmd('WinEnter', {
    group = nav_block_group,
    callback = function()
      vim.schedule(function()
        local win = vim.api.nvim_get_current_win()
        if not vim.api.nvim_win_is_valid(win) then
          return
        end
        local cfg = vim.api.nvim_win_get_config(win)
        if cfg.relative == '' then
          return
        end
        if not vim.wo[win].winfixbuf then
          return
        end
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].filetype == 'easy-dotnet' then
          return
        end
        block_nav(buf)
        vim.keymap.set('n', '<Esc>', function()
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
          end
        end, { buffer = buf, nowait = true })
      end)
    end,
  })

  -- Run only tests in the current file (not the whole project).
  -- Upstream run_all_tests_from_buffer runs by projectId which is too broad.
  -- This finds TestClass nodes matching the current file and runs each one.
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'cs',
    callback = function(args)
      vim.keymap.set('n', '<leader>tf', function()
        local state = require 'easy-dotnet.test-runner.state'
        local client = require('easy-dotnet.rpc.rpc').global_rpc_client
        local filepath = vim.fs.normalize(vim.api.nvim_buf_get_name(args.buf))
        -- Collect test nodes belonging to this file. Run at class level
        -- to avoid running individual methods separately.
        local run_ids = {}
        local seen_ids = {}
        state.traverse_all(function(node)
          if not node.filePath or vim.fs.normalize(node.filePath) ~= filepath then
            return
          end
          -- Find the highest runnable ancestor for this file (class > method)
          local target = node
          if node.type and node.type.type and node.parentId then
            local parent = state.nodes[node.parentId]
            if parent and parent.filePath and vim.fs.normalize(parent.filePath) == filepath then
              target = parent
            end
          end
          if not seen_ids[target.id] then
            seen_ids[target.id] = true
            table.insert(run_ids, target.id)
          end
        end)
        if #run_ids == 0 then
          vim.notify('No tests found in this file', vim.log.levels.INFO)
          return
        end
        for _, id in ipairs(run_ids) do
          client.testrunner:run(id, function() end, 'buffer')
        end
      end, { buffer = args.buf, desc = 'Run [F]ile tests (.NET)' })
    end,
  })
end

return M
