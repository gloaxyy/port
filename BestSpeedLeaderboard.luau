

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MAX_ROWS = 100 -- TOP 100 players (scrollable list; header stays fixed)
local ROW_HEIGHT = 40 -- px row height inside the scroller (PPS 100 canvas)
local ROW_GAP = 2
local QUERY_COOLDOWN = 60   -- min seconds between OrderedDataStore re-queries
local BOARD_REFRESH = 5     -- seconds between visible board re-renders
local SAVE_COOLDOWN = 30    -- min seconds between SetAsync per player
local FLUSH_INTERVAL = 10   -- how often we check for pending saves
local boardDirty = true     -- a new record happened; store re-query is due

local bestStore
local okStore, storeResult = pcall(function()
	return DataStoreService:GetOrderedDataStore("TreadmillBestSpeed_V1")
end)
if okStore then
	bestStore = storeResult
else
	warn("[BestSpeed] OrderedDataStore unavailable: " .. tostring(storeResult))
end

--------------------------------------------------
-- FIND THE DISPLAY PANEL (front face of GoldenLeaderboard)
--------------------------------------------------

local boardModel = workspace:FindFirstChild("GoldenLeaderboard", true)
local waitedModels = 0
while not boardModel and waitedModels < 60 do
	task.wait(1)
	waitedModels += 1
	boardModel = workspace:FindFirstChild("GoldenLeaderboard", true)
end
if not boardModel then
	warn("[BestSpeed] GoldenLeaderboard model not found anywhere in Workspace")
end
local panelPart
if boardModel then
	-- The front panel is the thinnest wide LeaderboardPart (7.5 x 11.7 x 1.1)
	local best
	for _, d in ipairs(boardModel:GetDescendants()) do
		if d:IsA("MeshPart") and d.Size.Z <= 2.2 and d.Size.Y >= 10 and d.Size.X >= 6 then
			if not best or d.Size.Z < best.Size.Z then
				best = d
			end
		end
	end
	panelPart = best
end
if not panelPart then
	warn("[BestSpeed] GoldenLeaderboard front panel not found - leaderboard UI disabled")
end

--------------------------------------------------
-- BIND TO THE PERSISTENT LEADERBOARD UI
--------------------------------------------------
-- The presentation (Safe frame, title, columns, Rows) is AUTHORED in the
-- DataModel under the panel as TopSpeedGui, so it stays visible and editable
-- in Studio Edit mode. Runtime code only POPULATES/UPDATES it. If it is ever
-- deleted, the fallback builder below recreates the same named structure.

local GOLD = Color3.fromRGB(255, 200, 40)
local CREAM = Color3.fromRGB(255, 244, 214)
local WHITE = Color3.new(1, 1, 1)

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

-- Fallback only: rebuilds the same named structure as the persistent authoring.
local function buildBoardStructure(gui)
	local safe = Instance.new("Frame")
	safe.Name = "Safe"
	safe.BackgroundTransparency = 1
	safe.Position = UDim2.fromScale(0.055, 0.032)
	safe.Size = UDim2.fromScale(0.89, 0.936)
	safe.Parent = gui

	makeLabel(safe, "Title", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.082), "TOP SPEED", GOLD, Enum.TextXAlignment.Center, 92)
	makeLabel(safe, "Subtitle", UDim2.fromScale(0, 0.088), UDim2.fromScale(1, 0.032), "PERSONAL BEST - NOT CURRENT SPEED", CREAM, Enum.TextXAlignment.Center, 28)
	makeLabel(safe, "ColRank", UDim2.fromScale(0, 0.135), UDim2.fromScale(0.10, 0.030), "#", CREAM, Enum.TextXAlignment.Left, 26)
	makeLabel(safe, "ColPlayer", UDim2.fromScale(0.115, 0.135), UDim2.fromScale(0.40, 0.030), "PLAYER", CREAM, Enum.TextXAlignment.Left, 26)
	makeLabel(safe, "ColValue", UDim2.fromScale(0.63, 0.135), UDim2.fromScale(0.37, 0.030), "BEST SPEED", CREAM, Enum.TextXAlignment.Right, 26)

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
	scroller.ScrollBarImageColor3 = Color3.fromRGB(255, 200, 40)
	scroller.ScrollBarImageTransparency = 0.35
	scroller.CanvasSize = UDim2.new(0, 0, 0, 0) -- runtime sets this from row count
	scroller.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	scroller.Parent = list

	local layout = Instance.new("UIListLayout")
	layout.Name = "RowsLayout"
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, ROW_GAP)
	layout.Parent = scroller
end

local rowRefs = {}
local boardGui
local rowScroller

-- Runtime-only row pool (created once; rows are never authored in Edit mode).
local function makeRow(parent, index)
	local row = Instance.new("Frame")
	row.Name = "Row" .. index
	row.LayoutOrder = index
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.BackgroundColor3 = Color3.new(0, 0, 0)
	row.BackgroundTransparency = (index == 1) and 0.70 or (index % 2 == 0 and 0.85 or 0.92)
	row.BorderSizePixel = 0
	row.Parent = parent
	makeLabel(row, "RankLabel", UDim2.fromScale(0, 0), UDim2.fromScale(0.10, 1), "#" .. index, CREAM, Enum.TextXAlignment.Left, 32)
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
	return { frame = row, rank = row:FindFirstChild("RankLabel"), avatar = avatar, name = name, value = value }
end

local function bindRows(gui)
	rowRefs = {}
	rowScroller = nil
	local safe = gui:FindFirstChild("Safe")
	local subtitle = safe and safe:FindFirstChild("Subtitle")
	if subtitle then
		subtitle.Text = "HIGHEST SPEED EVER REACHED - TOP 100"
	end
	local list = safe and safe:FindFirstChild("List")
	local scroller = list and list:FindFirstChild("Scroller")
	if not scroller then return end
	rowScroller = scroller
	-- reuse existing rows when the pool already exists (server restart within
	-- the same place session), otherwise create the full pool once
	for i = 1, MAX_ROWS do
		local existing = scroller:FindFirstChild("Row" .. i)
		if existing then
			rowRefs[i] = {
				frame = existing,
				rank = existing:FindFirstChild("RankLabel"),
				avatar = existing:FindFirstChild("Avatar"),
				name = existing:FindFirstChild("NameLabel"),
				value = existing:FindFirstChild("ValueLabel"),
			}
		else
			rowRefs[i] = makeRow(scroller, i)
		end
	end
	-- scrollable canvas sized to the full 50-row pool
	scroller.CanvasSize = UDim2.fromOffset(0, MAX_ROWS * ROW_HEIGHT + (MAX_ROWS - 1) * ROW_GAP)
end

local function getBoard()
	if boardGui and boardGui.Parent then return boardGui end
	boardGui = nil
	if panelPart then
		local gui = panelPart:FindFirstChild("TopSpeedGui")
		if gui and gui:FindFirstChild("Safe") then
			boardGui = gui
		elseif gui then
			gui:Destroy()
		end
		if not boardGui then
			gui = Instance.new("SurfaceGui")
			gui.Name = "TopSpeedGui"
			gui.Face = Enum.NormalId.Front -- panel front faces +X, toward the treadmill exits
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 100
			gui.LightInfluence = 0
			gui.Brightness = 1.2
			gui.ZOffset = 1
			buildBoardStructure(gui)
			gui.Parent = panelPart
			boardGui = gui
		end
		bindRows(boardGui)
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
-- RENDER (rows <- sorted entries)
--------------------------------------------------

local nameCache = {} -- userId -> name
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

local SILVER = Color3.fromRGB(206, 212, 222)
local BRONZE = Color3.fromRGB(205, 127, 50)

local MEDAL_TEXT = {
	[1] = GOLD,
	[2] = SILVER,
	[3] = BRONZE,
}
local MEDAL_BG = {
	[1] = Color3.fromRGB(64, 50, 10),
	[2] = Color3.fromRGB(48, 51, 58),
	[3] = Color3.fromRGB(58, 36, 20),
}

local function styleRow(refs, index, filled)
	local frame = refs.frame
	if not frame then return end
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

-- Publish the top-3 userIds so client chat scripts can tag players' messages
-- with their rank title (gold/silver/bronze). Attributes replicate to clients.
local chatRanksFolder = ReplicatedStorage:FindFirstChild("ChatSpeedRanks")
if not chatRanksFolder then
	chatRanksFolder = Instance.new("Folder")
	chatRanksFolder.Name = "ChatSpeedRanks"
	chatRanksFolder.Parent = ReplicatedStorage
end
local function publishTopRanks(entries)
	for rank = 1, 3 do
		local entry = entries[rank]
		local userId = 0
		if entry then
			local digits = string.match(tostring(entry.key), "%d+")
			userId = digits and tonumber(digits) or 0
		end
		chatRanksFolder:SetAttribute("Rank" .. rank, userId)
	end
end

-- Merged board render: authoritative store snapshot (rate-limited) + live
-- in-server session values (instant). A player in this server who just beat
-- their record shows up on the next BOARD_REFRESH tick without touching the
-- store; the store query only happens at most once per QUERY_COOLDOWN.
local lastQueryAt = -QUERY_COOLDOWN -- allow the FIRST query immediately
local lastPage = nil                 -- cached store snapshot between rate-limited queries
local function mergedRender()
	if not boardGui then return end

	local page
	if bestStore and (os.clock() - lastQueryAt) >= QUERY_COOLDOWN then
		local ok, pages = pcall(function()
			return bestStore:GetSortedAsync(false, MAX_ROWS) -- descending
		end)
		if ok then
			page = pages:GetCurrentPage()
			lastPage = page -- keep offline players visible between queries
			lastQueryAt = os.clock()
			boardDirty = false
		else
			warn("[BestSpeed] leaderboard query failed: " .. tostring(pages))
		end
	end

	-- current session players' authoritative BestSpeed (server-side attribute)
	local sessionBest = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local best = player:GetAttribute("BestSpeed")
		if best and best > 0 then
			sessionBest[player.UserId] = math.floor(best)
		end
	end

	local entries = {}
	local seen = {}
	if page == nil then
		page = lastPage -- render from cache so ranked offline players never vanish
	end
	if page then
		for _, entry in ipairs(page) do
			local digits = string.match(tostring(entry.key), "%d+")
			local userId = digits and tonumber(digits)
			if userId then
				-- session value wins if it is higher (it is the newer, live truth)
				local value = math.max(entry.value or 0, sessionBest[userId] or 0)
				entries[#entries+1] = {key = "p" .. userId, value = value}
				seen[userId] = true
			end
		end
	end
	for userId, best in pairs(sessionBest) do
		if not seen[userId] then
			entries[#entries+1] = {key = "p" .. userId, value = best}
		end
	end
	table.sort(entries, function(a, b) return (a.value or 0) > (b.value or 0) end)
	publishTopRanks(entries)
	renderBoard(entries)
end

--------------------------------------------------
-- PER-PLAYER BEST SPEED TRACKING
--------------------------------------------------

local pendingSaves = {} -- [player] = true (value changed since last save)
local lastSaveAt = {}    -- [player] = os.clock() of last successful save

local function ensureBestSpeed(player)
	-- leaderstats display (reuses the FIRST folder, same rule SellHandler uses)
	local leaderstats = player:FindFirstChild("leaderstats") or player:WaitForChild("leaderstats", 15)
	if leaderstats and not leaderstats:FindFirstChild("BestSpeed") then
		local v = Instance.new("IntValue")
		v.Name = "BestSpeed"
		v.Value = 0
		v.Parent = leaderstats
	end

	-- Load existing best (if any)
	local loaded
	if bestStore then
		local ok, val = pcall(function()
			return bestStore:GetAsync("p" .. player.UserId)
		end)
		if ok then
			loaded = val
		elseif not ok then
			warn("[BestSpeed] load failed for " .. player.Name .. ": " .. tostring(val))
		end
	end

	-- Initialize: max(loaded, current Speed) so existing players don't start at 0
	local current = player:GetAttribute("Speed")
	local best = math.max(loaded or 0, current and math.floor(current) or 0)
	player:SetAttribute("BestSpeed", best)
	local ls = player:FindFirstChild("leaderstats")
	local bv = ls and ls:FindFirstChild("BestSpeed")
	if bv then
		bv.Value = math.floor(best)
	end
end

local function maybeBeat(player)
	local speed = player:GetAttribute("Speed")
	if not speed then return end
	local whole = math.floor(speed)
	local best = player:GetAttribute("BestSpeed") or 0
	if whole > best then
		player:SetAttribute("BestSpeed", whole)
		local ls = player:FindFirstChild("leaderstats")
		local bv = ls and ls:FindFirstChild("BestSpeed")
		if bv then
			bv.Value = whole
		end
		pendingSaves[player] = true -- debounced; flusher handles the write
		boardDirty = true -- visible board refreshes on the next refresher tick
	end
end

local function saveBest(player)
	if not bestStore then return end
	local best = player:GetAttribute("BestSpeed")
	if not best or best <= 0 then return end
	local ok, err = pcall(function()
		bestStore:SetAsync("p" .. player.UserId, math.floor(best))
	end)
	if ok then
		lastSaveAt[player] = os.clock()
		pendingSaves[player] = nil
	else
		-- Back off instead of retrying immediately (rate-limit friendly; avoids spam)
		lastSaveAt[player] = os.clock()
		warn("[BestSpeed] save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

local function onPlayerAdded(player)
	-- 1) Connect the Speed watcher FIRST (before any yielding), so the initial
	--    Speed set by Treadmillsystem's async load can never be missed.
	player:GetAttributeChangedSignal("Speed"):Connect(function()
		maybeBeat(player)
	end)
	-- 2) Then load/init BestSpeed (yields are safe now; selling resets Speed only,
	--    and any later increase still beats via the watcher).
	ensureBestSpeed(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveBest(player) -- final flush on leave
	pendingSaves[player] = nil
	lastSaveAt[player] = nil
end)

--------------------------------------------------
-- BACKGROUND LOOPS (throttled - no per-frame DataStore calls)
--------------------------------------------------

-- Debounced saver
task.spawn(function()
	while true do
		task.wait(FLUSH_INTERVAL)
		for player in pairs(pendingSaves) do
			if player.Parent then
				local last = lastSaveAt[player] or 0
				if os.clock() - last >= SAVE_COOLDOWN then
					saveBest(player)
				end
			else
				pendingSaves[player] = nil
			end
		end
	end
end)

-- Board refresher: re-renders the visible board every BOARD_REFRESH seconds.
-- Between rate-limited store queries it merges the last store snapshot with
-- in-server players' live BestSpeed, so new records appear within seconds.
if panelPart then
	task.spawn(function()
		while true do
			mergedRender()
			task.wait(BOARD_REFRESH)
		end
	end)
end
