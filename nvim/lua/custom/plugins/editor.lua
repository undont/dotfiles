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

      -- Remove any nvim-treesitter-managed copies of parsers bundled with Neovim
      -- so that Neovim's own (always-compatible) versions take precedence.
      -- Check both the site parser dir and the Lazy plugin parser dir.
      local nvim_bundled = { 'lua', 'luadoc', 'vim', 'vimdoc', 'query', 'markdown', 'markdown_inline' }
      local bundled_dirs = { parser_dir, plugin_dir .. '/parser' }
      for _, dir in ipairs(bundled_dirs) do
        for _, lang in ipairs(nvim_bundled) do
          local so = dir .. '/' .. lang .. '.so'
          if vim.uv.fs_stat(so) then
            os.remove(so)
          end
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
            -- Only set treesitter indentexpr when indent queries exist for this
            -- language, otherwise fall back to Vim's native indent (autoindent,
            -- cindent, or filetype-specific indentexpr). Without this check,
            -- languages like C# that lack indent queries get forced to column 0.
            local lang = vim.treesitter.language.get_lang(vim.bo.filetype) or vim.bo.filetype
            if vim.treesitter.query.get(lang, 'indents') then
              vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            end
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
      vim.keymap.set('n', '>p', function()
        local ok, parser = pcall(vim.treesitter.get_parser)
        if not ok or not parser then
          vim.notify('No treesitter parser for this buffer', vim.log.levels.WARN)
          return
        end
        ts_swap.swap_next '@parameter.inner'
      end, { desc = 'Swap parameter right' })
      vim.keymap.set('n', '<p', function()
        local ok, parser = pcall(vim.treesitter.get_parser)
        if not ok or not parser then
          vim.notify('No treesitter parser for this buffer', vim.log.levels.WARN)
          return
        end
        ts_swap.swap_previous '@parameter.inner'
      end, { desc = 'Swap parameter left' })
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
      vim.g.VM_silent_exit = 1
      vim.g.VM_maps = {
        ['Add Cursor Up'] = '<M-Up>',
        ['Add Cursor Down'] = '<M-Down>',
        -- Disable motions that conflict with buffer-local maps (markdown gj/gk,
        -- mkdnflow o/O/<Del>) and insert maps (blink.cmp) to avoid startup stutter
        ['Motion j'] = '',
        ['Motion k'] = '',
        ['o'] = '',
        ['O'] = '',
        ['Del'] = '',
        ['I CtrlB'] = '',
        ['I CtrlD'] = '',
        ['I CtrlF'] = '',
        ['I Return'] = '',
        ['I Down Arrow'] = '',
        ['I Up Arrow'] = '',
        ['Goto Prev'] = '',
        ['Goto Next'] = '',
      }
    end,
  },

  -- Buffer removal without closing windows
  {
    'echasnovski/mini.bufremove',
    keys = {
      {
        '<leader>bd',
        function()
          require('mini.bufremove').delete(0, false)
        end,
        desc = '[D]elete buffer',
      },
      {
        '<leader>bD',
        function()
          require('mini.bufremove').delete(0, true)
        end,
        desc = '[D]elete buffer (force)',
      },
      {
        '<leader>ba',
        function()
          local current = vim.api.nvim_get_current_buf()
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if buf ~= current and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
              require('mini.bufremove').delete(buf, true)
            end
          end
        end,
        desc = 'Delete [A]ll other buffers',
      },
    },
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
      keymaps = {
        ['q'] = { 'actions.close', mode = 'n' },
      },
    },
  },

  -- Smart paste: auto-adjusts indentation when pasting
  {
    'nemanjamalesija/smart-paste.nvim',
    event = 'VeryLazy',
    opts = {},
  },

  -- Dial: increment/decrement engine
  {
    'monaqa/dial.nvim',
    keys = {
      {
        '<C-a>',
        function()
          if not vim.bo.modifiable then
            return
          end
          require('dial.map').manipulate('increment', 'normal')
        end,
        desc = 'Increment',
      },
      {
        '<C-x>',
        function()
          if not vim.bo.modifiable then
            return
          end
          require('dial.map').manipulate('decrement', 'normal')
        end,
        desc = 'Decrement',
      },
      {
        'g<C-a>',
        function()
          if not vim.bo.modifiable then
            return
          end
          require('dial.map').manipulate('increment', 'gnormal')
        end,
        desc = 'Increment (sequential)',
      },
      {
        'g<C-x>',
        function()
          if not vim.bo.modifiable then
            return
          end
          require('dial.map').manipulate('decrement', 'gnormal')
        end,
        desc = 'Decrement (sequential)',
      },
      {
        '<C-a>',
        mode = 'v',
        function()
          if not vim.bo.modifiable then
            return
          end
          require('dial.map').manipulate('increment', 'visual')
        end,
        desc = 'Increment',
      },
      {
        '<C-x>',
        mode = 'v',
        function()
          if not vim.bo.modifiable then
            return
          end
          require('dial.map').manipulate('decrement', 'visual')
        end,
        desc = 'Decrement',
      },
      {
        'g<C-a>',
        mode = 'v',
        function()
          if not vim.bo.modifiable then
            return
          end
          require('dial.map').manipulate('increment', 'gvisual')
        end,
        desc = 'Increment (sequential)',
      },
      {
        'g<C-x>',
        mode = 'v',
        function()
          if not vim.bo.modifiable then
            return
          end
          require('dial.map').manipulate('decrement', 'gvisual')
        end,
        desc = 'Decrement (sequential)',
      },
    },
    config = function()
      local augend = require 'dial.augend'
      require('dial.config').augends:register_group {
        default = {
          augend.integer.alias.decimal,
          augend.integer.alias.hex,
          augend.constant.alias.bool,
          augend.date.alias['%Y-%m-%d'],
          augend.semver.alias.semver,
        },
      }
    end,
  },

  -- TailwindCSS dial: increment/decrement tailwind classes
  {
    'ruicsh/tailwindcss-dial.nvim',
    dependencies = { 'monaqa/dial.nvim' },
    ft = { 'html', 'css', 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'astro', 'vue', 'svelte' },
    opts = {},
  },

  -- Harpoon2: quick file navigation
  {
    'ThePrimeagen/harpoon',
    branch = 'harpoon2',
    dependencies = { 'nvim-lua/plenary.nvim' },
    event = 'VeryLazy',
    config = function()
      local harpoon = require 'harpoon'
      harpoon:setup {
        settings = {
          save_on_toggle = true,
          sync_on_ui_close = true,
        },
      }

      -- Keymaps
      vim.keymap.set('n', '<leader>ha', function()
        harpoon:list():add()
      end, { desc = '[H]arpoon: [a]dd file' })

      vim.keymap.set('n', '<leader>hl', function()
        harpoon.ui:toggle_quick_menu(harpoon:list())
      end, { desc = '[H]arpoon: [l]ist files' })

      -- Quick access to files 1-4 (easier than <leader>h1-4)
      local function select_harpoon_file(index)
        local list = harpoon:list()
        local item = list:get(index)
        if item then
          list:select(index)
        else
          vim.notify('Harpoon: slot ' .. index .. ' is empty', vim.log.levels.INFO)
        end
      end

      vim.keymap.set('n', '<leader>1', function()
        select_harpoon_file(1)
      end, { desc = 'Harpoon: file 1' })

      vim.keymap.set('n', '<leader>2', function()
        select_harpoon_file(2)
      end, { desc = 'Harpoon: file 2' })

      vim.keymap.set('n', '<leader>3', function()
        select_harpoon_file(3)
      end, { desc = 'Harpoon: file 3' })

      vim.keymap.set('n', '<leader>4', function()
        select_harpoon_file(4)
      end, { desc = 'Harpoon: file 4' })

      -- Remove current file from harpoon list
      vim.keymap.set('n', '<leader>hd', function()
        harpoon:list():remove()
      end, { desc = '[H]arpoon: [d]elete current file' })

      -- Clear all harpoon marks (capital X = harder to accidentally press)
      vim.keymap.set('n', '<leader>hX', function()
        harpoon:list():clear()
      end, { desc = '[H]arpoon: clear all (X marks the spot)' })

      -- Telescope integration for harpoon
      local has_telescope, _ = pcall(require, 'telescope')
      if has_telescope then
        vim.keymap.set('n', '<leader>hs', function()
          require('telescope').extensions.harpoon.marks(require('telescope.themes').get_dropdown {})
        end, { desc = '[H]arpoon: [s]earch in Telescope' })
      end
    end,
  },
}
