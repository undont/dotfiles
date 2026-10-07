local ls = require 'luasnip'
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
  s('claudecomment', {
    t { '<comment state="open">', '    <user>', '        ' },
    i(1),
    t { '', '    </user>', '    <claude>', '        [ claude - reply here ]', '    </claude>', '</comment>' },
  }),

  -- the exchange without the outer comment tags
  s('cu', {
    t { '<user>', '    ' },
    i(1),
    t { '', '</user>', '<claude>', '    [ claude - reply here ]', '</claude>' },
  }),
}
