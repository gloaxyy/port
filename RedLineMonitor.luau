--[[
	RedLineMonitor
	Server-authoritative loop that continuously checks every Class-D player's
	position against the RedLine boundary and marks them as unauthorized when
	they are outside of it. Runs entirely on the server.

	Sets on each Class-D Player instance:
		player:SetAttribute("OutsideRedLine", true/false)

	Also attaches/removes a "UNAUTHORIZED" tag above the player's head so
	other players can see who is outside the boundary.
]]

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ServerScriptService = game:GetService("ServerScriptService")

local RedLineUtil = require(ServerScriptService:WaitForChild("RedLineUtil"))

-- Configuration
local CHECK_INTERVAL = 0.25
local TARGET_TEAM = "Class-D"
local TAG_NAME = "EscapedTag"
local UNAUTHORIZED_COOLDOWN = 5 -- seconds to keep tag after returning inside

local cooldowns = {} -- [player.UserId] = os.clock() when unauthorized started

local function getTargetTeam(): Team?
	return Teams:FindFirstChild(TARGET_TEAM)
end

local function ensureEscapedTag(character: Model)
	if character:FindFirstChild(TAG_NAME) then return end

	local head = character:FindFirstChild("Head")
	if not head then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = TAG_NAME
	billboard.Adornee = head
	billboard.Size = UDim2.new(0, 120, 0, 30)
	billboard.StudsOffset = Vector3.new(0, 1.0, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 40
	billboard.Parent = character

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = "UNAUTHORIZED"
	label.TextColor3 = Color3.fromRGB(255, 40, 40)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Parent = billboard
end

local function removeEscapedTag(character: Model)
	local tag = character:FindFirstChild(TAG_NAME)
	if tag then
		tag:Destroy()
	end
end

local function updatePlayer(player: Player)
	local targetTeam = getTargetTeam()
	if not targetTeam or player.Team ~= targetTeam then
		-- Not a Class-D player: clear any stale flag/tag
		cooldowns[player.UserId] = nil
		if player:GetAttribute("OutsideRedLine") ~= nil then
			player:SetAttribute("OutsideRedLine", nil)
		end
		local character = player.Character
		if character then
			removeEscapedTag(character)
		end
		return
	end

	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end

	local inside = RedLineUtil.IsPlayerInside(player)

	if not inside then
		-- Player is outside: mark cooldown start time and show tag
		if not cooldowns[player.UserId] then
			cooldowns[player.UserId] = os.clock()
		end
		player:SetAttribute("OutsideRedLine", true)
		ensureEscapedTag(character)
	else
		-- Player is back inside: keep tag for UNAUTHORIZED_COOLDOWN seconds
		local cd = cooldowns[player.UserId]
		if cd and (os.clock() - cd) < UNAUTHORIZED_COOLDOWN then
			-- Still within cooldown, keep the tag
			player:SetAttribute("OutsideRedLine", false)
			ensureEscapedTag(character)
		else
			-- Cooldown expired or was never outside, remove tag
			cooldowns[player.UserId] = nil
			player:SetAttribute("OutsideRedLine", false)
			removeEscapedTag(character)
		end
	end
end

local function updateAllPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		local ok, err = pcall(updatePlayer, player)
		if not ok then
			warn("[RedLineMonitor] error updating player " .. player.Name .. ": " .. tostring(err))
		end
	end
end

updateAllPlayers()

while task.wait(CHECK_INTERVAL) do
	updateAllPlayers()
end
