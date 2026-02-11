-- Claude Code prompt @ file picker
-- When editing Claude Code prompt files (claude-prompt-*.md via Ctrl+G),
-- maps @ in insert mode to open Telescope file finder for project file references.
-- On selection: inserts @path with proper spacing. On cancel: nothing inserted.

return {
  {
    dir = vim.fn.stdpath 'config',
    name = 'claude-prompt',
    ft = 'markdown',
    config = function()
      local group = vim.api.nvim_create_augroup('claude-prompt', { clear = true })

      vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
        pattern = '*.md',
        group = group,
        callback = function(ev)
          -- Only activate for Claude Code prompt files
          local filename = vim.fn.fnamemodify(ev.file, ':t')
          if not filename:match '^claude%-prompt%-.*%.md$' then
            return
          end

          -- Use git root as project root (matches Claude Code's @ file resolution)
          local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
          local cwd = (vim.v.shell_error == 0 and git_root ~= '') and git_root or vim.fn.getcwd()

          -- Map @ in insert mode to open file picker
          vim.keymap.set('i', '@', function()
            vim.cmd 'stopinsert'

            local actions = require 'telescope.actions'
            local action_state = require 'telescope.actions.state'

            require('telescope.builtin').find_files {
              prompt_title = '@ File Reference',
              cwd = cwd,
              attach_mappings = function(prompt_bufnr, map)
                -- On file selection: insert relative path
                actions.select_default:replace(function()
                  local selection = action_state.get_selected_entry()
                  actions.close(prompt_bufnr)
                  vim.schedule(function()
                    if selection then
                      local path = selection.value or selection[1]
                      -- Add leading space if cursor follows a non-space character
                      local col = vim.fn.col '.'
                      local prefix = ''
                      if col > 1 then
                        local line = vim.api.nvim_get_current_line()
                        local before = line:sub(col - 1, col - 1)
                        if before ~= ' ' and before ~= '' then
                          prefix = ' '
                        end
                      end
                      vim.api.nvim_put({ prefix .. '@' .. path }, 'c', false, true)
                    end
                    vim.cmd 'startinsert!'
                  end)
                end)

                -- On Esc: cancel without inserting anything
                map('i', '<Esc>', function()
                  actions.close(prompt_bufnr)
                  vim.schedule(function()
                    vim.cmd 'startinsert!'
                  end)
                end)

                return true
              end,
            }
          end, { buffer = ev.buf, desc = 'Claude @ file reference' })
        end,
      })
    end,
  },
}
