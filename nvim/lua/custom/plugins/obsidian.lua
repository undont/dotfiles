-- Obsidian vault integration: daily notes, backlinks, tags, templates.
-- Markdown rendering and list/link editing stay in markdown-ui.lua
-- (render-markdown + mkdnflow + conceallevel); obsidian.nvim is kept to
-- vault-aware features.
--
-- Vault root resolution (in order):
--   1. `vim.g.obsidian_vault_root` — set in ~/.config/nvim/local.lua to override
--   2. ~/Library/Mobile Documents/iCloud~md~obsidian/Documents — default iCloud path
--   3. Neither exists — plugin spec is empty, obsidian.nvim is not loaded
--
-- The resolved root can either be a vault itself (has `.obsidian/` directly
-- inside, e.g. `~/notes/.obsidian`) or a parent directory containing one or
-- more vaults (e.g. `~/vaults/work/.obsidian`, `~/vaults/personal/.obsidian`).

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

  local default = vim.fn.expand '~/Library/Mobile Documents/iCloud~md~obsidian/Documents'
  if vim.fn.isdirectory(default) == 1 then
    return default
  end
  return nil
end

local vault_root = resolve_vault_root()
if not vault_root then
  return {}
end

-- `vault_root` can either be a vault itself (has `.obsidian/` directly inside)
-- or a parent directory containing one or more vaults. Handle both.
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
    ('obsidian.nvim: no vaults found under %q (expected `.obsidian/` directly inside, or in an immediate subdirectory) — skipping'):format(vault_root),
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

      -- Filename already is the title for this vault (human-readable names,
      -- wiki+shortest links), so the builtin's `id` and auto-filled `aliases`
      -- are just noise. Strip `id` entirely; keep `aliases` as an empty
      -- placeholder so it's easy to drop in alternate titles when needed.
      frontmatter = {
        func = function(note)
          local out = require('obsidian.builtin').frontmatter(note)
          out.id = nil
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

      -- render-markdown + mkdnflow + conceallevel already handle display.
      ui = { enable = false },

      attachments = { folder = 'attachments' },

      -- For vault notes only: rebind `gf` to obsidian.nvim's link-follow
      -- action, matching what `<CR>` does. Two non-obvious things about
      -- the call:
      --   1. `follow_link` doesn't grab the cursor link itself — it
      --      requires the raw link string, otherwise its internal
      --      `parse_link` crashes on a nil.
      --   2. `open_strategy` is used as a literal vim command, not as a
      --      strategy enum (despite what some docs imply), so pass
      --      'edit' / 'vsplit' / 'split', not 'current'.
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
