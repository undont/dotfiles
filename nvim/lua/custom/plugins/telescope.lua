-- Telescope fuzzy finder configuration

return {
  {
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    dependencies = {
      'nvim-lua/plenary.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
      'nvim-telescope/telescope-ui-select.nvim',
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      -- Helper to format path as parent/parent/filename (2 dirs up)
      local function short_path(path)
        local tail = require('telescope.utils').path_tail(path)
        local parent = vim.fn.fnamemodify(path, ':h:t')
        local grandparent = vim.fn.fnamemodify(path, ':h:h:t')
        if grandparent == '.' or grandparent == '' then
          if parent == '.' or parent == '' then
            return tail
          end
          return parent .. '/' .. tail
        end
        return grandparent .. '/' .. parent .. '/' .. tail
      end

      require('telescope').setup {
        defaults = {
          -- Results show full relative path (default behaviour)
          path_display = { 'filename_first' },
        },
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown(),
          },
        },
      }

      -- Override previewer to show short path in title
      local conf = require('telescope.config').values

      local original_file_previewer = conf.file_previewer
      conf.file_previewer = function(opts)
        opts = opts or {}
        local previewer = original_file_previewer(opts)
        local original_title = previewer.title
        previewer.title = function(self, entry)
          if entry and entry.path then
            return short_path(entry.path)
          elseif entry and entry.filename then
            return short_path(entry.filename)
          end
          return original_title and original_title(self, entry) or 'Preview'
        end
        return previewer
      end

      local original_grep_previewer = conf.grep_previewer
      conf.grep_previewer = function(opts)
        opts = opts or {}
        local previewer = original_grep_previewer(opts)
        local original_title = previewer.title
        previewer.title = function(self, entry)
          if entry and entry.path then
            return short_path(entry.path)
          elseif entry and entry.filename then
            return short_path(entry.filename)
          end
          return original_title and original_title(self, entry) or 'Preview'
        end
        return previewer
      end

      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

      -- Go to line number
      vim.keymap.set('n', '<leader>sl', function()
        vim.ui.input({ prompt = 'Go to line: ' }, function(input)
          if input then
            vim.cmd('normal! ' .. input .. 'G')
          end
        end)
      end, { desc = '[S]earch [L]ine (go to line number)' })

      -- Fuzzy search in current buffer
      vim.keymap.set('n', '<leader>/', function()
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, { desc = '[/] Fuzzily search in current buffer' })

      -- Search in open files
      vim.keymap.set('n', '<leader>s/', function()
        builtin.live_grep {
          grep_open_files = true,
          prompt_title = 'Live Grep in Open Files',
        }
      end, { desc = '[S]earch [/] in Open Files' })

      -- Search Neovim config files
      vim.keymap.set('n', '<leader>sn', function()
        builtin.find_files { cwd = vim.fn.stdpath 'config' }
      end, { desc = '[S]earch [N]eovim files' })
    end,
  },
}
