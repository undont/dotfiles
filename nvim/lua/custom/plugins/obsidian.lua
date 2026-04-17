-- Obsidian vault integration: daily notes, backlinks, tags, templates.
-- Markdown rendering and list/link editing stay in markdown-ui.lua
-- (mkdnflow + conceallevel); obsidian.nvim is kept to vault-aware features.

local vault_root = vim.fn.expand '~/Library/Mobile Documents/iCloud~md~obsidian/Documents'

local function discover_workspaces()
  local workspaces = {}
  for _, dir in ipairs(vim.fn.glob(vault_root .. '/*', false, true)) do
    local name = vim.fn.fnamemodify(dir, ':t')
    if
      vim.fn.isdirectory(dir) == 1
      and vim.fn.isdirectory(dir .. '/.obsidian') == 1
      and not name:match '%.backup'
    then
      table.insert(workspaces, { name = name, path = dir })
    end
  end
  return workspaces
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
          vim.ui.input({ prompt = 'New note title: ' }, function(title)
            if title and title ~= '' then
              vim.cmd('Obsidian new ' .. vim.fn.fnameescape(title))
            end
          end)
        end,
        desc = '[N]ew note',
      },
      { '<leader>of', '<cmd>Obsidian quick_switch<cr>', desc = '[F]ind note' },
      { '<leader>os', '<cmd>Obsidian search<cr>', desc = '[S]earch vault' },
      { '<leader>ot', '<cmd>Obsidian tags<cr>', desc = '[T]ags' },
      { '<leader>ob', '<cmd>Obsidian backlinks<cr>', desc = '[B]acklinks' },
      { '<leader>ol', '<cmd>Obsidian links<cr>', desc = '[L]inks in note' },
      { '<leader>oi', '<cmd>Obsidian template<cr>', desc = '[I]nsert template into note' },
      { '<leader>oN', '<cmd>Obsidian new_from_template<cr>', desc = '[N]ew note from template' },
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
      workspaces = discover_workspaces(),

      -- Matches .obsidian/daily-notes.json (folder, format, template).
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

      completion = {
        nvim_cmp = false,
        blink = true,
        min_chars = 2,
      },

      picker = { name = 'telescope.nvim' },

      -- Vault uses [[title]] and ![[embed]] (see templates/daily note.md).
      link = {
        style = 'wiki',
        format = 'shortest',
      },

      -- Random/quick notes land in scratchpad; daily_notes override folder.
      new_notes_location = 'notes_subdir',
      notes_subdir = 'scratchpad',

      -- Keep `aliases:` as a placeholder but don't auto-fill it with the
      -- note title — the filename already is the title.
      frontmatter = {
        func = function(note)
          local out = require('obsidian.builtin').frontmatter(note)
          out.aliases = {}
          return out
        end,
      },

      -- Vault uses human-readable titles (e.g. "UI Redesign Ideas.md"),
      -- not Zettel IDs. Preserve the title as-is when given; fall back to
      -- a timestamp only if `:Obsidian new` is called with no title.
      note_id_func = function(title)
        if title ~= nil and title ~= '' then
          return title
        end
        return os.date '%Y-%m-%d-%H%M%S'
      end,

      -- mkdnflow + conceallevel already handle display.
      ui = { enable = false },

      attachments = { folder = 'attachments' },
    },
  },
}
