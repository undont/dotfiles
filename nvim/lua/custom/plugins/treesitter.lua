-- Treesitter: syntax highlighting, textobjects, indent detection.

return {
  -- Treesitter for syntax highlighting
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    lazy = false, -- treesitter doesn't support lazy loading
    build = ':TSUpdate',
    config = function()
      local parsers = {
        'astro',
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
        'json5',
        'jsonc',
        'make',
        'python',
        -- lua, luadoc, vim, vimdoc, query, markdown, markdown_inline are bundled
        -- with Neovim 0.11+ — let Neovim manage them to avoid query/parser mismatches
        'tsx',
        'typescript',
        'xml',
        'yaml',
        'zig',
        'awk',
        'toml',
      }

      -- Purge compiled parsers when nvim-treesitter updates to prevent ABI crashes.
      -- Old .so files compiled against a previous treesitter ABI can crash Neovim
      -- when opened (e.g. markdown, c_sharp after breaking updates). Remove the
      -- matching query directories too, otherwise health checks report orphaned
      -- queries for parsers that no longer exist on disk.
      local parser_dir = vim.fn.stdpath 'data' .. '/site/parser'
      local query_dir = vim.fn.stdpath 'data' .. '/site/queries'
      local marker_path = vim.fn.stdpath 'data' .. '/nvim-treesitter-rev'
      local plugin_dir = vim.fn.stdpath 'data' .. '/lazy/nvim-treesitter'
      local current_rev = vim.fn.system('GIT_DIR= GIT_WORK_TREE= git -C ' .. plugin_dir .. ' rev-parse --short HEAD 2>/dev/null'):gsub('%s+', '')
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
                  local lang = name:gsub('%.so$', '')
                  local qdir = query_dir .. '/' .. lang
                  if vim.uv.fs_stat(qdir) then
                    vim.fn.delete(qdir, 'rf')
                  end
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
        require('nvim-treesitter').install(missing):wait(120000)
      end

      -- Enable treesitter highlighting and indentation for all supported filetypes
      vim.api.nvim_create_autocmd('FileType', {
        callback = function()
          -- Skip treesitter for large files to avoid blocking the editor
          local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(0))
          if ok and stats and stats.size > 1024 * 1024 then
            return
          end

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
}
