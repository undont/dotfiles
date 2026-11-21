-- monkeypatches to vim.lsp internals. patch_lsp_start blocks LSP attach to
-- non-file:// scheme buffers; patch_show_document skips targets missing on
-- disk and recovers from servers reporting invalid cursor ranges

local M = {}

--- servers like gopls log JSON-RPC parse errors when nvim sends didOpen with
--- a non-file URI (differ://, fugitive://)
function M.patch_lsp_start()
  local orig_start = vim.lsp.start
  vim.lsp.start = function(config, opts)
    opts = opts or {}
    local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
    -- the buffer can be wiped between lsp_enable_callback queueing the start
    -- and this scheduled callback (e.g. differ disposing diff buffers)
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return nil
    end
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name:match '^%w[%w+.-]*://' and not name:match '^file://' then
      return nil
    end
    return orig_start(config, opts)
  end
end

function M.patch_show_document()
  local orig = vim.lsp.util.show_document
  vim.lsp.util.show_document = function(location, offset_encoding, opts)
    local uri = location.uri or location.targetUri
    -- a stale server index (clangd after a file move) points at deleted paths
    if uri and uri:match '^file://' then
      local fname = vim.uri_to_fname(uri)
      if not vim.uv.fs_stat(fname) and vim.fn.bufloaded(fname) == 0 then
        vim.notify('LSP target not on disk: ' .. vim.fn.fnamemodify(fname, ':~:.'), vim.log.levels.WARN)
        return false
      end
    end
    local ok, ret = pcall(orig, location, offset_encoding, opts)
    if ok then
      return ret
    end
    if ret:match 'Cursor position outside buffer' or ret:match 'Invalid cursor line' then
      if uri then
        vim.cmd('edit ' .. vim.uri_to_fname(uri))
        vim.notify('Jumped to file (cursor position was invalid)', vim.log.levels.WARN)
        return true
      end
    end
    error(ret)
  end
end

return M
