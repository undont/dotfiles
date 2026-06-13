-- Rich "issue details" popup. Extracted from plugins/sonarlint.lua.
--
-- Selecting sonar's "Show issue details for '<rule>'" code action makes the
-- server push sonarlint/showRuleDescription, which sonarlint.nvim renders as a
-- generic full-screen popup of the rule's HTML description. We replace that
-- rendering with our own popup that, for deprecation findings, leads with the
-- deprecated symbol's signature and its "@deprecated -> use X instead" note --
-- the specific guidance sonar's own (generic) S1874 text explicitly defers to
-- ("check the deprecation message ... what the recommended alternative is").
--
-- That note is pulled from the editor-facing language server's hover at the
-- finding. Deprecation is detected language-agnostically via a co-located
-- diagnostic carrying the LSP `Deprecated` tag (e.g. ts_ls reports
-- "'X' is deprecated" tagged Deprecated alongside sonar's S1874), so it extends
-- to any language whose server tags deprecated usages -- no rule-key list.

local common = require 'custom.features.sonar-common'

local M = {}

--- The editor-facing LSP diagnostic at `lnum` carrying the `Deprecated` tag, or
--- nil. Neovim normalises LSP `tags: [2]` to `_tags.deprecated`; we also accept
--- the raw payload form. Sonar's own diagnostics never set the tag, so a match
--- always comes from a language server (ts_ls, gopls, roslyn, ...).
local function deprecated_diagnostic_at(bufnr, lnum)
  for _, d in ipairs(vim.diagnostic.get(bufnr, { lnum = lnum })) do
    if d._tags and d._tags.deprecated then
      return d
    end
    local tags = d.user_data and d.user_data.lsp and d.user_data.lsp.tags
    if type(tags) == 'table' then
      for _, t in ipairs(tags) do
        if t == 2 then
          return d
        end
      end
    end
  end
  return nil
end

--- Request hover at `position` from every editor-facing (non-sonar) LSP client
--- on `bufnr`, returning the first non-empty result as markdown lines via `cb`.
--- Falls back to `cb(nil)` if nothing useful answers within the timeout.
local function deprecation_hover(bufnr, position, cb)
  local clients = vim.tbl_filter(function(c)
    return c.name ~= common.SONARLINT_CLIENT_NAME and c:supports_method 'textDocument/hover'
  end, vim.lsp.get_clients { bufnr = bufnr })

  local done = false
  local function finish(lines)
    if done then
      return
    end
    done = true
    cb(lines)
  end

  if #clients == 0 then
    return finish(nil)
  end

  local params = { textDocument = { uri = vim.uri_from_bufnr(bufnr) }, position = position }
  local remaining = #clients
  for _, client in ipairs(clients) do
    client:request('textDocument/hover', params, function(_, result)
      remaining = remaining - 1
      if not done and result and result.contents then
        local md = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
        if md and #md > 0 then
          return finish(md)
        end
      end
      if remaining == 0 then
        finish(nil)
      end
    end, bufnr)
  end

  -- Safety net: never leave the popup unshown if a server stalls.
  vim.defer_fn(function()
    finish(nil)
  end, 2000)
end

--- SonarLint appends a generic "others" fallback context (resource
--- `others_section_html_content.html`: "How can I fix it in another component
--- or framework?" + "Help us improve") to contextual tabs when it has no
--- framework-specific guidance. It carries no real fix, so we drop it; if a tab
--- has nothing left, the tab is skipped entirely (see rule_description_lines).
local function is_fallback_context(ctx)
  local key = ctx.contextKey and ctx.contextKey:lower()
  return key == 'others' or ctx.displayName == 'Others'
end

--- Render one rule-description tab's body. A tab is either non-contextual
--- (`ruleDescriptionTabNonContextual.htmlContent`) or contextual, where
--- `ruleDescriptionTabContextual` is a *list* of per-context variants
--- ({ htmlContent, contextKey, displayName }), e.g. "How to fix it in PropTypes"
--- vs "...in TypeScript". sonarlint.nvim's own renderer reads `.htmlContent` off
--- that list and so shows contextual tabs (S6767's "How can I fix it?") empty;
--- we render every real context, default first, each under its displayName.
--- Returns {} when the tab has no useful content (e.g. only the "others"
--- fallback) so the caller can omit it.
local function tab_body_lines(tab, filetype)
  local utils = require 'sonarlint.utils'

  local nonctx = tab.ruleDescriptionTabNonContextual
  if type(nonctx) == 'table' and nonctx.htmlContent and nonctx.htmlContent ~= '' then
    return utils.html_to_markdown_lines(nonctx.htmlContent, filetype)
  end

  local contexts = tab.ruleDescriptionTabContextual
  if type(contexts) ~= 'table' then
    return {}
  end

  -- Drop the generic fallback, then put the default context first.
  local useful = {}
  for _, ctx in ipairs(contexts) do
    if not is_fallback_context(ctx) then
      if ctx.contextKey and ctx.contextKey == tab.defaultContextKey then
        table.insert(useful, 1, ctx)
      else
        table.insert(useful, ctx)
      end
    end
  end
  if #useful == 0 then
    return {}
  end

  local lines = {}
  for i, ctx in ipairs(useful) do
    if i > 1 then
      table.insert(lines, '')
    end
    if ctx.displayName and ctx.displayName ~= '' then
      vim.list_extend(lines, { '### ' .. ctx.displayName, '' })
    end
    if ctx.htmlContent and ctx.htmlContent ~= '' then
      vim.list_extend(lines, utils.html_to_markdown_lines(ctx.htmlContent, filetype))
    end
  end
  return lines
end

--- Build the rule-description body (markdown lines) from a showRuleDescription
--- payload: a single htmlDescription, or the tabbed form ("Why is this an
--- issue?", "How can I fix it?", ...). Tabs with no useful body (e.g. a "How can
--- I fix it?" that only held the generic fallback) are omitted entirely.
local function rule_description_lines(result, filetype)
  local html = result.htmlDescription
  if html ~= nil and html ~= '' then
    return require('sonarlint.utils').html_to_markdown_lines(html, filetype)
  end
  local lines = {}
  for _, tab in ipairs(result.htmlDescriptionTabs or {}) do
    local body = tab_body_lines(tab, filetype)
    if #body > 0 then
      if #lines > 0 then
        table.insert(lines, '')
      end
      vim.list_extend(lines, { '## ' .. (tab.title or ''), '' })
      vim.list_extend(lines, body)
    end
  end
  return lines
end

--- Open a centred, read-only markdown popup. `q`/`<Esc>` close it.
local function show_details_popup(lines)
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = 'markdown'
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  local win = vim.api.nvim_open_win(buf, true, {
    style = 'minimal',
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    border = 'rounded',
  })
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].conceallevel = 2
  for _, key in ipairs { 'q', '<Esc>' } do
    vim.keymap.set('n', key, '<cmd>close<cr>', { buffer = buf, silent = true })
  end
end

--- showRuleDescription handler: render the rule description in our popup, led
--- by the deprecated symbol's hover note when the finding under the cursor is a
--- deprecation. Replaces sonarlint.nvim's generic renderer. Context (which
--- buffer/finding) is read from the current window -- focus stays on the source
--- buffer until this popup opens.
function M.rich_rule_handler(_, result, _)
  if type(result) ~= 'table' then
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local filetype = vim.bo[bufnr].filetype
  local title = { '# ' .. (result.key or '') .. ': ' .. (result.name or ''), '' }
  local body = rule_description_lines(result, filetype)

  local cursor = vim.api.nvim_win_get_cursor(0)
  local depr = deprecated_diagnostic_at(bufnr, cursor[1] - 1)
  if not depr then
    vim.list_extend(title, body)
    return show_details_popup(title)
  end

  deprecation_hover(bufnr, { line = depr.lnum, character = depr.col }, function(hover_lines)
    local lines = title
    if hover_lines and #hover_lines > 0 then
      vim.list_extend(lines, { '## Deprecated API', '' })
      vim.list_extend(lines, hover_lines)
      vim.list_extend(lines, { '', '---', '' })
    end
    vim.list_extend(lines, body)
    show_details_popup(lines)
  end)
end

return M
