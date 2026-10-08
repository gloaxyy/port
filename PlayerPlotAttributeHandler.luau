-- ============================================================
-- PlayerPlotAttributeHandler
-- Ensures player's plot attribute is restored after respawn
-- ============================================================

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ServerScriptService:WaitForChild("Modules")
local PlotManager = require(Modules:WaitForChild("PlotManager"))

-- Track player plot assignments
local PlayerPlots = {}

-- Listen for new players
Players.PlayerAdded:Connect(function(player)
	-- Listen for character spawns (including respawns)
	player.CharacterAdded:Connect(function(character)
		-- Wait a moment for everything to load
		task.wait(0.5)
		
		-- Get the player's plot number from PlotManager
		local plotNumber = PlotManager.GetPlotNumber(player)
		
		if plotNumber then
			-- Restore the player's plot attribute
			player:SetAttribute("PlayerPlot", plotNumber)
			print("[PlayerPlotAttributeHandler] Restored plot " .. plotNumber .. " for " .. player.Name .. " after respawn")
		end
	end)
end)

print("[PlayerPlotAttributeHandler] Initialized")