-- Plugin specifications loader
-- Each file returns a table of plugin specs

return {
  { import = 'custom.plugins.dashboard' },
  { import = 'custom.plugins.ui' },
  { import = 'custom.plugins.mini' },
  { import = 'custom.plugins.treesitter' },
  { import = 'custom.plugins.navigation' },
  { import = 'custom.plugins.buffers' },
  { import = 'custom.plugins.search' },
  { import = 'custom.plugins.multi-cursor' },
  { import = 'custom.plugins.paste' },
  { import = 'custom.plugins.dial' },
  { import = 'custom.plugins.markdown-ui' },
  { import = 'custom.plugins.telescope' },
  { import = 'custom.plugins.lsp' },
  { import = 'custom.plugins.sonarlint' },
  { import = 'custom.plugins.completion' },
  { import = 'custom.plugins.git' },
  { import = 'custom.plugins.copilot' },
  { import = 'custom.plugins.pr-review' },
  { import = 'custom.plugins.claude-prompt' },
}
