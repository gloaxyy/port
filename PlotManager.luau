local Players = game:GetService("Players")

-- ServerScriptService/PlotManager: assigns every spawning player one of the
-- existing Workspace "plots" models, drops them on it, and shows their
-- username + avatar headshot on a billboard above the plot.

local BOARD_OFFSET = 8 -- studs above the plot's highest point
local STUD_PATTERN = "rbxassetid://92521981645530"

local playerPlots = {} -- [player] = plot model

local function makeStudTile(parent, tile)
	local pattern = Instance.new("ImageLabel")
	pattern.Name = "Studs"
	pattern.BackgroundTransparency = 1
	pattern.Size = UDim2.fromScale(1, 1)
	pattern.Image = STUD_PATTERN
	pattern.ImageTransparency = 0.55
	pattern.ScaleType = Enum.ScaleType.Tile
	pattern.TileSize = UDim2.fromOffset(tile, tile)
	pattern.ZIndex = 2
	pattern.Parent = parent
end

local function buildBoard()
	local gui = Instance.new("BillboardGui")
	gui.Name = "PlayerBoard"
	gui.Size = UDim2.fromOffset(200, 74)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 250

	local base = Instance.new("Frame")
	base.Name = "Board"
	base.Size = UDim2.fromScale(1, 1)
	base.BackgroundColor3 = Color3.fromRGB(42, 32, 24)
	base.BackgroundTransparency = 0.15
	base.BorderSizePixel = 0
	base.ZIndex = 1
	base.Parent = gui

	local baseStroke = Instance.new("UIStroke")
	baseStroke.Color = Color3.new(0, 0, 0)
	baseStroke.Thickness = 4
	baseStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	baseStroke.Parent = base

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.AnchorPoint = Vector2.new(0.5, 1)
	face.Position = UDim2.fromScale(0.5, 1)
	face.Size = UDim2.new(1, 0, 0.94, 0)
	face.BackgroundColor3 = Color3.fromRGB(150, 160, 165)
	face.BorderSizePixel = 0
	face.ZIndex = 1
	face.Parent = base

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), face.BackgroundColor3)
	gradient.Parent = face

	makeStudTile(face, 44)

	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.BackgroundTransparency = 1
	avatar.AnchorPoint = Vector2.new(0, 0.5)
	avatar.Position = UDim2.new(0, 9, 0.5, 0)
	avatar.Size = UDim2.fromOffset(54, 54)
	avatar.Image = ""
	avatar.ScaleType = Enum.ScaleType.Fit
	avatar.ZIndex = 3
	avatar.Parent = face

	local avatarStroke = Instance.new("UIStroke")
	avatarStroke.Color = Color3.new(0, 0, 0)
	avatarStroke.Thickness = 3
	avatarStroke.Parent = avatar

	local name = Instance.new("TextLabel")
	name.Name = "PlayerName"
	name.BackgroundTransparency = 1
	name.AnchorPoint = Vector2.new(0, 0.5)
	name.Position = UDim2.new(0, 72, 0.5, 0)
	name.Size = UDim2.new(1, -80, 1, 0)
	name.Font = Enum.Font.FredokaOne
	name.Text = "Empty Plot"
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextScaled = true
	name.ZIndex = 3
	name.Parent = face

	local nameStroke = Instance.new("UIStroke")
	nameStroke.Color = Color3.new(0, 0, 0)
	nameStroke.Thickness = 3
	nameStroke.Parent = name

	return gui
end

local function setupPlot(plot)
	if plot:GetAttribute("Owner") == nil then
		plot:SetAttribute("Owner", "")
	end
	if plot:FindFirstChild("PlayerBoard") then return end

	local cf, size = plot:GetBoundingBox()
	local holder = Instance.new("Part")
	holder.Name = "BoardHolder"
	holder.Size = Vector3.new(1, 1, 1)
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Position = cf.Position + Vector3.new(0, size.Y / 2 + BOARD_OFFSET, 0)
	holder.Parent = plot

	buildBoard().Parent = holder
end

local plots = {}
for _, child in ipairs(workspace:GetDescendants()) do
	if child:IsA("Model") and child.Name == "plots" then
		setupPlot(child)
		table.insert(plots, child)
	end
end

local function setBoardState(plot, playerName, userId)
	local holder = plot:FindFirstChild("BoardHolder")
	local gui = holder and holder:FindFirstChild("PlayerBoard")
	if not gui then return end
	local face = gui.Board.Face
	local avatar = face.Avatar
	local nameLabel = face.PlayerName

	if userId then
		avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=150&h=150"
		nameLabel.Text = playerName .. "'s Plot"
	else
		avatar.Image = ""
		nameLabel.Text = "Empty Plot"
	end

	face.BackgroundColor3 = userId and Color3.fromRGB(90, 200, 70) or Color3.fromRGB(150, 160, 165)
	face.UIGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), face.BackgroundColor3)
end

local function teleportToPlot(player, plot)
	local character = player.Character or player.CharacterAdded:Wait()
	local hrp = character:WaitForChild("HumanoidRootPart", 10)
	if not hrp then return end
	local cf, size = plot:GetBoundingBox()
	local top = cf.Position + Vector3.new(0, size.Y / 2, 0)
	hrp.CFrame = CFrame.new(top + Vector3.new(0, 4, 0))
end

local function claimPlot(player)
	for _, plot in ipairs(plots) do
		if plot:GetAttribute("Owner") == "" then
			plot:SetAttribute("Owner", player.Name)
			playerPlots[player] = plot
			setBoardState(plot, player.DisplayName ~= "" and player.DisplayName or player.Name, player.UserId)
			print("[PlotManager] " .. player.Name .. " claimed a plot at " .. tostring(plot:GetBoundingBox().Position))
			return plot
		end
	end
	warn("[PlotManager] No free plots for " .. player.Name)
	return nil
end

local function releasePlot(player)
	local plot = playerPlots[player]
	if plot then
		plot:SetAttribute("Owner", "")
		setBoardState(plot, nil, nil)
		playerPlots[player] = nil
		print("[PlotManager] " .. player.Name .. " released their plot")
	end
end

Players.PlayerAdded:Connect(function(player)
	local plot = claimPlot(player)
	if not plot then return end

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		teleportToPlot(player, plot)
	end)

	if player.Character then
		teleportToPlot(player, plot)
	end
end)

Players.PlayerRemoving:Connect(releasePlot)

print("[PlotManager] " .. #plots .. " plots ready for assignment")