-- Claude Code prompt @ file picker
-- When editing Claude Code prompt files (claude-prompt-*.md, or any .md under .claude/),
-- maps @ in insert mode to open Telescope file finder for project file references.
-- On selection: inserts @path with proper spacing. On cancel: nothing inserted.
-- Type @@ to insert a literal @ character.

return {
  {
    dir = vim.fn.stdpath 'config',
    name = 'claude-prompt',
    enabled = true,
    ft = 'markdown',
    config = function()
      local group = vim.api.nvim_create_augroup('claude-prompt', { clear = true })

      vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
        pattern = '*.md',
        group = group,
        callback = function(ev)
          -- Only activate for Claude Code prompt files or files under .claude/
          local filename = vim.fn.fnamemodify(ev.file, ':t')
          local abs_path = vim.fn.fnamemodify(ev.file, ':p')
          if not filename:match '^claude%-prompt%-.*%.md$' and not abs_path:match '/%.claude/' then
            return
          end

          -- Use git root as project root (matches Claude Code's @ file resolution)
          local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
          local cwd = (vim.v.shell_error == 0 and git_root ~= '') and git_root or vim.fn.getcwd()

          -- Map @@ to insert a literal @ character
          vim.keymap.set('i', '@@', '@', { buffer = ev.buf, desc = 'Insert literal @' })

          -- Map @ in insert mode to open file picker
          vim.keymap.set('i', '@', function()
            -- Capture insert-mode cursor position before stopinsert shifts it left
            local insert_row = vim.fn.line '.'
            local insert_col = vim.fn.col '.' -- 1-indexed; where next char would be typed
            vim.cmd 'stopinsert'

            local actions = require 'telescope.actions'
            local action_state = require 'telescope.actions.state'

            require('telescope.builtin').find_files {
              prompt_title = '@ File Reference',
              cwd = cwd,
              attach_mappings = function(prompt_bufnr, map)
                -- On file selection: insert relative path at saved cursor position
                actions.select_default:replace(function()
                  local selection = action_state.get_selected_entry()
                  actions.close(prompt_bufnr)
                  vim.schedule(function()
                    if selection then
                      local path = selection.value or selection[1]
                      local line = vim.api.nvim_get_current_line()
                      local byte_col = insert_col - 1 -- 0-indexed for API
                      -- Add leading space if cursor follows a non-space character
                      local prefix = ''
                      if byte_col > 0 then
                        local before = line:sub(insert_col - 1, insert_col - 1)
                        if before ~= ' ' and before ~= '' then
                          prefix = ' '
                        end
                      end
                      local text = prefix .. '@' .. path
                      local row = insert_row - 1 -- 0-indexed
                      vim.api.nvim_buf_set_text(0, row, byte_col, row, byte_col, { text })
                      -- Resume insert mode after inserted text
                      local end_col = byte_col + #text
                      if end_col >= #vim.api.nvim_get_current_line() then
                        vim.cmd 'startinsert!'
                      else
                        vim.api.nvim_win_set_cursor(0, { insert_row, end_col })
                        vim.cmd 'startinsert'
                      end
                    else
                      vim.cmd 'startinsert!'
                    end
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
