-- git file/commit discovery shared by the scan, diff and picker keymaps, so
-- each group operates on one file set:
--   ticket commits  <leader>dT (differ), <leader>xT, <leader>lT
--   modified files  <leader>xm, <leader>lm, <leader>sm
--   branch files    <leader>xb, <leader>lb (the set <leader>dt diffs)

local M = {}

--- stdout lines, or nil on failure
local function git_lines(args)
  local result = vim.system(vim.list_extend({ 'git' }, args), { text = true }):wait()
  if result.code ~= 0 then
    return nil
  end
  local lines = {}
  for line in (result.stdout or ''):gmatch '[^\r\n]+' do
    table.insert(lines, line)
  end
  return lines
end

--- @class TicketCommits
--- @field base string      merge-base with main
--- @field head string      current HEAD hash
--- @field commits string[] matched commit hashes, newest first
--- @field input string     the grep string the user entered

--- prompt for a ticket / commit grep (default extracted from the branch
--- name) and resolve the matching commits in merge-base(main)..HEAD.
--- notifies and bails on failure; `cb` is only called with a non-empty
--- match. async: returns before the prompt is answered
--- @param cb fun(ctx: TicketCommits)
function M.prompt_commits(cb)
  local base = (git_lines { 'merge-base', 'main', 'HEAD' } or {})[1]
  if not base or base == '' then
    vim.notify('Could not find merge-base with main', vim.log.levels.WARN)
    return
  end

  local branch = (git_lines { 'rev-parse', '--abbrev-ref', 'HEAD' } or {})[1] or ''
  local default = branch:match '([A-Za-z]+%-%d+)' or ''

  vim.ui.input({ prompt = 'Ticket / commit grep: ', default = default }, function(input)
    if not input or input == '' then
      return
    end

    local commits = git_lines { 'log', '--grep=' .. input, '--fixed-strings', '--format=%H', base .. '..HEAD' }
    if not commits or #commits == 0 then
      vim.notify('No commits matching "' .. input .. '"', vim.log.levels.WARN)
      return
    end

    local head = (git_lines { 'rev-parse', 'HEAD' } or {})[1]
    cb { base = base, head = head, commits = commits, input = input }
  end)
end

--- union of absolute paths touched by the matched commits. per-commit
--- diff-tree, not a range diff, so interleaved non-matching commits add
--- nothing. when the newest matched commit is HEAD, modified/untracked files
--- are included too (<leader>dT's working-tree rule). returns nil (with a
--- notify) outside a git repo
--- @param ctx TicketCommits
--- @return string[]?
function M.commit_files(ctx)
  local toplevel = (git_lines { 'rev-parse', '--show-toplevel' } or {})[1]
  if not toplevel then
    vim.notify('Not a git repo', vim.log.levels.WARN)
    return nil
  end

  -- diff-tree paths are repo-root-relative (unlike cwd-relative ls-files)
  local seen = {}
  local paths = {}
  local function add(abs)
    if not seen[abs] then
      seen[abs] = true
      table.insert(paths, abs)
    end
  end
  for _, hash in ipairs(ctx.commits) do
    for _, f in ipairs(git_lines { 'diff-tree', '--no-commit-id', '--name-only', '-r', hash } or {}) do
      add(toplevel .. '/' .. f)
    end
  end

  if ctx.commits[1] == ctx.head then
    -- modified_files resolves paths from the repo root and includes
    -- staged-but-uncommitted work
    for _, abs in ipairs(M.modified_files() or {}) do
      add(abs)
    end
  end

  return paths
end

--- union of git-modified and untracked files as absolute paths: staged or
--- unstaged changes vs HEAD (excluding deletions, which neither a scan nor
--- a picker can use) plus untracked files that aren't gitignored. the
--- `diff HEAD` form catches staged-but-uncommitted work that
--- `ls-files -m` misses. returns nil (with a notify) outside a git repo
--- @return string[]?
function M.modified_files()
  local toplevel = (git_lines { 'rev-parse', '--show-toplevel' } or {})[1]
  if not toplevel then
    vim.notify('Not a git repo', vim.log.levels.WARN)
    return nil
  end

  -- run both from the repo root (-C) so the output is uniformly
  -- root-relative: `diff --name-only` always is, `ls-files` is cwd-relative
  local modified = git_lines { '-C', toplevel, 'diff', '--name-only', '--diff-filter=ACMR', 'HEAD' }
  local untracked = git_lines { '-C', toplevel, 'ls-files', '--others', '--exclude-standard' }

  local seen = {}
  local paths = {}
  for _, list in ipairs { modified or {}, untracked or {} } do
    for _, rel in ipairs(list) do
      local abs = toplevel .. '/' .. rel
      if not seen[abs] then
        seen[abs] = true
        table.insert(paths, abs)
      end
    end
  end
  return paths
end

--- files changed on this branch vs merge-base(main). the single-rev
--- `diff <base>` form diffs the merge-base against the working tree, so dirty
--- files are included, as in <leader>dt's `:Differ base`. deletions are
--- filtered out (ACMR; renames keep the new path). returns nil (with a notify)
--- outside a git repo or when there is no merge-base with main
--- @return string[]?
function M.branch_files()
  local toplevel = (git_lines { 'rev-parse', '--show-toplevel' } or {})[1]
  if not toplevel then
    vim.notify('Not a git repo', vim.log.levels.WARN)
    return nil
  end

  local base = (git_lines { 'merge-base', 'main', 'HEAD' } or {})[1]
  if not base or base == '' then
    vim.notify('Could not find merge-base with main', vim.log.levels.WARN)
    return nil
  end

  -- run both from the repo root (-C) so the output is uniformly
  -- root-relative: `diff --name-only` always is, `ls-files` is cwd-relative
  local changed = git_lines { '-C', toplevel, 'diff', '--name-only', '--diff-filter=ACMR', base }
  local untracked = git_lines { '-C', toplevel, 'ls-files', '--others', '--exclude-standard' }

  local seen = {}
  local paths = {}
  for _, list in ipairs { changed or {}, untracked or {} } do
    for _, rel in ipairs(list) do
      local abs = toplevel .. '/' .. rel
      if not seen[abs] then
        seen[abs] = true
        table.insert(paths, abs)
      end
    end
  end
  return paths
end

return M
