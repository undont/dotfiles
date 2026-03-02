-- Editor plugins: treesitter, indent detection, etc.

return {
  -- Treesitter for syntax highlighting
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    lazy = false, -- treesitter doesn't support lazy loading
    build = ':TSUpdate',
    config = function()
      local parsers = {
        'bash',
        'c',
        'c_sharp',
        'css',
        'diff',
        'dockerfile',
        'go',
        'html',
        'http',
        'javascript',
        'jsdoc',
        'json',
        'make',
        'python',
        -- lua, luadoc, vim, vimdoc, query, markdown, markdown_inline are bundled
        -- with Neovim 0.11+ — let Neovim manage them to avoid query/parser mismatches
        'tsx',
        'typescript',
        'xml',
        'yaml',
      }

      -- Purge compiled parsers when nvim-treesitter updates to prevent ABI crashes.
      -- Old .so files compiled against a previous treesitter ABI can crash Neovim
      -- when opened (e.g. markdown, c_sharp after breaking updates).
      local parser_dir = vim.fn.stdpath 'data' .. '/site/parser'
      local marker_path = vim.fn.stdpath 'data' .. '/nvim-treesitter-rev'
      local plugin_dir = vim.fn.stdpath 'data' .. '/lazy/nvim-treesitter'
      local current_rev = vim.fn.system('git -C ' .. plugin_dir .. ' rev-parse --short HEAD 2>/dev/null'):gsub('%s+', '')
      if current_rev ~= '' then
        local stored_rev = ''
        local f = io.open(marker_path, 'r')
        if f then
          stored_rev = f:read '*a' or ''
          f:close()
          stored_rev = stored_rev:gsub('%s+', '')
        end
        if stored_rev ~= current_rev then
          -- Plugin updated — purge all compiled parsers so they reinstall cleanly
          local stat = vim.uv.fs_stat(parser_dir)
          if stat and stat.type == 'directory' then
            local handle = vim.uv.fs_scandir(parser_dir)
            if handle then
              while true do
                local name, typ = vim.uv.fs_scandir_next(handle)
                if not name then
                  break
                end
                if typ == 'file' and name:match '%.so$' then
                  os.remove(parser_dir .. '/' .. name)
                end
              end
            end
            vim.notify('nvim-treesitter updated — reinstalling parsers', vim.log.levels.INFO)
          end
          -- Write new marker
          f = io.open(marker_path, 'w')
          if f then
            f:write(current_rev)
            f:close()
          end
        end
      end

      -- Remove any nvim-treesitter-managed copies of parsers bundled with Neovim 0.11+
      -- so that Neovim's own (always-compatible) versions take precedence.
      local nvim_bundled = { 'lua', 'luadoc', 'vim', 'vimdoc', 'query', 'markdown', 'markdown_inline' }
      for _, lang in ipairs(nvim_bundled) do
        local so = parser_dir .. '/' .. lang .. '.so'
        if vim.uv.fs_stat(so) then
          os.remove(so)
        end
      end

      -- Install any parsers from the list that aren't already on disk
      local missing = vim.tbl_filter(function(lang)
        return not pcall(vim.treesitter.language.inspect, lang)
      end, parsers)
      if #missing > 0 then
        require('nvim-treesitter').install(missing)
      end

      -- Enable treesitter highlighting and indentation for all supported filetypes
      vim.api.nvim_create_autocmd('FileType', {
        callback = function()
          if pcall(vim.treesitter.start) then
            vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })

      -- Register language aliases for markdown code fence highlighting
      vim.treesitter.language.register('c_sharp', { 'csharp', 'cs' })
    end,
  },

  -- Detect tabstop and shiftwidth automatically
  { 'NMAC427/guess-indent.nvim', event = 'BufReadPost', opts = {} },

  -- Cheatsheet for keybindings and commands
  {
    'sudormrfbin/cheatsheet.nvim',
    cmd = 'Cheatsheet',
    keys = {
      { '<leader>?', '<cmd>Cheatsheet<CR>', desc = 'Open cheatsheet' },
    },
    dependencies = {
      'nvim-telescope/telescope.nvim',
      'nvim-lua/popup.nvim',
      'nvim-lua/plenary.nvim',
    },
    opts = {
      bundled_cheatsheets = false,
      bundled_plugin_cheatsheets = false,
    },
  },

  -- Flash: jump/motion plugin
  {
    'folke/flash.nvim',
    event = 'VeryLazy',
    ---@type Flash.Config
    opts = {},
    -- stylua: ignore
    keys = {
      { 's', mode = { 'n', 'x', 'o' }, function() require('flash').jump() end, desc = 'Flash' },
      { 'S', mode = { 'n', 'x', 'o' }, function() require('flash').treesitter() end, desc = 'Flash Treesitter' },
      { 'r', mode = 'o', function() require('flash').remote() end, desc = 'Remote Flash' },
      { 'R', mode = { 'o', 'x' }, function() require('flash').treesitter_search() end, desc = 'Treesitter Search' },
      { '<C-s>', mode = 'c', function() require('flash').toggle() end, desc = 'Toggle Flash Search' },
    },
  },

  -- Treesitter textobjects: structural selection and motion
  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    branch = 'main',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    event = 'VeryLazy',
    config = function()
      local ts_select = require 'nvim-treesitter-textobjects.select'
      local ts_move = require 'nvim-treesitter-textobjects.move'
      local ts_swap = require 'nvim-treesitter-textobjects.swap'

      require('nvim-treesitter-textobjects').setup {
        select = { lookahead = true },
        move = { set_jumps = true },
      }

      -- Select textobjects
      local select_maps = {
        { 'am', '@function.outer', 'Around method/function' },
        { 'im', '@function.inner', 'Inside method/function' },
        { 'aC', '@class.outer', 'Around class' },
        { 'iC', '@class.inner', 'Inside class' },
      }
      for _, map in ipairs(select_maps) do
        vim.keymap.set({ 'x', 'o' }, map[1], function()
          ts_select.select_textobject(map[2])
        end, { desc = map[3] })
      end

      -- Move to next/previous function
      vim.keymap.set({ 'n', 'x', 'o' }, ']m', function()
        ts_move.goto_next_start '@function.outer'
      end, { desc = 'Next function start' })
      vim.keymap.set({ 'n', 'x', 'o' }, '[m', function()
        ts_move.goto_previous_start '@function.outer'
      end, { desc = 'Previous function start' })
      vim.keymap.set({ 'n', 'x', 'o' }, ']M', function()
        ts_move.goto_next_end '@function.outer'
      end, { desc = 'Next function end' })
      vim.keymap.set({ 'n', 'x', 'o' }, '[M', function()
        ts_move.goto_previous_end '@function.outer'
      end, { desc = 'Previous function end' })

      -- Swap parameters
      vim.keymap.set('n', '<leader>a', function()
        ts_swap.swap_next '@parameter.inner'
      end, { desc = 'Swap parameter with next' })
      vim.keymap.set('n', '<leader>A', function()
        ts_swap.swap_previous '@parameter.inner'
      end, { desc = 'Swap parameter with previous' })
    end,
  },

  -- Grug-far: project-wide search and replace
  {
    'MagicDuck/grug-far.nvim',
    cmd = 'GrugFar',
    keys = {
      {
        '<leader>sR',
        function()
          require('grug-far').open()
        end,
        desc = 'Search & [R]eplace',
      },
      {
        '<leader>sR',
        mode = 'v',
        function()
          require('grug-far').open { prefills = { search = vim.fn.expand '<cword>' } }
        end,
        desc = 'Search & [R]eplace (word)',
      },
    },
    opts = {},
  },

  -- Multiple cursors
  {
    'mg979/vim-visual-multi',
    lazy = false,
    init = function()
      vim.g.VM_maps = {
        ['Add Cursor Up'] = '<M-Up>',
        ['Add Cursor Down'] = '<M-Down>',
      }
    end,
  },

  -- Oil: filesystem-as-buffer
  {
    'stevearc/oil.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    keys = {
      { '-', '<cmd>Oil<CR>', desc = 'Oil: Open parent directory' },
    },
    opts = {
      default_file_explorer = false,
      columns = { 'icon' },
      view_options = { show_hidden = true },
    },
  },
}
