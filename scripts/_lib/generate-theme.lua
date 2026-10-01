-- parses a ghostty theme file and generates:
--   themes/generated/<name>.theme
--   nvim/colors/generated/<name>.lua

---@diagnostic disable: redundant-return-value

local colour = require("colour-utils")

local M = {}

--- @param val string
--- @param field string field name for the error message
--- @return string val the validated hex colour
local function assert_hex(val, field)
    if
        type(val) ~= "string" or not val:match("^#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$")
    then
        error(string.format("Invalid colour for %s: %s", field, tostring(val)))
    end
    return val
end

--- @param adj table {name, delta, surface}, {name, swapped} or {name, saturated}
--- @return string description
local function format_adjustment(adj)
    if adj.swapped then
        return string.format("%s swapped to bright palette variant", adj.name)
    end
    if adj.saturated then
        return string.format("%s promoted to bright variant (near-grey normal row)", adj.name)
    end
    return string.format("%s lightened +%.0f%% (against %s)", adj.name, adj.delta, adj.surface)
end

-- ══════════════════════════════════════════════════════════════
-- Ghostty Theme Parsing
-- ══════════════════════════════════════════════════════════════

--- file format: "key = value", with "palette = N=#RRGGBB" for palette entries
---@param path string path to ghostty theme file
---@return table|nil parsed theme, string|nil error
function M.parse_ghostty_theme(path)
    local f = io.open(path, "r")
    if not f then
        return nil, "Cannot open file: " .. path
    end

    local theme = { palette = {} }
    for raw_line in f:lines() do
        local line = raw_line:match("^%s*(.-)%s*$")
        if line ~= "" and not line:match("^#") then
            local key, value = line:match("^([%w_-]+)%s*=%s*(.+)$")
            if key and value then
                if key == "palette" then
                    local index, hex = value:match("^(%d+)=(.+)$")
                    if index and hex then
                        theme.palette[tonumber(index)] = hex
                    end
                else
                    theme[key] = value
                end
            end
        end
    end
    f:close()

    if not theme.background or not theme.foreground then
        return nil, "Theme missing background or foreground"
    end
    for i = 0, 7 do
        if not theme.palette[i] then
            return nil, string.format("Theme missing palette colour %d", i)
        end
    end

    return theme, nil
end

-- ══════════════════════════════════════════════════════════════
-- Colour Extraction (Ghostty ANSI -> Semantic Palette)
-- ══════════════════════════════════════════════════════════════

---@param ghostty table parsed ghostty theme
---@return table colours semantic colour palette
function M.extract_colours(ghostty)
    local p = ghostty.palette
    local bg = ghostty.background
    local fg = ghostty.foreground

    -- bg_secondary (sidebars, floats) is palette 0 when its contrast against
    -- bg falls inside a band and it is not near-black
    local bg_secondary
    local bg_lum = colour.luminance(bg)
    local p0_lum = colour.luminance(p[0])
    local p0_ratio = colour.contrast_ratio(p[0], bg)

    -- a near-black p[0] would strip the theme's hue from sidebars and floats
    local p0_usable = p0_ratio >= 1.1 and p0_ratio <= 2.5 and p0_lum >= 0.005

    if p0_usable then
        bg_secondary = p[0]
    elseif bg_lum < 0.03 then
        -- a very dark bg needs a larger lift to stay distinct
        bg_secondary = colour.lighten(bg, 10)
    else
        bg_secondary = colour.lighten(bg, 8)
    end

    -- fg_secondary is palette 8 (bright black) when readable, else a blend
    local fg_secondary
    local p8_ratio = p[8] and colour.contrast_ratio(p[8], bg) or 0
    if p8_ratio >= 4.0 then
        fg_secondary = p[8]
    else
        fg_secondary = colour.blend(fg, bg, 0.35)
    end

    -- fg_variable is fg tinted slightly toward cyan, so variable identifiers
    -- differ from Normal text without becoming an accent
    local fg_variable = colour.blend(fg, p[6], 0.10)
    fg_variable = colour.ensure_contrast(fg_variable, bg, 4.5)

    -- line highlight (CursorLine/ColorColumn) is a lift of bg smaller than
    -- bg_secondary's. a very dark bg needs a larger lift to show the same step
    local line_highlight
    if bg_lum < 0.03 then
        line_highlight = colour.lighten(bg, 7)
    else
        line_highlight = colour.lighten(bg, 5)
    end

    local selection = ghostty["selection-background"] or bg_secondary

    return {
        bg_primary = bg,
        fg_primary = fg,
        bg_secondary = bg_secondary,
        fg_secondary = fg_secondary,
        fg_variable = fg_variable,
        line_highlight = line_highlight,
        selection = selection,
        selection_fg = ghostty["selection-foreground"] or "#ffffff",
        cursor_colour = ghostty["cursor-color"] or fg,
        cursor_text = ghostty["cursor-text"] or bg,

        -- accent colours mapped from the ANSI palette
        red = p[1], -- ANSI red
        green = p[2], -- ANSI green
        yellow = p[3], -- ANSI yellow
        purple = p[4], -- ANSI blue -> "purple" role
        pink = p[5], -- ANSI magenta -> "pink" role
        cyan = p[6], -- ANSI cyan

        -- full 16-colour palette, passed through to the ghostty config
        palette = p,
    }
end

-- ══════════════════════════════════════════════════════════════
-- Chroma
-- ══════════════════════════════════════════════════════════════

--- chroma of a hex colour (RGB max-min, 0-255). HSL saturation over-rates
--- pale pastels (dracula's bright lavender above its purple)
---@param hex string
---@return number chroma
local function chroma(hex)
    local r, g, b = colour.hex_to_rgb(hex)
    return math.max(r, g, b) - math.min(r, g, b)
end

-- an accent below this chroma reads as tinted grey. the accents of
-- dull-but-chromatic themes (Spacegray Eighties Dull) sit above it
local NEAR_GREY_CHROMA = 30

-- ceiling on a bright-row swap, as a multiple of the most chromatic other
-- accent. Kanagawa Dragon's bright red exceeds it; Spacegray Eighties Dull's
-- does not
local BRIGHT_SWAP_CHROMA_CEILING = 1.5

-- ══════════════════════════════════════════════════════════════
-- WCAG Auto-Correction
-- ══════════════════════════════════════════════════════════════

--- corrects accent contrast against bg_primary, bg_secondary and
--- line_highlight, and fg_secondary against the two backgrounds
---@param colours table semantic colour palette (mutated in place)
---@return table adjustments list of {name, delta, surface} or {name, swapped}
function M.apply_wcag_corrections(colours)
    local adjustments = {}
    local accents = { "red", "green", "yellow", "purple", "pink", "cyan" }

    -- ANSI palette index for each accent role; bright variant = index + 8
    local accent_index = { red = 1, green = 2, yellow = 3, purple = 4, pink = 5, cyan = 6 }

    -- chroma of every accent on entry, so the band a swap is judged against
    -- doesn't shift as earlier accents in the loop are corrected
    local entry_chroma = {}
    for _, name in ipairs(accents) do
        entry_chroma[name] = chroma(colours[name])
    end

    -- highest chroma among the other accents, floored at NEAR_GREY_CHROMA so
    -- a near-monochrome palette doesn't reject every swap
    local function peer_chroma(accent_name)
        local peak = NEAR_GREY_CHROMA
        for _, name in ipairs(accents) do
            if name ~= accent_name then
                peak = math.max(peak, entry_chroma[name])
            end
        end
        return peak
    end

    -- surfaces accents must be readable on. line_highlight takes WCAG's
    -- large-text/UI minimum: the body-text minimum there brightens every
    -- dim-row colour in dull themes (Spacegray Eighties Dull)
    local accent_surfaces = {
        { name = "bg_secondary", colour = colours.bg_secondary, min = 4.5 },
        { name = "line_highlight", colour = colours.line_highlight, min = 3.0 },
        { name = "bg_primary", colour = colours.bg_primary, min = 4.5 },
    }

    -- worst contrast margin of a colour across the accent surfaces, as a
    -- fraction of each surface's minimum (1.0 = exactly passing)
    local function worst_margin(hex)
        local worst = math.huge
        for _, surface in ipairs(accent_surfaces) do
            local margin = colour.contrast_ratio(hex, surface.colour) / surface.min
            if margin < worst then
                worst = margin
            end
        end
        return worst
    end

    -- the colour lightening alone would produce, without recording an
    -- adjustment
    local function lightened(hex)
        for _, surface in ipairs(accent_surfaces) do
            hex = colour.ensure_contrast(hex, surface.colour, surface.min)
        end
        return hex
    end

    -- a bright variant fits when it is inside the peer band, or no more
    -- chromatic than the lightened fallback
    local function bright_fits(accent_name, bright)
        if chroma(bright) <= peer_chroma(accent_name) * BRIGHT_SWAP_CHROMA_CEILING then
            return true
        end
        return chroma(bright) <= chroma(lightened(colours[accent_name]))
    end

    for _, accent_name in ipairs(accents) do
        -- a failing accent swaps to the theme's bright variant when that has
        -- the better margin and fits the palette (Bluloco Dark's dim blue);
        -- ensure_contrast below covers any remaining shortfall. lightening the
        -- dim row alone produces pastels that are not in the theme
        if worst_margin(colours[accent_name]) < 1 then
            local bright = colours.palette and colours.palette[accent_index[accent_name] + 8]
            if
                bright
                and bright:match("^#%x%x%x%x%x%x$")
                and worst_margin(bright) > worst_margin(colours[accent_name])
                and bright_fits(accent_name, bright)
            then
                colours[accent_name] = bright
                table.insert(adjustments, { name = accent_name, swapped = true })
            end
        end

        for _, surface in ipairs(accent_surfaces) do
            local corrected, delta = colour.ensure_contrast(colours[accent_name], surface.colour, surface.min)
            if delta > 0 then
                colours[accent_name] = corrected
                table.insert(adjustments, { name = accent_name, delta = delta, surface = surface.name })
            end
        end
    end

    -- fg_secondary (line numbers, UI chrome) takes a higher minimum than the accents
    local fg_sec_surfaces = {
        { name = "bg_secondary", colour = colours.bg_secondary },
        { name = "bg_primary", colour = colours.bg_primary },
    }

    for _, surface in ipairs(fg_sec_surfaces) do
        local corrected, delta = colour.ensure_contrast(colours.fg_secondary, surface.colour, 5.0)
        if delta > 0 then
            colours.fg_secondary = corrected
            table.insert(adjustments, { name = "fg_secondary", delta = delta, surface = surface.name })
        end
    end

    return adjustments
end

-- ══════════════════════════════════════════════════════════════
-- Saturation Preference
-- ══════════════════════════════════════════════════════════════

--- swaps accents below NEAR_GREY_CHROMA for the theme's bright-row variant
--- when that is clearly more chromatic (Kanagawa Dragon keeps its accent
--- colours in the bright row). runs before the WCAG correction
---@param colours table semantic colour palette (mutated in place)
---@return table adjustments list of {name, saturated} adjustments made
function M.apply_saturation_preference(colours)
    local adjustments = {}
    local accents = { "red", "green", "yellow", "purple", "pink", "cyan" }
    local accent_index = { red = 1, green = 2, yellow = 3, purple = 4, pink = 5, cyan = 6 }

    for _, accent_name in ipairs(accents) do
        local current = colours[accent_name]
        local bright = colours.palette and colours.palette[accent_index[accent_name] + 8]
        if
            bright
            and bright:match("^#%x%x%x%x%x%x$")
            and bright ~= current
            and chroma(current) < NEAR_GREY_CHROMA
            and chroma(bright) >= chroma(current) * 1.4
        then
            colours[accent_name] = bright
            table.insert(adjustments, { name = accent_name, saturated = true })
        end
    end

    return adjustments
end

-- ══════════════════════════════════════════════════════════════
-- Active Accent Selection
-- ══════════════════════════════════════════════════════════════

--- picks whichever of purple, cyan and green has the highest contrast
--- against bg_primary
---@param colours table semantic colour palette
---@return string accent "purple", "cyan" or "green"
function M.choose_active_accent(colours)
    local candidates = { "purple", "cyan", "green" }
    local best_name = "purple"
    local best_ratio = 0

    for _, name in ipairs(candidates) do
        local ratio = colour.contrast_ratio(colours[name], colours.bg_primary)
        if ratio > best_ratio then
            best_ratio = ratio
            best_name = name
        end
    end

    return best_name
end

-- ══════════════════════════════════════════════════════════════
-- Plugin Status Indicator Colours
-- ══════════════════════════════════════════════════════════════

--- CPU/RAM/battery status indicator backgrounds
---@param colours table semantic colour palette
---@return table status_colours status bg colours
function M.derive_status_colours(colours)
    local bg = colours.bg_primary
    return {
        cpu_low_bg = colour.blend(bg, colours.cyan, 0.15),
        cpu_medium_bg = colour.blend(bg, colours.purple, 0.15),
        cpu_high_bg = colour.blend(bg, colours.pink, 0.15),
        ram_low_bg = colour.blend(bg, colours.green, 0.15),
        ram_medium_bg = colour.blend(bg, colours.cyan, 0.15),
        ram_high_bg = colour.blend(bg, colours.purple, 0.15),
        battery_normal_bg = colour.blend(bg, colours.green, 0.12),
        battery_low_bg = colour.blend(bg, colours.red, 0.15),
    }
end

-- ══════════════════════════════════════════════════════════════
-- .theme File Generation
-- ══════════════════════════════════════════════════════════════

---@param name string theme name (kebab-case)
---@param display_name string display name (Title Case)
---@param colours table semantic colour palette
---@param status table status indicator colours
---@param active_accent string chosen active accent
---@param adjustments table adjustments made
---@return string theme file content
function M.generate_theme_file(name, display_name, colours, status, active_accent, adjustments)
    assert_hex(colours.bg_primary, "bg_primary")
    assert_hex(colours.fg_primary, "fg_primary")
    assert_hex(colours.bg_secondary, "bg_secondary")
    assert_hex(colours.fg_secondary, "fg_secondary")
    assert_hex(colours.fg_variable, "fg_variable")
    assert_hex(colours.line_highlight, "line_highlight")
    assert_hex(colours.selection, "selection")
    assert_hex(colours.selection_fg, "selection_fg")
    assert_hex(colours.cursor_colour, "cursor_colour")
    assert_hex(colours.red, "red")
    assert_hex(colours.green, "green")
    assert_hex(colours.yellow, "yellow")
    assert_hex(colours.purple, "purple")
    assert_hex(colours.pink, "pink")
    assert_hex(colours.cyan, "cyan")
    for i = 0, 15 do
        if colours.palette[i] then
            assert_hex(colours.palette[i], string.format("palette_%d", i))
        end
    end

    local lines = {}
    local function add(line)
        table.insert(lines, line)
    end

    add("# shellcheck shell=bash")
    add(string.format("# Generated from Ghostty theme: %s", display_name))
    add("# Auto-generated by scripts/generate-theme — do not edit manually")
    if #adjustments > 0 then
        add("# WCAG adjustments applied:")
        for _, adj in ipairs(adjustments) do
            add("#   " .. format_adjustment(adj))
        end
    end
    add("")
    add(string.format('THEME_NAME="%s"', display_name))
    add(string.format('THEME_ACTIVE_ACCENT="%s"', active_accent))
    add("")
    add("# " .. string.rep("=", 62))
    add("# Base Colours")
    add("# " .. string.rep("=", 62))
    add("")
    add(string.format('TMUX_BG_PRIMARY="%s"', colours.bg_primary))
    add(string.format('TMUX_FG_PRIMARY="%s"', colours.fg_primary))
    add(string.format('TMUX_BG_SECONDARY="%s"', colours.bg_secondary))
    add(string.format('TMUX_FG_SECONDARY="%s"', colours.fg_secondary))
    add("")
    add("# " .. string.rep("=", 62))
    add("# Accent Colours")
    add("# " .. string.rep("=", 62))
    add("")
    add(string.format('TMUX_ACCENT_PURPLE="%s"', colours.purple))
    add(string.format('TMUX_ACCENT_PINK="%s"', colours.pink))
    add(string.format('TMUX_ACCENT_CYAN="%s"', colours.cyan))
    add(string.format('TMUX_ACCENT_GREEN="%s"', colours.green))
    add(string.format('TMUX_ACCENT_YELLOW="%s"', colours.yellow))
    add(string.format('TMUX_ACCENT_RED="%s"', colours.red))
    add("")
    add("# " .. string.rep("=", 62))
    add("# Plugin Status Indicators")
    add("# " .. string.rep("=", 62))
    add("")
    add(string.format('TMUX_CPU_LOW_BG="%s"', status.cpu_low_bg))
    add(string.format('TMUX_CPU_MEDIUM_BG="%s"', status.cpu_medium_bg))
    add(string.format('TMUX_CPU_HIGH_BG="%s"', status.cpu_high_bg))
    add(string.format('TMUX_RAM_LOW_BG="%s"', status.ram_low_bg))
    add(string.format('TMUX_RAM_MEDIUM_BG="%s"', status.ram_medium_bg))
    add(string.format('TMUX_RAM_HIGH_BG="%s"', status.ram_high_bg))
    add(string.format('TMUX_BATTERY_NORMAL_BG="%s"', status.battery_normal_bg))
    add(string.format('TMUX_BATTERY_LOW_BG="%s"', status.battery_low_bg))
    add("")
    add("# " .. string.rep("=", 62))
    add("# Ghostty Colours")
    add("# " .. string.rep("=", 62))
    add("")
    add(string.format('GHOSTTY_BACKGROUND="%s"', colours.bg_primary))
    add(string.format('GHOSTTY_FOREGROUND="%s"', colours.fg_primary))
    add(string.format('GHOSTTY_CURSOR_COLOR="%s"', colours.cursor_colour))
    add(string.format('GHOSTTY_CURSOR_TEXT="%s"', colours.cursor_text))
    add(string.format('GHOSTTY_SELECTION_BG="%s"', colours.selection))
    add(string.format('GHOSTTY_SELECTION_FG="%s"', colours.selection_fg))
    add("")
    add("# Terminal palette")
    for i = 0, 15 do
        local val = colours.palette[i]
        if val then
            add(string.format('GHOSTTY_PALETTE_%d="%s"', i, val))
        end
    end
    add("")
    add("# " .. string.rep("=", 62))
    add("# Neovim Colours")
    add("# " .. string.rep("=", 62))
    add("")
    add(string.format('NVIM_COLORSCHEME="%s"', name))
    add(string.format('NVIM_FG_VARIABLE="%s"', colours.fg_variable))
    add("")

    return table.concat(lines, "\n")
end

-- ══════════════════════════════════════════════════════════════
-- Neovim Colourscheme Generation
-- ══════════════════════════════════════════════════════════════

-- selection band. steps are HSL lightness points off line_highlight: the
-- largest step up to BAND_STEP_MAX at which every accent clears
-- BAND_CONTRAST_FLOOR against the band. the hue is fixed, matching the cool
-- selections of most hand-crafted schemes in nvim/colors/
local BAND_STEP_MIN = 6
local BAND_STEP_MAX = 16
local BAND_CONTRAST_FLOOR = 3.0
local BAND_HUE = 220
local BAND_SATURATION = 0.16
local BAND_ACCENTS = { "fg_primary", "fg_variable", "purple", "pink", "cyan", "green", "yellow", "red" }

--- content of nvim/colors/generated/<name>.lua
---@param name string colourscheme name (kebab-case)
---@param colours table semantic colour palette
---@return string lua file content
function M.generate_nvim_colourscheme(name, colours)
    local neotree_cursor = colour.lighten(colours.bg_secondary, 12)

    -- the selection band is derived from line_highlight, not ghostty's
    -- selection-background: an inverted selection (Bluloco Dark) needs a fg on
    -- Visual, which overrides syntax colours, and a saturated one (Aura) leaves
    -- accents unreadable on it. LspReference* and TelescopeSelection share it
    local function band_at(step)
        local _, _, line_l = colour.hex_to_hsl(colours.line_highlight)
        local l = colour.luminance(colours.bg_primary) < 0.5 and math.min(1, line_l + step / 100)
            or math.max(0, line_l - step / 100)
        return colour.hsl_to_hex(BAND_HUE, BAND_SATURATION, l)
    end
    local function band_worst_accent(band)
        local worst = math.huge
        for _, key in ipairs(BAND_ACCENTS) do
            worst = math.min(worst, colour.contrast_ratio(colours[key], band))
        end
        return worst
    end
    local selection_bg = band_at(BAND_STEP_MIN)
    for step = BAND_STEP_MAX, BAND_STEP_MIN + 1, -1 do
        local candidate = band_at(step)
        if band_worst_accent(candidate) >= BAND_CONTRAST_FLOOR then
            selection_bg = candidate
            break
        end
    end

    -- comments are dimmer than fg_secondary (@variable.parameter, LineNr, UI
    -- chrome), with a contrast floor against the editor background
    local comment = colour.blend(colours.fg_secondary, colours.bg_primary, 0.30)
    comment = colour.ensure_contrast(comment, colours.bg_primary, 4.0)

    -- punctuation is fg tinted toward purple, as in the hand-crafted schemes
    local punct =
        colour.ensure_contrast(colour.blend(colours.fg_primary, colours.purple, 0.35), colours.bg_primary, 4.5)

    -- role mapping shared with the hand-crafted schemes: strings green,
    -- functions purple (the ANSI blue role), types and modules cyan, literal
    -- data and properties yellow, keywords, control flow and operators pink
    local c = {
        constant = "colors.yellow",
        string = "colors.green",
        character = "colors.green",
        number = "colors.yellow",
        boolean = "colors.yellow",
        float = "colors.yellow",
        func = "colors.purple",
        statement = "colors.pink",
        conditional = "colors.pink",
        ["repeat"] = "colors.pink",
        label = "colors.pink",
        operator = "colors.pink",
        keyword = "colors.pink",
        exception = "colors.pink",
        preproc = "colors.pink",
        include = "colors.pink",
        define = "colors.pink",
        macro = "colors.cyan",
        precondit = "colors.pink",
        type = "colors.cyan",
        storageclass = "colors.pink",
        structure = "colors.cyan",
        typedef = "colors.cyan",
        special = "colors.cyan",
        specialchar = "colors.pink",
        tag = "colors.pink",
    }

    local lines = {}
    local function add(line)
        table.insert(lines, line)
    end

    add(string.format("-- %s colourscheme for Neovim", name))
    add("-- Generated from Ghostty theme by scripts/generate-theme")
    add("")
    add("vim.cmd 'highlight clear'")
    add("if vim.fn.exists 'syntax_on' then")
    add("  vim.cmd 'syntax reset'")
    add("end")
    add("")
    add(string.format("vim.g.colors_name = '%s'", name))
    add("vim.o.termguicolors = true")
    add("")

    add("local colors = {")
    add(string.format("  bg_primary = '%s',", colours.bg_primary))
    add(string.format("  fg_primary = '%s',", colours.fg_primary))
    add(string.format("  bg_secondary = '%s',", colours.bg_secondary))
    add(string.format("  fg_secondary = '%s',", colours.fg_secondary))
    add(string.format("  fg_variable = '%s',", colours.fg_variable))
    add(string.format("  purple = '%s',", colours.purple))
    add(string.format("  pink = '%s',", colours.pink))
    add(string.format("  cyan = '%s',", colours.cyan))
    add(string.format("  green = '%s',", colours.green))
    add(string.format("  yellow = '%s',", colours.yellow))
    add(string.format("  red = '%s',", colours.red))
    add("")
    add(string.format("  selection = '%s',", selection_bg))
    add(string.format("  reference = '%s',", selection_bg))
    add(string.format("  comment = '%s',", comment))
    add(string.format("  ghost = '%s',", colour.blend(colours.fg_secondary, colours.bg_primary, 0.40)))
    add(string.format("  punct = '%s',", punct))
    add(string.format("  line_highlight = '%s',", colours.line_highlight))
    add("}")
    add("")

    add("local function hl(group, opts)")
    add("  vim.api.nvim_set_hl(0, group, opts)")
    add("end")
    add("")

    -- editor highlights (fixed mappings)
    local editor = {
        { "Normal", "fg = colors.fg_primary, bg = colors.bg_primary" },
        { "NormalFloat", "fg = colors.fg_primary, bg = colors.bg_secondary" },
        { "FloatBorder", "fg = colors.purple, bg = colors.bg_secondary" },
        { "ColorColumn", "bg = colors.line_highlight" },
        { "Cursor", "fg = colors.bg_primary, bg = colors.fg_primary" },
        { "CursorLine", "bg = colors.line_highlight" },
        { "CursorLineNr", "fg = colors.purple, bold = true" },
        { "LineNr", "fg = colors.comment" },
        { "SignColumn", "bg = colors.bg_primary" },
        { "Visual", "bg = colors.selection" },
        { "VisualNOS", "bg = colors.selection" },
        { "Search", "fg = colors.bg_primary, bg = colors.yellow" },
        { "IncSearch", "fg = colors.bg_primary, bg = colors.pink" },
        { "MatchParen", "fg = colors.green, bold = true" },
        { "Question", "fg = colors.cyan" },
        { "ModeMsg", "fg = colors.green, bold = true" },
        { "MoreMsg", "fg = colors.green" },
        { "ErrorMsg", "fg = colors.red, bold = true" },
        { "WarningMsg", "fg = colors.yellow" },
        { "VertSplit", "fg = colors.bg_secondary" },
        { "WinSeparator", "fg = colors.bg_secondary" },
        { "Folded", "fg = colors.comment, bg = colors.line_highlight" },
        { "FoldColumn", "fg = colors.comment" },
        { "Pmenu", "fg = colors.fg_primary, bg = colors.bg_secondary" },
        { "PmenuSel", "fg = colors.bg_primary, bg = colors.purple" },
        { "PmenuSbar", "bg = colors.bg_secondary" },
        { "PmenuThumb", "bg = colors.purple" },
        { "StatusLine", "fg = colors.purple, bg = colors.bg_secondary" },
        { "StatusLineNC", "fg = colors.comment, bg = colors.bg_secondary" },
        { "TabLine", "fg = colors.fg_secondary, bg = colors.bg_secondary" },
        { "TabLineFill", "bg = colors.bg_secondary" },
        { "TabLineSel", "fg = colors.purple, bg = colors.bg_primary, bold = true" },
        { "Directory", "fg = colors.cyan" },
        { "Title", "fg = colors.pink, bold = true" },
        { "SpecialKey", "fg = colors.comment" },
        { "NonText", "fg = colors.comment" },
        { "Whitespace", "fg = colors.comment" },
    }

    add("-- Editor highlights")
    for _, e in ipairs(editor) do
        add(string.format("hl('%s', { %s })", e[1], e[2]))
    end
    add("")

    -- vim syntax groups (role mapping)
    local syntax = {
        { "Comment", "fg = colors.comment, italic = true" },
        { "Constant", "fg = " .. c.constant },
        { "String", "fg = " .. c.string },
        { "Character", "fg = " .. c.character },
        { "Number", "fg = " .. c.number },
        { "Boolean", "fg = " .. c.boolean },
        { "Float", "fg = " .. c.float },
        { "Identifier", "fg = colors.fg_primary" },
        { "Function", "fg = " .. c.func },
        { "Statement", "fg = " .. c.statement },
        { "Conditional", "fg = " .. c.conditional },
        { "Repeat", "fg = " .. c["repeat"] },
        { "Label", "fg = " .. c.label },
        { "Operator", "fg = " .. c.operator },
        { "Keyword", "fg = " .. c.keyword },
        { "Exception", "fg = " .. c.exception },
        { "PreProc", "fg = " .. c.preproc },
        { "Include", "fg = " .. c.include },
        { "Define", "fg = " .. c.define },
        { "Macro", "fg = " .. c.macro },
        { "PreCondit", "fg = " .. c.precondit },
        { "Type", "fg = " .. c.type },
        { "StorageClass", "fg = " .. c.storageclass },
        { "Structure", "fg = " .. c.structure },
        { "Typedef", "fg = " .. c.typedef },
        { "Special", "fg = " .. c.special },
        { "SpecialChar", "fg = " .. c.specialchar },
        { "Tag", "fg = " .. c.tag },
        { "Delimiter", "fg = colors.punct" },
        { "SpecialComment", "fg = colors.comment, italic = true" },
        { "Debug", "fg = colors.red" },
        { "Underlined", "fg = colors.cyan, underline = true" },
        { "Ignore", "fg = colors.comment" },
        { "Error", "fg = colors.red, bold = true" },
        { "Todo", "fg = colors.pink, bold = true" },
    }

    add("-- Syntax highlighting")
    for _, s in ipairs(syntax) do
        add(string.format("hl('%s', { %s })", s[1], s[2]))
    end
    add("")

    -- git signs, diagnostics, LSP (fixed mappings)
    add("-- Git signs")
    add("hl('GitSignsAdd', { fg = colors.green })")
    add("hl('GitSignsChange', { fg = colors.yellow })")
    add("hl('GitSignsDelete', { fg = colors.red })")
    add("hl('GitSignsTopdelete', { fg = colors.red })")
    add("hl('GitSignsChangedelete', { fg = colors.yellow })")
    add("")
    add("-- Diagnostics")
    add("hl('DiagnosticError', { fg = colors.red })")
    add("hl('DiagnosticWarn', { fg = colors.yellow })")
    add("hl('DiagnosticInfo', { fg = colors.cyan })")
    add("hl('DiagnosticHint', { fg = colors.purple })")
    add("hl('DiagnosticUnderlineError', { undercurl = true, sp = colors.red })")
    add("hl('DiagnosticUnderlineWarn', { undercurl = true, sp = colors.yellow })")
    add("hl('DiagnosticUnderlineInfo', { undercurl = true, sp = colors.cyan })")
    add("hl('DiagnosticUnderlineHint', { undercurl = true, sp = colors.purple })")
    add("")
    add("-- LSP")
    add("hl('LspReferenceText', { bg = colors.reference })")
    add("hl('LspReferenceRead', { bg = colors.reference })")
    add("hl('LspReferenceWrite', { bg = colors.reference })")
    add("")

    -- treesitter groups (role mapping)
    local ts = {
        { "@variable", "fg = colors.fg_primary" }, -- plain text; swap to colors.fg_variable for a subtle tint
        { "@variable.builtin", "fg = colors.red" },
        { "@variable.parameter", "fg = colors.fg_secondary" },
        { "@variable.member", "fg = colors.yellow" },
        { "@constant", "fg = " .. c.constant },
        { "@constant.builtin", "fg = " .. c.constant },
        { "@module", "fg = colors.cyan" },
        { "@string", "fg = " .. c.string },
        { "@string.escape", "fg = " .. c.specialchar },
        { "@string.special", "fg = " .. c.specialchar },
        { "@character", "fg = " .. c.character },
        { "@number", "fg = " .. c.number },
        { "@boolean", "fg = " .. c.boolean },
        { "@function", "fg = " .. c.func },
        { "@function.builtin", "fg = colors.cyan" },
        { "@function.call", "fg = " .. c.func },
        { "@function.macro", "fg = " .. c.macro },
        { "@method", "fg = " .. c.func },
        { "@method.call", "fg = " .. c.func },
        { "@constructor", "fg = " .. c.type },
        { "@keyword", "fg = " .. c.keyword },
        { "@keyword.function", "fg = " .. c.keyword },
        { "@keyword.operator", "fg = " .. c.keyword },
        { "@keyword.return", "fg = " .. c.keyword },
        { "@conditional", "fg = " .. c.conditional },
        { "@repeat", "fg = " .. c["repeat"] },
        { "@label", "fg = " .. c.label },
        { "@operator", "fg = " .. c.operator },
        { "@exception", "fg = " .. c.exception },
        { "@type", "fg = " .. c.type },
        { "@type.builtin", "fg = " .. c.type },
        { "@type.qualifier", "fg = " .. c.keyword },
        { "@property", "fg = colors.yellow" },
        { "@attribute", "fg = colors.red" },
        { "@tag", "fg = " .. c.tag },
        { "@tag.attribute", "fg = colors.yellow" },
        { "@tag.delimiter", "fg = colors.punct" },
        { "@punctuation.delimiter", "fg = colors.punct" },
        { "@punctuation.bracket", "fg = colors.punct" },
        { "@punctuation.special", "fg = " .. c.specialchar },
        { "@comment", nil }, -- link to Comment
        { "@markup.strong", "bold = true" },
        { "@markup.italic", "italic = true" },
        { "@markup.underline", "underline = true" },
        { "@markup.heading", "fg = colors.pink, bold = true" },
        { "@markup.link", "fg = colors.cyan, underline = true" },
        { "@markup.link.url", "fg = colors.purple, underline = true" },
        { "@markup.list", "fg = colors.cyan" },
        { "@markup.raw", "fg = " .. c.string },
    }

    add("-- Treesitter")
    for _, t in ipairs(ts) do
        if t[2] == nil then
            add(string.format("hl('%s', { link = 'Comment' })", t[1]))
        else
            add(string.format("hl('%s', { %s })", t[1], t[2]))
        end
    end
    add("")

    -- plugin highlights
    add("-- Telescope")
    add("hl('TelescopeBorder', { fg = colors.purple, bg = colors.bg_secondary })")
    add("hl('TelescopePromptBorder', { fg = colors.pink, bg = colors.bg_secondary })")
    add("hl('TelescopePromptTitle', { fg = colors.pink, bold = true })")
    add("hl('TelescopePreviewTitle', { fg = colors.purple, bold = true })")
    add("hl('TelescopeResultsTitle', { fg = colors.purple, bold = true })")
    add("hl('TelescopeSelection', { fg = colors.purple, bg = colors.reference, bold = true })")
    add("hl('TelescopeMatching', { fg = colors.green, bold = true })")
    add("")
    add("-- Neo-tree")
    add("hl('NeoTreeNormal', { fg = colors.fg_primary, bg = colors.bg_secondary })")
    add("hl('NeoTreeNormalNC', { fg = colors.fg_primary, bg = colors.bg_secondary })")
    add(string.format("hl('NeoTreeCursorLine', { bg = '%s' })", neotree_cursor))
    add("hl('NeoTreeDirectoryIcon', { fg = colors.cyan })")
    add("hl('NeoTreeDirectoryName', { fg = colors.cyan })")
    add("hl('NeoTreeFileName', { fg = colors.fg_primary })")
    add("hl('NeoTreeFileNameOpened', { fg = colors.pink })")
    add("hl('NeoTreeGitModified', { fg = colors.yellow })")
    add("hl('NeoTreeGitAdded', { fg = colors.green })")
    add("hl('NeoTreeGitDeleted', { fg = colors.red })")
    add("hl('NeoTreeIndentMarker', { fg = colors.comment })")
    add("hl('NeoTreeRootName', { fg = colors.pink, bold = true })")
    add("")
    add("-- Which-key")
    add("hl('WhichKey', { fg = colors.cyan })")
    add("hl('WhichKeyGroup', { fg = colors.pink })")
    add("hl('WhichKeyDesc', { fg = colors.fg_primary })")
    add("hl('WhichKeySeparator', { fg = colors.comment })")
    add("")
    add("-- Mini.nvim statusline")
    add("hl('MiniStatuslineModeNormal', { fg = colors.bg_primary, bg = colors.purple, bold = true })")
    add("hl('MiniStatuslineModeInsert', { fg = colors.bg_primary, bg = colors.green, bold = true })")
    add("hl('MiniStatuslineModeVisual', { fg = colors.bg_primary, bg = colors.pink, bold = true })")
    add("hl('MiniStatuslineModeReplace', { fg = colors.bg_primary, bg = colors.red, bold = true })")
    add("hl('MiniStatuslineModeCommand', { fg = colors.bg_primary, bg = colors.yellow, bold = true })")
    add("hl('MiniStatuslineDevinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })")
    add("hl('MiniStatuslineFilename', { fg = colors.fg_primary, bg = colors.bg_secondary })")
    add("hl('MiniStatuslineFileinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })")
    add("hl('MiniStatuslineInactive', { fg = colors.comment, bg = colors.bg_secondary })")
    add("")
    add("-- Copilot")
    add("hl('CopilotSuggestion', { fg = colors.ghost, italic = true })")
    add("")
    add("-- Indent-blankline")
    add("hl('IblIndent', { fg = colors.line_highlight })")
    add("hl('IblScope', { fg = colors.purple })")
    add("")
    add("-- Neotest")
    add("hl('NeotestPassed', { fg = colors.green })")
    add("hl('NeotestFailed', { fg = colors.red })")
    add("hl('NeotestRunning', { fg = colors.yellow })")
    add("hl('NeotestSkipped', { fg = colors.comment })")
    add("hl('NeotestTest', { fg = colors.fg_primary })")
    add("hl('NeotestNamespace', { fg = colors.cyan })")
    add("hl('NeotestFile', { fg = colors.cyan })")
    add("hl('NeotestDir', { fg = colors.cyan })")
    add("hl('NeotestAdapterName', { fg = colors.purple, bold = true })")
    add("hl('NeotestBorder', { fg = colors.purple })")
    add("hl('NeotestIndent', { fg = colors.comment })")
    add("hl('NeotestFocused', { bold = true, underline = true })")
    add("hl('NeotestMarked', { fg = colors.pink, bold = true })")
    add("hl('NeotestWinSelect', { fg = colors.purple, bold = true })")
    add("")
    add("-- Flash")
    add("hl('FlashBackdrop', { fg = colors.comment })")
    add("hl('FlashLabel', { fg = colors.bg_primary, bg = colors.pink, bold = true })")
    add("hl('FlashMatch', { fg = colors.bg_primary, bg = colors.yellow })")
    add("hl('FlashCurrent', { fg = colors.bg_primary, bg = colors.green })")
    add("")
    add("-- Fidget")
    add("hl('FidgetTitle', { fg = colors.purple, bold = true })")
    add("hl('FidgetTask', { fg = colors.comment })")

    return table.concat(lines, "\n") .. "\n"
end

-- ══════════════════════════════════════════════════════════════
-- Display Name Derivation
-- ══════════════════════════════════════════════════════════════

--- display name from a ghostty theme filename. the name is written into a
--- sourced shell assignment, so only safe display characters are kept
---@param filename string ghostty theme filename (no path)
---@return string display_name
function M.display_name(filename)
    local safe = filename:gsub("[^%w%s%-%_%(%)%.%,]", "")
    safe = safe:gsub('"', "")
    if safe == "" then
        safe = "Unknown Theme"
    end
    return safe
end

--- kebab-case name for file paths: "3024 Night" -> "3024-night"
---@param filename string ghostty theme filename
---@return string kebab name
function M.kebab_name(filename)
    local name = filename:lower()
    name = name:gsub("[^%w]+", "-")
    name = name:gsub("^-+", ""):gsub("-+$", "")
    return name
end

-- ══════════════════════════════════════════════════════════════
-- Main Generation Entry Point
-- ══════════════════════════════════════════════════════════════

--- writes the .theme file and the nvim colourscheme, and prints the theme
--- name on stdout
---@param ghostty_path string path to ghostty theme file
---@param themes_dir string path to themes/generated/ output directory
---@param nvim_dir string path to nvim/colors/generated/ output directory
---@param opts table|nil options: { quiet = bool }
---@return boolean success
---@return string|nil error message
function M.generate(ghostty_path, themes_dir, nvim_dir, opts)
    opts = opts or {}
    local quiet = opts.quiet or false

    local filename = ghostty_path:match("[/\\]([^/\\]+)$") or ghostty_path
    local display = M.display_name(filename)
    local name = M.kebab_name(filename)

    local ghostty, err = M.parse_ghostty_theme(ghostty_path)
    if not ghostty then
        return false, err
    end

    local colours = M.extract_colours(ghostty)

    local adjustments = M.apply_saturation_preference(colours)
    for _, adj in ipairs(M.apply_wcag_corrections(colours)) do
        table.insert(adjustments, adj)
    end

    local active_accent = M.choose_active_accent(colours)

    local status = M.derive_status_colours(colours)

    local theme_content = M.generate_theme_file(name, display, colours, status, active_accent, adjustments)
    local theme_path = themes_dir .. "/" .. name .. ".theme"
    local f = io.open(theme_path, "w")
    if not f then
        return false, "Cannot write: " .. theme_path
    end
    f:write(theme_content)
    f:close()

    local nvim_content = M.generate_nvim_colourscheme(name, colours)
    local nvim_path = nvim_dir .. "/" .. name .. ".lua"
    f = io.open(nvim_path, "w")
    if not f then
        return false, "Cannot write: " .. nvim_path
    end
    f:write(nvim_content)
    f:close()

    if not quiet then
        io.stderr:write(string.format("Generated: %s\n", theme_path))
        io.stderr:write(string.format("Generated: %s\n", nvim_path))
        if #adjustments > 0 then
            io.stderr:write("WCAG adjustments:\n")
            for _, adj in ipairs(adjustments) do
                io.stderr:write("  " .. format_adjustment(adj) .. "\n")
            end
        end
    end

    io.write(name)

    return true, nil
end

-- ══════════════════════════════════════════════════════════════
-- CLI Entry Point (when run as script)
-- ══════════════════════════════════════════════════════════════

-- true only when executed directly, not when required as a module
if not pcall(debug.getlocal, 4, 1) then
    local ghostty_path = arg[1]
    local themes_dir = arg[2]
    local nvim_dir = arg[3]
    local quiet = arg[4] == "--quiet"

    if not ghostty_path or not themes_dir or not nvim_dir then
        io.stderr:write(
            "Usage: lua generate-theme.lua <ghostty-theme-path> <themes-generated-dir> <nvim-colors-generated-dir> [--quiet]\n"
        )
        os.exit(1)
    end

    local ok, err = M.generate(ghostty_path, themes_dir, nvim_dir, { quiet = quiet })
    if not ok then
        io.stderr:write("Error: " .. (err or "unknown") .. "\n")
        os.exit(1)
    end
end

return M
