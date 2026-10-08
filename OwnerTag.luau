local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local TAGGED_PLAYERS = {
	{
		username = "ajsmart13",
		text = "OWNER",
		color = Color3.fromRGB(255, 255, 0),
	},
	{
		username = "syntax40438",
		text = "ADMIN",
		color = Color3.fromRGB(255, 64, 64),
	},
	{
		username = "GeneralChaosDurden",
		text = "DEVELOPER?????",
		color = Color3.fromRGB(0, 112, 255),
	},
	{
		username = "ahmedminir123",
		text = "DEVELOPER????",
		color = Color3.fromRGB(0, 112, 255),
	},
	{
		username = "eh_of",
		text = "DEVELOPER????",
		color = Color3.fromRGB(0, 112, 255),
	},
	{
		username = "OneElitely",
		text = "CO-OWNER",
		color = Color3.fromRGB(255, 130, 20),
	},
	{
		username = "hbm_yeetime3",
		text = "MODERATOR",
		color = Color3.fromRGB(160, 0, 255),
	},
}

local OUTLINE_COLOR = Color3.fromRGB(0, 0, 0)

local function createTag(text, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "RankTag"
	billboard.Size = UDim2.fromOffset(160, 40)
	billboard.StudsOffset = Vector3.new(0, 2.4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 200

	local label = Instance.new("TextLabel")
	label.Name = "Tag"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Parent = billboard

	local stroke = Instance.new("UIStroke")
	stroke.Color = OUTLINE_COLOR
	stroke.Thickness = 2.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = label

	-- Moving shine: a bright band sweeps across the text forever.
	-- The gradient multiplies TextColor3, so dim edges + white band = shine.
	local shine = Instance.new("UIGradient")
	shine.Rotation = 20
	shine.Offset = Vector2.new(-1, 0)
	shine.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(165, 165, 165)),
		ColorSequenceKeypoint.new(0.42, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.58, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(165, 165, 165)),
	})
	shine.Parent = label

	TweenService:Create(shine, TweenInfo.new(
		1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, 0
	), { Offset = Vector2.new(1, 0) }):Play()

	TweenService:Create(stroke, TweenInfo.new(
		2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, 0
	), { Transparency = 0.35 }):Play()

	return billboard
end

local function findTagFor(username)
	for _, entry in TAGGED_PLAYERS do
		if entry.username == username then
			return entry
		end
	end
	return nil
end

local function addTag(player, entry)
	local function attach(character)
		local head = character:WaitForChild("Head", 10)
		if not head then
			warn("[RankTag] Head not found for " .. player.Name)
			return
		end
		local tag = createTag(entry.text, entry.color)
		tag.Adornee = head
		tag.Parent = character
	end

	player.CharacterAdded:Connect(attach)

	if player.Character then
		attach(player.Character)
	end
end

Players.PlayerAdded:Connect(function(player)
	local entry = findTagFor(player.Name)
	if entry then
		addTag(player, entry)
	end
end)

for _, player in Players:GetPlayers() do
	local entry = findTagFor(player.Name)
	if entry then
		addTag(player, entry)
	end
end

print("[RankTag] Loaded with " .. #TAGGED_PLAYERS .. " tagged players")