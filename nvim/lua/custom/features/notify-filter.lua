-- vim.notify spam filter. extracted from plugins/ui.lua's fidget config.
-- install() must run AFTER fidget.setup(): fidget's `override_vim_notify = true`
-- replaces vim.notify at setup time, so a wrap installed earlier would be blown
-- away. captures the post-fidget vim.notify and drops dotnet/roslyn/sonar
-- startup chatter (some always, some gated on the review-suppression flags
-- owned by sonarlint.lua / dotnet.lua)

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

    -- transient roslyn pre-init noise: nvim core auto-pulls
    -- textDocument/diagnostic the moment roslyn attaches to a buffer,
    -- but roslyn can't resolve a file's language until its project has
    -- loaded, so each early pull errors -30099 ("Failed to get
    -- language"). scans hidden-loading many cs files during a cold
    -- solution load burst one per file. harmless: diagnostics arrive
    -- once init completes (the scans' own explicit pulls are
    -- init-gated in features/diag-scan.lua). still recorded in lsp.log
    if msg:match '^roslyn: %-30099: Failed to get language' then
      return
    end

    local title = nopts and nopts.title
    local title_str = type(title) == 'string' and title or nil

    -- always-silenced dotnet/roslyn startup spam (regardless of suppress)
    if not title or title == 'Progress' or (title_str and (title_str:match 'roslyn' or title_str:match 'easy%-dotnet')) then
      local dotnet_spam = { '^Initializing', '^Loading ', ' loaded$', '^Client initialized' }
      for _, pat in ipairs(dotnet_spam) do
        if msg:match(pat) then
          return
        end
      end
    end

    -- suppress-gated filters: drop sonarlint/roslyn chatter while in
    -- diff/review contexts. flags are owned by sonarlint.lua / dotnet.lua
    if vim.g.sonarlint_suppressed then
      if msg:match '[Ss]onarlint' or msg:match '[Ss]onar[Qq]ube' then
        return
      end
      if title_str and title_str:lower():match 'sonar' then
        return
      end
    end

    if vim.g.roslyn_suppressed then
      if msg:match '[Rr]oslyn' then
        return
      end
      if title_str and title_str:lower():match 'roslyn' then
        return
      end
    end

    return base_notify(msg, level, nopts)
  end
end

return M
