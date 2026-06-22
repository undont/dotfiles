-- macOS-style navigation: Opt+arrows for words, Cmd+arrows for line ends.
-- also handles Ghostty's Shift+Enter (sent as Alt+Enter / \x1b\r)

local M = {}

function M.setup()
  -- Shift+Enter → Enter (Ghostty sends Alt+Enter / \x1b\r)
  vim.keymap.set({ 'i', 'n', 'v', 'c' }, '<M-CR>', '<CR>')

  -- Word-wise deletion
  vim.keymap.set({ 'i', 'c' }, '<M-BS>', '<C-w>', { desc = 'Delete word backward (Opt+Backspace)' })
  vim.keymap.set('i', '<D-BS>', '<C-u>', { desc = 'Delete to beginning of line (Cmd+Backspace)' })
  -- inside tmux, Cmd+Backspace arrives as Ctrl+Backspace (tmux has no super modifier)
  vim.keymap.set('i', '<C-BS>', '<C-u>', { desc = 'Delete to beginning of line (Cmd+Backspace, tmux)' })

  -- Word motion
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

  -- Line ends
  vim.keymap.set('i', '<Home>', '<C-o>0', { desc = 'Beginning of line (Cmd+Left)' })
  vim.keymap.set('i', '<End>', '<C-o>$', { desc = 'End of line (Cmd+Right)' })
end

return M
