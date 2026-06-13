local ls = require 'luasnip'
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
  -- comment template snippet
  s('claudecomment', {
    t { '<comment state="open">', '    <user>', '        ' },
    i(1), -- first cursor position inside <user> tag
    t { '', '    </user>', '    <claude>', '        [ claude - reply here ]', '    </claude>', '</comment>' },
  }),

  -- user/Claude exchange snippet (without outer comment tags)
  s('cu', {
    t { '<user>', '    ' },
    i(1), -- first cursor position inside <user> tag
    t { '', '</user>', '<claude>', '    [ claude - reply here ]', '</claude>' },
  }),
}
