-- git file/commit discovery shared by the scan, diff and picker keymaps.
--
-- ticket-scoped commit discovery behind <leader>dT (diffview), <leader>xT
-- (all-LSP diagnostics scan) and <leader>lT (sonar scan): merge-base with
-- main, ticket default pulled from the branch name, commit subjects grepped
-- with --fixed-strings in base..HEAD.
--
-- modified-file discovery behind <leader>xm (all-LSP diagnostics scan),
-- <leader>lm (sonar scan) and <leader>sm (telescope picker), so all three
-- always operate on the same file set.
--
-- branch-total discovery behind <leader>xt (all-LSP diagnostics scan):
-- every file changed vs merge-base(main), mirroring <leader>dt's diffview

local M = {}

--- run `git <args>` and return stdout lines, or nil on failure
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
--- diff-tree (not a range diff) so interleaved non-matching commits don't
--- drag their files in. mirrors <leader>dT's working-tree rule: when the
--- newest matched commit is HEAD the ticket is the branch tip, so
--- uncommitted work is part of it, union in modified/untracked files.
--- otherwise dirty files likely belong to other work; stick to exactly the
--- matched commits. returns nil (with a notify) outside a git repo
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
    -- reuse modified_files so the union resolves paths from the repo root
    -- (cwd-relative ls-files + :p breaks when nvim's cwd isn't the root)
    -- and catches staged-but-uncommitted work via its `diff HEAD` form
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

--- union of files changed on this branch vs merge-base(main): committed
--- branch work plus uncommitted/untracked changes. the single-rev
--- `diff <base>` form (no second rev) diffs the merge-base against the
--- working tree, so it already includes dirty files, the same semantics as
--- <leader>dt's single-rev DiffviewOpen. deletions are filtered out (ACMR;
--- renames keep the new path) since a scan can't use a missing file. returns
--- nil (with a notify) outside a git repo or when no merge-base with main
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
