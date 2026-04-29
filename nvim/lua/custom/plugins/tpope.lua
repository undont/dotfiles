-- Tpope utilities that complement (rather than overlap) the existing setup:
--   * vim-abolish   — `:Subvert/`, `:Abolish`, `cr*` case coercions (snake/camel/kebab/…)
--   * vim-repeat    — lets `.` repeat plugin actions (fugitive, abolish coercions)
--   * vim-sleuth    — auto-detects `shiftwidth`/`expandtab` per buffer
--
-- Surround / commentary / unimpaired are intentionally not included — already
-- covered by mini.surround, built-in `gc`, and mini.bracketed respectively.

return {
  {
    'tpope/vim-abolish',
    cmd = { 'Abolish', 'Subvert', 'S' },
    -- VeryLazy so the `cr*` coercion mappings (crs, crc, crm, crk, crt, cru, …)
    -- are bound after startup without blocking the UI.
    event = 'VeryLazy',
  },

  {
    'tpope/vim-repeat',
    event = 'VeryLazy',
  },

  {
    'tpope/vim-sleuth',
    -- Sleuth installs BufReadPost/BufNewFile autocmds, so loading on those
    -- events catches every subsequent buffer. The dashboard buffer at startup
    -- has no file to detect, so deferred load is safe.
    event = { 'BufReadPost', 'BufNewFile' },
  },
}
