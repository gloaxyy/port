

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local ServerStorage = game:GetService("ServerStorage")

-- ============================================================
-- CONFIG
-- ============================================================
local CARRY_SCALE = 0.5               -- baby is shrunk to this fraction of its size while carried
local CARRY_HEIGHT = 3.2              -- studs above the player's HumanoidRootPart
local COINS_PER_CROC_PER_SECOND = 5   -- coins each banked croc generates per second
-- Coins per second for each kind of baby croc. Babies not listed here use
-- 5 + 10 * (number - 1): BabyCrocodile1 = 5, 2 = 15, 3 = 25, 4 = 35, and so on.
-- Only add an entry here to make one croc pay differently from the pattern.
local CROC_RATES = {}

local function rateFor(name)
	local override = CROC_RATES[name]
	if override then
		return override
	end
	local n = tonumber(name:match("^BabyCrocodile(%d+)$"))
	if n then
		return COINS_PER_CROC_PER_SECOND + 10 * (n - 1)
	end
	return COINS_PER_CROC_PER_SECOND
end

-- SIZE TIERS: every baby croc rolls a size when it spawns. Bigger = pays more coins.
-- weightLow  = spawn weight for BabyCrocodile1 (lowest number)
-- weightHigh = spawn weight for the highest-numbered baby (e.g. BabyCrocodile7)
-- Babies in between blend smoothly, so a higher number in the name means better odds
-- of the big tiers. Weights are relative (they don't need to add up to 100).
local SIZE_TIERS = {
	{ name = "Normal", size = 1.0, coinMult = 1,   color = Color3.fromRGB(255, 255, 255), weightLow = 78,  weightHigh = 25 },
	{ name = "Large",  size = 1.4, coinMult = 1.5, color = Color3.fromRGB(120, 220, 120), weightLow = 18,  weightHigh = 35 },
	{ name = "Huge",   size = 1.8, coinMult = 2.5, color = Color3.fromRGB(90, 170, 255),  weightLow = 3.5, weightHigh = 25 },
	{ name = "Giant",  size = 2.3, coinMult = 5,   color = Color3.fromRGB(255, 120, 60),  weightLow = 0.5, weightHigh = 15 },
}

local REPLACEMENT_DELAY = 10          -- seconds until a new baby appears after one is banked
local OFFLINE_CAP_SECONDS = 7200      -- max seconds of offline earnings paid on rejoin (2 hours)

local BIG_CROC_RUN_SPEED = 29        -- Crocodile1 burst speed; each higher-number croc is 10 faster
local BIG_CROC_HUNT_SPEED = 18       -- Crocodile1 cruising speed; each higher-number croc is 6 faster
local CATCH_DISTANCE = 4              -- studs from the big croc's body that counts as "touching"
local CHASE_TIMEOUT = 90              -- seconds the big croc chases one carrier before giving up
local CATCH_PAUSE = 2                 -- seconds the big croc pauses after catching someone

local SAFE_PAD = 12                   -- studs around every plot that also count as safe from the croc

local RAGDOLL_TIME = 3                -- seconds a caught player stays ragdolled
local RAGDOLL_PUSH = 35               -- horizontal knock-back speed
local RAGDOLL_LIFT = 30               -- upward knock-back speed

-- Where banked crocs sit inside a plot (grid around the plot centre)
local SLOT_COLS, SLOT_ROWS = 3, 5
local SLOT_SPACING_X, SLOT_SPACING_Z = 12, 11

-- Baby croc wandering in plot
local WANDER_SPEED = 5              -- studs/sec walking speed
local WANDER_PAUSE_MIN = 1          -- min seconds paused between walks
local WANDER_PAUSE_MAX = 4          -- max seconds paused between walks
local WANDER_MARGIN = 4             -- studs from plot edge to keep crocs

-- LIMIT SHOP: how many crocs a player may keep in their plot.
--   DefaultLimit      = what every player starts with
--   MaxLimit          = hard cap, nobody can go above this
--   SetProcessReceipt = set to false if ANOTHER script already sets MarketplaceService.ProcessReceipt
--                       (then call the function CrocLimit.ProcessReceipt(info) from yours - it
--                       returns nil for products that aren't limit packs)
--   Packs: Id = any unique name your UI uses | Add = limit slots given
--          Coins = coin price (nil = not sold for coins)
--          ProductId = Developer Product id from the Creator Hub (0 = not sold for Robux)
--   PRICES AND PRODUCT IDS BELOW ARE PLACEHOLDERS, change them!
local LIMIT_CONFIG = {
	DefaultLimit = 5,
	MaxLimit = 50,
	DataStoreName = "CrocLimits_v1",
	SetProcessReceipt = true,
	Packs = {
		{ Id = "plus1",  Add = 1,  Coins = 2500,  ProductId = 0 },
		{ Id = "plus3",  Add = 3,  Coins = 10000, ProductId = 0 },
		{ Id = "plus5",  Add = 5,  Coins = 25000, ProductId = 0 },
		{ Id = "plus10", Add = 10, Coins = 75000, ProductId = 0 },
	},
}

-- ============================================================
-- STATE
-- ============================================================
local babies = {}     -- [model] = info
local carrying = {}   -- [player] = info of the baby they hold
local carriers = {}   -- [player] = tick() when they picked up (big croc targets these)
local banked = {}     -- [player] = { info, ... } crocs generating coins in their plot
local ragdolled = {}  -- [character] = true
local bigKeys = {}    -- ["Crocodile1"] = true, ... which big crocs exist (filled by setupBigCroc)

local registerBaby -- forward declaration
local resolveHunter -- forward declaration (called by pickUp, defined later)
local babyTemplates = {}           -- [model name] = pristine croc of that kind (so saved crocs come back as the right type)
local babyTemplate = nil           -- pristine croc model used for cloning banked crocs
local crocStore = DataStoreService:GetDataStore("BankedCrocs_v1")

-- server -> client notice: how many coins a player earned while offline
local offlineNotice = ReplicatedStorage:FindFirstChild("OfflineEarnings")
if not offlineNotice then
	offlineNotice = Instance.new("RemoteEvent")
	offlineNotice.Name = "OfflineEarnings"
	offlineNotice.Parent = ReplicatedStorage
end

-- ============================================================
-- HELPERS
-- ============================================================
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- The croc models use standard Roblox orientation: +Y = up, LookVector (-Z) = forward (head direction).
local function poseCFrame(position, forward)
	local f = flat(forward)
	if f.Magnitude < 1e-3 then
		f = Vector3.new(0, 0, -1)
	end
	f = f.Unit
	return CFrame.lookAt(position, position + f)
end

local function lowestY(model)
	local low = math.huge
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local cf, s = d.CFrame, d.Size
			local half = 0.5 * (math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z)
			low = math.min(low, cf.Position.Y - half)
		end
	end
	return low
end

-- The game has several objects named "leaderstats" on a player (other scripts add
-- their own), so find the one that actually holds Coins.
local function getCoinStat(player)
	for _, c in ipairs(player:GetChildren()) do
		if c.Name == "leaderstats" then
			local coins = c:FindFirstChild("Coins")
			if coins then
				return coins, c
			end
		end
	end
	return nil, nil
end

local function addCoins(player, amount)
	local coins = getCoinStat(player)
	if coins then
		coins.Value += amount
	end
end

-- Earnings multiplier: +50% per Rebirth, times the active Trials boost
local function earnMult(player)
	local rebirthMult = 1 + 0.5 * (player:GetAttribute("Rebirths") or 0)
	local trialMult = player:GetAttribute("TrialMult") or 1
	return rebirthMult * trialMult
end

-- ============================================================
-- LIMIT SHOP: how many crocs a player may keep in their plot
--  * everyone starts with LIMIT_CONFIG.DefaultLimit
--  * extra slots are bought with coins or Robux (Developer Products)
--  * purchased slots are saved per player (only the number of extra slots is saved)
--  * for your UI designer, everything is in ReplicatedStorage > LimitShop:
--      GetShopData    (RemoteFunction) invoke() -> { limit, default, max, packs = {{id, add, coins, productId}} }
--      BuyWithCoins   (RemoteFunction) invoke(packId) -> success, message
--      BuyWithRobux   (RemoteEvent)    FireServer(packId)  (opens the Robux purchase prompt)
--      LimitUpdated   (RemoteEvent)    server -> client (newLimit)
--      PurchaseResult (RemoteEvent)    server -> client (packId, success, message)
--    The current limit is also the player attribute "CrocLimit".
-- ============================================================
local CrocLimit = {}
local limitStore = DataStoreService:GetDataStore(LIMIT_CONFIG.DataStoreName)
local MAX_LIMIT_BONUS = LIMIT_CONFIG.MaxLimit - LIMIT_CONFIG.DefaultLimit
local limitProfiles = {} -- [player] = { data = { bonus, receipts }, canSave = bool }
local limitLastRequest = {}

local packById, packByProduct = {}, {}
for _, pack in ipairs(LIMIT_CONFIG.Packs) do
	packById[pack.Id] = pack
	if pack.ProductId and pack.ProductId > 0 then
		packByProduct[pack.ProductId] = pack
	end
end

local limitFolder = ReplicatedStorage:FindFirstChild("LimitShop") or Instance.new("Folder")
limitFolder.Name = "LimitShop"
limitFolder.Parent = ReplicatedStorage

local function makeRemote(class, name)
	local r = limitFolder:FindFirstChild(name) or Instance.new(class)
	r.Name = name
	r.Parent = limitFolder
	return r
end
local getShopData = makeRemote("RemoteFunction", "GetShopData")
local buyWithCoins = makeRemote("RemoteFunction", "BuyWithCoins")
local buyWithRobux = makeRemote("RemoteEvent", "BuyWithRobux")
local limitUpdated = makeRemote("RemoteEvent", "LimitUpdated")
local purchaseResult = makeRemote("RemoteEvent", "PurchaseResult")

local function limitDataKey(player)
	return "Player_" .. player.UserId
end

local function limitFor(bonus)
	return math.min(LIMIT_CONFIG.DefaultLimit + bonus, LIMIT_CONFIG.MaxLimit)
end

local function applyLimit(player)
	local profile = limitProfiles[player]
	local limit = profile and limitFor(profile.data.bonus) or LIMIT_CONFIG.DefaultLimit
	player:SetAttribute("CrocLimit", limit)
	limitUpdated:FireClient(player, limit)
end

local function loadLimitProfile(player)
	local ok, result
	for _ = 1, 3 do
		ok, result = pcall(limitStore.GetAsync, limitStore, limitDataKey(player))
		if ok then break end
		task.wait(1.5)
	end
	local data = { bonus = 0, receipts = {} }
	if ok and type(result) == "table" then
		data.bonus = math.clamp(tonumber(result.bonus) or 0, 0, MAX_LIMIT_BONUS)
		if type(result.receipts) == "table" then
			data.receipts = result.receipts
		end
	elseif not ok then
		warn("[CrocLimit] Couldn't load data for " .. player.Name .. ": " .. tostring(result))
	end
	return { data = data, canSave = ok }
end

local function saveLimit(player, data)
	local ok, err = pcall(limitStore.UpdateAsync, limitStore, limitDataKey(player), function()
		return data
	end)
	if not ok then
		warn("[CrocLimit] Save failed for " .. player.Name .. ": " .. tostring(err))
	end
	return ok
end

-- Adds slots and saves. Only changes the in-memory limit if the save worked.
local function grantLimit(player, amount, receiptId)
	local profile = limitProfiles[player]
	if not profile then return false end

	local newReceipts = table.clone(profile.data.receipts)
	if receiptId then
		table.insert(newReceipts, receiptId)
		while #newReceipts > 100 do
			table.remove(newReceipts, 1)
		end
	end
	local newData = { bonus = math.clamp(profile.data.bonus + amount, 0, MAX_LIMIT_BONUS), receipts = newReceipts }

	if profile.canSave then
		if not saveLimit(player, newData) then return false end
	elseif not RunService:IsStudio() then
		return false -- never hand out paid limits we can't save outside Studio
	end

	profile.data = newData
	applyLimit(player)
	return true
end

-- Public API
function CrocLimit.GetLimit(player)
	return player:GetAttribute("CrocLimit") or LIMIT_CONFIG.DefaultLimit
end

function CrocLimit.CanPlace(player, placedCount)
	return placedCount < CrocLimit.GetLimit(player)
end

-- For rewards, admin commands, gamepasses, etc.
function CrocLimit.AddLimit(player, amount)
	return grantLimit(player, amount, nil)
end

-- Resets purchased slots back to the default (used by the Rebirth system)
function CrocLimit.Reset(player)
	local profile = limitProfiles[player]
	if not profile then return false end
	profile.data = { bonus = 0, receipts = {} }
	if profile.canSave then
		saveLimit(player, profile.data)
	end
	applyLimit(player)
	return true
end

local function limitRateLimited(player)
	local now = os.clock()
	if limitLastRequest[player] and now - limitLastRequest[player] < 0.4 then return true end
	limitLastRequest[player] = now
	return false
end

local function spendCoins(player, amount)
	local coins = getCoinStat(player)
	if not coins or coins.Value < amount then return false end
	coins.Value -= amount
	return true
end

getShopData.OnServerInvoke = function(player)
	local packs = {}
	for _, pack in ipairs(LIMIT_CONFIG.Packs) do
		table.insert(packs, {
			id = pack.Id,
			add = pack.Add,
			coins = pack.Coins,
			productId = (pack.ProductId and pack.ProductId > 0) and pack.ProductId or nil,
		})
	end
	return {
		limit = CrocLimit.GetLimit(player),
		default = LIMIT_CONFIG.DefaultLimit,
		max = LIMIT_CONFIG.MaxLimit,
		packs = packs,
	}
end

buyWithCoins.OnServerInvoke = function(player, packId)
	if typeof(packId) ~= "string" or limitRateLimited(player) then return false, "Slow down!" end
	local pack = packById[packId]
	if not pack or not pack.Coins then return false, "That item isn't sold for coins." end
	if not limitProfiles[player] then return false, "Your data is still loading." end
	if CrocLimit.GetLimit(player) >= LIMIT_CONFIG.MaxLimit then return false, "You've reached the max limit!" end

	local coins = getCoinStat(player)
	if not coins then return false, "Couldn't read your coins." end
	if coins.Value < pack.Coins then return false, "Not enough coins!" end

	if not spendCoins(player, pack.Coins) then return false, "Not enough coins!" end
	if not grantLimit(player, pack.Add, nil) then
		addCoins(player, pack.Coins) -- refund
		return false, "Something went wrong, you were refunded."
	end
	return true, "Limit increased to " .. CrocLimit.GetLimit(player) .. "!"
end

buyWithRobux.OnServerEvent:Connect(function(player, packId)
	if typeof(packId) ~= "string" or limitRateLimited(player) then return end
	local pack = packById[packId]
	if not pack or not pack.ProductId or pack.ProductId <= 0 then
		purchaseResult:FireClient(player, packId, false, "That item isn't sold for Robux.")
		return
	end
	if not limitProfiles[player] then
		purchaseResult:FireClient(player, packId, false, "Your data is still loading.")
		return
	end
	if CrocLimit.GetLimit(player) >= LIMIT_CONFIG.MaxLimit then
		purchaseResult:FireClient(player, packId, false, "You've reached the max limit!")
		return
	end
	MarketplaceService:PromptProductPurchase(player, pack.ProductId)
end)

-- Returns nil if the product isn't a limit pack, so you can chain it from your own ProcessReceipt
function CrocLimit.ProcessReceipt(info)
	local pack = packByProduct[info.ProductId]
	if not pack then return nil end

	local player = Players:GetPlayerByUserId(info.PlayerId)
	local profile = player and limitProfiles[player]
	if not profile then return Enum.ProductPurchaseDecision.NotProcessedYet end

	local receiptId = tostring(info.PurchaseId)
	if table.find(profile.data.receipts, receiptId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already given
	end

	if grantLimit(player, pack.Add, receiptId) then
		purchaseResult:FireClient(player, pack.Id, true, "Limit increased to " .. CrocLimit.GetLimit(player) .. "!")
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

if LIMIT_CONFIG.SetProcessReceipt then
	MarketplaceService.ProcessReceipt = function(info)
		return CrocLimit.ProcessReceipt(info) or Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

local function onLimitPlayerAdded(player)
	player:SetAttribute("CrocLimit", LIMIT_CONFIG.DefaultLimit)
	local profile = loadLimitProfile(player)
	if player.Parent == nil then return end
	limitProfiles[player] = profile
	applyLimit(player)
	player:SetAttribute("CrocLimitLoaded", true)
end

Players.PlayerAdded:Connect(onLimitPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onLimitPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	limitProfiles[player] = nil
	limitLastRequest[player] = nil
end)

-- ============================================================
-- SIZE TIERS
-- ============================================================
local tierByName = {}
for _, t in ipairs(SIZE_TIERS) do
	tierByName[t.name] = t
end

local function babyNumber(name)
	local n = tonumber(name:match("^BabyCrocodile(%d+)$"))
	return n or 1
end

-- highest BabyCrocodile number in the game = the best odds
local maxBabyNumber = 1
for _, d in ipairs(Workspace:GetDescendants()) do
	if d:IsA("Model") then
		local n = tonumber(d.Name:match("^BabyCrocodile(%d+)$"))
		if n and n > maxBabyNumber then
			maxBabyNumber = n
		end
	end
end

-- 0 for BabyCrocodile1 up to 1 for the highest-numbered baby
local function luckFor(name)
	local n = babyNumber(name)
	if n > maxBabyNumber then
		maxBabyNumber = n
	end
	if maxBabyNumber <= 1 then
		return 0
	end
	return math.clamp((n - 1) / (maxBabyNumber - 1), 0, 1)
end

local function rollTier(name)
	local luck = luckFor(name)
	local weights, total = {}, 0
	for i, t in ipairs(SIZE_TIERS) do
		local w = t.weightLow + (t.weightHigh - t.weightLow) * luck
		weights[i] = w
		total += w
	end
	local r = math.random() * total
	for i, t in ipairs(SIZE_TIERS) do
		r -= weights[i]
		if r <= 0 then
			return t
		end
	end
	return SIZE_TIERS[1]
end

-- Resize a baby to a tier, keep its feet on the ground, and update its coin rate.
local TIERS_ENABLED = true
local function applyTier(info, tier)
	if not TIERS_ENABLED then
		info.rate = rateFor(info.model.Name)
		return
	end
	local model = info.model
	info.baseScale = info.baseScale or model:GetScale()
	local before = lowestY(model)
	model:ScaleTo(info.baseScale * tier.size)
	local after = lowestY(model)
	if before ~= math.huge and after ~= math.huge then
		model:PivotTo(model:GetPivot() + Vector3.new(0, before - after, 0))
	end
	local pivot = model:GetPivot()
	local bboxCF = model:GetBoundingBox()
	info.tier = tier
	info.home = pivot
	info.homeScale = model:GetScale()
	info.centerLocal = pivot:PointToObjectSpace(bboxCF.Position)
	info.homeGroundY = lowestY(model)
	info.rate = math.floor(rateFor(model.Name) * tier.coinMult + 0.5)
	model:SetAttribute("SizeTier", tier.name)
	model:SetAttribute("CoinMultiplier", tier.coinMult)
end

-- Label over an idle baby so players can see what they're about to grab.
local function addTierGui(info)
	local tier = info.tier
	if not tier or tier.coinMult == 1 then return end
	local model = info.model
	local root = model.PrimaryPart
	if not root then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				root = d
				break
			end
		end
	end
	if not root then return end

	local old = root:FindFirstChild("SizeTierGui")
	if old then old:Destroy() end

	local boxCF, boxSize = model:GetBoundingBox()
	local topY = boxCF.Position.Y + boxSize.Y / 2

	local gui = Instance.new("BillboardGui")
	gui.Name = "SizeTierGui"
	gui.Adornee = root
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(200, 32)
	gui.StudsOffsetWorldSpace = Vector3.new(0, topY - root.Position.Y + 2, 0)
	gui.MaxDistance = 120
	gui.Parent = root

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 20
	label.TextColor3 = tier.color
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Text = tier.name .. "  x" .. tier.coinMult .. " coins"
	label.Parent = gui
end

-- Optional "Crocs" leaderstat = how many crocs are in your base.
local function setupPlayer(player)
	task.spawn(function()
		local deadline = tick() + 30
		while player.Parent and tick() < deadline do
			local _, folder = getCoinStat(player)
			if folder then
				if not folder:FindFirstChild("Crocs") then
					local crocs = Instance.new("IntValue")
					crocs.Name = "Crocs"
					crocs.Value = 0
					crocs.Parent = folder
				end
				return
			end
			task.wait(0.5)
		end
	end)
end

-- ============================================================
-- PLOTS (bases)
-- ============================================================
local plots = {}
for _, m in ipairs(Workspace:GetDescendants()) do
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
			table.insert(plots, {
				model = m, minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ,
				cx = (minX + maxX) / 2, cz = (minZ + maxZ) / 2,
			})
		end
	end
end

-- Different games mark plot ownership differently, so accept several common forms:
-- an attribute or a child value named Owner / OwnerName / OwnerId / OwnerUserId / Player / PlayerName,
-- holding a name, a UserId, or the Player itself.
local OWNER_KEYS = { "Owner", "OwnerName", "OwnerId", "OwnerUserId", "Player", "PlayerName" }

local function ownerMatches(v, player)
	local t = typeof(v)
	if t == "string" then
		return v == player.Name or v == player.DisplayName or v == tostring(player.UserId)
	elseif t == "number" then
		return v == player.UserId
	elseif t == "Instance" then
		return v == player
	end
	return false
end

local function plotOwnedBy(model, player)
	for _, key in ipairs(OWNER_KEYS) do
		local a = model:GetAttribute(key)
		if a ~= nil and ownerMatches(a, player) then
			return true
		end
		local c = model:FindFirstChild(key)
		if c and c:IsA("ValueBase") and ownerMatches(c.Value, player) then
			return true
		end
	end
	return false
end

local function plotHasOwner(model)
	for _, key in ipairs(OWNER_KEYS) do
		local a = model:GetAttribute(key)
		if a ~= nil and a ~= "" and a ~= 0 then
			return true
		end
		local c = model:FindFirstChild(key)
		if c and c:IsA("ValueBase") and c.Value ~= nil and c.Value ~= "" and c.Value ~= 0 then
			return true
		end
	end
	return false
end

local function getPlotFor(player)
	for _, pd in ipairs(plots) do
		if plotOwnedBy(pd.model, player) then
			return pd
		end
	end
	return nil
end

local function insidePlot(pd, pos)
	return pos.X >= pd.minX and pos.X <= pd.maxX and pos.Z >= pd.minZ and pos.Z <= pd.maxZ
end

local function plotAt(pos)
	for _, pd in ipairs(plots) do
		if insidePlot(pd, pos) then
			return pd
		end
	end
	return nil
end

-- Plot a player may bank into. Normally their own plot; if the game never marks
-- plot owners at all, fall back to whichever plot they are standing in.
local function bankPlotFor(player, pos)
	local pd = getPlotFor(player)
	if pd then
		return insidePlot(pd, pos) and pd or nil
	end
	for _, p in ipairs(plots) do
		if plotHasOwner(p.model) then
			return nil -- owners exist but none is this player's: don't bank in someone else's plot
		end
	end
	return plotAt(pos)
end

local function slotPosition(pd, index)
	local i = index - 1
	local col = i % SLOT_COLS
	local row = math.floor(i / SLOT_COLS) % SLOT_ROWS
	return pd.cx + (col - (SLOT_COLS - 1) / 2) * SLOT_SPACING_X,
		pd.cz + (row - (SLOT_ROWS - 1) / 2) * SLOT_SPACING_Z
end

local function groundYAt(x, z, ignoreModel)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true -- ignore decorations and other non-solid parts
	local exclude = { ignoreModel }
	for m in pairs(babies) do
		table.insert(exclude, m)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	-- start just above the croc itself (not a fixed height) so high walls/roofs can't be hit
	local startY = ignoreModel and (ignoreModel:GetPivot().Position.Y + 8) or 40
	local hit = Workspace:Raycast(Vector3.new(x, startY, z), Vector3.new(0, -250, 0), params)
	return hit and hit.Position.Y or nil
end

-- ============================================================
-- SAFE ZONES (the big croc never chases into or enters these)
-- ============================================================
local safeBoxes = {} -- extra safe zones found by name: { cf, size }

for _, d in ipairs(Workspace:GetDescendants()) do
	local n = d.Name:lower()
	if n:find("safezone", 1, true) or n:find("safe zone", 1, true) or n:find("safe_zone", 1, true) then
		if d:IsA("BasePart") then
			table.insert(safeBoxes, { cf = d.CFrame, size = d.Size })
		elseif d:IsA("Model") then
			local cf, size = d:GetBoundingBox()
			table.insert(safeBoxes, { cf = cf, size = size })
		end
	end
end

local function boxContains(cf, size, pos, extra)
	local lp = cf:PointToObjectSpace(pos)
	return math.abs(lp.X) <= size.X / 2 + extra
		and math.abs(lp.Z) <= size.Z / 2 + extra
		and math.abs(lp.Y) <= size.Y / 2 + 40 -- generous height so standing on a thin part still counts
end

-- `extra` widens every zone (the croc uses this to keep its whole body outside).
local function inSafeZone(pos, extra)
	extra = extra or 0
	local pad = SAFE_PAD + extra
	for _, pd in ipairs(plots) do
		if pos.X >= pd.minX - pad and pos.X <= pd.maxX + pad
			and pos.Z >= pd.minZ - pad and pos.Z <= pd.maxZ + pad then
			return true
		end
	end
	for _, b in ipairs(safeBoxes) do
		if boxContains(b.cf, b.size, pos, extra) then
			return true
		end
	end
	for _, t in ipairs(CollectionService:GetTagged("SafeZone")) do
		if t:IsA("BasePart") and boxContains(t.CFrame, t.Size, pos, extra) then
			return true
		end
	end
	return false
end

-- ============================================================
-- BABY CROC: carry / return / bank
-- ============================================================

-- Undo everything attachToPlayer did (welds, collision, anchoring, joints).
local function detach(info)
	if info.carryObjects then
		for _, o in ipairs(info.carryObjects) do
			o:Destroy()
		end
		info.carryObjects = nil
	end
	if info.partStates then
		for part, st in pairs(info.partStates) do
			if part.Parent then
				part.Anchored = true
				part.CanCollide = st.CanCollide
				part.CanTouch = st.CanTouch
				part.Massless = st.Massless
			end
		end
		info.partStates = nil
	end
	if info.jointStates then
		for joint, enabled in pairs(info.jointStates) do
			if joint.Parent then
				joint.Enabled = enabled
			end
		end
		info.jointStates = nil
	end
end

local function attachToPlayer(info, hrp)
	local model = info.model
	local look = hrp.CFrame.LookVector

	-- shrink + pose above the player's head while everything is still anchored
	model:ScaleTo(info.homeScale * CARRY_SCALE)
	local rot = poseCFrame(Vector3.zero, look)
	local center = hrp.Position + Vector3.new(0, CARRY_HEIGHT, 0)
	local pivotPos = center - rot:VectorToWorldSpace(info.centerLocal * CARRY_SCALE)
	model:PivotTo(poseCFrame(pivotPos, look))

	-- weld every part to one root part, weld the root to the player, then unanchor
	local parts = {}
	info.partStates, info.jointStates = {}, {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			info.jointStates[d] = d.Enabled
			d.Enabled = false
		end
	end

	local root = parts[1]
	local objects = {}
	for _, p in ipairs(parts) do
		info.partStates[p] = { CanCollide = p.CanCollide, CanTouch = p.CanTouch, Massless = p.Massless }
		p.CanCollide = false
		p.CanTouch = false
		p.Massless = true
		if p ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = p
			w.Parent = root
			table.insert(objects, w)
		end
	end
	local carryWeld = Instance.new("WeldConstraint")
	carryWeld.Part0 = hrp
	carryWeld.Part1 = root
	carryWeld.Parent = root
	table.insert(objects, carryWeld)
	info.carryObjects = objects

	for _, p in ipairs(parts) do
		p.Anchored = false
	end

	-- TEMP DEBUG
	task.delay(0.6, function()
		local r = parts[1]
		print("[CARRYDBG] root=" .. r.Name .. " pos=" .. tostring(r.Position) .. " hrp=" .. tostring(hrp.Position))
		for _, p in ipairs(parts) do
			local ar = p.AssemblyRootPart
			print(string.format("[CARRYDBG]  %s anch=%s pos=%s assembly=%s owner=%s", p.Name, tostring(p.Anchored), tostring(p.Position), ar and ar:GetFullName() or "nil", "-"))
		end
		for _, o in ipairs(objects) do
			print("[CARRYDBG]  weld " .. tostring(o.Part0 and o.Part0.Name) .. "->" .. tostring(o.Part1 and o.Part1.Name) .. " enabled=" .. tostring(o.Enabled) .. " active=" .. tostring(o.Active))
		end
	end)
end

local storeIdleCroc, storeBankedCroc, addToInventory -- forward declarations (defined in the INVENTORY section below)

-- Small on-screen notice shown to one player.
local lastFullNotice = setmetatable({}, { __mode = "k" })
local function notify(player, text)
	local now = tick()
	if lastFullNotice[player] and now - lastFullNotice[player] < 1.5 then return end
	lastFullNotice[player] = now

	local pg = player:FindFirstChildOfClass("PlayerGui")
	if not pg then return end

	local oldNotice = pg:FindFirstChild("PlotFullNotice")
	if oldNotice then oldNotice:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "PlotFullNotice"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.12)
	label.Size = UDim2.fromOffset(440, 46)
	label.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	label.BackgroundTransparency = 0.2
	label.Font = Enum.Font.GothamBold
	label.TextSize = 22
	label.TextColor3 = Color3.fromRGB(255, 110, 110)
	label.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	label.Parent = gui
	gui.Parent = pg

	task.delay(2.5, function()
		gui:Destroy()
	end)
end

local function pickUp(player, info)
	-- a croc standing in your plot: pressing the prompt puts it in your inventory
	if info.state == "banked" then
		storeBankedCroc(player, info)
		return
	end
	if info.state ~= "idle" or carrying[player] then return end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 or ragdolled[char] then return end

	info.state = "carried"
	info.carrier = player
	resolveHunter(info)
	info.prompt.Enabled = false
	carrying[player] = info
	task.delay(1.7, function()
		if carrying[player] == info then
			carriers[player] = tick()
		end
	end)
	attachToPlayer(info, hrp)
end

-- Place a baby croc on the ground at (x, z) facing `forward`
local function placeCrocOnGround(info, x, z, forward)
	local model = info.model
	local gy = groundYAt(x, z, model)
	-- The plot floor is flat. If the ray hit something well above/below the floor this
	-- croc already stands on (a fence rail, a ledge...), ignore it and stay on the floor.
	if info.floorY then
		if not gy or math.abs(gy - info.floorY) > 1.5 then
			gy = info.floorY
		end
	else
		gy = gy or info.homeGroundY
		info.floorY = gy
	end
	local rot = poseCFrame(Vector3.zero, forward)
	local center = Vector3.new(x, gy + 2, z)
	model:PivotTo(poseCFrame(center - rot:VectorToWorldSpace(info.centerLocal), forward))
	model:PivotTo(model:GetPivot() + Vector3.new(0, gy - lowestY(model), 0))
end

-- Start a wandering loop for a banked baby croc inside its plot
local function startWandering(info, pd)
	if info.wandering then return end
	info.wandering = true
	task.spawn(function()
		local model = info.model
		while info.wandering and info.state == "banked" and model.Parent do
			-- pick a random target inside the plot (clamped so tiny plots still work)
			local rangeX = math.max(0, pd.maxX - pd.minX - 2 * WANDER_MARGIN)
			local rangeZ = math.max(0, pd.maxZ - pd.minZ - 2 * WANDER_MARGIN)
			local rx = pd.minX + WANDER_MARGIN + math.random() * rangeX
			local rz = pd.minZ + WANDER_MARGIN + math.random() * rangeZ
			local targetPos = Vector3.new(rx, 0, rz)

			-- walk toward target
			while info.wandering and info.state == "banked" and model.Parent do
				local cur = model:GetPivot().Position
				local remaining = flat(targetPos - cur)
				if remaining.Magnitude < 1 then break end
				local moveDir = remaining.Unit
				local step = math.min(WANDER_SPEED * 0.05, remaining.Magnitude)
				local nx = cur.X + moveDir.X * step
				local nz = cur.Z + moveDir.Z * step
				placeCrocOnGround(info, nx, nz, moveDir)
				task.wait(0.05)
			end

			-- pause before picking a new destination
			local pause = WANDER_PAUSE_MIN + math.random() * (WANDER_PAUSE_MAX - WANDER_PAUSE_MIN)
			task.wait(pause)
		end
	end)
end

local function stopWandering(info)
	info.wandering = false
end

-- Put the baby back where it originally stood.
local function returnHome(info)
	print("[CARRYDBG] returnHome called for " .. info.model.Name .. " state=" .. tostring(info.state) .. "\n" .. debug.traceback())
	local player = info.carrier
	stopWandering(info)
	detach(info)
	if player then
		if carrying[player] == info then
			carrying[player] = nil
		end
		carriers[player] = nil
	end
	info.carrier = nil
	info.model:ScaleTo(info.homeScale)
	info.model:PivotTo(info.home)
	info.state = "idle"
	info.prompt.Enabled = true
end

local function spawnReplacement(info)
	local clone = info.template:Clone()
	clone.Parent = info.parent or Workspace
	registerBaby(clone, info.template)
end

-- Floating label above a banked croc showing how many coins it earns each second.
local function addRateGui(info)
	local model = info.model
	local root = model.PrimaryPart
	if not root then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				root = d
				break
			end
		end
	end
	if not root then return end

	local old = root:FindFirstChild("CoinRateGui")
	if old then old:Destroy() end
	local tierGui = root:FindFirstChild("SizeTierGui")
	if tierGui then tierGui:Destroy() end

	-- sit a couple of studs above the top of the croc (yaw-only rotation keeps this valid while it wanders)
	local boxCF, boxSize = model:GetBoundingBox()
	local topY = boxCF.Position.Y + boxSize.Y / 2

	local gui = Instance.new("BillboardGui")
	gui.Name = "CoinRateGui"
	gui.Adornee = root
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(240, 36)
	gui.StudsOffsetWorldSpace = Vector3.new(0, topY - root.Position.Y + 2, 0)
	gui.MaxDistance = 150
	gui.Parent = root

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 22
	label.TextColor3 = Color3.fromRGB(255, 214, 64)
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Text = "+" .. (info.rate or COINS_PER_CROC_PER_SECOND) .. " coins/s"
	if info.tier and info.tier.coinMult ~= 1 then
		label.Text ..= " (" .. info.tier.name .. ")"
		label.TextColor3 = info.tier.color
	end
	label.Parent = gui
end

-- A banked croc's prompt lets its owner put it in their inventory.
local function setStorePrompt(prompt)
	if not prompt then return end
	prompt.ActionText = "Put in Inventory"
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true
end

local function bankBaby(player, info, pd)
	local model = info.model
	detach(info)
	carrying[player] = nil
	carriers[player] = nil
	info.carrier = nil
	info.state = "banked"
	info.owner = player
	setStorePrompt(info.prompt)

	model:ScaleTo(info.homeScale)

	local list = banked[player]
	if not list then
		list = {}
		banked[player] = list
	end
	table.insert(list, info)

	-- stand it on the ground in the next free slot of the plot
	local x, z = slotPosition(pd, #list)
	local groundY = groundYAt(x, z, model) or info.homeGroundY
	info.floorY = groundY
	local forward = Vector3.new(0, 0, 1)
	local rot = poseCFrame(Vector3.zero, forward)
	local center = Vector3.new(x, groundY + 2, z)
	model:PivotTo(poseCFrame(center - rot:VectorToWorldSpace(info.centerLocal), forward))
	model:PivotTo(model:GetPivot() + Vector3.new(0, groundY - lowestY(model), 0))

	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end

	local _, statsFolder = getCoinStat(player)
	local crocsStat = statsFolder and statsFolder:FindFirstChild("Crocs")
	if crocsStat then
		crocsStat.Value = #list
	end

	startWandering(info, pd)
	addRateGui(info)

	task.delay(REPLACEMENT_DELAY, function()
		spawnReplacement(info)
	end)
end

local function spawnBankedCroc(player, pd, typeName, tierName)
	local source = babyTemplates[typeName] or babyTemplate
	if not source then return nil end
	local clone = source:Clone()
	clone.Parent = Workspace
	clone:SetAttribute("CrocType", "Little")

	local prompt = clone:FindFirstChild("StealCrocPrompt", true)
	local pivot = clone:GetPivot()
	local bboxCF = clone:GetBoundingBox()
	local info = {
		model = clone,
		prompt = prompt,
		template = babyTemplate,
		parent = Workspace,
		home = pivot,
		homeScale = clone:GetScale(),
		centerLocal = pivot:PointToObjectSpace(bboxCF.Position),
		homeGroundY = lowestY(clone),
		state = "banked",
		owner = player,
		rate = rateFor(clone.Name),
	}
	babies[clone] = info
	applyTier(info, tierByName[tierName] or SIZE_TIERS[1])

	if prompt then
		setStorePrompt(prompt)
		prompt.Triggered:Connect(function(p)
			pickUp(p, info)
		end)
	end

	clone:ScaleTo(info.homeScale)

	local list = banked[player]
	if not list then
		list = {}
		banked[player] = list
	end
	table.insert(list, info)

	-- place in the next free slot
	local x, z = slotPosition(pd, #list)
	placeCrocOnGround(info, x, z, Vector3.new(0, 0, 1))

	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end

	startWandering(info, pd)
	addRateGui(info)

	return info
end

local function restoreBankedCrocs(player)
	task.spawn(function()
		-- wait for the player's plot to be assigned (up to 30s)
		local deadline = tick() + 30
		local pd
		while player.Parent and tick() < deadline do
			pd = getPlotFor(player)
			if pd then break end
			task.wait(0.5)
		end
		if not pd or not player.Parent then return end

		-- load saved croc count
		-- load saved crocs. Old saves were just a number of basic crocs; new saves are
		-- a list of croc names (so a BabyCrocodile2 comes back as a BabyCrocodile2).
		local saved
		local ok = pcall(function()
			saved = crocStore:GetAsync(tostring(player.UserId))
		end)
		if not ok or not saved then return end

		-- New saves are { crocs = { names }, lastSeen = os.time() }; old saves were
		-- a bare number or a bare array of names.
		local names, lastSeen = {}, nil
		if type(saved) == "number" then
			for _ = 1, saved do
				table.insert(names, "BabyCrocodile")
			end
		elseif type(saved) == "table" then
			if typeof(saved.crocs) == "table" then
				names = saved.crocs
				lastSeen = tonumber(saved.lastSeen)
			else
				names = saved
			end
		end
		if #names <= 0 then return end

		-- wait until the player's bought limit has loaded, otherwise someone with
		-- more than the default saved crocs would have the extras pushed to inventory
		local limitDeadline = tick() + 20
		while player.Parent and not player:GetAttribute("CrocLimitLoaded") and tick() < limitDeadline do
			task.wait(0.25)
		end
		if not player.Parent then return end

		local count = math.min(#names, CrocLimit.GetLimit(player))

		-- OFFLINE EARNINGS: pay the banked crocs' rate for time away (capped)
		if lastSeen and player.Parent then
			local offline = math.clamp(os.time() - lastSeen, 0, OFFLINE_CAP_SECONDS)
			if offline >= 30 then
				local rate = 0
				for i = 1, count do
					local typeName, tierName = tostring(names[i]):match("^(.-)|(.+)$")
					local r = rateFor(typeName or tostring(names[i]))
					local tier = tierByName[tierName]
					if TIERS_ENABLED and tier then
						r = math.floor(r * tier.coinMult + 0.5)
					end
					rate += r
				end
				if rate > 0 then
					local earned = math.floor(rate * offline * earnMult(player) + 0.5)
					addCoins(player, earned)
					offlineNotice:FireClient(player, earned, offline)
				end
			end
		end

		for i = 1, count do
			-- saves look like "BabyCrocodile3|Giant" (older saves are just the name)
			local typeName, tierName = tostring(names[i]):match("^(.-)|(.+)$")
			spawnBankedCroc(player, pd, typeName or names[i], tierName)
		end

		-- anything over the limit goes to the inventory instead of being lost
		for i = count + 1, #names do
			local typeName, tierName = tostring(names[i]):match("^(.-)|(.+)$")
			typeName = typeName or tostring(names[i])
			local rate = rateFor(typeName)
			local tier = tierByName[tierName]
			if TIERS_ENABLED and tier then
				rate = math.floor(rate * tier.coinMult + 0.5)
			end
			addToInventory(player, typeName, tierName, rate)
		end

		-- update leaderstat
		local _, statsFolder = getCoinStat(player)
		local crocsStat = statsFolder and statsFolder:FindFirstChild("Crocs")
		if crocsStat then
			crocsStat.Value = count
		end
	end)
end

-- ============================================================
-- INVENTORY: crocs a player holds as Backpack tools
--  * Picking up a croc while your plot is full stores it here.
--  * Pressing the prompt on a croc in your own plot stores it here.
--  * Equip the tool and click while standing in your plot to place it.
-- Tool name: "<BabyCrocodile name> (+<coins> coins/s)".
-- ============================================================
local inventory = {} -- [player] = { entry, ... }, entry = { typeName, tierName, rate, tool }

local function entryName(entry)
	return entry.typeName .. " (+" .. entry.rate .. " coins/s)"
end

local function updateCrocsStat(player)
	local _, statsFolder = getCoinStat(player)
	local crocsStat = statsFolder and statsFolder:FindFirstChild("Crocs")
	if crocsStat then
		local list = banked[player]
		crocsStat.Value = list and #list or 0
	end
end

-- While an inventory croc is equipped, show a small copy of it above the player's head
-- (like carrying it) with a label of how many coins per second it makes.
local function hideHeldCroc(entry)
	if entry.held then
		entry.held:Destroy()
		entry.held = nil
	end
end

local function showHeldCroc(player, entry)
	hideHeldCroc(entry)

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local source = babyTemplates[entry.typeName] or babyTemplate
	if not hrp or not source then return end

	local visual = source:Clone()
	visual.Name = "HeldCroc"
	for _, d in ipairs(visual:GetDescendants()) do
		if d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("BaseScript") then
			d:Destroy()
		end
	end

	-- same size as the tier it was (x the carry scale)
	local tier = tierByName[entry.tierName]
	local scale = visual:GetScale()
	if TIERS_ENABLED and tier then
		scale = scale * tier.size
	end
	visual:ScaleTo(scale * CARRY_SCALE)

	-- pose it centred above the head
	local pivot = visual:GetPivot()
	local bboxCF = visual:GetBoundingBox()
	local centerLocal = pivot:PointToObjectSpace(bboxCF.Position)
	local look = hrp.CFrame.LookVector
	local rot = poseCFrame(Vector3.zero, look)
	local center = hrp.Position + Vector3.new(0, CARRY_HEIGHT, 0)
	visual:PivotTo(poseCFrame(center - rot:VectorToWorldSpace(centerLocal), look))

	-- weld everything to one root part, and that root to the player
	local parts = {}
	for _, d in ipairs(visual:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			d.Enabled = false
		end
	end
	local root = parts[1]
	if not root then
		visual:Destroy()
		return
	end
	for _, p in ipairs(parts) do
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		if p ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = p
			w.Parent = root
		end
	end
	local carryWeld = Instance.new("WeldConstraint")
	carryWeld.Part0 = hrp
	carryWeld.Part1 = root
	carryWeld.Parent = root

	-- coins-per-second label above it
	local boxCF, boxSize = visual:GetBoundingBox()
	local topY = boxCF.Position.Y + boxSize.Y / 2
	local gui = Instance.new("BillboardGui")
	gui.Name = "HeldCrocRateGui"
	gui.Adornee = root
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(240, 36)
	gui.StudsOffsetWorldSpace = Vector3.new(0, topY - root.Position.Y + 1.5, 0)
	gui.MaxDistance = 150
	gui.Parent = root

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 22
	label.TextColor3 = Color3.fromRGB(255, 214, 64)
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Text = "+" .. entry.rate .. " coins/s"
	if TIERS_ENABLED and tier and tier.coinMult ~= 1 then
		label.Text ..= " (" .. tier.name .. ")"
		label.TextColor3 = tier.color
	end
	label.Parent = gui

	for _, p in ipairs(parts) do
		p.Anchored = false
	end
	visual.Parent = char
	entry.held = visual
end

local function removeEntry(player, entry)
	hideHeldCroc(entry)
	local list = inventory[player]
	if list then
		local i = table.find(list, entry)
		if i then
			table.remove(list, i)
		end
	end
	if entry.tool then
		entry.tool:Destroy()
		entry.tool = nil
	end
end

local function placeFromInventory(player, entry)
	if entry.busy then return end
	entry.busy = true

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local pd = hrp and bankPlotFor(player, hrp.Position)
	if not pd then
		notify(player, "Stand inside your plot to place this crocodile")
		entry.busy = false
		return
	end

	local owned = banked[player]
	local limit = CrocLimit.GetLimit(player)
	if owned and #owned >= limit then
		notify(player, "Your plot is full! (" .. limit .. "/" .. limit .. " crocodiles) - buy more space in the Limit Shop!")
		entry.busy = false
		return
	end

	if not spawnBankedCroc(player, pd, entry.typeName, entry.tierName) then
		entry.busy = false
		return
	end
	removeEntry(player, entry)
	updateCrocsStat(player)
end

local function giveTool(player, entry)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack then return end
	if entry.tool then
		hideHeldCroc(entry)
		entry.tool:Destroy()
	end

	local tool = Instance.new("Tool")
	tool.Name = entryName(entry)
	tool.ToolTip = "Click while standing in your plot to place it"
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool:SetAttribute("StoredCroc", entry.typeName)
	tool.Activated:Connect(function()
		placeFromInventory(player, entry)
	end)
	tool.Equipped:Connect(function()
		showHeldCroc(player, entry)
	end)
	tool.Unequipped:Connect(function()
		hideHeldCroc(entry)
	end)
	tool.Destroying:Connect(function()
		hideHeldCroc(entry)
	end)
	tool.Parent = backpack
	entry.tool = tool
end

function addToInventory(player, typeName, tierName, rate)
	local list = inventory[player]
	if not list then
		list = {}
		inventory[player] = list
	end
	local entry = { typeName = typeName, tierName = tierName or "Normal", rate = rate or rateFor(typeName) }
	table.insert(list, entry)
	giveTool(player, entry)
	return entry
end

-- A croc standing at its spawn spot (plot full): take it, a new one respawns later.
function storeIdleCroc(player, info)
	if info.state ~= "idle" and info.state ~= "carried" then return end
	if info.state == "carried" then
		-- reached the plot while carrying: let go of it first
		detach(info)
		if carrying[player] == info then
			carrying[player] = nil
		end
		carriers[player] = nil
		info.carrier = nil
	end
	info.state = "stored"

	local model = info.model
	local entry = addToInventory(player, model.Name, info.tier and info.tier.name, info.rate)
	babies[model] = nil
	model:Destroy()

	task.delay(REPLACEMENT_DELAY, function()
		spawnReplacement(info)
	end)

	notify(player, "Added to inventory: " .. entryName(entry))
end

-- A croc living in the player's own plot: take it back into the inventory.
function storeBankedCroc(player, info)
	if info.state ~= "banked" or info.owner ~= player then return end
	local list = banked[player]
	local i = list and table.find(list, info)
	if not i then return end
	table.remove(list, i)

	info.state = "stored"
	info.wandering = false
	local model = info.model
	local entry = addToInventory(player, model.Name, info.tier and info.tier.name, info.rate)
	babies[model] = nil
	model:Destroy()

	updateCrocsStat(player)
	notify(player, "Added to inventory: " .. entryName(entry))
end

local function loadInventory(player)
	-- Backpack tools are wiped when the character respawns, so hand them out again
	player.CharacterAdded:Connect(function()
		task.delay(0.5, function()
			for _, entry in ipairs(inventory[player] or {}) do
				giveTool(player, entry)
			end
		end)
	end)

	task.spawn(function()
		local saved
		local ok = pcall(function()
			saved = crocStore:GetAsync(tostring(player.UserId) .. "_inv")
		end)
		if not ok or type(saved) ~= "table" or not player.Parent then return end

		for _, s in ipairs(saved) do
			local typeName, tierName = tostring(s):match("^(.-)|(.+)$")
			if typeName then
				local rate = rateFor(typeName)
				local tier = tierByName[tierName]
				if TIERS_ENABLED and tier then
					rate = math.floor(rate * tier.coinMult + 0.5)
				end
				addToInventory(player, typeName, tierName, rate)
			end
		end
	end)
end

-- Which big croc hunts the thief of this baby? BabyCrocodile -> Crocodile1,
-- BabyCrocodile2 -> Crocodile2, BabyCrocodile3 -> Crocodile3, ...
-- If that exact croc isn't in the game, the baby falls back to the strongest
-- (highest-numbered) big croc that DOES exist - still only ONE hunter chases.
local function hunterFor(model)
	local n = model.Name:match("^BabyCrocodile(%d*)$")
	if n == nil then
		return nil
	end
	if n == "" then
		n = "1"
	end
	return "Crocodile" .. n
end

-- Called at pickup: pins this baby to one specific, existing big croc.
resolveHunter = function(info)
	if info.hunter and bigKeys[info.hunter] then
		return
	end
	local best, bestN = nil, -1
	for key in pairs(bigKeys) do
		local n = tonumber(key:match("Crocodile(%d+)")) or 0
		if n > bestN then
			best, bestN = key, n
		end
	end
	info.hunter = best
end

function registerBaby(model, template)
	local prompt = model:FindFirstChild("StealCrocPrompt", true)
	if not prompt or babies[model] then return end

	-- Babies never collide with anything, so players can't bump into them and speed-glitch.
	-- (Done before the pristine template copy below, so respawned babies are collision-free too.)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end

	local pivot = model:GetPivot()

	local bboxCF = model:GetBoundingBox()
	local info = {
		model = model,
		prompt = prompt,
		template = template or model:Clone(), -- pristine copy used for respawns
		parent = model.Parent,
		home = pivot,
		homeScale = model:GetScale(),
		centerLocal = pivot:PointToObjectSpace(bboxCF.Position),
		homeGroundY = lowestY(model),
		state = "idle",
		hunter = hunterFor(model),
		rate = rateFor(model.Name),
	}
	babies[model] = info

	if not babyTemplates[model.Name] then
		babyTemplates[model.Name] = info.template
	end

	if not babyTemplate then
		babyTemplate = template or model:Clone()
	end

	applyTier(info, rollTier(model.Name))
	addTierGui(info)

	prompt.Triggered:Connect(function(player)
		pickUp(player, info)
	end)
end

-- ============================================================
-- RAGDOLL
-- ============================================================
local function ragdollPlayer(player, fromPos)
	local char = player.Character
	if not char or ragdolled[char] then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp or humanoid.Health <= 0 then return end
	ragdolled[char] = true

	local created, disabled = {}, {}
	local oldRequiresNeck = humanoid.RequiresNeck
	humanoid.RequiresNeck = false
	humanoid.PlatformStand = true
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	for _, m in ipairs(char:GetDescendants()) do
		if m:IsA("Motor6D") and m.Part0 and m.Part1 and m.Name ~= "Root" and m.Name ~= "RootJoint" then
			local a0 = Instance.new("Attachment")
			a0.Name = "RagdollA0"
			a0.CFrame = m.C0
			a0.Parent = m.Part0
			local a1 = Instance.new("Attachment")
			a1.Name = "RagdollA1"
			a1.CFrame = m.C1
			a1.Parent = m.Part1
			local socket = Instance.new("BallSocketConstraint")
			socket.Name = "RagdollSocket"
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.LimitsEnabled = true
			socket.UpperAngle = 60
			socket.TwistLimitsEnabled = true
			socket.TwistLowerAngle = -45
			socket.TwistUpperAngle = 45
			socket.Parent = m.Part0
			m.Enabled = false
			table.insert(created, a0)
			table.insert(created, a1)
			table.insert(created, socket)
			table.insert(disabled, m)
		end
	end

	-- knock the player away from the croc
	local away = flat(hrp.Position - fromPos)
	if away.Magnitude < 0.1 then
		away = flat(hrp.CFrame.LookVector)
	end
	-- The player's client normally owns its character physics and overrides any velocity
	-- the server sets. Take ownership on the server so the fling actually applies.
	pcall(function()
		hrp:SetNetworkOwner(nil)
	end)
	hrp.AssemblyLinearVelocity = away.Unit * RAGDOLL_PUSH + Vector3.new(0, RAGDOLL_LIFT, 0)

	task.delay(RAGDOLL_TIME, function()
		ragdolled[char] = nil
		if hrp.Parent then
			pcall(function()
				hrp:SetNetworkOwnershipAuto()
			end)
		end
		for _, inst in ipairs(created) do
			inst:Destroy()
		end
		for _, m in ipairs(disabled) do
			if m.Parent then
				m.Enabled = true
			end
		end
		if humanoid.Parent and hrp.Parent and humanoid.Health > 0 then
			local p = hrp.Position + Vector3.new(0, 2, 0)
			local look = flat(hrp.CFrame.LookVector)
			if look.Magnitude < 0.1 then
				look = Vector3.new(0, 0, -1)
			end
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
			hrp.CFrame = CFrame.lookAt(p, p + look)
			humanoid.PlatformStand = false
			humanoid.RequiresNeck = oldRequiresNeck
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

-- Big croc touched a carrier: baby goes home, player gets ragdolled.
local function catchPlayer(player, fromPos)
	local info = carrying[player]
	carriers[player] = nil
	if info then
		returnHome(info)
	end
	ragdollPlayer(player, fromPos)
end

-- ============================================================
-- BIG CROC AI (Crocodile1 & Crocodile2)
-- ============================================================
local function setupBigCroc(bigModel, runSpeed, huntSpeed, bigKey)
	if not bigModel then return end
	bigKeys[bigKey] = true

	local bigHome = bigModel:GetPivot()
	local bigHomePos = bigHome.Position
	local bigY = bigHomePos.Y
	local bboxCF, bboxSize = bigModel:GetBoundingBox()
	local bigHalf = bboxSize / 2
	local bigCenterLocal = bigHome:PointToObjectSpace(bboxCF.Position)

	-- AI tuning
	local HUNT_SPEED = huntSpeed           -- cruising speed while hunting from far away
	local RUN_SPEED = runSpeed             -- burst speed when close
	local BURST_DISTANCE = 30       -- studs: inside this it bursts
	local ACCEL = 45                -- studs/sec^2
	local TURN_RATE = math.rad(720) -- radians/sec (fast, so it keeps facing a speeding player)
	local LEAD_TIME_MAX = 0.5       -- seconds of target prediction
	local RETARGET_MARGIN = 0.6     -- a new carrier must be 40% closer to steal focus
	local STUCK_TIME = 2.5          -- seconds without progress = stuck
	local IGNORE_TIME = 6           -- seconds to ignore a target it can't reach
	local LEASH_DISTANCE = math.huge -- never gives up just because the player is far away
	local REPATH_INTERVAL = 0.5
	local LOS_HEIGHT = 2            -- ray height for line-of-sight; raise if wall steps block it wrongly

	local forward = flat(bigHome.LookVector)
	local speed = 0
	local busyUntil = 0
	local atHome = true
	local target = nil
	local ignoreUntil = {}
	local visible = true
	local waypoints, wpIndex = nil, 1
	local pathBusy = false
	local lastRepath = 0
	local lastProgressPos, lastProgressTime = bigHomePos, tick()

	-- keeps the croc's whole body outside plots / safe zones, and a player on the edge out of catch range
	local zoneMargin = math.max(bigHalf.X, bigHalf.Z) + CATCH_DISTANCE + 2

	local path = PathfindingService:CreatePath({
		AgentRadius = 4, -- tune to roughly half the croc's width; too big = paths fail
		AgentHeight = 5,
		AgentCanJump = false,
		WaypointSpacing = 6,
	})

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local function refreshFilter()
		local ex = { bigModel }
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Character then table.insert(ex, p.Character) end
		end
		for model in pairs(babies) do
			table.insert(ex, model)
		end
		rayParams.FilterDescendantsInstances = ex
	end

	local function hasLineOfSight(from, to)
		refreshFilter()
		local origin = from + Vector3.new(0, LOS_HEIGHT, 0)
		return Workspace:Raycast(origin, (to + Vector3.new(0, LOS_HEIGHT, 0)) - origin, rayParams) == nil
	end

	local function hrpOf(player)
		local char = player.Character
		return char and char:FindFirstChild("HumanoidRootPart")
	end

	-- Only chase carriers who stole a baby assigned to THIS croc. Exactly one
	-- croc ever chases a given thief (see resolveHunter).
	local function huntsPlayer(player)
		local info = carrying[player]
		return info ~= nil and info.hunter == bigKey
	end

	local function resetNav()
		waypoints = nil
		wpIndex = 1
		lastRepath = 0
		lastProgressPos = bigModel:GetPivot().Position
		lastProgressTime = tick()
	end

	-- distance from a point to the surface of the croc's body box
	local function distanceToBig(position)
		local lp = bigModel:GetPivot():PointToObjectSpace(position) - bigCenterLocal
		local clamped = Vector3.new(
			math.clamp(lp.X, -bigHalf.X, bigHalf.X),
			math.clamp(lp.Y, -bigHalf.Y, bigHalf.Y),
			math.clamp(lp.Z, -bigHalf.Z, bigHalf.Z)
		)
		return (lp - clamped).Magnitude
	end

	-- Stops (or slides) a move that would carry the croc into a plot / safe zone.
	local function keepOutOfZones(pos, newPos)
		if inSafeZone(newPos, zoneMargin) and not inSafeZone(pos, zoneMargin) then
			local slideX = Vector3.new(newPos.X, newPos.Y, pos.Z)
			local slideZ = Vector3.new(pos.X, newPos.Y, newPos.Z)
			if not inSafeZone(slideX, zoneMargin) then
				return slideX
			elseif not inSafeZone(slideZ, zoneMargin) then
				return slideZ
			end
			return Vector3.new(pos.X, newPos.Y, pos.Z)
		end
		return newPos
	end

	local function requestPath(from, goal)
		if pathBusy then return end
		pathBusy = true
		task.spawn(function()
			local ok = pcall(function()
				path:ComputeAsync(from, goal)
			end)
			if ok and path.Status == Enum.PathStatus.Success then
				waypoints = path:GetWaypoints()
				wpIndex = 1 -- nextWaypointDir skips ones we're already past
			else
				waypoints = nil
			end
			pathBusy = false
		end)
	end

	local function nextWaypointDir(pos)
		if not waypoints then return nil end
		while wpIndex <= #waypoints and flat(waypoints[wpIndex].Position - pos).Magnitude < 4 do
			wpIndex += 1
		end
		local wp = waypoints[wpIndex]
		if not wp then return nil end
		return flat(wp.Position - pos).Unit
	end

	local function turnToward(dir, dt)
		local angle = math.atan2(forward.Z * dir.X - forward.X * dir.Z, forward:Dot(dir))
		local maxTurn = TURN_RATE * dt
		angle = math.clamp(angle, -maxTurn, maxTurn)
		forward = CFrame.Angles(0, angle, 0):VectorToWorldSpace(forward)
	end

	-- B-line: head straight at the goal, ignoring walls, obstacles and pathfinding.
	-- (Big crocs are moved by CFrame, so they phase through everything. Plots and
	-- safe zones are still respected via keepOutOfZones.)
	local function steer(pos, goal, desiredSpeed, dt, now)
		local toGoal = flat(goal - pos)
		if toGoal.Magnitude < 0.05 then
			speed = math.max(speed - ACCEL * 2 * dt, 0)
			return
		end
		local dir = toGoal.Unit

		turnToward(dir, dt)
		speed += math.clamp(desiredSpeed - speed, -ACCEL * 2 * dt, ACCEL * dt)

		local step = math.min(speed * dt, toGoal.Magnitude)
		local newPos = Vector3.new(pos.X, bigY, pos.Z) + dir * step
		newPos = keepOutOfZones(pos, newPos)
		bigModel:PivotTo(poseCFrame(newPos, forward))
	end

	RunService.Heartbeat:Connect(function(dt)
		dt = math.min(dt, 0.1)
		local now = tick()
		bigModel:SetAttribute("IsChasing", target ~= nil)

		if now < busyUntil then
			speed = 0
			return
		end

		local pos = bigModel:GetPivot().Position

		-- 1) keep or drop the current target (drop if they reached a plot / safe zone)
		if target then
			local startedAt = carriers[target]
			local hrp = hrpOf(target)
			if not startedAt or not hrp
				or not huntsPlayer(target)
				or inSafeZone(hrp.Position)
				or now - startedAt > CHASE_TIMEOUT
				or flat(hrp.Position - pos).Magnitude > LEASH_DISTANCE then
				target = nil
				resetNav()
			end
		end

		-- 2) only switch targets if another carrier is much closer (never someone who is safe)
		local curDist = math.huge
		if target then
			curDist = flat(hrpOf(target).Position - pos).Magnitude
		end
		for player, startedAt in pairs(carriers) do
			if player ~= target and huntsPlayer(player) and now - startedAt <= CHASE_TIMEOUT and (ignoreUntil[player] or 0) < now then
				local hrp = hrpOf(player)
				if hrp and not inSafeZone(hrp.Position) then
					local d = flat(hrp.Position - pos).Magnitude
					if d < curDist * RETARGET_MARGIN then
						target, curDist = player, d
						resetNav()
					end
				end
			end
		end

		-- 3) act
		if target then
			atHome = false
			local hrp = hrpOf(target)

			if distanceToBig(hrp.Position) <= CATCH_DISTANCE then
				catchPlayer(target, pos)
				busyUntil = now + CATCH_PAUSE
				target = nil
				resetNav()
				return
			end

			-- aim straight at the player's current position (no prediction: leading a
			-- very fast player just makes the croc overshoot)
			local flatDist = flat(hrp.Position - pos).Magnitude
			local goal = hrp.Position

			local desired = flatDist < BURST_DISTANCE and RUN_SPEED or HUNT_SPEED
			steer(pos, goal, desired, dt, now)

			-- (no stuck detection: with no pathfinding or walls in the way the croc
			-- always has a straight line to the player, so it never gives up on one)
		else
			-- nobody to chase: head home
			if flat(bigHomePos - pos).Magnitude > 0.6 then
				atHome = false
				steer(pos, bigHomePos, HUNT_SPEED, dt, now)
			elseif not atHome then
				bigModel:PivotTo(bigHome)
				forward = flat(bigHome.LookVector)
				speed = 0
				atHome = true
				resetNav()
			end
		end
	end)
end

-- Drop a model onto whatever surface is below it, so croc models placed in
-- Studio never hover above the terrain. Only moves the model DOWN - a model
-- you deliberately sunk or placed on a ledge keeps its height if it's already
-- at or below the surface under it.
local function snapToGround(model)
	local pivot = model:GetPivot()
	local low = lowestY(model)
	if not low then return end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { model }
	for _, m in ipairs(Workspace:GetChildren()) do
		if m:IsA("Model") and m ~= model
			and (m.Name:match("^Crocodile%d+$") or m.Name:match("^BabyCrocodile%d*$")) then
			table.insert(exclude, m)
		end
	end
	params.FilterDescendantsInstances = exclude

	-- ray from just under the croc's belly straight down
	local hit = Workspace:Raycast(Vector3.new(pivot.Position.X, low + 0.1, pivot.Position.Z), Vector3.new(0, -300, 0), params)
	if hit then
		local gap = low - hit.Position.Y
		if gap > 0.1 then
			model:PivotTo(pivot - Vector3.new(0, gap, 0))
		end
	end
end

-- ============================================================
-- BIG CROC SETUP
-- Every model in Workspace named Crocodile1, Crocodile2, Crocodile3, ... chases
-- players automatically. To add another chaser: duplicate a big croc model in
-- Workspace and name it with the next number. Nothing else needed.
-- Speeds scale with the number (higher number = faster); override any single
-- croc by adding an entry to BIG_CROC_SPEEDS below.
-- ============================================================
local BIG_CROC_SPEEDS = {
	-- Crocodile1 = { run = 29, hunt = 18 },
}

local setupCount = 0
for _, m in ipairs(Workspace:GetChildren()) do
	if m:IsA("Model") then
		local n = tonumber(m.Name:match("^Crocodile(%d+)$"))
		if n then
			snapToGround(m)
			local speeds = BIG_CROC_SPEEDS[m.Name]
			local run = speeds and speeds.run or (BIG_CROC_RUN_SPEED + 10 * (n - 1))
			local hunt = speeds and speeds.hunt or (BIG_CROC_HUNT_SPEED + 6 * (n - 1))
			setupBigCroc(m, run, hunt, m.Name)
			setupCount += 1
		end
	end
end

if setupCount == 0 then
	warn("[CrocStealChaseHandler] No models named Crocodile1, Crocodile2, ... found - nothing will chase carriers")
end

-- ============================================================
-- CARRIER MAINTENANCE: deposit in base, handle death / leaving
-- ============================================================
task.spawn(function()
	while true do
		task.wait(0.05)
		for player, info in pairs(carrying) do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not player.Parent or not hrp or not hum or hum.Health <= 0 then
				returnHome(info)
			else
				local pd = bankPlotFor(player, hrp.Position)
				if pd then
					local owned = banked[player]
					if owned and #owned >= CrocLimit.GetLimit(player) then
						storeIdleCroc(player, info) -- plot is full: it goes to the inventory instead of the plot
					else
						bankBaby(player, info, pd)
					end
				end
			end
		end
	end
end)

-- ============================================================
-- COIN GENERATION
-- ============================================================
task.spawn(function()
	while true do
		task.wait(1)
		for player, list in pairs(banked) do
			if player.Parent and #list > 0 then
				local total = 0
				for _, b in ipairs(list) do
					total += b.rate or COINS_PER_CROC_PER_SECOND
				end
				addCoins(player, math.floor(total * earnMult(player) + 0.5))
			end
		end
	end
end)

-- ============================================================
-- PLAYER LIFECYCLE
-- ============================================================
Players.PlayerAdded:Connect(function(player)
	setupPlayer(player)
	restoreBankedCrocs(player)
	loadInventory(player)
end)
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
	restoreBankedCrocs(player)
	loadInventory(player)
end

Players.PlayerRemoving:Connect(function(player)
	local info = carrying[player]
	if info then
		returnHome(info)
	end
	carriers[player] = nil
	local list = banked[player]
	local savedNames = {}
	if list then
		for _, b in ipairs(list) do
			table.insert(savedNames, b.model.Name .. "|" .. (b.tier and b.tier.name or "Normal"))
		end
	end

	-- save crocs + last-seen time (for offline earnings) so they persist across sessions
	pcall(function()
		crocStore:SetAsync(tostring(player.UserId), { crocs = savedNames, lastSeen = os.time() })
	end)

	-- save the inventory crocs too
	local invNames = {}
	for _, entry in ipairs(inventory[player] or {}) do
		table.insert(invNames, entry.typeName .. "|" .. entry.tierName)
	end
	pcall(function()
		crocStore:SetAsync(tostring(player.UserId) .. "_inv", invNames)
	end)
	inventory[player] = nil

	if list then
		for _, b in ipairs(list) do
			stopWandering(b)
			b.model:Destroy()
		end
		banked[player] = nil
	end
end)

-- ============================================================
-- INIT
-- ============================================================
-- Adding a new baby croc is just: duplicate an existing BabyCrocodile model in
-- Workspace and name it BabyCrocodile<next number>. Anything missing (the
-- CrocType attribute, the pickup prompt, anchoring) is added automatically.
local function autoSetupBaby(model)
	-- first, ground the model in case it was placed floating in Studio
	snapToGround(model)
	if model:GetAttribute("CrocType") ~= "Little" then
		model:SetAttribute("CrocType", "Little")
	end
	if not model:FindFirstChild("StealCrocPrompt", true) then
		local root = model.PrimaryPart
		if not root then
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					root = d
					break
				end
			end
		end
		if root then
			root.Anchored = true
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "StealCrocPrompt"
			prompt.ActionText = "Pick Up"
			prompt.ObjectText = "Baby Crocodile"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0.3
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.Parent = root
		else
			warn("[CrocStealChaseHandler] " .. model.Name .. " has no parts, skipped")
		end
	end
end

for _, d in ipairs(Workspace:GetDescendants()) do
	if d:IsA("Model") and d.Name:match("^BabyCrocodile%d*$") then
		autoSetupBaby(d)
	end
	if d:IsA("Model") and d:GetAttribute("CrocType") == "Little" then
		registerBaby(d)
	end
end

if #plots == 0 then
	warn("[CrocStealChaseHandler] No plots found (expected Models named 'plots' in Workspace) - crocs can't be banked and the croc has no safe zones. Add parts named or tagged 'SafeZone' as a fallback.")
end

print("[CrocStealChaseHandler] Ready - " .. #plots .. " plots, " .. #safeBoxes .. " named safe zones")

-- ============================================================
-- REBIRTH RESET: RebirthService invokes this to wipe a player's crocs
-- (banked + carried + inventory) and their saved croc data.
-- ============================================================
local resetBindable = ServerStorage:FindFirstChild("RebirthReset")
if not resetBindable then
	resetBindable = Instance.new("BindableFunction")
	resetBindable.Name = "RebirthReset"
	resetBindable.Parent = ServerStorage
end
resetBindable.OnInvoke = function(player)
	local carryingInfo = carrying[player]
	if carryingInfo then
		returnHome(carryingInfo)
	end
	carriers[player] = nil
	local list = banked[player]
	if list then
		for _, b in ipairs(list) do
			stopWandering(b)
			b.model:Destroy()
		end
		banked[player] = nil
	end
	local inv = inventory[player]
	if inv then
		for _, entry in ipairs(inv) do
			if entry.tool then
				entry.tool:Destroy()
			end
		end
		inventory[player] = nil
	end
	pcall(function()
		crocStore:SetAsync(tostring(player.UserId), { crocs = {}, lastSeen = os.time() })
	end)
	pcall(function()
		crocStore:SetAsync(tostring(player.UserId) .. "_inv", {})
	end)
	updateCrocsStat(player)
	return true
end
