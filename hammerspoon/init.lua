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
}

for _, appName in ipairs(centredApps) do
	hs.window.filter.new(appName):subscribe(hs.window.filter.windowCreated, function(window)
		-- Hide immediately
		window:setAlpha(0)

		-- Wait for app to finish setting up window
		hs.timer.doAfter(0.5, function()
			if not window or not window:isVisible() then return end

			local sf = window:screen():frame()
			local newW = sf.w * 0.7
			local newH = sf.h * 0.7

			window:setSize(newW, newH)
			window:centerOnScreen()
			window:setAlpha(1)
		end)
	end)
end

-- Reload config notification
hs.alert.show("Hammerspoon config loaded")
