-- prompt buffers opened by an agent harness (claude, pi, codex, opencode) and
-- plan files: `@` opens a telescope file picker rooted at the git project and
-- inserts a relative path (`@path`, a bare path for codex); `@@` inserts a
-- literal `@`. harnesses that expand skills anywhere in a prompt also get skill
-- names from a blink.cmp source (provider prompt_skills in plugins/completion)

local M = {}

local function tmpdir()
  return vim.uv.fs_realpath(vim.env.TMPDIR or '/tmp')
end

-- prefix precedes the path in the inserted text; skill is the sigil and name
-- prefix the harness expands, nil where skills aren't completed
local HARNESSES = {
  {
    name = 'claude',
    prefix = '@',
    skill = { sigil = '/', prefix = '' },
    match = function(path)
      return vim.fs.basename(path):match '^claude%-prompt%-.*%.md$' ~= nil
    end,
  },
  {
    name = 'pi',
    prefix = '@',
    skill = { sigil = '/', prefix = 'skill:' },
    match = function(path)
      return path:match '/pi%-editor%-[^/]+/prompt%.md$' ~= nil
    end,
  },
  {
    name = 'codex',
    prefix = '',
    skill = { sigil = '$', prefix = '' },
    match = function(path)
      return path:match '/%.codex/editor/[^/]+%.md$' ~= nil
    end,
  },
  {
    name = 'opencode',
    prefix = '@',
    match = function(path)
      return vim.fs.basename(path):match '^%d%d%d%d%d%d%d%d%d%d%d%d%d%.md$' ~= nil and vim.fs.dirname(path) == tmpdir()
    end,
  },
  {
    name = 'plans',
    prefix = '@',
    match = function(path)
      return path:match '/%.claude/' ~= nil or path:match '/%.plans/' ~= nil
    end,
  },
}

local function find_harness(abs_path)
  local path = vim.uv.fs_realpath(abs_path) or abs_path
  for _, harness in ipairs(HARNESSES) do
    if harness.match(path) then
      return harness
    end
  end
  return nil
end

local function map_file_picker(bufnr, harness)
  local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
  local cwd = (vim.v.shell_error == 0 and git_root ~= '') and git_root or vim.fn.getcwd()

  vim.keymap.set('i', '@@', '@', { buffer = bufnr, desc = 'Insert literal @' })

  vim.keymap.set('i', '@', function()
    -- stopinsert shifts the cursor left, so the position is read first
    local insert_row = vim.fn.line '.'
    local insert_col = vim.fn.col '.' -- 1-indexed; where next char would be typed
    vim.cmd 'stopinsert'

    local actions = require 'telescope.actions'
    local action_state = require 'telescope.actions.state'

    require('telescope.builtin').find_files {
      prompt_title = '@ File Reference',
      cwd = cwd,
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          vim.schedule(function()
            if selection then
              local path = selection.value or selection[1]
              local line = vim.api.nvim_get_current_line()
              local byte_col = insert_col - 1 -- 0-indexed for API
              -- add leading space if cursor follows a non-space character
              local prefix = ''
              if byte_col > 0 then
                local before = line:sub(insert_col - 1, insert_col - 1)
                if before ~= ' ' and before ~= '' then
                  prefix = ' '
                end
              end
              local text = prefix .. harness.prefix .. path
              local row = insert_row - 1 -- 0-indexed
              vim.api.nvim_buf_set_text(0, row, byte_col, row, byte_col, { text })
              local end_col = byte_col + #text
              if end_col >= #vim.api.nvim_get_current_line() then
                vim.cmd 'startinsert!'
              else
                vim.api.nvim_win_set_cursor(0, { insert_row, end_col })
                vim.cmd 'startinsert'
              end
            else
              vim.cmd 'startinsert!'
            end
          end)
        end)

        map('i', '<Esc>', function()
          actions.close(prompt_bufnr)
          vim.schedule(function()
            vim.cmd 'startinsert!'
          end)
        end)

        return true
      end,
    }
  end, { buffer = bufnr, desc = '@ file reference' })
end

-- skill source for blink.cmp

local cache

local function frontmatter(path)
  local lines = vim.fn.readfile(path, '', 20)
  local name, description
  for i, line in ipairs(lines) do
    name = name or line:match '^name:%s*(.-)%s*$'
    local inline = line:match '^description:%s*(.-)%s*$'
    if inline and inline:match '^[|>]' then
      description = (lines[i + 1] or ''):match '^%s*(.-)%s*$'
    elseif inline then
      description = inline
    end
  end
  return name, description
end

local function skills()
  if cache then
    return cache
  end
  local root = vim.fs.root(0, '.git')
  local dirs = { '~/.ai/skills', '~/.agents/skills' }
  if root then
    vim.list_extend(dirs, { root .. '/.agents/skills', root .. '/.claude/skills' })
  end
  local seen, found = {}, {}
  for _, dir in ipairs(dirs) do
    for _, path in ipairs(vim.fn.glob(vim.fn.expand(dir) .. '/*/SKILL.md', false, true)) do
      local name, description = frontmatter(path)
      if name and not seen[name] then
        seen[name] = true
        found[#found + 1] = { name = name, description = description }
      end
    end
  end
  cache = found
  return found
end

local Source = {}

function Source:enabled()
  return vim.b.prompt_skill ~= nil
end

function Source:get_trigger_characters()
  return { '/', '$' }
end

function Source:get_completions(context, callback)
  local skill = vim.b.prompt_skill
  local before = context.line:sub(1, context.cursor[2])
  local pattern = '(' .. vim.pesc(skill.sigil) .. '[%w_:%-]*)$'
  local token = before:match('^' .. pattern) or before:match('%s' .. pattern)
  if not token then
    callback { items = {} }
    return
  end

  local range = {
    start = { line = context.cursor[1] - 1, character = context.cursor[2] - #token },
    ['end'] = { line = context.cursor[1] - 1, character = context.cursor[2] },
  }
  local items = {}
  for _, s in ipairs(skills()) do
    items[#items + 1] = {
      label = s.name,
      filterText = s.name,
      documentation = s.description,
      textEdit = { newText = skill.sigil .. skill.prefix .. s.name .. ' ', range = range },
    }
  end
  callback { items = items, is_incomplete_forward = false, is_incomplete_backward = false }
end

function M.new()
  return setmetatable({}, { __index = Source })
end

local function attach(bufnr, abs_path)
  local harness = find_harness(abs_path)
  if not harness then
    return
  end
  vim.b[bufnr].prompt_skill = harness.skill
  map_file_picker(bufnr, harness)
end

function M.setup()
  vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
    pattern = '*.md',
    group = vim.api.nvim_create_augroup('agent-prompt', { clear = true }),
    callback = function(ev)
      attach(ev.buf, vim.fn.fnamemodify(ev.file, ':p'))
    end,
  })
end

return M
