-- keeps a session file per instance and reports `nvim -S <file>` to the
-- terminal (OSC 7577), so a rex server restart brings the editor back. the
-- matching trust rule is `resume.trust.nvim` in rex/init.lua

local M = {}

local dir = vim.fn.stdpath 'state' .. '/rex-sessions'
local max_age = 30 * 24 * 60 * 60

local token
local owner
local file
local save_timer

local function send(fields)
  local body = ('pid=%d:time=%d:%s'):format(owner, os.time(), fields)
  local mac = vim.fn.sha256(body .. ':' .. token)
  vim.api.nvim_ui_send(('\27]7577;%s:mac=%s\27\\'):format(body, mac))
end

local function report()
  local argv = {}
  for i, arg in ipairs { 'nvim', '-S', file } do
    argv[i] = vim.base64.encode(arg)
  end
  send('argv=' .. table.concat(argv, ','))
end

local function save()
  local sessionoptions = vim.o.sessionoptions
  vim.o.sessionoptions = 'buffers,curdir,help,tabpages,winsize'
  local this_session = vim.v.this_session
  pcall(vim.cmd.mksession, { vim.fn.fnameescape(file), bang = true })
  vim.v.this_session = this_session
  vim.o.sessionoptions = sessionoptions
end

local function prune()
  local now = os.time()
  for name, kind in vim.fs.dir(dir) do
    local path = dir .. '/' .. name
    local stat = vim.uv.fs_stat(path)
    if kind == 'file' and stat and now - stat.mtime.sec > max_age then
      os.remove(path)
    end
  end
end

local function start()
  vim.fn.mkdir(dir, 'p', '0700')
  prune()

  -- a resumed instance loaded the previous instance's file through -S
  local loaded = vim.v.this_session
  file = ('%s/%d.vim'):format(dir, owner)
  save()
  if loaded ~= '' and loaded ~= file and vim.fs.dirname(loaded) == dir then
    os.remove(loaded)
  end
  report()

  save_timer = vim.uv.new_timer()
  local group = vim.api.nvim_create_augroup('rex-resume', { clear = true })
  vim.api.nvim_create_autocmd({
    'BufEnter',
    'BufDelete',
    'WinNew',
    'WinClosed',
    'TabNew',
    'TabClosed',
    'DirChanged',
    'VimResized',
    'FocusLost',
  }, {
    group = group,
    callback = function()
      save_timer:start(500, 0, vim.schedule_wrap(save))
    end,
  })
  vim.api.nvim_create_autocmd('VimResume', { group = group, callback = report })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      save_timer:stop()
      -- a hangup reaches the TUI, and the server then exits with no UI left: the
      -- terminal ending, which is when the record is needed
      if vim.v.dying ~= 0 or #vim.api.nvim_list_uis() == 0 then
        return
      end
      send 'clear=1'
      os.remove(file)
    end,
  })
end

function M.setup()
  token = vim.env.OSC7577_TOKEN
  if not token then
    return
  end
  -- :terminal and job children would otherwise report over this instance
  vim.env.OSC7577_TOKEN = nil

  vim.api.nvim_create_autocmd('UIEnter', {
    once = true,
    callback = function()
      local tty_ui = vim.iter(vim.api.nvim_list_uis()):any(function(ui)
        return ui.stdout_tty
      end)
      if not tty_ui then
        return
      end
      -- this process is the server; the terminal runs its parent, the TUI
      owner = vim.uv.os_getppid()
      vim.schedule(start)
    end,
  })
end

return M
