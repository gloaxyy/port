-- Sell Handler (Server-side)
-- Handles selling Speed points for Coins

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Create RemoteEvent if it doesn't exist
local sellRemote = ReplicatedStorage:FindFirstChild("SellRemote")
if not sellRemote then
	sellRemote = Instance.new("RemoteEvent")
	sellRemote.Name = "SellRemote"
	sellRemote.Parent = ReplicatedStorage
end

-- Multiple scripts create their own "leaderstats" folder on each player.
-- CashHUD (bottom-left coin HUD) watches the FIRST one, so Coins must live there.
local function ensureCoins(player)
	local first = player:FindFirstChild("leaderstats") or player:WaitForChild("leaderstats", 30)
	if not first then
		warn("[SellHandler] no leaderstats appeared for " .. player.Name)
		return
	end
	if not first:FindFirstChild("Coins") then
		local coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Value = 0
		coins.Parent = first
		print("[SellHandler] created Coins for " .. player.Name)
	end
end

Players.PlayerAdded:Connect(ensureCoins)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(ensureCoins, player)
end

local SPEED_TO_COINS_RATE = 10  -- 1 Speed point above base = 10 Coins
local START_SPEED = 16          -- matches TreadmillSystem base speed

sellRemote.OnServerEvent:Connect(function(player, action)
	if typeof(action) ~= "string" then return end
	if action ~= "SellSpeed" and action ~= "SellAll" then return end

	-- Scan every leaderstats folder (there are several) for the one holding Coins
	local coins = nil
	for _, folder in ipairs(player:GetChildren()) do
		if folder.Name == "leaderstats" then
			local found = folder:FindFirstChild("Coins")
			if found then
				coins = found
				break
			end
		end
	end
	if not coins then return end

	local currentSpeed = player:GetAttribute("Speed")
	if not currentSpeed then return end

	local speedPoints = math.floor(currentSpeed - START_SPEED)
	if speedPoints <= 0 then return end

	local coinsGained = speedPoints * SPEED_TO_COINS_RATE

	-- Reset speed to the base and pay out coins
	player:SetAttribute("Speed", START_SPEED)
	coins.Value = coins.Value + coinsGained

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = START_SPEED
		end
	end

	print("[SellHandler] " .. player.Name .. " sold " .. speedPoints .. " speed points for " .. coinsGained .. " coins")
end)