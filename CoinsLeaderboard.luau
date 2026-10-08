

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local MAX_ROWS = 50
local ROW_HEIGHT = 40
local ROW_GAP = 2
local QUERY_COOLDOWN = 60
local BOARD_REFRESH = 5
local SAVE_COOLDOWN = 30
local FLUSH_INTERVAL = 10

-- CrystalLeaderboard front face (flip to Back if the text shows on the wrong side)
local BOARD_FACE = Enum.NormalId.Front

local coinStore
local okStore, storeResult = pcall(function()
	return DataStoreService:GetOrderedDataStore("CrocCoinsBoard_V1")
end)
if okStore then
	coinStore = storeResult
else
	warn("[CoinsBoard] OrderedDataStore unavailable: " .. tostring(storeResult))
end

--------------------------------------------------
-- FIND THE DISPLAY PANEL (CrystalLeaderboard)
--------------------------------------------------

local boardModel = workspace:FindFirstChild("CrystalLeaderboard", true)
local waited = 0
while not boardModel and waited < 60 do
	task.wait(1)
	waited += 1
	boardModel = workspace:FindFirstChild("CrystalLeaderboard", true)
end
if not boardModel then
	warn("[CoinsBoard] CrystalLeaderboard model not found anywhere in Workspace")
end
local panelPart
if boardModel then
	local best
	for _, d in ipairs(boardModel:GetDescendants()) do
		if d:IsA("MeshPart") then
			local area = d.Size.X * d.Size.Y
			if area > 20 and (not best or area > best.Size.X * best.Size.Y) then
				best = d
			end
		end
	end
	panelPart = best
end
if not panelPart then
	warn("[CoinsBoard] CrystalLeaderboard display panel not found - leaderboard UI disabled")
end

--------------------------------------------------
-- BOARD UI (built once on the panel)
--------------------------------------------------

local GOLD = Color3.fromRGB(255, 200, 40)
local CREAM = Color3.fromRGB(255, 244, 214)
local WHITE = Color3.new(1, 1, 1)
local SILVER = Color3.fromRGB(206, 212, 222)
local BRONZE = Color3.fromRGB(205, 127, 50)
local MEDAL_TEXT = { [1] = GOLD, [2] = SILVER, [3] = BRONZE }
local MEDAL_BG = {
	[1] = Color3.fromRGB(64, 50, 10),
	[2] = Color3.fromRGB(48, 51, 58),
	[3] = Color3.fromRGB(58, 36, 20),
}

local function makeLabel(parent, name, pos, size, text, color, xAlign, maxSize)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Font = Enum.Font.FredokaOne
	l.Text = text
	l.TextColor3 = color
	l.TextScaled = true
	l.TextXAlignment = xAlign
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	l.TextStrokeTransparency = 0.15
	l.Parent = parent
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.Parent = l
	return l
end

local rowRefs = {}
local boardGui

local function makeRow(parent, index)
	local row = Instance.new("Frame")
	row.Name = "Row" .. index
	row.LayoutOrder = index
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.BackgroundColor3 = Color3.new(0, 0, 0)
	row.BackgroundTransparency = (index == 1) and 0.70 or (index % 2 == 0 and 0.85 or 0.92)
	row.BorderSizePixel = 0
	row.Parent = parent
	local rankLabel = makeLabel(row, "RankLabel", UDim2.fromScale(0, 0), UDim2.fromScale(0.10, 1), "#" .. index, CREAM, Enum.TextXAlignment.Left, 32)
	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.BackgroundTransparency = 1
	avatar.AnchorPoint = Vector2.new(0, 0.5)
	avatar.Position = UDim2.fromScale(0.115, 0.5)
	avatar.Size = UDim2.fromScale(0.075, 0.85)
	avatar.Image = ""
	avatar.Visible = false
	avatar.Parent = row
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.DominantAxis = Enum.DominantAxis.Width
	aspect.Parent = avatar
	local name = makeLabel(row, "NameLabel", UDim2.fromScale(0.205, 0), UDim2.fromScale(0.415, 1), "-", WHITE, Enum.TextXAlignment.Left, 30)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local value = makeLabel(row, "ValueLabel", UDim2.fromScale(0.63, 0), UDim2.fromScale(0.37, 1), "-", WHITE, Enum.TextXAlignment.Right, 32)
	return { frame = row, rank = rankLabel, avatar = avatar, name = name, value = value }
end

local function buildBoardStructure(gui)
	local safe = Instance.new("Frame")
	safe.Name = "Safe"
	safe.BackgroundTransparency = 1
	safe.Position = UDim2.fromScale(0.055, 0.032)
	safe.Size = UDim2.fromScale(0.89, 0.936)
	safe.Parent = gui

	makeLabel(safe, "Title", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.082), "TOP COINS", GOLD, Enum.TextXAlignment.Center, 92)
	makeLabel(safe, "Subtitle", UDim2.fromScale(0, 0.088), UDim2.fromScale(1, 0.032), "MOST COINS EVER HELD - TOP 50", CREAM, Enum.TextXAlignment.Center, 28)
	makeLabel(safe, "ColRank", UDim2.fromScale(0, 0.135), UDim2.fromScale(0.10, 0.030), "#", CREAM, Enum.TextXAlignment.Left, 26)
	makeLabel(safe, "ColPlayer", UDim2.fromScale(0.115, 0.135), UDim2.fromScale(0.40, 0.030), "PLAYER", CREAM, Enum.TextXAlignment.Left, 26)
	makeLabel(safe, "ColValue", UDim2.fromScale(0.63, 0.135), UDim2.fromScale(0.37, 0.030), "COINS", CREAM, Enum.TextXAlignment.Right, 26)

	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0, 0.178)
	list.Size = UDim2.fromScale(1, 0.792)
	list.Parent = safe

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "Scroller"
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Size = UDim2.fromScale(1, 1)
	scroller.ScrollingDirection = Enum.ScrollingDirection.Y
	scroller.ScrollBarThickness = 6
	scroller.ScrollBarImageColor3 = GOLD
	scroller.ScrollBarImageTransparency = 0.35
	scroller.CanvasSize = UDim2.fromOffset(0, MAX_ROWS * ROW_HEIGHT + (MAX_ROWS - 1) * ROW_GAP)
	scroller.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	scroller.Parent = list

	local layout = Instance.new("UIListLayout")
	layout.Name = "RowsLayout"
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, ROW_GAP)
	layout.Parent = scroller

	for i = 1, MAX_ROWS do
		rowRefs[i] = makeRow(scroller, i)
	end
end

local function getBoard()
	if boardGui and boardGui.Parent then return boardGui end
	boardGui = nil
	if panelPart then
		local gui = panelPart:FindFirstChild("CoinsGui")
		if gui and gui:FindFirstChild("Safe") then
			boardGui = gui
		elseif gui then
			gui:Destroy()
		end
		if not boardGui then
			gui = Instance.new("SurfaceGui")
			gui.Name = "CoinsGui"
			gui.Face = BOARD_FACE
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 100
			gui.LightInfluence = 0
			gui.Brightness = 1.2
			gui.ZOffset = 1
			buildBoardStructure(gui)
			gui.Parent = panelPart
			boardGui = gui
		end
	end
	return boardGui
end

getBoard()

local function formatNumber(n)
	local s = tostring(math.floor(n))
	local k
	while true do
		s, k = s:gsub("^(%-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return s
end

--------------------------------------------------
-- RENDER
--------------------------------------------------

local nameCache = {}
local function getName(userId)
	if nameCache[userId] then return nameCache[userId] end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and name then
		nameCache[userId] = name
		return name
	end
	return nil
end

local function styleRow(refs, index, filled)
	local frame = refs.frame
	if filled then
		local color = MEDAL_TEXT[index] or (index % 2 == 0 and CREAM or WHITE)
		refs.rank.TextColor3 = color
		refs.name.TextColor3 = color
		refs.value.TextColor3 = color
		if MEDAL_TEXT[index] then
			frame.BackgroundColor3 = MEDAL_BG[index]
			frame.BackgroundTransparency = 0.25
		else
			frame.BackgroundColor3 = Color3.new(0, 0, 0)
			frame.BackgroundTransparency = (index % 2 == 0) and 0.85 or 0.92
		end
	else
		refs.rank.TextColor3 = CREAM
		refs.name.TextColor3 = WHITE
		refs.value.TextColor3 = WHITE
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BackgroundTransparency = (index % 2 == 0) and 0.85 or 0.92
	end
end

local function renderBoard(entries)
	for i = 1, MAX_ROWS do
		local refs = rowRefs[i]
		if refs and refs.rank then
			local entry = entries[i]
			if entry then
				local digits = string.match(tostring(entry.key), "%d+")
				local userId = digits and tonumber(digits) or nil
				refs.rank.Text = "#" .. i
				refs.value.Text = formatNumber(entry.value or 0)
				if userId then
					local name = getName(userId)
					refs.name.Text = (i == 1 and "\u{1F451} " or "") .. (name or ("Player " .. userId))
					refs.avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=150&h=150"
					refs.avatar.Visible = true
				else
					refs.name.Text = "?"
					refs.avatar.Visible = false
				end
				styleRow(refs, i, true)
			else
				refs.rank.Text = "#" .. i
				refs.name.Text = "-"
				refs.value.Text = "-"
				refs.avatar.Visible = false
				styleRow(refs, i, false)
			end
		end
	end
end

local lastQueryAt = -QUERY_COOLDOWN
local lastPage = nil
local function mergedRender()
	if not boardGui then return end

	local page
	if coinStore and (os.clock() - lastQueryAt) >= QUERY_COOLDOWN then
		local ok, pages = pcall(function()
			return coinStore:GetSortedAsync(false, MAX_ROWS)
		end)
		if ok then
			page = pages:GetCurrentPage()
			lastPage = page
			lastQueryAt = os.clock()
		else
			warn("[CoinsBoard] leaderboard query failed: " .. tostring(pages))
		end
	end

	local sessionPeak = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local peak = player:GetAttribute("PeakCoins")
		if peak and peak > 0 then
			sessionPeak[player.UserId] = math.floor(peak)
		end
	end

	local entries = {}
	local seen = {}
	if page == nil then
		page = lastPage
	end
	if page then
		for _, entry in ipairs(page) do
			local digits = string.match(tostring(entry.key), "%d+")
			local userId = digits and tonumber(digits)
			if userId then
				local value = math.max(entry.value or 0, sessionPeak[userId] or 0)
				entries[#entries+1] = {key = "p" .. userId, value = value}
				seen[userId] = true
			end
		end
	end
	for userId, peak in pairs(sessionPeak) do
		if not seen[userId] then
			entries[#entries+1] = {key = "p" .. userId, value = peak}
		end
	end
	table.sort(entries, function(a, b) return (a.value or 0) > (b.value or 0) end)
	renderBoard(entries)
end

--------------------------------------------------
-- PER-PLAYER PEAK COIN TRACKING
--------------------------------------------------

local pendingSaves = {}
local lastSaveAt = {}

-- same lookup rule TrialsService/RebirthService use (first leaderstats with Coins)
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

local function watchCoins(player)
	task.spawn(function()
		local coins = player:WaitForChild("leaderstats", 30)
		coins = coins and coins:WaitForChild("Coins", 30) or getCoinStat(player)
		if not coins and player.Parent then
			coins = getCoinStat(player)
		end
		if not coins then
			warn("[CoinsBoard] no Coins stat found for " .. player.Name)
			return
		end

		local loaded
		if coinStore then
			local ok, val = pcall(function()
				return coinStore:GetAsync("p" .. player.UserId)
			end)
			if ok then
				loaded = val
			else
				warn("[CoinsBoard] load failed for " .. player.Name .. ": " .. tostring(val))
			end
		end

		local function peakNow()
			local peak = player:GetAttribute("PeakCoins") or 0
			local current = math.floor(coins.Value)
			if current > peak then
				player:SetAttribute("PeakCoins", current)
				pendingSaves[player] = true
			end
		end

		local loadedPeak = loaded and math.floor(loaded) or 0
		if player.Parent and (player:GetAttribute("PeakCoins") or 0) < loadedPeak then
			player:SetAttribute("PeakCoins", loadedPeak)
		end
		peakNow()

		coins.Changed:Connect(peakNow)
	end)
end

local function savePeak(player)
	if not coinStore then return end
	local peak = player:GetAttribute("PeakCoins")
	if not peak or peak <= 0 then return end
	local ok, err = pcall(function()
		coinStore:SetAsync("p" .. player.UserId, math.floor(peak))
	end)
	if ok then
		lastSaveAt[player] = os.clock()
		pendingSaves[player] = nil
	else
		lastSaveAt[player] = os.clock()
		warn("[CoinsBoard] save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

Players.PlayerAdded:Connect(watchCoins)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(watchCoins, player)
end

Players.PlayerRemoving:Connect(function(player)
	savePeak(player)
	pendingSaves[player] = nil
	lastSaveAt[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePeak(player)
	end
end)

--------------------------------------------------
-- BACKGROUND LOOPS
--------------------------------------------------

task.spawn(function()
	while true do
		task.wait(FLUSH_INTERVAL)
		for player in pairs(pendingSaves) do
			if player.Parent then
				local last = lastSaveAt[player] or 0
				if os.clock() - last >= SAVE_COOLDOWN then
					savePeak(player)
				end
			else
				pendingSaves[player] = nil
			end
		end
	end
end)

if panelPart then
	task.spawn(function()
		while true do
			mergedRender()
			task.wait(BOARD_REFRESH)
		end
	end)
end

print("[CoinsBoard] Coins leaderboard loaded on " .. (panelPart and panelPart:GetFullName() or "no panel"))
