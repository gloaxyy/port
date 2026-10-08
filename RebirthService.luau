-- RebirthService (Server-side)
--  * Rebirth costs coins: cost = 100000 * (currentRebirths + 1)
--  * Rebirthing resets coins to 0, wipes crocs (banked + carried + inventory)
--    and purchased plot-limit slots back to the default.
--  * Every rebirth gives +50% coin earnings from banked crocs, forever.
--  * Rebirth count is saved in the "De" DataStore and exposed as the player
--    attribute "Rebirths" (the croc payout loop in CrocStealChaseHandler reads it).
--  * Remotes live in ReplicatedStorage > Rebirth:
--      Rebirth (RemoteFunction) invoke() -> success, message
--      Changed (RemoteEvent)    server -> client (newRebirths)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BASE_COST = 100000
local MULT_PER_REBIRTH = 0.5

local store = nil
local okStore = pcall(function()
	store = DataStoreService:GetDataStore("De")
end)
if not okStore then
	store = nil
	warn("[Rebirth] DataStore unavailable - rebirths won't save")
end

-- Optional: reset purchased limit slots (ModuleScript version). CrocStealChaseHandler
-- also resets its own in-script limit profile via the RebirthReset bindable.
local crocModule = nil
task.spawn(function()
	local ok, result = pcall(function()
		return require(ServerScriptService:WaitForChild("CrocLimit", 30))
	end)
	if ok then
		crocModule = result
	else
		warn("[Rebirth] Couldn't load CrocLimit module: " .. tostring(result))
	end
end)

local folder = ReplicatedStorage:FindFirstChild("Rebirth")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Rebirth"
	folder.Parent = ReplicatedStorage
end

local rebirthRemote = folder:FindFirstChild("Rebirth")
if not rebirthRemote then
	rebirthRemote = Instance.new("RemoteFunction")
	rebirthRemote.Name = "Rebirth"
	rebirthRemote.Parent = folder
end
local changed = folder:FindFirstChild("Changed")
if not changed then
	changed = Instance.new("RemoteEvent")
	changed.Name = "Changed"
	changed.Parent = folder
end

local lastRequest = {}

local function costFor(rebirths)
	return BASE_COST * (rebirths + 1)
end

local function getCoinValue(player)
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

local function applyRebirths(player, count)
	player:SetAttribute("Rebirths", count)
	player:SetAttribute("RebirthMult", 1 + MULT_PER_REBIRTH * count)
	changed:FireClient(player, count)
end

local function saveRebirths(player)
	if not store then return end
	pcall(function()
		store:SetAsync(player.UserId .. "Rebirths", player:GetAttribute("Rebirths") or 0)
	end)
end

local function onPlayerAdded(player)
	local saved = nil
	if store then
		pcall(function()
			saved = store:GetAsync(player.UserId .. "Rebirths")
		end)
	end
	if player.Parent then
		applyRebirths(player, tonumber(saved) or 0)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveRebirths(player)
	lastRequest[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveRebirths(player)
	end
end)

rebirthRemote.OnServerInvoke = function(player)
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < 1 then
		return false, "Slow down!"
	end
	lastRequest[player] = now

	local rebirths = player:GetAttribute("Rebirths") or 0
	local cost = costFor(rebirths)
	local coins = getCoinValue(player)
	if not coins then return false, "Your coins aren't ready yet." end
	if coins.Value < cost then
		return false, "You need " .. tostring(cost) .. " coins to rebirth!"
	end

	coins.Value = 0
	applyRebirths(player, rebirths + 1)

	-- wipe crocs + inventory (handled inside CrocStealChaseHandler)
	local resetBindable = ServerStorage:FindFirstChild("RebirthReset")
	if resetBindable then
		resetBindable:Invoke(player)
	end

	-- reset purchased limit slots (module copy, keeps both stores consistent)
	if crocModule and crocModule.Reset then
		pcall(crocModule.Reset, player)
	end

	task.spawn(saveRebirths, player)

	print("[Rebirth] " .. player.Name .. " rebirthed to #" .. tostring(rebirths + 1))
	local newMult = player:GetAttribute("RebirthMult")
	return true, "Rebirth #" .. tostring(rebirths + 1)
		.. "! Your crocs now earn " .. tostring(math.floor((newMult or 1) * 100 + 0.5)) .. "% coins."
end

print("[Rebirth] RebirthService loaded - base cost " .. tostring(BASE_COST) .. " coins")