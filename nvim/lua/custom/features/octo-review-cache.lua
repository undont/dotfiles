-- Octo review-diff caching. extracted from plugins/pr-review.lua.
-- monkeypatches octo's PullRequest.get_changed_files / FileEntry.fetch to
-- snapshot a review's changed-file list and per-file left/right contents, so
-- re-entering the same review (same commits) renders from cache instead of
-- re-fetching over the network. also patches Review.set_files_and_select_first
-- to honour a one-shot resume target (set by <leader>pe). OctoCacheClear drops
-- the cache

local M = {}

local octo_review_cache = {
  changed_files = {},
  file_contents = {},
}

--- one-shot navigation target for `Octo review resume`. set before issuing
--- the command; consumed once by the patched set_files_and_select_first
local pending_resume_target = nil ---@type {path: string, line: integer}?

--- stash a one-shot resume target consumed by the next review open
function M.set_resume_target(target)
  pending_resume_target = target
end

local function octo_review_cache_key(pr)
  return table.concat({ pr.repo, tostring(pr.number), pr.left.commit, pr.right.commit }, ':')
end

local function octo_review_prefix(pr)
  return table.concat({ pr.repo, tostring(pr.number) }, ':') .. ':'
end

local function octo_file_cache_key(repo, commit, path)
  return table.concat({ repo, commit, path }, ':')
end

local function snapshot_octo_changed_files(files)
  local out = {}
  for _, file in ipairs(files) do
    out[#out + 1] = {
      path = file.path,
      previous_path = file.previous_path,
      patch = file.patch,
      status = file.status,
      stats = vim.deepcopy(file.stats),
    }
  end
  return out
end

local function build_octo_changed_files(pr, cached_files)
  local FileEntry = require 'octo.reviews.file-entry'
  local out = {}
  for _, file in ipairs(cached_files) do
    out[#out + 1] = FileEntry.FileEntry:new {
      path = file.path,
      previous_path = file.previous_path,
      patch = file.patch,
      pull_request = pr,
      status = file.status,
      stats = vim.deepcopy(file.stats),
    }
  end
  return out
end

local function clear_stale_octo_review_entries(pr, keep_key)
  local prefix = octo_review_prefix(pr)
  for key in pairs(octo_review_cache.changed_files) do
    if vim.startswith(key, prefix) and key ~= keep_key then
      octo_review_cache.changed_files[key] = nil
    end
  end
end

local function persist_octo_file_cache(file, left_key, right_key)
  if not file:is_ready_to_render() then
    return false
  end
  octo_review_cache.file_contents[left_key] = vim.deepcopy(file.left_lines)
  octo_review_cache.file_contents[right_key] = vim.deepcopy(file.right_lines)
  return true
end

local function defer_octo_file_cache(file, left_key, right_key, attempts_left)
  if persist_octo_file_cache(file, left_key, right_key) or attempts_left <= 0 then
    return
  end
  vim.defer_fn(function()
    defer_octo_file_cache(file, left_key, right_key, attempts_left - 1)
  end, 25)
end

function M.setup()
  if vim.g.octo_review_cache_patched then
    return
  end
  vim.g.octo_review_cache_patched = true

  local PullRequest = require('octo.model.pull-request').PullRequest
  local FileEntry = require('octo.reviews.file-entry').FileEntry
  local orig_get_changed_files = PullRequest.get_changed_files
  local orig_fetch = FileEntry.fetch

  PullRequest.get_changed_files = function(self, callback)
    local cache_key = octo_review_cache_key(self)
    clear_stale_octo_review_entries(self, cache_key)

    local cached = octo_review_cache.changed_files[cache_key]
    if cached then
      callback(build_octo_changed_files(self, cached))
      return
    end

    orig_get_changed_files(self, function(files)
      octo_review_cache.changed_files[cache_key] = snapshot_octo_changed_files(files)
      callback(files)
    end)
  end

  FileEntry.fetch = function(self, sync)
    local current_review = require('octo.reviews').get_current_review()
    if not current_review then
      return orig_fetch(self, sync)
    end

    local left_path = self.path
    if self.status == 'R' and self.previous_path then
      left_path = self.previous_path
    end

    local left_key = octo_file_cache_key(self.pull_request.repo, current_review.layout.left.commit, left_path)
    local right_key = octo_file_cache_key(self.pull_request.repo, current_review.layout.right.commit, self.path)
    local cached_left = octo_review_cache.file_contents[left_key]
    local cached_right = octo_review_cache.file_contents[right_key]

    if cached_left and cached_right then
      self.left_lines = vim.deepcopy(cached_left)
      self.right_lines = vim.deepcopy(cached_right)
      self.left_fetched = true
      self.right_fetched = true
      self.left_fetching = false
      self.right_fetching = false
      return
    end

    orig_fetch(self, sync)
    if not persist_octo_file_cache(self, left_key, right_key) then
      defer_octo_file_cache(self, left_key, right_key, sync and 10 or 80)
    end
  end

  vim.api.nvim_create_user_command('OctoCacheClear', function()
    octo_review_cache.changed_files = {}
    octo_review_cache.file_contents = {}
    vim.notify('Cleared Octo review cache', vim.log.levels.INFO)
  end, { desc = 'Clear cached Octo review diffs' })

  -- honour pending_resume_target: when set, select the matching file (and
  -- restore cursor line) instead of the default first-unviewed file
  local Review = require('octo.reviews').Review
  local orig_select_first = Review.set_files_and_select_first
  Review.set_files_and_select_first = function(self, files)
    local target = pending_resume_target
    pending_resume_target = nil
    if not target then
      return orig_select_first(self, files)
    end

    local match_idx
    for idx, file in ipairs(files) do
      if file.path == target.path then
        match_idx = idx
        break
      end
    end

    if not match_idx then
      return orig_select_first(self, files)
    end

    self.layout.files = files
    files[match_idx]:fetch(true)
    self.layout.selected_file_idx = match_idx
    for _, file in ipairs(files) do
      file:fetch(false)
    end
    self.layout:update_files()

    local right_winid = self.layout.right_winid
    if target.line and right_winid then
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(right_winid) then
          local line_count = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(right_winid))
          local clamped = math.min(target.line, line_count)
          pcall(vim.api.nvim_win_set_cursor, right_winid, { clamped, 0 })
        end
      end)
    end
  end
end

return M
