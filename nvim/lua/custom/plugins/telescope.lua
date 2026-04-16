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

      local actions = require 'telescope.actions'

      require('telescope').setup {
        defaults = {
          -- Results show full relative path (default behaviour)
          path_display = { 'filename_first' },
          file_ignore_patterns = {
            '%.git/',
            '%.DS_Store',
          },
          mappings = {
            i = {
              ['<C-j>'] = actions.move_selection_next,
              ['<C-k>'] = actions.move_selection_previous,
              ['<C-f>'] = function(bufnr)
                for _ = 1, 10 do
                  actions.move_selection_next(bufnr)
                end
              end,
              ['<C-b>'] = function(bufnr)
                for _ = 1, 10 do
                  actions.move_selection_previous(bufnr)
                end
              end,
              ['<M-BS>'] = function()
                vim.api.nvim_input '<C-w>'
              end,
              ['<C-u>'] = function(prompt_bufnr)
                require('telescope.actions.state').get_current_picker(prompt_bufnr):set_prompt ''
              end,
              ['<C-g>'] = function(prompt_bufnr)
                actions.send_to_loclist(prompt_bufnr)
                actions.open_loclist(prompt_bufnr)
              end,
              ['<M-g>'] = function(prompt_bufnr)
                actions.send_selected_to_loclist(prompt_bufnr)
                actions.open_loclist(prompt_bufnr)
              end,
            },
          },
        },
        pickers = {
          find_files = {
            hidden = true,
          },
          live_grep = {
            additional_args = { '--hidden' },
          },
          grep_string = {
            additional_args = { '--hidden' },
          },
        },
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown {
              width = 0.9,
            },
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
      pcall(require('telescope').load_extension, 'harpoon')

      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = 'Search [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = 'Search [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = 'Search [F]iles' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = 'Telescope built-in[S]' })
      vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = 'Search [W]ord' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = 'Search [G]rep' })
      vim.keymap.set('n', '<leader>sG', function()
        builtin.live_grep { additional_args = { '--hidden', '--fixed-strings' } }
      end, { desc = 'Search [G]rep (literal)' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = 'Search [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = 'Search [R]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = 'Recent files [.]' })
      vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = 'Buffers' })

      -- Fuzzy search in current buffer
      vim.keymap.set('n', '<leader>s/', function()
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, { desc = 'Fuzzy search buffer' })

      -- Search Neovim config files
      vim.keymap.set('n', '<leader>sn', function()
        builtin.find_files { cwd = vim.fn.stdpath 'config' }
      end, { desc = 'Search [N]eovim files' })
    end,
  },
}
