-- Plugin specifications loader
-- Each file returns a table of plugin specs

return {
  { import = 'custom.plugins.dashboard' },
  { import = 'custom.plugins.ui' },
  { import = 'custom.plugins.editor' },
  { import = 'custom.plugins.markdown-ui' },
  { import = 'custom.plugins.telescope' },
  { import = 'custom.plugins.lsp' },
  { import = 'custom.plugins.completion' },
  { import = 'custom.plugins.git' },
  { import = 'custom.plugins.copilot' },
  { import = 'custom.plugins.pr-review' },
  { import = 'custom.plugins.claude-prompt' },
  { import = 'custom.plugins.discord' },
}
