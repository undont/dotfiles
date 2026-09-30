-- smart paste: reindents pasted text, and skips non-modifiable buffers

return {
  {
    'nemanjamalesija/smart-paste.nvim',
    event = 'VeryLazy',
    config = function()
      require('smart-paste').setup()
      -- the plugin's keymaps look these functions up on the module table at call time
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
