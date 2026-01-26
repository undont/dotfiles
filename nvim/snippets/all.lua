local ls = require 'luasnip'
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
  -- Comment template snippet
  s('claudecomment', {
    t { '' }, -- Newline before
    t { '<comment state="open">' },
    t { '    <user>' },
    t { '        ' },
    i(1), -- First cursor position inside <user> tag
    t { '    </user>' },
    t { '    <claude>' },
    t { '        [ claude - reply here ]' },
    t { '    </claude>' },
    t { '</comment>' },
    t { '' }, -- Newline after
  }),

  -- User/Claude exchange snippet (without outer comment tags)
  s('cu', {
    t { '<user>' },
    t { '    ' },
    i(1), -- First cursor position inside <user> tag
    t { '</user>' },
    t { '<claude>' },
    t { '    [ claude - reply here ]' },
    t { '</claude>' },
  }),
}
