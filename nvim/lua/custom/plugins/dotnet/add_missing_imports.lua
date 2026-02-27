-- Add missing imports across .cs files that have missing-type errors.
-- Runs dotnet build to find files with CS0246/CS0234/CS0103, then sends
-- source.addMissingImports only to those files via the Roslyn LSP client.

return function()
  local client = vim.lsp.get_clients({ name = 'easy_dotnet' })[1]
  if not client then
    vim.notify('Roslyn LSP not running — open a .cs file first', vim.log.levels.WARN)
    return
  end

  local notify_key = 'dotnet_add_imports'
  local function progress_notify(msg, level)
    vim.notify(msg, level or vim.log.levels.INFO, {
      key = notify_key,
      annote = 'dotnet imports',
      ttl = 3,
    })
  end

  -- Use the cached selected solution as the build target
  local target = require('easy-dotnet.current_solution').try_get_selected_solution()
  if not target then
    -- Walk up from cwd looking for a solution
    for _, ext in ipairs { '*.slnx', '*.sln' } do
      local matches = vim.fn.glob(ext, false, true)
      matches = vim.tbl_filter(function(p)
        return not vim.fs.basename(p):match '%.[%l][%w]*%.slnx?$'
      end, matches)
      if #matches > 0 then
        target = vim.fn.fnamemodify(matches[1], ':p')
        break
      end
    end
  end

  if not target then
    vim.notify('No solution file found', vim.log.levels.WARN)
    return
  end

  progress_notify 'Building to find missing imports...'

  local MISSING_CODES = { CS0246 = true, CS0234 = true, CS0103 = true }
  -- errorformat pattern: file(line,col): error CSxxxx: message
  local efm_pat = '^(.-)%((%d+),(%d+)%)%: %a+ (CS%d+)'

  vim.system(
    { 'dotnet', 'build', target, '-consoleloggerparameters:NoSummary', '--no-restore' },
    { text = true, cwd = vim.fn.getcwd() },
    vim.schedule_wrap(function(result)
      local output = (result.stdout or '') .. (result.stderr or '')
      -- Strip ANSI escape codes
      output = output:gsub('\027%[[%d;]*m', '')

      local files_with_errors = {}
      local seen = {}
      for line in output:gmatch '[^\n]+' do
        local filepath, _, _, code = line:match(efm_pat)
        if filepath and MISSING_CODES[code] then
          local abs = vim.fn.fnamemodify(filepath, ':p')
          if not seen[abs] and abs:match '%.cs$' and not abs:match '/obj/' and not abs:match '/bin/' then
            seen[abs] = true
            table.insert(files_with_errors, abs)
          end
        end
      end

      local total = #files_with_errors
      if total == 0 then
        progress_notify('No missing imports found', vim.log.levels.INFO)
        return
      end

      progress_notify(string.format('[0/%d] Adding missing imports...', total))

      local done = 0
      local changed = 0

      local function on_done()
        done = done + 1
        if done == total then
          progress_notify(string.format('Done — %d/%d file(s) changed', changed, total), vim.log.levels.INFO)
        elseif done % 10 == 0 then
          progress_notify(string.format('[%d/%d] Adding missing imports...', done, total))
        end
      end

      local function apply_edit_and_save(edit)
        vim.lsp.util.apply_workspace_edit(edit, 'utf-8')
      end

      -- Process files one at a time: open in a temp split, wait for
      -- diagnostics to confirm Roslyn has analysed it, apply the action,
      -- then close. Sequential to avoid many simultaneous windows.
      local queue = vim.list_slice(files_with_errors, 1)
      local prev_win = vim.api.nvim_get_current_win()

      local function process_next_file()
        if #queue == 0 then
          return
        end
        local filepath = table.remove(queue, 1)
        local fname = vim.fn.fnamemodify(filepath, ':t')
        local uri = vim.uri_from_fname(filepath)

        -- Check if already open in a buffer/window
        local existing_bufnr = vim.fn.bufnr(filepath)
        local was_loaded = existing_bufnr ~= -1 and vim.api.nvim_buf_is_loaded(existing_bufnr)

        -- Open in a small horizontal split so Roslyn activates fully
        local opened_win
        if not was_loaded then
          vim.cmd('noswapfile split ' .. vim.fn.fnameescape(filepath))
          opened_win = vim.api.nvim_get_current_win()
          vim.api.nvim_win_set_height(opened_win, 1)
        end

        local bufnr = vim.api.nvim_get_current_buf()
        if was_loaded then
          bufnr = existing_bufnr
        end

        local function close_and_next()
          if opened_win and vim.api.nvim_win_is_valid(opened_win) then
            vim.api.nvim_win_close(opened_win, true)
          end
          if not was_loaded and vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_delete(bufnr, { force = true })
          end
          -- Return focus to original window
          if vim.api.nvim_win_is_valid(prev_win) then
            vim.api.nvim_set_current_win(prev_win)
          end
          on_done()
          process_next_file()
        end

        -- Poll for diagnostics — when they arrive Roslyn has fully analysed the file
        local attempts = 0
        local function wait_then_act()
          attempts = attempts + 1
          local has_diags = #vim.diagnostic.get(bufnr) > 0
          if has_diags then
            client.request('textDocument/codeAction', {
              textDocument = { uri = uri },
              range = {
                start = { line = 0, character = 0 },
                ['end'] = { line = 0, character = 0 },
              },
              context = {
                diagnostics = {},
                only = { 'source.addMissingImports' },
                triggerKind = 1,
              },
            }, function(err, actions)
              if err or not actions or #actions == 0 then
                close_and_next()
                return
              end

              local action = actions[1]

              local function apply(edit)
                if edit then
                  apply_edit_and_save(edit)
                  -- write if the buffer was modified by the edit
                  if vim.bo[bufnr].modified then
                    vim.api.nvim_buf_call(bufnr, function()
                      vim.cmd 'noautocmd write'
                    end)
                    changed = changed + 1
                  end
                end
                close_and_next()
              end

              if action.edit then
                apply(action.edit)
              elseif vim.tbl_get(client, 'server_capabilities', 'codeActionProvider', 'resolveProvider') then
                client.request('codeAction/resolve', action, function(_, resolved)
                  apply(resolved and resolved.edit or nil)
                end)
              else
                close_and_next()
              end
            end)
          elseif attempts < 100 then
            vim.defer_fn(wait_then_act, 100)
          else
            vim.notify(fname .. ': timed out', vim.log.levels.WARN)
            close_and_next()
          end
        end

        vim.defer_fn(wait_then_act, 100)
      end

      process_next_file()
    end)
  )
end
