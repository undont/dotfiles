-- Hammerspoon configuration

-- Enable CLI (hs command)
require("hs.ipc")

-- Apps to auto-centre when windows are created
local centredApps = {
    "Ghostty",
    "Arc",
    "Dia",
    "GoLand",
    "WebStorm",
    "PyCharm",
    "Rider",
    "Discord",
    "Slack",
    "Notion",
}

-- Store filters to prevent garbage collection
local windowFilters = {}

for _, appName in ipairs(centredApps) do
    local filter = hs.window.filter.new(appName)
    filter:subscribe(hs.window.filter.windowCreated, function(window)
        print("Window created for: " .. appName)

        -- Wait for app to finish setting up window
        hs.timer.doAfter(0.1, function()
            if not window or not window:isVisible() then
                print("Window no longer valid or visible: " .. appName)
                return
            end

            -- Check if window has a valid screen
            local screen = window:screen()
            if not screen then
                print("No screen found for window: " .. appName)
                return
            end

            local sf = screen:frame()
            local currentFrame = window:frame()

            -- Calculate window and screen centers
            local windowCenterX = currentFrame.x + (currentFrame.w / 2)
            local windowCenterY = currentFrame.y + (currentFrame.h / 2)
            local screenCenterX = sf.x + (sf.w / 2)
            local screenCenterY = sf.y + (sf.h / 2)

            -- Skip if window is already centered (within 50px tolerance)
            local isAlreadyCentered = math.abs(windowCenterX - screenCenterX) < 50
                and math.abs(windowCenterY - screenCenterY) < 50

            if isAlreadyCentered then
                print("Window already centred, skipping: " .. appName)
                return
            end

            local newW = sf.w * 0.7
            local newH = sf.h * 0.7

            print("Centring window for: " .. appName .. " (size: " .. newW .. "x" .. newH .. ")")
            window:setSize(newW, newH)
            window:centerOnScreen()
        end)
    end)
    table.insert(windowFilters, filter)
end

-- Reload config notification
hs.alert.show("Hammerspoon config loaded")

-- Load personal local overrides if present (survives dotfiles update)
pcall(require, "local")
