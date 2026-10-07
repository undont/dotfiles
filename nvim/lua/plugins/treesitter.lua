-- treesitter: syntax highlighting and indent

return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    lazy = false, -- the plugin does not support lazy loading
    build = ':TSUpdate',
    config = function()
      local parsers = {
        'astro',
        'bash',
        'c',
        'c_sharp',
        'cpp',
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
        'make',
        'objc',
        'rust',
        'python',
        'sql',
        -- lua, luadoc, vim, vimdoc, query, markdown, markdown_inline are bundled
        -- with nvim, whose queries match its own parsers
        'swift',
        'tsx',
        'typescript',
        'xml',
        'yaml',
        'ruby',
        'zig',
        'awk',
        'toml',
        'razor',
        -- injection-only: go's injections.scm puts regex into
        -- regexp.MustCompile args. printf is absent: its grammar reads go's
        -- %t and %w as c length modifiers and runs the node on to the next
        -- conversion character
        'regex',
      }

      require('features.treesitter-parsers').purge_if_updated()

      -- the go grammar takes new/make's first argument as a type, so go 1.26's
      -- new(expr) is a syntax error and the file collapses into ERROR nodes
      -- (highlighting, folds, neotest discovery). this pins the open upstream
      -- pr, tree-sitter-go#193; drop the entry once it merges. it mis-parses
      -- `new[i]` on a variable shadowing the builtin (tree-sitter-go#189)
      require('features.treesitter-parsers').sync_pins {
        go = {
          -- upstream serves the commit as the head of the open pr
          url = 'https://github.com/tree-sitter/tree-sitter-go',
          revision = '5a6af13a0a5b45bc76cac289c783b315b2b74e13',
        },
      }

      -- installs parsers missing from disk or lacking a highlights query on
      -- runtimepath. a file existence check: query.get would compile every query
      local missing = vim.tbl_filter(function(lang)
        local ok = pcall(vim.treesitter.language.inspect, lang)
        return not ok or #vim.api.nvim_get_runtime_file('queries/' .. lang .. '/highlights.scm', false) == 0
      end, parsers)
      if #missing > 0 then
        -- force: the plugin counts a language as installed when its query dir exists
        require('nvim-treesitter').install(missing, { force = true }):wait(120000)
      end

      vim.api.nvim_create_autocmd('FileType', {
        callback = function()
          local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(0))
          if ok and stats and stats.size > 1024 * 1024 then
            return
          end

          if pcall(vim.treesitter.start) then
            -- a language without indent queries (C#) keeps vim's native indent;
            -- the treesitter indentexpr would put every line at column 0
            local lang = vim.treesitter.language.get_lang(vim.bo.filetype) or vim.bo.filetype
            if vim.treesitter.query.get(lang, 'indents') then
              vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            end
          end
        end,
      })

      -- go format verbs, which no query can reach: see the module header
      require('features.go-format-verbs').setup()

      -- language aliases for markdown code fences
      vim.treesitter.language.register('c_sharp', { 'csharp', 'cs' })

      -- upstream astro/injections.scm inherits html_tags (`<script>` ->
      -- javascript) and adds a typescript rule, so every astro `<script>` is
      -- injected twice. query.get reads the `; inherits:` modeline from every
      -- matching file in rtp, so the override is applied with query.set
      local astro_inj = vim.fn.stdpath 'config' .. '/queries/astro/injections.scm'
      local f = io.open(astro_inj, 'r')
      if f then
        local scm = f:read '*a'
        f:close()
        pcall(vim.treesitter.query.set, 'astro', 'injections', scm)
      end
    end,
  },
}
