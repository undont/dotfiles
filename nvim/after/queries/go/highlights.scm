;; extends

; upstream captures "chan"/"map" as @type.builtin alongside builtin type
; names, so `chan string` renders as a single colour. re-capture them as
; keywords so the keyword and its element type read distinctly
[
  "chan"
  "map"
] @keyword
