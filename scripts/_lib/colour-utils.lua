-- Colour utility library for theme generation
-- Provides hex<->HSL conversion, WCAG 2.1 contrast ratio, lightness adjustment

local M = {}

--- Parse hex colour string to RGB (0-255)
---@param hex string e.g. "#ff5555" or "ff5555"
---@return number r, number g, number b
function M.hex_to_rgb(hex)
  hex = hex:gsub('^#', '')
  if not hex:match('^%x%x%x%x%x%x$') then
    error('Invalid hex colour: #' .. hex)
  end
  local r = tonumber(hex:sub(1, 2), 16)
  local g = tonumber(hex:sub(3, 4), 16)
  local b = tonumber(hex:sub(5, 6), 16)
  return r, g, b
end

--- Convert RGB (0-255) to hex string
---@param r number
---@param g number
---@param b number
---@return string hex e.g. "#ff5555"
function M.rgb_to_hex(r, g, b)
  local function clamp(v) return math.max(0, math.min(255, math.floor(v + 0.5))) end
  return string.format('#%02x%02x%02x', clamp(r), clamp(g), clamp(b))
end

--- Convert RGB (0-255) to HSL (h: 0-360, s: 0-1, l: 0-1)
---@param r number
---@param g number
---@param b number
---@return number h, number s, number l
function M.rgb_to_hsl(r, g, b)
  r, g, b = r / 255, g / 255, b / 255
  local max = math.max(r, g, b)
  local min = math.min(r, g, b)
  local h, s
  local l = (max + min) / 2

  if max == min then
    h, s = 0, 0
  else
    local d = max - min
    s = l > 0.5 and d / (2 - max - min) or d / (max + min)
    if max == r then
      h = (g - b) / d + (g < b and 6 or 0)
    elseif max == g then
      h = (b - r) / d + 2
    else
      h = (r - g) / d + 4
    end
    h = h * 60
  end

  return h, s, l
end

--- Convert HSL to RGB (0-255)
---@param h number 0-360
---@param s number 0-1
---@param l number 0-1
---@return number r, number g, number b
function M.hsl_to_rgb(h, s, l)
  if s == 0 then
    local v = math.floor(l * 255 + 0.5)
    return v, v, v
  end

  local function hue_to_rgb(p, q, t)
    if t < 0 then t = t + 1 end
    if t > 1 then t = t - 1 end
    if t < 1 / 6 then return p + (q - p) * 6 * t end
    if t < 1 / 2 then return q end
    if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
    return p
  end

  local q = l < 0.5 and l * (1 + s) or l + s - l * s
  local p = 2 * l - q
  local hn = h / 360

  local r = hue_to_rgb(p, q, hn + 1 / 3) * 255
  local g = hue_to_rgb(p, q, hn) * 255
  local b = hue_to_rgb(p, q, hn - 1 / 3) * 255

  return r, g, b
end

--- Convert hex to HSL
---@param hex string
---@return number h, number s, number l
function M.hex_to_hsl(hex)
  return M.rgb_to_hsl(M.hex_to_rgb(hex))
end

--- Convert HSL to hex
---@param h number
---@param s number
---@param l number
---@return string hex
function M.hsl_to_hex(h, s, l)
  return M.rgb_to_hex(M.hsl_to_rgb(h, s, l))
end

--- Linearise an sRGB channel value (0-1) to linear RGB
---@param channel number 0-1
---@return number linear value
function M.linearise(channel)
  if channel <= 0.04045 then
    return channel / 12.92
  else
    return ((channel + 0.055) / 1.055) ^ 2.4
  end
end

--- Calculate relative luminance per WCAG 2.1
---@param hex string
---@return number luminance 0-1
function M.luminance(hex)
  local r, g, b = M.hex_to_rgb(hex)
  local rl = M.linearise(r / 255)
  local gl = M.linearise(g / 255)
  local bl = M.linearise(b / 255)
  return 0.2126 * rl + 0.7152 * gl + 0.0722 * bl
end

--- Calculate WCAG 2.1 contrast ratio between two colours
---@param hex1 string
---@param hex2 string
---@return number ratio e.g. 4.52
function M.contrast_ratio(hex1, hex2)
  local l1 = M.luminance(hex1)
  local l2 = M.luminance(hex2)
  local lighter = math.max(l1, l2)
  local darker = math.min(l1, l2)
  return (lighter + 0.05) / (darker + 0.05)
end

--- Adjust lightness of a colour to meet a minimum contrast ratio against a background
--- Preserves hue and saturation. Moves lightness up or down depending on whether
--- the foreground is lighter or darker than the background.
---@param fg_hex string foreground colour to adjust
---@param bg_hex string background colour (fixed)
---@param min_ratio number minimum contrast ratio (e.g. 4.5)
---@return string adjusted_hex, number adjustments_made (lightness delta percentage)
function M.ensure_contrast(fg_hex, bg_hex, min_ratio)
  local ratio = M.contrast_ratio(fg_hex, bg_hex)
  if ratio >= min_ratio then
    return fg_hex, 0
  end

  local h, s, l = M.hex_to_hsl(fg_hex)
  local bg_l = select(3, M.hex_to_hsl(bg_hex))
  local original_l = l

  -- Determine direction: lighten if fg is lighter than bg, darken if darker
  -- (For dark themes, fg is lighter; for light themes, fg is darker)
  local step = 0.01
  local direction = (l >= bg_l) and 1 or -1

  for _ = 1, 95 do
    l = l + step * direction
    if l > 0.97 or l < 0.03 then break end

    local candidate = M.hsl_to_hex(h, s, l)
    ratio = M.contrast_ratio(candidate, bg_hex)
    if ratio >= min_ratio then
      local delta = math.abs(l - original_l) * 100
      return candidate, delta
    end
  end

  -- If we couldn't reach the ratio, return the best we got
  return M.hsl_to_hex(h, s, l), math.abs(l - original_l) * 100
end

--- Lighten a hex colour by a percentage in HSL space
---@param hex string
---@param percent number e.g. 8 for 8%
---@return string adjusted hex
function M.lighten(hex, percent)
  local h, s, l = M.hex_to_hsl(hex)
  l = math.min(1, l + percent / 100)
  return M.hsl_to_hex(h, s, l)
end

--- Darken a hex colour by a percentage in HSL space
--- Currently unused by generate-theme.lua; available for future extensions.
---@param hex string
---@param percent number e.g. 8 for 8%
---@return string adjusted hex
function M.darken(hex, percent)
  local h, s, l = M.hex_to_hsl(hex)
  l = math.max(0, l - percent / 100)
  return M.hsl_to_hex(h, s, l)
end

--- Blend two colours by a ratio (0 = colour1, 1 = colour2)
---@param hex1 string
---@param hex2 string
---@param ratio number 0-1
---@return string blended hex
function M.blend(hex1, hex2, ratio)
  local r1, g1, b1 = M.hex_to_rgb(hex1)
  local r2, g2, b2 = M.hex_to_rgb(hex2)
  local r = r1 + (r2 - r1) * ratio
  local g = g1 + (g2 - g1) * ratio
  local b = b1 + (b2 - b1) * ratio
  return M.rgb_to_hex(r, g, b)
end

return M
