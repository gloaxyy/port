local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

local speedStore = DataStoreService:GetDataStore("TreadmillSpeed_V1")

local treadmillsFolder = workspace:WaitForChild("Treadmills")
local treadmillExit = ReplicatedStorage:WaitForChild("TreadmillExit")
local speedGainEffect = ReplicatedStorage:WaitForChild("SpeedGainEffect")
local tpOff = workspace:FindFirstChild("TPoff")
local tpOff2 = workspace:FindFirstChild("TPoff2")
local tpOff3 = workspace:FindFirstChild("TPoff3")

if not tpOff then
	warn("[Treadmillsystem] TPoff not found in Workspace - creating a default")
	tpOff = Instance.new("Part")
	tpOff.Name = "TPoff"
	tpOff.Size = Vector3.new(6, 1, 6)
	tpOff.Position = Vector3.new(140, 0.5, -394)
	tpOff.Anchored = true
	tpOff.CanCollide = false
	tpOff.Transparency = 1
	tpOff.Parent = workspace
end

if not tpOff2 then
	warn("[Treadmillsystem] TPoff2 not found in Workspace - creating a default")
	tpOff2 = Instance.new("Part")
	tpOff2.Name = "TPoff2"
	tpOff2.Size = Vector3.new(6, 1, 6)
	tpOff2.Position = Vector3.new(140, 0.5, -421)
	tpOff2.Anchored = true
	tpOff2.CanCollide = false
	tpOff2.Transparency = 1
	tpOff2.Parent = workspace
end

if not tpOff3 then
	warn("[Treadmillsystem] TPoff3 not found in Workspace - creating a default")
	tpOff3 = Instance.new("Part")
	tpOff3.Name = "TPoff3"
	tpOff3.Size = Vector3.new(6, 1, 6)
	tpOff3.Position = Vector3.new(140, 0.5, -448)
	tpOff3.Anchored = true
	tpOff3.CanCollide = false
	tpOff3.Transparency = 1
	tpOff3.Parent = workspace
end

-- SETTINGS
local START_SPEED = 16

local NORMAL_GAIN = 0.5
local GOLD_GAIN = 5.0
local DIAMOND_GAIN = 7.0
local ADMIN_GAIN = 1000000 -- Admin Treadmill (spawned/banked by admins)

local CHECK_INTERVAL = 0.1

local playerTreadmill = {}
local checkTimer = 0

-- Max multiplier above WalkSpeed that velocity is allowed to reach before clamping.
-- This prevents collision spikes from launching players at high speed.
local VELOCITY_CLAMP_MARGIN = 1.25

-- Hard cap on how fast the character can actually MOVE. The "Speed" attribute
-- (what the HUD shows) keeps growing past this, but the real WalkSpeed and
-- velocity are capped so extreme speeds can't fling the player.
local MAX_MOVE_SPEED = 500

local function getMoveSpeed(player)
	return math.min(player:GetAttribute("Speed") or START_SPEED, MAX_MOVE_SPEED)
end

--------------------------------------------------
-- PLAYER SETUP
--------------------------------------------------

local function setupPlayer(player)
	-- Load saved speed from DataStore
	local savedSpeed
	local success = pcall(function()
		savedSpeed = speedStore:GetAsync(player.UserId)
	end)

	if success and savedSpeed then
		player:SetAttribute("Speed", math.max(savedSpeed, START_SPEED))
	else
		player:SetAttribute("Speed", START_SPEED)
	end

	player:SetAttribute("OnTreadmill", false)
	player:SetAttribute("TreadmillName", "")

	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")

		humanoid.WalkSpeed = getMoveSpeed(player)

		player:SetAttribute("OnTreadmill", false)
		player:SetAttribute("TreadmillName", "")

		playerTreadmill[player] = nil
	end)
end

Players.PlayerAdded:Connect(setupPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

local function saveSpeed(player)
	local currentSpeed = player:GetAttribute("Speed")
	if currentSpeed then
		pcall(function()
			speedStore:SetAsync(player.UserId, currentSpeed)
		end)
	end
end

Players.PlayerRemoving:Connect(function(player)
	playerTreadmill[player] = nil
	saveSpeed(player)
end)

-- Periodic autosave so speed survives crashes, plus a shutdown flush
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			saveSpeed(player)
		end
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveSpeed(player)
	end
end)

--------------------------------------------------
-- FIND PLAYERS IN TRIGGER
--------------------------------------------------

local function getPlayersInTrigger(trigger)
	local foundPlayers = {}

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = {
		treadmillsFolder
	}

	local parts = workspace:GetPartsInPart(trigger, overlapParams)

	for _, part in ipairs(parts) do
		local character = part:FindFirstAncestorOfClass("Model")

		if not character then
			continue
		end

		local player = Players:GetPlayerFromCharacter(character)
		local humanoid = character:FindFirstChildOfClass("Humanoid")

		if player and humanoid and humanoid.Health > 0 then
			foundPlayers[player] = humanoid
		end
	end

	return foundPlayers
end

--------------------------------------------------
-- TELEPORT PLAYER ONCE
--------------------------------------------------

local function teleportToTreadmill(player, treadmill)
	local character = player.Character

	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local trigger = treadmill:FindFirstChild("Trigger")

	if not humanoid or not rootPart or not trigger then
		return
	end

	local yOffset = (trigger.Size.Y / 2) + humanoid.HipHeight

	local targetPosition =
		trigger.Position + Vector3.new(0, yOffset, 0)

	local targetCFrame =
		CFrame.new(targetPosition) * trigger.CFrame.Rotation

	character:PivotTo(targetCFrame)
end

--------------------------------------------------
-- ENTER TREADMILL
--------------------------------------------------

local function enterTreadmill(player, humanoid, treadmill)
	if playerTreadmill[player] then
		return
	end

	local character = player.Character

	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if not rootPart then
		return
	end

	playerTreadmill[player] = treadmill

	player:SetAttribute("OnTreadmill", true)
	player:SetAttribute("TreadmillName", treadmill.Name)

	-- Teleport ONLY ONCE
	teleportToTreadmill(player, treadmill)

	-- Lock movement
	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false
	humanoid.JumpPower = 0

	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
end

--------------------------------------------------
-- EXIT TREADMILL
--------------------------------------------------

local function exitTreadmill(player)
	local treadmill = playerTreadmill[player]

	if not treadmill then
		return
	end

	playerTreadmill[player] = nil

	player:SetAttribute("OnTreadmill", false)
	player:SetAttribute("TreadmillName", "")

	local character = player.Character

	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if not humanoid then
		return
	end

	humanoid.AutoRotate = true
	humanoid.WalkSpeed = getMoveSpeed(player)
	humanoid.JumpPower = 50

	-- Teleport player to the appropriate TPoff part
	if rootPart then
		local tpPart = tpOff

		if treadmill.Name == "Gold Treadmill" then
			tpPart = tpOff2
		elseif treadmill.Name == "diamond" then
			tpPart = tpOff3
		end

		if tpPart then
			local yOffset = (tpPart.Size.Y / 2) + humanoid.HipHeight
			local exitPosition = tpPart.Position + Vector3.new(0, yOffset, 0)

			character:PivotTo(CFrame.new(exitPosition))
		end
	end
end

--------------------------------------------------
-- JUMP TO EXIT
--------------------------------------------------

treadmillExit.OnServerEvent:Connect(function(player)
	exitTreadmill(player)
end)

--------------------------------------------------
-- MAIN LOOP
--------------------------------------------------

RunService.Heartbeat:Connect(function(deltaTime)
	--------------------------------------------------
	-- VELOCITY CLAMP (runs every frame)
	-- Prevents collision spikes from launching players at high speed.
	--------------------------------------------------
	for _, player in ipairs(Players:GetPlayers()) do
		if not playerTreadmill[player] then
			local character = player.Character
			if character then
				local hrp = character:FindFirstChild("HumanoidRootPart")
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if hrp and humanoid and humanoid.Health > 0 then
					local speed = getMoveSpeed(player)
					local maxVel = speed * VELOCITY_CLAMP_MARGIN
					local vel = hrp.AssemblyLinearVelocity
					local horizontal = Vector3.new(vel.X, 0, vel.Z)
					if horizontal.Magnitude > maxVel then
						horizontal = horizontal.Unit * maxVel
						hrp.AssemblyLinearVelocity = Vector3.new(horizontal.X, vel.Y, horizontal.Z)
					end
				end
			end
		end
	end

	checkTimer += deltaTime

	if checkTimer < CHECK_INTERVAL then
		return
	end

	local elapsed = checkTimer
	checkTimer = 0

	--------------------------------------------------
	-- DETECT PLAYERS ENTERING
	--------------------------------------------------

	for _, treadmill in ipairs(treadmillsFolder:GetChildren()) do
		local trigger = treadmill:FindFirstChild("Trigger")

		if not trigger or not trigger:IsA("BasePart") then
			continue
		end

		local playersInside = getPlayersInTrigger(trigger)

		for player, humanoid in pairs(playersInside) do
			if not playerTreadmill[player] then
				enterTreadmill(player, humanoid, treadmill)
			end
		end
	end

	--------------------------------------------------
	-- HANDLE PLAYERS ON TREADMILLS
	--------------------------------------------------

	for player, treadmill in pairs(playerTreadmill) do
		if not player.Parent then
			playerTreadmill[player] = nil
			continue
		end

		-- spawned admin treadmills can despawn/be destroyed under a player: release them
		if not treadmill.Parent then
			playerTreadmill[player] = nil
			player:SetAttribute("OnTreadmill", false)
			player:SetAttribute("TreadmillName", "")
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.AutoRotate = true
				humanoid.WalkSpeed = getMoveSpeed(player)
				humanoid.JumpPower = 50
			end
			continue
		end

		local character = player.Character

		if not character then
			playerTreadmill[player] = nil
			continue
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local rootPart = character:FindFirstChild("HumanoidRootPart")

		if not humanoid or not rootPart then
			playerTreadmill[player] = nil
			continue
		end

		-- Keep player locked
		humanoid.WalkSpeed = 0
		humanoid.AutoRotate = false
		humanoid.JumpPower = 0

		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero

		--------------------------------------------------
		-- SPEED GAIN
		--------------------------------------------------

		local gain = NORMAL_GAIN

		if treadmill.Name == "Gold Treadmill" then
			gain = GOLD_GAIN
		elseif treadmill.Name == "diamond" then
			gain = DIAMOND_GAIN
		elseif treadmill.Name == "Admin Treadmill" then
			gain = ADMIN_GAIN
		end

		local currentSpeed = player:GetAttribute("Speed") or START_SPEED

		local oldWhole = math.floor(currentSpeed)

		currentSpeed += gain * elapsed

		player:SetAttribute("Speed", currentSpeed)

		local newWhole = math.floor(currentSpeed)

		-- Show +1 / +5 only when a whole number is gained
		if newWhole > oldWhole then
			local amountGained = newWhole - oldWhole

			speedGainEffect:FireClient(
				player,
				amountGained
			)
		end
	end
end)