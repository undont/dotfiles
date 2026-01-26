local ls = require 'luasnip'
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
  -- Comment template snippet
  s('claudecomment', {
    t { '', '<comment state="open">' },
    t { '', '    <user>' },
    t { '', '        ' },
    i(1), -- First cursor position inside <user> tag
    t { '', '    </user>' },
    t { '', '    <claude>' },
    t { '', '        [ claude - reply here ]' },
    t { '', '    </claude>' },
    t { '', '</comment>' },
  }),
}
