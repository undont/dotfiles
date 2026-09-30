-- vim.notify spam filter. install() must run after fidget.setup(): fidget's
-- `override_vim_notify = true` replaces vim.notify at setup time. drops
-- dotnet/roslyn/sonar startup messages

local M = {}

function M.install()
  local base_notify = vim.notify
  vim.notify = function(msg, level, nopts)
    if type(msg) ~= 'string' then
      return base_notify(msg, level, nopts)
    end

    if msg:match '^Multiple potential target files found' then
      return
    end

    -- nvim core pulls textDocument/diagnostic as soon as roslyn attaches, and
    -- roslyn answers -30099 ("Failed to get language") until the file's
    -- project has loaded. still recorded in lsp.log
    if msg:match '^roslyn: %-30099: Failed to get language' then
      return
    end

    local title = nopts and nopts.title
    local title_str = type(title) == 'string' and title or nil

    -- dotnet/roslyn startup messages
    if not title or title == 'Progress' or (title_str and (title_str:match 'roslyn' or title_str:match 'easy%-dotnet')) then
      local dotnet_spam = { '^Initializing', '^Loading ', ' loaded$', '^Client initialized' }
      for _, pat in ipairs(dotnet_spam) do
        if msg:match(pat) then
          return
        end
      end
    end

    return base_notify(msg, level, nopts)
  end
end

return M
