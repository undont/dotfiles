#!/usr/bin/env lua
-- Unit tests for scripts/_lib/generate-theme.lua

local script_dir = arg[0]:match('(.*/)')
package.path = script_dir .. '../_lib/?.lua;' .. package.path

local gen = require('generate-theme')

local pass_count = 0
local fail_count = 0

local function pass(desc)
  pass_count = pass_count + 1
  io.write(string.format('\027[0;32m✓\027[0m %s\n', desc))
end

local function fail(desc, detail)
  fail_count = fail_count + 1
  io.write(string.format('\027[0;31m✗\027[0m %s', desc))
  if detail then io.write(string.format(' (%s)', detail)) end
  io.write('\n')
end

local function section(name)
  io.write(string.format('\n─────────────────────────────────────────\n%s\n─────────────────────────────────────────\n', name))
end

-- Helper: write a temp file and return its path
local function write_temp(content)
  local path = os.tmpname()
  local f = io.open(path, 'w')
  f:write(content)
  f:close()
  return path
end

-- ═══════════════════════════════════════════════
section('kebab_name')

local cases = {
  { '3024 Night', '3024-night' },
  { 'Aardvark Blue', 'aardvark-blue' },
  { 'catppuccin-mocha', 'catppuccin-mocha' },
  { 'Solarized (Light)', 'solarized-light' },
  { 'UPPERCASE', 'uppercase' },
  { '  leading spaces  ', 'leading-spaces' },
}
for _, c in ipairs(cases) do
  local result = gen.kebab_name(c[1])
  if result == c[2] then pass('kebab_name("' .. c[1] .. '") = "' .. c[2] .. '"')
  else fail('kebab_name("' .. c[1] .. '")', 'got "' .. result .. '"') end
end

-- ═══════════════════════════════════════════════
section('display_name')

-- Should sanitise shell metacharacters
local safe = gen.display_name('Normal Theme')
if safe == 'Normal Theme' then pass('display_name preserves normal names')
else fail('display_name normal', safe) end

local sanitised = gen.display_name('Evil$(rm -rf)Theme')
if not sanitised:find('%$') then pass('display_name strips $ characters')
else fail('display_name should strip $', sanitised) end

sanitised = gen.display_name('back`tick`name')
if not sanitised:find('`') then pass('display_name strips backticks')
else fail('display_name should strip backticks', sanitised) end

-- ═══════════════════════════════════════════════
section('parse_ghostty_theme')

-- Minimal valid theme
local minimal_theme = [[
background = #282a36
foreground = #f8f8f2
palette = 0=#282a36
palette = 1=#ff5555
palette = 2=#50fa7b
palette = 3=#f1fa8c
palette = 4=#bd93f9
palette = 5=#ff79c6
palette = 6=#8be9fd
palette = 7=#f8f8f2
]]

local path = write_temp(minimal_theme)
local theme, err = gen.parse_ghostty_theme(path)
os.remove(path)

if theme then pass('parses minimal valid theme')
else fail('parse minimal theme', err) end

if theme and theme.background == '#282a36' then pass('extracts background')
else fail('extract background') end

if theme and theme.foreground == '#f8f8f2' then pass('extracts foreground')
else fail('extract foreground') end

if theme and theme.palette[1] == '#ff5555' then pass('extracts palette entry')
else fail('extract palette') end

-- Missing background
path = write_temp('foreground = #f8f8f2\npalette = 0=#000000\n')
theme, err = gen.parse_ghostty_theme(path)
os.remove(path)
if not theme and err:find('background') then pass('rejects missing background')
else fail('should reject missing background') end

-- Missing palette entry
path = write_temp('background = #000000\nforeground = #ffffff\npalette = 0=#000000\n')
theme, err = gen.parse_ghostty_theme(path)
os.remove(path)
if not theme and err:find('palette') then pass('rejects missing palette entries')
else fail('should reject incomplete palette') end

-- Comments and blank lines
local commented_theme = [[
# This is a comment
background = #282a36
foreground = #f8f8f2

# Another comment
palette = 0=#282a36
palette = 1=#ff5555
palette = 2=#50fa7b
palette = 3=#f1fa8c
palette = 4=#bd93f9
palette = 5=#ff79c6
palette = 6=#8be9fd
palette = 7=#f8f8f2
]]
path = write_temp(commented_theme)
theme, err = gen.parse_ghostty_theme(path)
os.remove(path)
if theme then pass('ignores comments and blank lines')
else fail('comments/blanks', err) end

-- Non-existent file
theme, err = gen.parse_ghostty_theme('/tmp/nonexistent-theme-xyz-12345')
if not theme and err:find('Cannot open') then pass('reports error for missing file')
else fail('should report missing file error') end

-- ═══════════════════════════════════════════════
section('extract_colours')

-- Build a parsed theme fixture
local fixture = {
  background = '#282a36',
  foreground = '#f8f8f2',
  palette = {
    [0] = '#44475a', [1] = '#ff5555', [2] = '#50fa7b', [3] = '#f1fa8c',
    [4] = '#bd93f9', [5] = '#ff79c6', [6] = '#8be9fd', [7] = '#f8f8f2',
    [8] = '#6272a4',
  },
}

local colours = gen.extract_colours(fixture)
if colours.bg_primary == '#282a36' then pass('bg_primary from background')
else fail('bg_primary') end

if colours.fg_primary == '#f8f8f2' then pass('fg_primary from foreground')
else fail('fg_primary') end

if colours.red == '#ff5555' then pass('red from palette[1]')
else fail('red') end

if colours.bg_secondary then pass('bg_secondary derived')
else fail('bg_secondary missing') end

if colours.fg_secondary then pass('fg_secondary derived')
else fail('fg_secondary missing') end

-- ═══════════════════════════════════════════════
section('apply_wcag_corrections')

-- Use colours with known low contrast against dark bg
local test_colours = {
  bg_primary = '#282a36',
  bg_secondary = '#44475a',
  line_highlight = '#2e3042',
  fg_primary = '#f8f8f2',
  fg_secondary = '#555555',  -- Low contrast
  red = '#ff5555', green = '#50fa7b', yellow = '#f1fa8c',
  purple = '#bd93f9', pink = '#ff79c6', cyan = '#8be9fd',
}

local adjustments = gen.apply_wcag_corrections(test_colours)
-- fg_secondary was low contrast, should have been adjusted
local colour_utils = require('colour-utils')
local fg_sec_ratio = colour_utils.contrast_ratio(test_colours.fg_secondary, test_colours.bg_primary)
if fg_sec_ratio >= 5.0 then pass('fg_secondary meets 5.0:1 after correction')
else fail('fg_secondary contrast', string.format('ratio=%.2f', fg_sec_ratio)) end

-- ═══════════════════════════════════════════════
section('choose_active_accent')

local accent = gen.choose_active_accent({
  bg_primary = '#282a36',
  purple = '#bd93f9', cyan = '#8be9fd', green = '#50fa7b',
})
if accent == 'purple' or accent == 'cyan' or accent == 'green' then
  pass('chooses from candidate set: ' .. accent)
else fail('invalid accent choice', accent) end

-- ═══════════════════════════════════════════════
section('generate_theme_file')

local theme_content = gen.generate_theme_file(
  'test-theme', 'Test Theme',
  {
    bg_primary = '#282a36', fg_primary = '#f8f8f2',
    bg_secondary = '#44475a', fg_secondary = '#6272a4',
    red = '#ff5555', green = '#50fa7b', yellow = '#f1fa8c',
    purple = '#bd93f9', pink = '#ff79c6', cyan = '#8be9fd',
    cursor_colour = '#f8f8f2', cursor_text = '#282a36',
    selection = '#44475a', selection_fg = '#ffffff',
    palette = { [0]='#282a36', [1]='#ff5555', [2]='#50fa7b', [3]='#f1fa8c',
                [4]='#bd93f9', [5]='#ff79c6', [6]='#8be9fd', [7]='#f8f8f2' },
  },
  { cpu_low_bg='#2a3040', cpu_medium_bg='#2a3040', cpu_high_bg='#2a3040',
    ram_low_bg='#2a3040', ram_medium_bg='#2a3040', ram_high_bg='#2a3040',
    battery_normal_bg='#2a3040', battery_low_bg='#2a3040' },
  'purple', {}
)

if theme_content:find('THEME_NAME="Test Theme"') then pass('theme file has THEME_NAME')
else fail('theme file THEME_NAME') end

if theme_content:find('TMUX_BG_PRIMARY="#282a36"') then pass('theme file has bg_primary')
else fail('theme file bg_primary') end

if theme_content:find('GHOSTTY_BACKGROUND') then pass('theme file has Ghostty section')
else fail('theme file Ghostty section') end

-- ═══════════════════════════════════════════════
section('Module can be required without CLI side effects')

-- The module guards CLI execution with pcall(debug.getlocal, 4, 1)
-- If we got this far without errors, the guard works
pass('module loads without executing CLI entry point')

-- ═══════════════════════════════════════════════
-- Summary
io.write(string.format('\n===========================================\n'))
io.write(string.format('Test Results: \027[0;32m%d passed\027[0m, \027[0;31m%d failed\027[0m\n', pass_count, fail_count))
io.write(string.format('===========================================\n'))

os.exit(fail_count > 0 and 1 or 0)
