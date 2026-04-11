#!/usr/bin/env lua
-- Unit tests for scripts/_lib/colour-utils.lua

-- Setup LUA_PATH to find the module
local script_dir = arg[0]:match("(.*/)")
package.path = script_dir .. "../_lib/?.lua;" .. package.path

local colour = require("colour-utils")

local pass_count = 0
local fail_count = 0

local function pass(desc)
    pass_count = pass_count + 1
    io.write(string.format("\027[0;32m✓\027[0m %s\n", desc))
end

local function fail(desc, detail)
    fail_count = fail_count + 1
    io.write(string.format("\027[0;31m✗\027[0m %s", desc))
    if detail then
        io.write(string.format(" (%s)", detail))
    end
    io.write("\n")
end

local function section(name)
    io.write(
        string.format(
            "\n─────────────────────────────────────────\n%s\n─────────────────────────────────────────\n",
            name
        )
    )
end

local function approx(a, b, tolerance)
    return math.abs(a - b) < (tolerance or 0.01)
end

-- ═══════════════════════════════════════════════
section("hex_to_rgb")

local r, g, b = colour.hex_to_rgb("#ff5555")
if r == 255 and g == 85 and b == 85 then
    pass("parses #ff5555")
else
    fail("parses #ff5555", string.format("got %d,%d,%d", r, g, b))
end

r, g, b = colour.hex_to_rgb("282a36")
if r == 40 and g == 42 and b == 54 then
    pass("parses without hash")
else
    fail("parses without hash", string.format("got %d,%d,%d", r, g, b))
end

r, g, b = colour.hex_to_rgb("#000000")
if r == 0 and g == 0 and b == 0 then
    pass("parses black")
else
    fail("parses black")
end

r, g, b = colour.hex_to_rgb("#ffffff")
if r == 255 and g == 255 and b == 255 then
    pass("parses white")
else
    fail("parses white")
end

-- Invalid input
local ok, err = pcall(colour.hex_to_rgb, "#gggggg")
if not ok then
    pass("rejects invalid hex")
else
    fail("should reject invalid hex")
end

ok, err = pcall(colour.hex_to_rgb, "#ff")
if not ok then
    pass("rejects short hex")
else
    fail("should reject short hex")
end

-- ═══════════════════════════════════════════════
section("rgb_to_hex")

if colour.rgb_to_hex(255, 85, 85) == "#ff5555" then
    pass("converts to hex")
else
    fail("converts to hex", colour.rgb_to_hex(255, 85, 85))
end

if colour.rgb_to_hex(0, 0, 0) == "#000000" then
    pass("converts black")
else
    fail("converts black")
end

if colour.rgb_to_hex(255, 255, 255) == "#ffffff" then
    pass("converts white")
else
    fail("converts white")
end

-- ═══════════════════════════════════════════════
section("RGB <-> HSL round-trip")

-- Round-trip: hex -> rgb -> hsl -> rgb -> hex
local function round_trip(hex)
    local r1, g1, b1 = colour.hex_to_rgb(hex)
    local h, s, l = colour.rgb_to_hsl(r1, g1, b1)
    local r2, g2, b2 = colour.hsl_to_rgb(h, s, l)
    return colour.rgb_to_hex(r2, g2, b2)
end

local test_colours = {
    "#ff5555",
    "#50fa7b",
    "#8be9fd",
    "#caa8fa",
    "#282a36",
    "#f8f8f2",
    "#000000",
    "#ffffff",
    "#808080",
}
for _, hex in ipairs(test_colours) do
    local result = round_trip(hex)
    if result == hex then
        pass("round-trip " .. hex)
    else
        fail("round-trip " .. hex, "got " .. result)
    end
end

-- Grey (s=0 path)
local h, s, l = colour.rgb_to_hsl(128, 128, 128)
if s == 0 then
    pass("grey has zero saturation")
else
    fail("grey saturation", tostring(s))
end

-- ═══════════════════════════════════════════════
section("luminance (WCAG 2.1)")

-- Known reference values
if approx(colour.luminance("#ffffff"), 1.0) then
    pass("white luminance = 1.0")
else
    fail("white luminance", tostring(colour.luminance("#ffffff")))
end

if approx(colour.luminance("#000000"), 0.0) then
    pass("black luminance = 0.0")
else
    fail("black luminance", tostring(colour.luminance("#000000")))
end

-- Mid-grey ~0.2159
local grey_lum = colour.luminance("#808080")
if approx(grey_lum, 0.2159, 0.01) then
    pass("mid-grey luminance ~0.216")
else
    fail("mid-grey luminance", tostring(grey_lum))
end

-- ═══════════════════════════════════════════════
section("contrast_ratio (WCAG 2.1)")

local ratio = colour.contrast_ratio("#ffffff", "#000000")
if approx(ratio, 21.0, 0.1) then
    pass("white/black contrast = 21:1")
else
    fail("white/black contrast", tostring(ratio))
end

ratio = colour.contrast_ratio("#000000", "#000000")
if approx(ratio, 1.0) then
    pass("same colour contrast = 1:1")
else
    fail("same colour contrast", tostring(ratio))
end

-- Order independence
local r1 = colour.contrast_ratio("#ff5555", "#282a36")
local r2 = colour.contrast_ratio("#282a36", "#ff5555")
if approx(r1, r2) then
    pass("contrast_ratio is symmetric")
else
    fail("contrast_ratio symmetric", string.format("%.2f vs %.2f", r1, r2))
end

-- ═══════════════════════════════════════════════
section("ensure_contrast")

-- Already meets ratio — should return unchanged
local adjusted, delta = colour.ensure_contrast("#ffffff", "#000000", 4.5)
if delta == 0 and adjusted == "#ffffff" then
    pass("already-meeting returns unchanged")
else
    fail("already-meeting", string.format("delta=%.1f", delta))
end

-- Low contrast — should adjust
adjusted, delta = colour.ensure_contrast("#555555", "#282a36", 4.5)
local new_ratio = colour.contrast_ratio(adjusted, "#282a36")
if new_ratio >= 4.5 then
    pass("low-contrast adjusted to meet 4.5:1")
else
    fail("low-contrast adjustment", string.format("ratio=%.2f", new_ratio))
end

if delta > 0 then
    pass("reports positive delta for adjustment")
else
    fail("delta should be positive")
end

-- ═══════════════════════════════════════════════
section("lighten / darken")

local lighter = colour.lighten("#808080", 10)
local _, _, ll = colour.hex_to_hsl(lighter)
local _, _, orig_l = colour.hex_to_hsl("#808080")
if ll > orig_l then
    pass("lighten increases lightness")
else
    fail("lighten increases lightness")
end

local darker = colour.darken("#808080", 10)
local _, _, dl = colour.hex_to_hsl(darker)
if dl < orig_l then
    pass("darken decreases lightness")
else
    fail("darken decreases lightness")
end

-- Clamping
local max_light = colour.lighten("#ffffff", 50)
if max_light == "#ffffff" then
    pass("lighten clamps at white")
else
    fail("lighten clamp", max_light)
end

local max_dark = colour.darken("#000000", 50)
if max_dark == "#000000" then
    pass("darken clamps at black")
else
    fail("darken clamp", max_dark)
end

-- ═══════════════════════════════════════════════
section("blend")

if colour.blend("#000000", "#ffffff", 0) == "#000000" then
    pass("blend ratio=0 returns first")
else
    fail("blend ratio=0")
end

if colour.blend("#000000", "#ffffff", 1) == "#ffffff" then
    pass("blend ratio=1 returns second")
else
    fail("blend ratio=1")
end

local mid = colour.blend("#000000", "#ffffff", 0.5)
if mid == "#808080" or mid == "#7f7f7f" then
    pass("blend ratio=0.5 gives mid-grey")
else
    fail("blend ratio=0.5", mid)
end

-- ═══════════════════════════════════════════════
-- Summary
io.write(string.format("\n===========================================\n"))
io.write(
    string.format("Test Results: \027[0;32m%d passed\027[0m, \027[0;31m%d failed\027[0m\n", pass_count, fail_count)
)
io.write(string.format("===========================================\n"))

os.exit(fail_count > 0 and 1 or 0)
