-- obsidian.nvim: vault features only (daily notes, backlinks, tags,
-- templates); rendering and list/link editing are in render-markdown.lua
-- and mkdnflow.lua.
-- vault root: `vim.g.obsidian_vault_root` (set in local.lua), else ~/obsidian.
-- when neither exists the spec is empty. the root is a vault itself
-- (`.obsidian/` directly inside) or a parent directory of vaults

local function resolve_vault_root()
  local override = vim.g.obsidian_vault_root
  if override and override ~= '' then
    local path = vim.fn.expand(override)
    if vim.fn.isdirectory(path) == 1 then
      return path
    end
    vim.notify(('obsidian.nvim: vim.g.obsidian_vault_root=%q not found, skipping'):format(override), vim.log.levels.WARN)
    return nil
  end

  local default = vim.fn.expand '~/obsidian'
  if vim.fn.isdirectory(default) == 1 then
    return default
  end
  return nil
end

local vault_root = resolve_vault_root()
if not vault_root then
  return {}
end

local function discover_workspaces()
  local workspaces = {}
  if vim.fn.isdirectory(vault_root .. '/.obsidian') == 1 then
    table.insert(workspaces, { name = vim.fn.fnamemodify(vault_root, ':t'), path = vault_root })
    return workspaces
  end
  for _, dir in ipairs(vim.fn.glob(vault_root .. '/*', false, true)) do
    local name = vim.fn.fnamemodify(dir, ':t')
    if vim.fn.isdirectory(dir) == 1 and vim.fn.isdirectory(dir .. '/.obsidian') == 1 and not name:match '%.backup' then
      table.insert(workspaces, { name = name, path = dir })
    end
  end
  return workspaces
end

local workspaces = discover_workspaces()
if #workspaces == 0 then
  vim.notify(
    ('obsidian.nvim: no vaults found under %q (expected `.obsidian/` directly inside, or in an immediate subdirectory); skipping'):format(vault_root),
    vim.log.levels.WARN
  )
  return {}
end

return {
  {
    'obsidian-nvim/obsidian.nvim',
    version = '*',
    ft = { 'markdown' },
    cmd = { 'Obsidian' },
    keys = {
      { '<leader>oo', '<cmd>Obsidian today<cr>', desc = '[O]pen daily note' },
      { '<leader>oy', '<cmd>Obsidian yesterday<cr>', desc = '[Y]esterday daily note' },
      { '<leader>oT', '<cmd>Obsidian tomorrow<cr>', desc = '[T]omorrow daily note' },
      {
        '<leader>on',
        function()
          local ok, api = pcall(require, 'obsidian.api')
          if ok and api.templates_dir() then
            vim.cmd 'Obsidian new_from_template'
          else
            vim.ui.input({ prompt = 'New note title: ' }, function(title)
              if title and title ~= '' then
                vim.cmd('Obsidian new ' .. vim.fn.fnameescape(title))
              end
            end)
          end
        end,
        desc = '[N]ew note (from template if available)',
      },
      {
        '<leader>oN',
        function()
          vim.ui.input({ prompt = 'New note title: ' }, function(title)
            if title and title ~= '' then
              vim.cmd('Obsidian new ' .. vim.fn.fnameescape(title))
            end
          end)
        end,
        desc = '[N]ew blank note (no template)',
      },
      { '<leader>of', '<cmd>Obsidian quick_switch<cr>', desc = '[F]ind note' },
      { '<leader>og', '<cmd>Obsidian search<cr>', desc = '[G]rep vault' },
      { '<leader>ot', '<cmd>Obsidian tags<cr>', desc = '[T]ags' },
      { '<leader>ob', '<cmd>Obsidian backlinks<cr>', desc = '[B]acklinks' },
      { '<leader>ol', '<cmd>Obsidian links<cr>', desc = '[L]inks in note' },
      { '<leader>oi', '<cmd>Obsidian template<cr>', desc = '[I]nsert template into note' },
      { '<leader>ow', '<cmd>Obsidian workspace<cr>', desc = '[W]orkspace switch' },
      { '<leader>or', '<cmd>Obsidian rename<cr>', desc = '[R]ename note' },
      { '<leader>oe', '<cmd>Obsidian extract_note<cr>', mode = { 'n', 'v' }, desc = '[E]xtract to new note' },
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope.nvim',
    },
    ---@module 'obsidian'
    ---@type obsidian.config
    opts = {
      legacy_commands = false,
      workspaces = workspaces,

      -- matches .obsidian/daily-notes.json (folder, format, template)
      daily_notes = {
        folder = 'daily',
        date_format = 'DD-MM-YYYY',
        template = 'daily note.md',
        default_tags = { 'daily' },
      },

      templates = {
        folder = 'templates',
        date_format = 'YYYY-MM-DD',
        time_format = 'HH:mm',
      },

      -- completion comes from obsidian.nvim's built-in `obsidian-ls` server
      -- through blink.cmp's `lsp` source
      completion = {
        min_chars = 2,
      },

      picker = { name = 'telescope.nvim' },

      -- vault uses [[title]] and ![[embed]] (see templates/daily note.md)
      link = {
        style = 'wiki',
        format = 'shortest',
      },

      -- random/quick notes land in scratchpad; daily_notes override folder
      new_notes_location = 'notes_subdir',
      notes_subdir = 'scratchpad',

      -- the filename is the title in this vault, so the builtin's `id` field
      -- is dropped. aliases are kept only when the note has them; the builtin
      -- would write an empty `aliases:` line on every save
      frontmatter = {
        sort = false,
        func = function(note)
          local out = require('obsidian.builtin').frontmatter(note)
          out.id = nil
          if not note.aliases or #note.aliases == 0 then
            out.aliases = nil
          end
          return out
        end,
      },

      -- titles are human-readable, not Zettel IDs; a timestamp is used only
      -- when `:Obsidian new` has no title
      note_id_func = function(title)
        if title ~= nil and title ~= '' then
          return title
        end
        return os.date '%Y-%m-%d-%H%M%S'
      end,

      -- render-markdown.lua handles display
      ui = { enable = false },

      attachments = { folder = 'attachments' },

      -- `gf` in vault notes follows links as `<CR>` does. `follow_link` needs
      -- the raw link string, and `open_strategy` is a literal vim command
      -- ('edit' / 'vsplit' / 'split')
      callbacks = {
        enter_note = function(note)
          vim.keymap.set('n', 'gf', function()
            local link = require('obsidian.api').cursor_link()
            if not link then
              vim.notify('No link under cursor', vim.log.levels.INFO)
              return
            end
            require('obsidian.actions').follow_link(link, { open_strategy = 'edit' })
          end, { buffer = note.bufnr or 0, desc = 'Follow link (in nvim)' })
        end,
      },
    },
  },
}
