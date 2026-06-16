-- smart paste: auto-adjusts indentation when pasting, with a guard against
-- pasting into non-modifiable buffers (help, neotest output, etc)

return {
  {
    'nemanjamalesija/smart-paste.nvim',
    event = 'VeryLazy',
    config = function()
      require('smart-paste').setup()
      -- the plugin's keymaps look up these functions on the module table at call time,
      -- so patching after setup intercepts all paste paths
      local paste = require 'smart-paste.paste'
      local orig_smart_paste = paste.smart_paste
      paste.smart_paste = function(entry, ...)
        if not vim.bo.modifiable then
          return type(entry) == 'string' and entry or entry.lhs
        end
        return orig_smart_paste(entry, ...)
      end
      local orig_visual_paste = paste.do_visual_paste
      paste.do_visual_paste = function(...)
        if not vim.bo.modifiable then
          return
        end
        return orig_visual_paste(...)
      end
    end,
  },
}
