; astro injection override. the upstream query does `; inherits: html_tags`,
; whose bare `<script>` rule injects javascript, then adds an unconditional
; typescript rule on top, so a plain `<script>` is injected twice (ts + js).
; the javascript parse errors on ts-only syntax and smears broken highlights
; over the correct typescript ones. this file replaces the upstream query
; (no `; extends`) and treats every astro `<script>` as typescript only

; comments
((comment) @injection.content
  (#set! injection.language "comment"))

; frontmatter fence is typescript
(frontmatter
  (frontmatter_js_block) @injection.content
  (#set! injection.language "typescript"))

; <script> ... </script> is typescript in astro
(script_element
  (raw_text) @injection.content
  (#set! injection.language "typescript"))

; <style> ... </style> defaults to css
((style_element
  (start_tag) @_no_lang
  (raw_text) @injection.content)
  (#not-lua-match? @_no_lang "%slang%s*=")
  (#set! injection.language "css"))

; <style lang="scss">
(style_element
  (start_tag
    (attribute
      (attribute_name) @_lang_attr
      (quoted_attribute_value
        (attribute_value) @_lang_value)))
  (raw_text) @injection.content
  (#eq? @_lang_attr "lang")
  (#eq? @_lang_value "scss")
  (#set! injection.language "scss"))

; {expr} attribute interpolation and `backtick` attribute strings are typescript
(attribute_interpolation
  (attribute_js_expr) @injection.content
  (#set! injection.language "typescript"))

(attribute
  (attribute_backtick_string) @injection.content
  (#set! injection.language "typescript"))

; {expr} in markup
(html_interpolation
  (permissible_text) @injection.content
  (#set! injection.language "typescript"))

; style="..." attribute -> css
((attribute
  (attribute_name) @_attr
  (quoted_attribute_value
    (attribute_value) @injection.content))
  (#eq? @_attr "style")
  (#set! injection.language "css"))
