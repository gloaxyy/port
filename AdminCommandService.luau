-- AdminCommandService: server-side admin spawn, carry & place, plot banking, announcements
-- SERVER = this server only. GLOBAL = every server in the game (MessagingService).
-- Add new admin ids here AND in StarterPlayerScripts/AdminCommandBar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")

local ADMIN_IDS = {
	[1812272806] = true, -- put more user ids here, comma separated
	[1674817126] = true,
	[4743830923] = true,
	[11573893043] = true,
	[9244019797] = true,
	[7168589948] = true,
}

local EventService = require(script.Parent.EventService)

local ADMIN_NAMES = {
	["zestrbx"] = true, -- admins by exact username
	["syntax40438"] = true,
	["generalchaosdurden"] = true,
	["bombachara3738"] = true,
	["eh_of"] = true,
	["prime_ahmed"] = true,
	["ahmedminir123"] = true,
}

-- owners: full admin access + can ban and kick other admins (owners are protected from kick/ban)
local OWNER_NAMES = {
	["oneelitely"] = true,
	["zestrbx"] = true,
}

-- one announcement text + banner style + look + coin rate per croc type
local CROC_TYPES = {
	croc = {
		name = "SpawnedCroc",
		pickupName = "Croc",
		announce = "A CROC HAS SPAWNED!",
		style = "gold",
		coinsPerSec = 1,
	},
	goldcroc = {
		name = "GoldCroc",
		pickupName = "Gold Croc",
		announce = "A GOLD CROC HAS SPAWNED!",
		style = "gold",
		coinsPerSec = 50,
		look = {
			color = Color3.fromRGB(255, 190, 40),
			sparkles = ColorSequence.new(Color3.fromRGB(255, 215, 80), Color3.fromRGB(120, 80, 0)),
			tag = "GOLD CROC",
			tagColor = Color3.fromRGB(255, 210, 60),
		},
	},
	diamondcroc = {
		name = "DiamondCroc",
		pickupName = "Diamond Croc",
		announce = "A DIAMOND CROC HAS SPAWNED!",
		style = "diamond",
		coinsPerSec = 150,
		look = {
			color = Color3.fromRGB(120, 220, 255),
			sparkles = ColorSequence.new(Color3.fromRGB(200, 250, 255), Color3.fromRGB(60, 150, 255)),
			tag = "DIAMOND CROC",
			tagColor = Color3.fromRGB(150, 235, 255),
		},
	},
	redcroc = {
		name = "RedAdminCroc",
		pickupName = "Admin Croc",
		announce = "THE RAREST RED ADMIN CROC HAS SPAWNED!",
		style = "admin",
		coinsPerSec = 1000000,
		look = {
			color = Color3.fromRGB(190, 16, 16),
			sparkles = ColorSequence.new(Color3.fromRGB(255, 40, 40), Color3.fromRGB(20, 0, 0)),
			tag = "ADMIN CROC",
			tagColor = Color3.fromRGB(255, 30, 30),
		},
	},
}

local GLOBAL_TOPIC = "AdminCrocGlobal"

local remoteFolder = Instance.new("Folder")
remoteFolder.Name = "AdminRemotes"
remoteFolder.Parent = ReplicatedStorage

local runCommand = Instance.new("RemoteEvent")
runCommand.Name = "RunCommand"
runCommand.Parent = remoteFolder

local spawnAnnounce = Instance.new("RemoteEvent")
spawnAnnounce.Name = "SpawnAnnounce"
spawnAnnounce.Parent = remoteFolder

local commandFeedback = Instance.new("RemoteEvent")
commandFeedback.Name = "CommandFeedback"
commandFeedback.Parent = remoteFolder

local toggleFly = Instance.new("RemoteEvent")
toggleFly.Name = "ToggleFly"
toggleFly.Parent = remoteFolder

local adminAnnounce = Instance.new("RemoteEvent")
adminAnnounce.Name = "AdminAnnounce"
adminAnnounce.Parent = remoteFolder

local heldCrocs = {} -- [croc model] = { holder = Player, conn = Heartbeat connection }
local heldByPlayer = {} -- [player] = croc model they are carrying (one at a time, like regular crocs)
local bankedCrocs = {} -- [croc model] = { owner = Player, rate = coins per second }

-- ============================================================
-- WANDERING: spawned crocs roam around instead of standing frozen,
-- and banked ones wander inside their plot like the regular baby crocs.
-- ============================================================
local WANDER_SPEED = 5        -- studs/sec
local WANDER_PAUSE_MIN = 1    -- seconds paused between walks
local WANDER_PAUSE_MAX = 4
local WANDER_MARGIN = 4       -- studs kept from plot edges
local WANDER_RADIUS = 18      -- loose crocs roam this far from where they spawned/dropped
local WANDER_FREEZE_DISTANCE = 8 -- crocs stand still when a player is this close, so they can be grabbed like the regular crocs

local wandering = {} -- [croc model] = true while its wander loop runs

local function playerNearby(croc, pos)
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if r and (r.Position - pos).Magnitude <= WANDER_FREEZE_DISTANCE then
			return true
		end
	end
	return false
end

local function wanderBoundsAround(position)
	return {
		minX = position.X - WANDER_RADIUS, maxX = position.X + WANDER_RADIUS,
		minZ = position.Z - WANDER_RADIUS, maxZ = position.Z + WANDER_RADIUS,
	}
end

local function wanderBoundsForPlot(pd)
	return {
		minX = pd.minX + WANDER_MARGIN, maxX = pd.maxX - WANDER_MARGIN,
		minZ = pd.minZ + WANDER_MARGIN, maxZ = pd.maxZ - WANDER_MARGIN,
	}
end

local function stopWandering(croc)
	wandering[croc] = nil
end

local function startWandering(croc, bounds, extents)
	if wandering[croc] then return end
	wandering[croc] = true
	task.spawn(function()
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { croc }
		local floorY = nil
		while wandering[croc] and croc.Parent do
			-- pick a random target inside the bounds (clamped so tiny plots still work)
			local rangeX = math.max(0, bounds.maxX - bounds.minX)
			local rangeZ = math.max(0, bounds.maxZ - bounds.minZ)
			local targetPos = Vector3.new(bounds.minX + math.random() * rangeX, 0, bounds.minZ + math.random() * rangeZ)

			-- walk toward the target, hugging the ground (standing still whenever a player is close)
			while wandering[croc] and croc.Parent do
				local cur = croc:GetPivot().Position
				if playerNearby(croc, cur) then
					task.wait(0.2)
				else
					local remaining = Vector3.new(targetPos.X - cur.X, 0, targetPos.Z - cur.Z)
					if remaining.Magnitude < 1 then break end
					local moveDir = remaining.Unit
					local step = math.min(WANDER_SPEED * 0.05, remaining.Magnitude)
					local nx, nz = cur.X + moveDir.X * step, cur.Z + moveDir.Z * step
					local ray = workspace:Raycast(Vector3.new(nx, cur.Y + 30, nz), Vector3.new(0, -300, 0), rayParams)
					local gy = ray and ray.Position.Y or cur.Y
					-- clamp to the croc's starting floor like the regular crocs do, so wandering
					-- crocs never climb steep terrain, fences, or roofs
					if floorY == nil then
						floorY = gy
					elseif math.abs(gy - floorY) > 1.5 then
						gy = floorY
					end
					local placePos = Vector3.new(nx, gy + extents.Y * 0.5 + 0.5, nz)
					croc:PivotTo(CFrame.lookAt(placePos, placePos + moveDir))
					task.wait(0.05)
				end
			end

			-- pause before picking a new destination; stay frozen the whole time a player is close
			local pause = WANDER_PAUSE_MIN + math.random() * (WANDER_PAUSE_MAX - WANDER_PAUSE_MIN)
			local waited = 0
			while wandering[croc] and croc.Parent and waited < pause do
				if playerNearby(croc, croc:GetPivot().Position) then
					waited = 0
					task.wait(0.2)
				else
					task.wait(0.1)
					waited += 0.1
				end
			end
		end
		wandering[croc] = nil
	end)
end

local function isAdmin(player)
	return ADMIN_IDS[player.UserId] == true or ADMIN_NAMES[player.Name:lower()] == true or OWNER_NAMES[player.Name:lower()] == true
end

local function isOwner(player)
	return OWNER_NAMES[player.Name:lower()] == true
end

-- bans last for this server session (cleared when the server restarts)
local bannedUsers = {} -- [userId] = name at time of ban

Players.PlayerAdded:Connect(function(player)
	if bannedUsers[player.UserId] then
		player:Kick("You are banned from this server (banned as " .. bannedUsers[player.UserId] .. ").")
	end
end)

-- ============================================================
-- COINS (same leaderstats layout CrocStealChaseHandler uses)
-- ============================================================
local function getCoinStat(player)
	for _, c in ipairs(player:GetChildren()) do
		if c.Name == "leaderstats" then
			local coins = c:FindFirstChild("Coins")
			if coins then
				return coins
			end
		end
	end
	return nil
end

-- ============================================================
-- PLOTS (bases): models named "plots" in Workspace, owned via the Owner
-- attribute that PlotManager writes. Banked admin crocs pay coins like
-- the regular baby crocs do.
-- ============================================================
local plots = {}
for _, m in ipairs(workspace:GetDescendants()) do
	if m:IsA("Model") and m.Name == "plots" then
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "BoardHolder" then
				local p = d.Position
				minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
				minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
			end
		end
		if minX < maxX and minZ < maxZ then
			table.insert(plots, { model = m, minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ })
		end
	end
end

local function plotOwnedBy(plotModel, player)
	local owner = plotModel:GetAttribute("Owner")
	if owner == nil then
		return false
	end
	return owner == player.Name or owner == player.DisplayName or owner == tostring(player.UserId)
end

local function bankPlotFor(player, pos)
	for _, pd in ipairs(plots) do
		if plotOwnedBy(pd.model, player)
			and pos.X >= pd.minX and pos.X <= pd.maxX
			and pos.Z >= pd.minZ and pos.Z <= pd.maxZ then
			return pd
		end
	end
	return nil
end

-- pay out coins every second for every banked admin croc
task.spawn(function()
	while true do
		task.wait(1)
		for croc, info in pairs(bankedCrocs) do
			if not croc.Parent then
				bankedCrocs[croc] = nil
			else
				local owner = info.owner
				if owner.Parent then
					local coins = getCoinStat(owner)
					if coins then
						coins.Value += info.rate
					end
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	heldByPlayer[player] = nil
	for croc, info in pairs(heldCrocs) do
		if info.holder == player then
			info.conn:Disconnect()
			heldCrocs[croc] = nil
			-- drop it on the ground where they left it so someone else can grab it
			if croc.Parent then
				local groundPos = groundCFrame(croc:GetPivot().Position, Vector3.new(0, 0, -1))
				croc:PivotTo(CFrame.new(groundPos + Vector3.new(0, croc:GetExtentsSize().Y * 0.5 + 0.5, 0)))
				startWandering(croc, wanderBoundsAround(croc:GetPivot().Position), croc:GetExtentsSize())
			end
		end
	end
	for croc, info in pairs(bankedCrocs) do
		if info.owner == player then
			bankedCrocs[croc] = nil
			if croc.Parent then
				croc:Destroy()
			end
		end
	end
end)

local function groundCFrame(position, lookDir, excludeChar)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeChar and { excludeChar } or {}
	local ray = workspace:Raycast(position + Vector3.new(0, 60, 0), Vector3.new(0, -300, 0), params)
	local groundY = ray and ray.Position.Y or position.Y
	local flat = Vector3.new(lookDir.X, 0, lookDir.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, -1)
	end
	flat = flat.Unit
	return Vector3.new(position.X, groundY, position.Z), flat
end

-- E-prompt pickup, same as the regular baby crocs: ANYONE can pick these up,
-- carry them, and bank them by walking into (or dropping them inside) their
-- own plot. Banked crocs stay forever and pay coins/sec.
local function makePickable(croc, extents, crocType)
	local promptRoot = croc.PrimaryPart or croc:FindFirstChildWhichIsA("BasePart", true)
	if not promptRoot then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CrocPickup"
	prompt.ActionText = "Pick Up"
	prompt.ObjectText = crocType.pickupName or "Croc"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptRoot

	local function placeDown(player, dropDist)
		local state = heldCrocs[croc]
		if state then
			state.conn:Disconnect()
			heldCrocs[croc] = nil
		end
		if heldByPlayer[player] == croc then
			heldByPlayer[player] = nil
		end
		prompt.ActionText = "Pick Up"
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local groundPos, flat = groundCFrame(root.CFrame.Position + root.CFrame.LookVector * dropDist, root.CFrame.LookVector, char)
		local placePos = groundPos + Vector3.new(0, extents.Y * 0.5 + 0.5, 0)
		croc:PivotTo(CFrame.lookAt(placePos, placePos + flat))

		-- inside the placer's own plot? bank it like the other crocs
		local pd = bankPlotFor(player, croc:GetPivot().Position)
		if pd then
			croc:SetAttribute("Banked", true)
			croc:SetAttribute("Owner", player.Name)
			bankedCrocs[croc] = { owner = player, rate = crocType.coinsPerSec }
			prompt.Enabled = false
			startWandering(croc, wanderBoundsForPlot(pd), extents)
			print("[AdminCommands] " .. player.Name .. " banked a " .. crocType.name .. " in their plot (" .. crocType.coinsPerSec .. " coins/sec)")
		else
			startWandering(croc, wanderBoundsAround(croc:GetPivot().Position), extents)
			print("[AdminCommands] " .. player.Name .. " placed their croc down")
		end
	end

	prompt.Triggered:Connect(function(player)
		local state = heldCrocs[croc]

		if state then
			if state.holder ~= player then
				return -- someone else is carrying it
			end
			placeDown(player, 6)
		else
			if bankedCrocs[croc] then
				return -- already banked: no re-picking it up
			end
			if heldByPlayer[player] then
				return -- already carrying a croc
			end
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if not root then
				return
			end
			croc:SetAttribute("Carried", true) -- cancels the 12s despawn
			stopWandering(croc)
			heldByPlayer[player] = croc
			prompt.ActionText = "Drop"
			local liftY = extents.Y * 0.5 + 3.5
			local lastBankCheck = 0
			local conn
			conn = RunService.Heartbeat:Connect(function()
				if not croc.Parent then
					conn:Disconnect()
					heldCrocs[croc] = nil
					return
				end
				local c = player.Character
				local r = c and c:FindFirstChild("HumanoidRootPart")
				if r then
					croc:PivotTo(r.CFrame * CFrame.new(0, liftY, 0))
					-- walking into your own plot while carrying banks it, like the other crocs
					local now = os.clock()
					if now - lastBankCheck >= 0.25 then
						lastBankCheck = now
						if bankPlotFor(player, r.Position) then
							placeDown(player, 0)
						end
					end
				end
			end)
			heldCrocs[croc] = { holder = player, conn = conn }
			print("[AdminCommands] " .. player.Name .. " picked up a croc")
		end
	end)
end

-- special croc looks: tinted body, matching glow + sparkles, floating name tag
local function makeVariant(croc, look)
	for _, d in ipairs(croc:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Color = look.color
		end
	end

	local root = croc.PrimaryPart or croc:FindFirstChildWhichIsA("BasePart", true)
	if root then
		local light = Instance.new("PointLight")
		light.Color = look.color
		light.Range = 14
		light.Brightness = 2
		light.Parent = root

		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Color = look.sparkles
		sparkles.LightEmission = 1
		sparkles.Lifetime = NumberRange.new(0.6, 1.2)
		sparkles.Rate = 14
		sparkles.Speed = NumberRange.new(2, 4)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(0.35, 0)
		sparkles.Parent = root
	end

	local tag = Instance.new("BillboardGui")
	tag.Name = "CrocTag"
	tag.Size = UDim2.fromOffset(160, 36)
	tag.StudsOffset = Vector3.new(0, 4, 0)
	tag.AlwaysOnTop = true
	tag.LightInfluence = 0
	tag.MaxDistance = 120
	tag.Parent = croc
	tag.Adornee = root

	local tagText = Instance.new("TextLabel")
	tagText.Size = UDim2.fromScale(1, 1)
	tagText.BackgroundTransparency = 1
	tagText.Font = Enum.Font.FredokaOne
	tagText.Text = look.tag
	tagText.TextColor3 = look.tagColor
	tagText.TextStrokeColor3 = Color3.new(0, 0, 0)
	tagText.TextStrokeTransparency = 0
	tagText.TextScaled = true
	tagText.Parent = tag
end

-- find a croc model to clone for admin spawns. Prefers a real baby croc
-- ("BabyCrocodile" anywhere in Workspace, or any model tagged CrocType = "Little");
-- falls back to a big croc, which gets shrunk to baby size after cloning.
local function findCrocTemplate()
	local baby = workspace:FindFirstChild("BabyCrocodile", true)
	if baby and baby:IsA("Model") then
		return baby, false
	end
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Model") and d:GetAttribute("CrocType") == "Little" then
			return d, false
		end
	end
	for _, d in ipairs(workspace:GetChildren()) do
		if d:IsA("Model") and d:GetAttribute("CrocType") == "Big" then
			return d, true
		end
	end
	return nil, false
end

local function spawnCrocNear(targetPlayer, crocType)
	local char = targetPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	local model, isBigFallback = findCrocTemplate()
	if not model then
		warn("[AdminCommands] no croc model found in workspace to clone")
		return nil
	end

	local croc = model:Clone()
	croc.Name = crocType.name
	if isBigFallback then
		-- only big crocs exist in this place: shrink the clone to baby size so it can be carried and banked
		local size = croc:GetExtentsSize()
		local longest = math.max(size.X, size.Y, size.Z)
		if longest > 0 then
			croc:ScaleTo(croc:GetScale() * (7 / longest))
		end
	end
	croc:SetAttribute("CrocType", nil)
	for _, d in ipairs(croc:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ProximityPrompt") then
			d:Destroy()
		end
	end
	for _, part in ipairs(croc:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end

	if crocType.look then
		makeVariant(croc, crocType.look)
	end

	local extents = croc:GetExtentsSize()
	local groundPos, flat = groundCFrame(root.CFrame.Position + root.CFrame.LookVector * 8, root.CFrame.LookVector, char)
	local spawnPos = groundPos + Vector3.new(0, extents.Y * 0.5 + 0.5, 0)
	croc:PivotTo(CFrame.lookAt(spawnPos, spawnPos + flat))
	makePickable(croc, extents, crocType)
	croc.Parent = workspace
	startWandering(croc, wanderBoundsAround(spawnPos), extents)

	-- despawns after 12s unless someone picked it up (to carry home) or it was banked
	task.delay(12, function()
		if croc.Parent and not croc:GetAttribute("Carried") and not croc:GetAttribute("Banked") then
			croc:Destroy()
		end
	end)

	print("[AdminCommands] " .. crocType.name .. " spawned near " .. targetPlayer.Name)
	return croc
end

-- ============================================================
-- ADMIN TREADMILL SPAWN: same flow as the crocs - clones the
-- "Admin Treadmill lemonade" model from ReplicatedStorage, spawns it in
-- front of the admin, click to carry, click again to place. Placed inside
-- YOUR plot it banks there forever and works as a treadmill with a big
-- speed gain (handled by Treadmillsystem via the "Admin Treadmill" name).
-- ============================================================
local TREADMILL_TYPE = {
	name = "Admin Treadmill",
	announce = "AN ADMIN TREADMILL HAS SPAWNED!",
	style = "admin",
}

local heldTreadmills = {} -- [treadmill model] = { holder = Player, conn = Heartbeat connection }

local function findTreadmillTemplate()
	local template = ReplicatedStorage:FindFirstChild("Admin Treadmill lemonade")
	if template and template:IsA("Model") then
		return template
	end
	-- fallback: any model whose name contains "treadmill" (case-insensitive)
	for _, d in ipairs(ReplicatedStorage:GetChildren()) do
		if d:IsA("Model") and d.Name:lower():find("treadmill", 1, true) then
			return d
		end
	end
	return nil
end

-- admin look: red glow + sparkles + floating name tag (keeps the model's own colors)
local function makeTreadmillLook(treadmill)
	local root = treadmill.PrimaryPart or treadmill:FindFirstChildWhichIsA("BasePart", true)
	if root then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 30, 30)
		light.Range = 14
		light.Brightness = 2
		light.Parent = root

		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 40, 40), Color3.fromRGB(20, 0, 0))
		sparkles.LightEmission = 1
		sparkles.Lifetime = NumberRange.new(0.6, 1.2)
		sparkles.Rate = 14
		sparkles.Speed = NumberRange.new(2, 4)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(0.35, 0)
		sparkles.Parent = root
	end

	local tag = Instance.new("BillboardGui")
	tag.Name = "TreadmillTag"
	tag.Size = UDim2.fromOffset(220, 36)
	tag.StudsOffset = Vector3.new(0, 6, 0)
	tag.AlwaysOnTop = true
	tag.LightInfluence = 0
	tag.MaxDistance = 120
	tag.Parent = treadmill
	tag.Adornee = root

	local tagText = Instance.new("TextLabel")
	tagText.Size = UDim2.fromScale(1, 1)
	tagText.BackgroundTransparency = 1
	tagText.Font = Enum.Font.FredokaOne
	tagText.Text = "ADMIN TREADMILL"
	tagText.TextColor3 = Color3.fromRGB(255, 30, 30)
	tagText.TextStrokeColor3 = Color3.new(0, 0, 0)
	tagText.TextStrokeTransparency = 0
	tagText.TextScaled = true
	tagText.Parent = tag
end

-- invisible zone Treadmillsystem uses to detect players stepping on.
-- Only added when banked, so carrying it never locks the carrier onto it.
local function addTreadmillTrigger(treadmill)
	if treadmill:FindFirstChild("Trigger") then
		return
	end
	local extents = treadmill:GetExtentsSize()
	local trigger = Instance.new("Part")
	trigger.Name = "Trigger"
	trigger.Size = Vector3.new(extents.X * 0.7, 5, extents.Z * 0.7)
	trigger.Transparency = 1
	trigger.CanCollide = false
	trigger.CanQuery = false
	trigger.Anchored = true
	trigger.Massless = true
	trigger.CFrame = treadmill:GetPivot() * CFrame.new(0, extents.Y * 0.1, 0)
	trigger.Parent = treadmill
end

local function makeTreadmillPickable(treadmill, extents)
	local detector = Instance.new("ClickDetector")
	detector.Name = "TreadmillPickup"
	detector.MaxActivationDistance = 30
	detector.Parent = treadmill

	detector.MouseClick:Connect(function(player)
		local state = heldTreadmills[treadmill]

		if state then
			if state.holder ~= player then
				return -- someone else is carrying it
			end
			state.conn:Disconnect()
			heldTreadmills[treadmill] = nil
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				local groundPos, flat = groundCFrame(root.CFrame.Position + root.CFrame.LookVector * 10, root.CFrame.LookVector, char)
				local placePos = groundPos + Vector3.new(0, extents.Y * 0.5 + 0.5, 0)
				treadmill:PivotTo(CFrame.lookAt(placePos, placePos + flat))

				-- inside the admin's own plot? bank it: stays forever, becomes a working treadmill
				if bankPlotFor(player, treadmill:GetPivot().Position) then
					treadmill:SetAttribute("Banked", true)
					treadmill:SetAttribute("Owner", player.Name)
					addTreadmillTrigger(treadmill)
					local folder = workspace:FindFirstChild("Treadmills")
					if folder then
						treadmill.Parent = folder
					end
					print("[AdminCommands] " .. player.Name .. " banked an Admin Treadmill in their plot")
				else
					print("[AdminCommands] " .. player.Name .. " placed their treadmill down")
				end
			end
		else
			if treadmill:GetAttribute("Banked") then
				return -- already banked: no re-picking it up
			end
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if not root then
				return
			end
			treadmill:SetAttribute("Carried", true) -- cancels the 12s despawn
			local liftY = extents.Y * 0.5 + 3.5
			local conn
			conn = RunService.Heartbeat:Connect(function()
				if not treadmill.Parent then
					conn:Disconnect()
					heldTreadmills[treadmill] = nil
					return
				end
				local c = player.Character
				local r = c and c:FindFirstChild("HumanoidRootPart")
				if r then
					treadmill:PivotTo(r.CFrame * CFrame.new(0, liftY, 0))
				end
			end)
			heldTreadmills[treadmill] = { holder = player, conn = conn }
			print("[AdminCommands] " .. player.Name .. " picked up the admin treadmill")
		end
	end)
end

local function spawnTreadmillNear(targetPlayer)
	local char = targetPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	local template = findTreadmillTemplate()
	if not template then
		warn("[AdminCommands] no treadmill model found in ReplicatedStorage to clone")
		return nil
	end

	local treadmill = template:Clone()
	treadmill.Name = TREADMILL_TYPE.name
	for _, d in ipairs(treadmill:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ProximityPrompt") then
			d:Destroy()
		end
	end
	for _, part in ipairs(treadmill:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = true
		end
	end

	makeTreadmillLook(treadmill)

	local extents = treadmill:GetExtentsSize()
	local groundPos, flat = groundCFrame(root.CFrame.Position + root.CFrame.LookVector * 10, root.CFrame.LookVector, char)
	local spawnPos = groundPos + Vector3.new(0, extents.Y * 0.5 + 0.5, 0)
	treadmill:PivotTo(CFrame.lookAt(spawnPos, spawnPos + flat))
	makeTreadmillPickable(treadmill, extents)
	treadmill.Parent = workspace

	-- despawns after 12s unless someone picked it up (to carry home) or it was banked
	task.delay(12, function()
		if treadmill.Parent and not treadmill:GetAttribute("Carried") and not treadmill:GetAttribute("Banked") then
			treadmill:Destroy()
		end
	end)

	print("[AdminCommands] Admin Treadmill spawned near " .. targetPlayer.Name)
	return treadmill
end

-- ============================================================
-- ADMIN UTILITY COMMANDS: give money, give speed
-- ============================================================
-- (walk speed persists via the player's Speed attribute, which
-- TreadmillSystem reapplies on respawn and the SpeedGui counter reads)

local function findPlayerByName(query, admin)
	if not query or query == "" then
		return nil
	end
	local q = query:lower()
	if q == "me" or q == admin.Name:lower() then
		return admin
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower() == q or p.DisplayName:lower() == q then
			return p
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():sub(1, #q) == q or p.DisplayName:lower():sub(1, #q) == q then
			return p
		end
	end
	return nil
end

local function giveCoins(admin, targetName, amount)
	local target = findPlayerByName(targetName, admin)
	if not target then
		commandFeedback:FireClient(admin, "no player named '" .. tostring(targetName) .. "' in this server", false)
		return
	end
	amount = tonumber(amount)
	if not amount then
		commandFeedback:FireClient(admin, "amount must be a number (give money <player> <amount>)", false)
		return
	end
	local coins = getCoinStat(target)
	if not coins then
		commandFeedback:FireClient(admin, target.Name .. " has no Coins stat yet", false)
		return
	end
	coins.Value += amount
	print("[AdminCommands] " .. admin.Name .. " gave " .. amount .. " coins to " .. target.Name)
	commandFeedback:FireClient(admin, "gave " .. amount .. " coins to " .. target.Name, true)
end

local function setWalkSpeed(admin, targetName, amount)
	local target = findPlayerByName(targetName, admin)
	if not target then
		commandFeedback:FireClient(admin, "no player named '" .. tostring(targetName) .. "' in this server", false)
		return
	end
	amount = tonumber(amount)
	if not amount or amount < 1 then
		commandFeedback:FireClient(admin, "speed must be a number of 1 or more (give speed <player> <amount>)", false)
		return
	end
	local char = target.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		commandFeedback:FireClient(admin, target.Name .. " has no character right now", false)
		return
	end
	target:SetAttribute("Speed", amount)
	-- Speed attribute (HUD) stays uncapped; real movement speed is capped at 500
	hum.WalkSpeed = math.min(amount, 500)
	print("[AdminCommands] " .. admin.Name .. " set " .. target.Name .. "'s speed to " .. amount)
	commandFeedback:FireClient(admin, "set " .. target.Name .. "'s speed to " .. amount, true)
end

-- ============================================================
-- ADMIN UTILITY: fly, kick, ban, announce
-- ============================================================
local function toggleFlyFor(admin, targetName)
	local target = findPlayerByName(targetName, admin)
	if not target then
		commandFeedback:FireClient(admin, "no player named '" .. tostring(targetName) .. "' in this server", false)
		return
	end
	local char = target.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		commandFeedback:FireClient(admin, target.Name .. " has no character right now", false)
		return
	end
	toggleFly:FireClient(target)
	commandFeedback:FireClient(admin, "toggled fly for " .. target.Name, true)
	print("[AdminCommands] " .. admin.Name .. " toggled fly for " .. target.Name)
end

local function kickPlayer(admin, targetName)
	local target = findPlayerByName(targetName, admin)
	if not target then
		commandFeedback:FireClient(admin, "no player named '" .. tostring(targetName) .. "' in this server", false)
		return
	end
	if isAdmin(target) then
		-- owners can kick admins, but nobody can kick an owner
		if not (isOwner(admin) and not isOwner(target)) then
			commandFeedback:FireClient(admin, "you can't kick another admin", false)
			return
		end
	end
	target:Kick("Kicked by " .. (isOwner(admin) and "owner " or "admin ") .. admin.Name)
	commandFeedback:FireClient(admin, "kicked " .. target.Name, true)
	print("[AdminCommands] " .. admin.Name .. " kicked " .. target.Name)
end

local function banPlayer(admin, targetName)
	local target = findPlayerByName(targetName, admin)
	if not target then
		commandFeedback:FireClient(admin, "no player named '" .. tostring(targetName) .. "' in this server", false)
		return
	end
	if isAdmin(target) then
		-- owners can ban admins, but nobody can ban an owner
		if not (isOwner(admin) and not isOwner(target)) then
			commandFeedback:FireClient(admin, "you can't ban another admin", false)
			return
		end
	end
	bannedUsers[target.UserId] = target.Name
	target:Kick("Banned from this server by " .. (isOwner(admin) and "owner " or "admin ") .. admin.Name)
	commandFeedback:FireClient(admin, "banned " .. target.Name .. " (they can't rejoin this server)", true)
	print("[AdminCommands] " .. admin.Name .. " banned " .. target.Name)
end

local function unbanPlayer(admin, targetName)
	local q = (targetName or ""):lower()
	if q == "" then
		commandFeedback:FireClient(admin, "usage: unban <player>", false)
		return
	end
	for id, name in pairs(bannedUsers) do
		if name:lower():sub(1, #q) == q then
			bannedUsers[id] = nil
			commandFeedback:FireClient(admin, "unbanned " .. name, true)
			print("[AdminCommands] " .. admin.Name .. " unbanned " .. name)
			return
		end
	end
	commandFeedback:FireClient(admin, "no ban found for '" .. tostring(targetName) .. "' this session", false)
end

local function announceMessage(admin, message)
	local msg = tostring(message or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if #msg == 0 then
		commandFeedback:FireClient(admin, "usage: announce <message>", false)
		return
	end
	msg = msg:sub(1, 180)
	adminAnnounce:FireAllClients(msg, admin.Name)
	commandFeedback:FireClient(admin, "announced to everyone in the server", true)
	print("[AdminCommands] " .. admin.Name .. " announced: " .. msg)
end

runCommand.OnServerEvent:Connect(function(player, action, arg1, arg2)
	if not isAdmin(player) then
		return
	end

	if action == "giveMoney" then
		giveCoins(player, arg1, arg2)
		return
	elseif action == "setSpeed" then
		setWalkSpeed(player, arg1, arg2)
		return
	elseif action == "startEvent" then
		local ok, msg = EventService.Start(arg1)
		commandFeedback:FireClient(player, msg, ok)
		return
	elseif action == "stopEvent" then
		local ok, msg = EventService.Stop(arg1)
		commandFeedback:FireClient(player, msg, ok)
		return
	elseif action == "fly" then
		toggleFlyFor(player, arg1)
		return
	elseif action == "kick" then
		kickPlayer(player, arg1)
		return
	elseif action == "ban" then
		banPlayer(player, arg1)
		return
	elseif action == "unban" then
		unbanPlayer(player, arg1)
		return
	elseif action == "banlist" then
		local names = {}
		for _, name in pairs(bannedUsers) do
			table.insert(names, name)
		end
		if #names > 0 then
			commandFeedback:FireClient(player, "banned this session: " .. table.concat(names, ", "), true)
		else
			commandFeedback:FireClient(player, "no one is banned this session", true)
		end
		return
	elseif action == "announce" then
		announceMessage(player, arg1)
		return
	end

	local crocKey = arg1

	-- admin treadmill spawn (same carry/place/bank flow, cloned from ReplicatedStorage)
	if crocKey == "treadmill" or crocKey == "admintreadmill" then
		if action == "spawn" then
			if spawnTreadmillNear(player) then
				spawnAnnounce:FireAllClients(TREADMILL_TYPE.announce, TREADMILL_TYPE.style)
			end
		elseif action == "spawnGlobal" then
			local treadmill = spawnTreadmillNear(player)
			if treadmill then
				spawnAnnounce:FireAllClients(TREADMILL_TYPE.announce, TREADMILL_TYPE.style)
				pcall(function()
					MessagingService:PublishAsync(GLOBAL_TOPIC, { jobId = game.JobId, crocKey = crocKey })
				end)
			end
		end
		return
	end

	local crocType = CROC_TYPES[crocKey] or CROC_TYPES.croc

	if action == "spawn" then
		if spawnCrocNear(player, crocType) then
			spawnAnnounce:FireAllClients(crocType.announce, crocType.style)
		end
	elseif action == "spawnGlobal" then
		local croc = spawnCrocNear(player, crocType)
		if croc then
			spawnAnnounce:FireAllClients(crocType.announce, crocType.style)
			-- every other server spawns the same croc + announce
			pcall(function()
				MessagingService:PublishAsync(GLOBAL_TOPIC, { jobId = game.JobId, crocKey = crocKey or "croc" })
			end)
		end
	end
end)

-- receive global spawns from other servers
pcall(function()
	MessagingService:SubscribeAsync(GLOBAL_TOPIC, function(message)
		local data = message.Data
		if type(data) == "table" and data.jobId == game.JobId then
			return -- our own server already spawned it
		end
		local crocKey = data and data.crocKey or "croc"
		local candidates = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
				table.insert(candidates, p)
			end
		end
		if #candidates > 0 then
			if crocKey == "treadmill" or crocKey == "admintreadmill" then
				spawnAnnounce:FireAllClients(TREADMILL_TYPE.announce, TREADMILL_TYPE.style)
				spawnTreadmillNear(candidates[math.random(1, #candidates)])
			else
				local crocType = CROC_TYPES[crocKey] or CROC_TYPES.croc
				spawnAnnounce:FireAllClients(crocType.announce, crocType.style)
				spawnCrocNear(candidates[math.random(1, #candidates)], crocType)
			end
		end
	end)
end)

print("[AdminCommands] server handler loaded - " .. #plots .. " plots available for banking")