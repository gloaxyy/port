-- ===== KEYCARD SYSTEM =====
-- Players automatically receive keycards based on their XP.
-- XP thresholds are configured in ReplicatedStorage.SCPConfig (Config.KeycardLevels)
-- Level 2 = 50 XP, Level 3 = 100 XP, Level 4 = 200 XP, Level 5 = 250 XP (editable in config)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("SCPConfig"))
local teamSelectEvent = ReplicatedStorage:WaitForChild("TeamSelectEvent")

local templatesFolder = ServerStorage:WaitForChild("KeycardTemplates")

-- Team-based keycard overrides: certain teams always get a specific keycard
-- level (or none at all), regardless of XP. nil means "use XP-based logic".
local TEAM_KEYCARD_OVERRIDES = {
	["Class-D"] = 0,                       -- No keycard
	["Neutral"] = 0,                       -- No keycard
	["Rapid Response Team"] = 5,           -- Max level
	["Internal Security Department"] = 5,  -- Max level
	["Intelligence Agency"] = 5,          -- Max level
	["Chaos Insurgency"] = 5,             -- Max level
	["Nu-7"] = 5,                          -- Max level
	["Security Department"] = 5,          -- Max level
	["Scientific Department"] = 5,         -- Max level
}

local function getLevelForXP(xp)
	local bestLevel = 1
	for _, entry in ipairs(Config.KeycardLevels) do
		if xp >= entry.xpRequired and entry.level > bestLevel then
			bestLevel = entry.level
		end
	end
	return bestLevel
end

local function getTemplate(level)
	for _, tool in ipairs(templatesFolder:GetChildren()) do
		if tool:IsA("Tool") and tool:GetAttribute("KeycardLevel") == level then
			return tool
		end
	end
	return nil
end

local function isKeycard(tool)
	return tool:IsA("Tool") and tool:GetAttribute("KeycardLevel") ~= nil
end

local function hasKeycard(player, level)
	local containers = {}
	local backpack = player:FindFirstChild("Backpack")
	if backpack then table.insert(containers, backpack) end
	if player.Character then table.insert(containers, player.Character) end

	for _, container in ipairs(containers) do
		for _, item in ipairs(container:GetChildren()) do
			if isKeycard(item) and item:GetAttribute("KeycardLevel") == level then
				return true
			end
		end
	end
	return false
end

local function getTeamKeycardLevel(player)
	local team = player.Team
	if not team then return nil end
	return TEAM_KEYCARD_OVERRIDES[team.Name]
end

local function removeAllKeycards(player)
	local containers = {}
	local backpack = player:FindFirstChild("Backpack")
	if backpack then table.insert(containers, backpack) end
	if player.Character then table.insert(containers, player.Character) end

	for _, container in ipairs(containers) do
		for _, item in ipairs(container:GetChildren()) do
			if isKeycard(item) then
				item:Destroy()
			end
		end
	end
end

local function giveKeycard(player, level)
	local template = getTemplate(level)
	if not template then
		warn("[KeycardSystem] Missing keycard template for level " .. tostring(level))
		return false
	end

	local function removeOutdatedCards(container)
		if not container then return end
		for _, item in ipairs(container:GetChildren()) do
			if isKeycard(item) and item:GetAttribute("KeycardLevel") ~= level then
				item:Destroy()
			end
		end
	end

	-- FIX: The Backpack is destroyed and recreated on every respawn (LoadCharacter),
	-- so parenting a card can race with the respawn and the card gets destroyed
	-- with the old backpack. Retry a few times and verify the card actually
	-- landed in the player's CURRENT backpack.
	for _ = 1, 4 do
		if not player.Parent then return false end

		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			removeOutdatedCards(backpack)
			removeOutdatedCards(player.Character)

			if hasKeycard(player, level) then
				return true
			end

			local tool = template:Clone()
			tool.Parent = backpack

			-- Verify the card survived (backpack may have been swapped mid-operation)
			if tool.Parent == backpack and player:FindFirstChild("Backpack") == backpack then
				return true
			end

			tool:Destroy()
		end

		task.wait(0.15)
	end

	return hasKeycard(player, level)
end

local function updateKeycard(player, xp, notify)
	-- Team-based override: certain teams always get a fixed keycard level (or none)
	local teamLevel = getTeamKeycardLevel(player)

	if teamLevel == 0 then
		-- Class-D: remove all keycards, never give one
		removeAllKeycards(player)
		player:SetAttribute("KeycardLevel", 0)
		return
	end

	if teamLevel ~= nil then
		-- Override team: always give the team's fixed keycard level
		local previous = player:GetAttribute("KeycardLevel")
		if hasKeycard(player, teamLevel) and previous == teamLevel then return end
		if not giveKeycard(player, teamLevel) then return end
		player:SetAttribute("KeycardLevel", teamLevel)

		if notify and previous ~= nil and teamLevel > (tonumber(previous) or 0) then
			teamSelectEvent:FireClient(player, "keycard", {level = teamLevel})
		end
		return
	end

	-- No team override: fall back to XP-based logic
	-- Level 1 is free for everyone: give it immediately, even before saved XP
	-- finishes loading from the DataStore. No waiting required.
	if player:GetAttribute("XPReady") ~= true then
		if not hasKeycard(player, 1) then
			giveKeycard(player, 1)
		end
		return
	end

	-- FIX: "previous" is nil until the first successful sync after joining.
	-- We only notify on genuine level-ups DURING play, never on the initial
	-- load of saved XP. This removes the annoying "Keycard Level X" popup
	-- that appeared every time a player joined the game.
	local previous = player:GetAttribute("KeycardLevel")
	local oldLevel = math.max(1, tonumber(previous) or 1)
	local newLevel = math.max(getLevelForXP(xp), oldLevel)
	local alreadyHasCard = hasKeycard(player, newLevel)

	if newLevel == oldLevel and alreadyHasCard then return end
	if not giveKeycard(player, newLevel) then return end

	player:SetAttribute("KeycardLevel", newLevel)

	if notify and previous ~= nil and newLevel > oldLevel then
		teamSelectEvent:FireClient(player, "keycard", {level = newLevel})
	end
end

local function watchXP(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		local conn
		conn = player.ChildAdded:Connect(function(child)
			if child.Name == "leaderstats" then
				conn:Disconnect()
				watchXP(player)
			end
		end)
		return
	end

	local xp = leaderstats:FindFirstChild("XP")
	if not xp then
		local conn
		conn = leaderstats.ChildAdded:Connect(function(child)
			if child.Name == "XP" then
				conn:Disconnect()
				watchXP(player)
			end
		end)
		return
	end

	local function refreshKeycard(notify)
		if player:GetAttribute("XPReady") ~= true then return end
		updateKeycard(player, xp.Value, notify)
	end

	xp.Changed:Connect(function()
		refreshKeycard(true)
	end)
	player:GetAttributeChangedSignal("XPReady"):Connect(function()
		refreshKeycard(false)
	end)
	refreshKeycard(false)
end

local function watchCharacter(player)
	player.CharacterAdded:Connect(function()
		task.spawn(function()
			local teamLevel = getTeamKeycardLevel(player)

			if teamLevel == 0 then
				-- Class-D: no keycard on spawn
				removeAllKeycards(player)
				return
			end

			if teamLevel ~= nil then
				-- Override team: give the team's fixed keycard level
				giveKeycard(player, teamLevel)

				-- Re-check shortly after spawn (backpack may be recreated)
				task.wait(1)
				if player.Parent and player.Character then
					if not hasKeycard(player, teamLevel) then
						giveKeycard(player, teamLevel)
					end
				end
				return
			end

			-- No team override: use XP-based logic
			local level = player:GetAttribute("KeycardLevel")
			if typeof(level) ~= "number" then
				local leaderstats = player:FindFirstChild("leaderstats")
				local xp = leaderstats and leaderstats:FindFirstChild("XP")
				level = getLevelForXP(xp and xp.Value or 0)
			end

			giveKeycard(player, level)

			-- FIX: Re-check shortly after spawn. The backpack can be recreated
			-- during respawn, which can silently swallow the keycard.
			task.wait(1)
			if player.Parent and player.Character then
				local currentLevel = player:GetAttribute("KeycardLevel")
				if typeof(currentLevel) == "number" and not hasKeycard(player, currentLevel) then
					giveKeycard(player, currentLevel)
				end
			end
		end)
	end)
end

local function onPlayerAdded(player)
	watchXP(player)
	watchCharacter(player)

	-- Watch for team changes and update keycard accordingly
	player:GetPropertyChangedSignal("Team"):Connect(function()
		local leaderstats = player:FindFirstChild("leaderstats")
		local xp = leaderstats and leaderstats:FindFirstChild("XP")
		updateKeycard(player, xp and xp.Value or 0, true)
	end)

	-- If the character already spawned before we connected, give the card now
	if player.Character then
		task.spawn(function()
			local teamLevel = getTeamKeycardLevel(player)

			if teamLevel == 0 then
				removeAllKeycards(player)
				return
			end

			if teamLevel ~= nil then
				giveKeycard(player, teamLevel)
				player:SetAttribute("KeycardLevel", teamLevel)
				return
			end

			local level = player:GetAttribute("KeycardLevel")
			if typeof(level) ~= "number" then
				local leaderstats = player:FindFirstChild("leaderstats")
				local xp = leaderstats and leaderstats:FindFirstChild("XP")
				level = getLevelForXP(xp and xp.Value or 0)
			end
			giveKeycard(player, level)
		end)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end