-- macOS-style navigation: Opt+arrows for words, Cmd+arrows for line ends

local M = {}

function M.setup()
  -- ghostty sends Shift+Enter as Alt+Enter
  vim.keymap.set({ 'i', 'n', 'v', 'c' }, '<M-CR>', '<CR>')

  vim.keymap.set({ 'i', 'c' }, '<M-BS>', '<C-w>', { desc = 'Delete word backward (Opt+Backspace)' })
  vim.keymap.set('i', '<D-BS>', '<C-u>', { desc = 'Delete to beginning of line (Cmd+Backspace)' })
  -- tmux has no super modifier, so Cmd+Backspace arrives as Ctrl+Backspace
  vim.keymap.set('i', '<C-BS>', '<C-u>', { desc = 'Delete to beginning of line (Cmd+Backspace, tmux)' })

  vim.keymap.set({ 'n', 'v' }, '<M-Right>', 'w', { desc = 'Move word right (Opt+Right)' })
  vim.keymap.set({ 'n', 'v' }, '<M-Left>', 'b', { desc = 'Move word left (Opt+Left)' })
  vim.keymap.set({ 'n', 'v' }, '<M-f>', 'w', { desc = 'Move word right (Opt+Right)' })
  vim.keymap.set({ 'n', 'v' }, '<M-b>', 'b', { desc = 'Move word left (Opt+Left)' })
  vim.keymap.set('i', '<M-Left>', '<C-o>b', { desc = 'Move word left (Opt+Left)' })
  vim.keymap.set('i', '<M-Right>', '<C-o>w', { desc = 'Move word right (Opt+Right)' })
  vim.keymap.set('i', '<M-b>', '<C-o>b', { desc = 'Move word left (Opt+Left)' })
  vim.keymap.set('i', '<M-f>', '<C-o>w', { desc = 'Move word right (Opt+Right)' })
  vim.keymap.set('c', '<M-Left>', '<S-Left>', { desc = 'Move word left in cmdline (Opt+Left)' })
  vim.keymap.set('c', '<M-Right>', '<S-Right>', { desc = 'Move word right in cmdline (Opt+Right)' })
  vim.keymap.set('c', '<M-b>', '<S-Left>', { desc = 'Move word left in cmdline (Opt+Left)' })
  vim.keymap.set('c', '<M-f>', '<S-Right>', { desc = 'Move word right in cmdline (Opt+Right)' })

  vim.keymap.set('i', '<Home>', '<C-o>0', { desc = 'Beginning of line (Cmd+Left)' })
  vim.keymap.set('i', '<End>', '<C-o>$', { desc = 'End of line (Cmd+Right)' })
end

return M
