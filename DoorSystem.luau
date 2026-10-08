local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local OPEN_DURATION = 1.5
local LARGE_DOOR_OPEN_DURATION = 3
local LARGE_DOOR_WIDTH_THRESHOLD = 5
local LARGE_DOOR_HEIGHT_THRESHOLD = 7.5
local STAY_OPEN_TIME = 5
local CLUSTER_THRESHOLD = 15
local SCANNER_RANGE = 30
local DEFAULT_KEYCARD_LEVEL = 2

local SOUND_DENIED = "rbxassetid://97367190838793"
local SOUND_OPEN = "rbxassetid://6049670667"
local SOUND_CLOSE = "rbxassetid://6049670667"

local initializedDoors = setmetatable({}, {__mode = "k"})

local function containsDoorName(model)
	local name = string.lower(model.Name)
	return name:match("door") ~= nil or name:match("gate") ~= nil
end

local function findDoorPanels(model)
	local panels = {}
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("Model") and string.lower(desc.Name):match("door") and desc.PrimaryPart then
			local originalCFrame = desc:FindFirstChild("OriginalCFrame")
			if originalCFrame and originalCFrame:IsA("CFrameValue") then
				local closedCFrame = desc.PrimaryPart.CFrame
				local parts = {}
				local originalCollision = {}
				for _, part in ipairs(desc:GetDescendants()) do
					if part:IsA("BasePart") then
						table.insert(parts, part)
						originalCollision[part] = {
							CanCollide = part.CanCollide,
							CanQuery = part.CanQuery,
						}
					end
				end
				table.insert(panels, {
					model = desc,
					primaryPart = desc.PrimaryPart,
					closedCFrame = closedCFrame,
					primarySize = desc.PrimaryPart.Size,
					primaryToPivot = desc.PrimaryPart.CFrame:ToObjectSpace(desc:GetPivot()),
					parts = parts,
					originalCollision = originalCollision,
					openCFrame = nil,
				})
			end
		end
	end
	return panels
end

local function clusterPanels(panels)
	local groups = {}
	local assigned = {}

	for i, panel in ipairs(panels) do
		if not assigned[i] then
			local group = {panel}
			assigned[i] = true

			for j = i + 1, #panels do
				if not assigned[j] then
					local distance = (panel.closedCFrame.Position - panels[j].closedCFrame.Position).Magnitude
					if distance < CLUSTER_THRESHOLD then
						table.insert(group, panels[j])
						assigned[j] = true
					end
				end
			end

			table.insert(groups, group)
		end
	end

	return groups
end

local function computeOpenCFrames(group)
	local center = Vector3.zero
	for _, panel in ipairs(group) do
		center += panel.closedCFrame.Position
	end
	center /= #group

	for _, panel in ipairs(group) do
		local position = panel.closedCFrame.Position
		local size = panel.primaryPart.Size
		local direction = position - center
		direction = Vector3.new(direction.X, 0, direction.Z)

		if direction.Magnitude < 0.1 then
			direction = panel.closedCFrame.RightVector
			direction = Vector3.new(direction.X, 0, direction.Z)
		else
			direction = direction.Unit
		end

		local width = math.max(size.X, size.Z)
		local openPosition = position + direction * width
		panel.openCFrame = CFrame.new(openPosition) * (panel.closedCFrame - panel.closedCFrame.Position)
	end
end

local function normalizeLevel(value)
	local level = tonumber(value)
	if not level or level ~= level or level == math.huge or level == -math.huge or level < 0 then
		return nil
	end
	return math.floor(level)
end

local function getDoorRequiredLevel(doorModel)
	local requiredLevel = normalizeLevel(doorModel:GetAttribute("RequiredKeycardLevel"))
	if requiredLevel ~= nil then
		doorModel:SetAttribute("RequiredKeycardLevel", requiredLevel)
		return requiredLevel
	end

	local allowed = doorModel:GetAttribute("Allowed")
	local allowedLevel = allowed and string.match(tostring(allowed), "[Ll](%d+)")
	requiredLevel = tonumber(allowedLevel) or DEFAULT_KEYCARD_LEVEL
	doorModel:SetAttribute("RequiredKeycardLevel", requiredLevel)
	return requiredLevel
end

local function getKeycardLevel(tool)
	local toolName = string.lower(tool.Name)
	local hasCardName = toolName:match("key%s*card") ~= nil
		or toolName:match("key_card") ~= nil
		or toolName:match("keycard") ~= nil
		or toolName:match("card%s*%-?%s*[lL]?%d+") ~= nil
		or toolName:match("card%-omni") ~= nil
	local attributeLevel = normalizeLevel(tool:GetAttribute("KeycardLevel"))

	if attributeLevel ~= nil then
		return attributeLevel
	end
	if not hasCardName then
		return nil
	end
	if toolName:match("omni") then
		return 99
	end

	local levelText = string.match(tool.Name, "[Ll]evel%s*(%d+)")
		or string.match(tool.Name, "[Ll](%d+)")
		or string.match(tool.Name, "[Cc]ard%s*%-?%s*[Ll](%d+)")
	return tonumber(levelText) or 0
end

local function setupDoor(doorModel)
	if initializedDoors[doorModel] or not doorModel.Parent then
		return
	end

	local panels = findDoorPanels(doorModel)
	if #panels == 0 then
		return
	end
	initializedDoors[doorModel] = true

	local requiredLevel = getDoorRequiredLevel(doorModel)
	local groups = clusterPanels(panels)
	for _, group in ipairs(groups) do
		computeOpenCFrames(group)
	end

	local prompts = {}
	local allLights = {}
	local originalColors = {}
	for _, desc in ipairs(doorModel:GetDescendants()) do
		if desc:IsA("ProximityPrompt") then
			table.insert(prompts, desc)
		elseif desc:IsA("BasePart") and string.lower(desc.Name):match("light") then
			table.insert(allLights, desc)
			originalColors[desc] = desc.Color
		end
	end

	for _, group in ipairs(groups) do
		group.lights = {}
		group.originalColors = {}
		local groupCenter = Vector3.zero
		for _, panel in ipairs(group) do
			groupCenter += panel.closedCFrame.Position
		end
		groupCenter /= #group

		for _, light in ipairs(allLights) do
			if (light.Position - groupCenter).Magnitude < SCANNER_RANGE then
				table.insert(group.lights, light)
				group.originalColors[light] = originalColors[light]
			end
		end

		group.state = {
			isOpen = false,
			isAnimating = false,
			closeThread = nil,
		}
	end

	local soundPart
	for _, group in ipairs(groups) do
		for _, panel in ipairs(group) do
			if panel.primaryPart.Parent then
				soundPart = panel.primaryPart
				break
			end
		end
		if soundPart then
			break
		end
	end
	if not soundPart then
		for _, desc in ipairs(doorModel:GetDescendants()) do
			if desc:IsA("BasePart") then
				soundPart = desc
				break
			end
		end
	end

	local function playSound(soundId, sourcePart)
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Volume = 2
		sound.RollOffMaxDistance = 70
		if sourcePart and sourcePart.Parent then
			sound.Parent = sourcePart
		elseif soundPart and soundPart.Parent then
			sound.Parent = soundPart
		else
			sound.Parent = SoundService
		end
		sound:Play()
		task.delay(8, function()
			if sound.Parent then
				sound:Destroy()
			end
		end)
	end

	local function setGroupLights(group, color)
		for _, light in ipairs(group.lights) do
			if light.Parent then
				light.Color = color
			end
		end
	end

	local function restoreGroupLights(group)
		for _, light in ipairs(group.lights) do
			if light.Parent and group.originalColors[light] then
				light.Color = group.originalColors[light]
			end
		end
	end

	local function flashRed(groupsToFlash, sourcePart)
		playSound(SOUND_DENIED, sourcePart)
		for _, group in ipairs(groupsToFlash) do
			setGroupLights(group, Color3.fromRGB(255, 30, 30))
		end
		task.delay(0.4, function()
			for _, group in ipairs(groupsToFlash) do
				restoreGroupLights(group)
			end
		end)
	end

	local function isDoorwayOccupied(group)
		for _, panel in ipairs(group) do
			local position = panel.closedCFrame.Position
			local size = panel.primaryPart.Size
			local radius = math.max(size.X, size.Z) * 0.5 + 2
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local rootPart = character and character:FindFirstChild("HumanoidRootPart")
				if rootPart then
					local delta = rootPart.Position - position
					local flat = Vector3.new(delta.X, 0, delta.Z)
					if flat.Magnitude < radius and math.abs(delta.Y) < size.Y * 0.5 + 5 then
						return true
					end
				end
			end
		end
		return false
	end

	local allPanelParts = {}
	for _, group in ipairs(groups) do
		for _, panel in ipairs(group) do
			for _, part in ipairs(panel.parts) do
				allPanelParts[part] = true
			end
		end
	end

	local originalDoorwayCollision = {}
	for _, part in ipairs(doorModel:GetDescendants()) do
		if part:IsA("BasePart") then
			originalDoorwayCollision[part] = part.CanCollide
		end
	end

	local function getPartBounds(part)
		local frame = part.CFrame
		local halfSize = part.Size * 0.5
		local right = frame.RightVector
		local up = frame.UpVector
		local look = frame.LookVector
		local extents = Vector3.new(
			math.abs(right.X) * halfSize.X + math.abs(up.X) * halfSize.Y + math.abs(look.X) * halfSize.Z,
			math.abs(right.Y) * halfSize.X + math.abs(up.Y) * halfSize.Y + math.abs(look.Y) * halfSize.Z,
			math.abs(right.Z) * halfSize.X + math.abs(up.Z) * halfSize.Y + math.abs(look.Z) * halfSize.Z
		)
		return frame.Position - extents, frame.Position + extents
	end

	local function getDoorwayBounds(group)
		local minimum = Vector3.new(math.huge, math.huge, math.huge)
		local maximum = Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, panel in ipairs(group) do
			local frame = panel.closedCFrame
			local halfSize = panel.primarySize * 0.5
			local right = frame.RightVector
			local up = frame.UpVector
			local look = frame.LookVector
			local extents = Vector3.new(
				math.abs(right.X) * halfSize.X + math.abs(up.X) * halfSize.Y + math.abs(look.X) * halfSize.Z,
				math.abs(right.Y) * halfSize.X + math.abs(up.Y) * halfSize.Y + math.abs(look.Y) * halfSize.Z,
				math.abs(right.Z) * halfSize.X + math.abs(up.Z) * halfSize.Y + math.abs(look.Z) * halfSize.Z
			)
			minimum = Vector3.new(
				math.min(minimum.X, frame.Position.X - extents.X),
				math.min(minimum.Y, frame.Position.Y - extents.Y),
				math.min(minimum.Z, frame.Position.Z - extents.Z)
			)
			maximum = Vector3.new(
				math.max(maximum.X, frame.Position.X + extents.X),
				math.max(maximum.Y, frame.Position.Y + extents.Y),
				math.max(maximum.Z, frame.Position.Z + extents.Z)
			)
		end
		return minimum, maximum
	end

	local function setGroupCollision(group, collidable)
		for _, panel in ipairs(group) do
			for _, part in ipairs(panel.parts) do
				if part.Parent then
					local original = panel.originalCollision[part]
					part.CanCollide = collidable and original.CanCollide or false
					part.CanQuery = collidable and original.CanQuery or false
				end
			end
		end
	end

	local function setDoorwayCollision(group, collidable)
		local minimum, maximum = getDoorwayBounds(group)
		for part, originalCanCollide in pairs(originalDoorwayCollision) do
			if part.Parent and not allPanelParts[part] and originalCanCollide then
				local partMinimum, partMaximum = getPartBounds(part)
				local overlapsDoorway = partMinimum.X <= maximum.X and partMaximum.X >= minimum.X
					and partMinimum.Y <= maximum.Y and partMaximum.Y >= minimum.Y
					and partMinimum.Z <= maximum.Z and partMaximum.Z >= minimum.Z
				if overlapsDoorway and part.Name == "Middle" then
					part.CanCollide = collidable
				end
			end
		end
	end

	local function setGroupPassage(group, passable)
		setGroupCollision(group, not passable)
		setDoorwayCollision(group, not passable)
	end

	local function getGroupAnimationDuration(group)
		for _, panel in ipairs(group) do
			local size = panel.primarySize
			local width = math.max(size.X, size.Z)
			if width >= LARGE_DOOR_WIDTH_THRESHOLD or size.Y >= LARGE_DOOR_HEIGHT_THRESHOLD then
				return LARGE_DOOR_OPEN_DURATION
			end
		end
		return OPEN_DURATION
	end

	local function moveGroup(group, opening)
		local tweens = {}
		local duration = getGroupAnimationDuration(group)
		local tweenInfo = TweenInfo.new(
			duration,
			Enum.EasingStyle.Quad,
			opening and Enum.EasingDirection.Out or Enum.EasingDirection.In
		)

		for _, panel in ipairs(group) do
			if panel.model.Parent and panel.primaryPart.Parent then
				local primaryTarget = opening and panel.openCFrame or panel.closedCFrame
				local targetPivot = primaryTarget * panel.primaryToPivot
				local pivotValue = Instance.new("CFrameValue")
				pivotValue.Value = panel.model:GetPivot()
				local connection = pivotValue:GetPropertyChangedSignal("Value"):Connect(function()
					if panel.model.Parent then
						panel.model:PivotTo(pivotValue.Value)
					end
				end)
				local tween = TweenService:Create(pivotValue, tweenInfo, {Value = targetPivot})
				table.insert(tweens, {
					value = pivotValue,
					connection = connection,
					tween = tween,
					model = panel.model,
					target = targetPivot,
				})
				tween:Play()
			end
		end

		task.wait(duration)
		for _, active in ipairs(tweens) do
			active.connection:Disconnect()
			if active.model.Parent then
				active.model:PivotTo(active.target)
			end
			active.value:Destroy()
		end
	end

	local function closeGroup(group)
		local state = group.state
		if state.isAnimating or not state.isOpen then
			return
		end
		if isDoorwayOccupied(group) then
			state.closeThread = task.delay(1, function()
				closeGroup(group)
			end)
			return
		end

		state.isAnimating = true
		state.closeThread = nil
		playSound(SOUND_CLOSE)
		setGroupPassage(group, true)
		moveGroup(group, false)
		state.isOpen = false
		state.isAnimating = false
		setGroupPassage(group, false)
		restoreGroupLights(group)
	end

	local function openGroup(group)
		local state = group.state
		if state.isAnimating then
			return
		end
		if state.isOpen then
			if state.closeThread then
				task.cancel(state.closeThread)
			end
			state.closeThread = task.delay(STAY_OPEN_TIME, function()
				closeGroup(group)
			end)
			return
		end

		state.isAnimating = true
		setGroupPassage(group, true)
		setGroupLights(group, Color3.fromRGB(0, 255, 0))
		playSound(SOUND_OPEN)
		moveGroup(group, true)
		state.isOpen = true
		state.isAnimating = false
		state.closeThread = task.delay(STAY_OPEN_TIME, function()
			closeGroup(group)
		end)
	end

	for _, prompt in ipairs(prompts) do
		prompt.ActionText = "Open"
		prompt.ObjectText = ""
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.OneGlobally
		prompt.Enabled = true
		prompt.Style = Enum.ProximityPromptStyle.Default

		local scannerGroups = {}
		local promptPart = prompt.Parent
		if promptPart and promptPart:IsA("BasePart") then
			local scannerPosition = promptPart.Position
			for _, group in ipairs(groups) do
				for _, panel in ipairs(group) do
					if (panel.closedCFrame.Position - scannerPosition).Magnitude < SCANNER_RANGE then
						table.insert(scannerGroups, group)
						break
					end
				end
			end
		end
		if #scannerGroups == 0 then
			scannerGroups = groups
		end

		prompt.Triggered:Connect(function(player)
			for _, group in ipairs(scannerGroups) do
				if group.state.isAnimating then
					return
				end
			end

			local character = player.Character
			if not character then
				return
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then
				return
			end

			if requiredLevel == 0 then
				for _, group in ipairs(scannerGroups) do
					task.spawn(function()
						openGroup(group)
					end)
				end
				return
			end

			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				local rayParams = RaycastParams.new()
				rayParams.FilterType = Enum.RaycastFilterType.Exclude
				rayParams.FilterDescendantsInstances = {doorModel, character}
				for _, group in ipairs(scannerGroups) do
					local center = Vector3.zero
					for _, panel in ipairs(group) do
						center += panel.closedCFrame.Position
					end
					center /= #group
					local delta = center - rootPart.Position
					if delta.Magnitude > 1 and workspace:Raycast(rootPart.Position, delta, rayParams) then
						return
					end
				end
			end

			local keycardLevel
			local containers = {character, player:FindFirstChildOfClass("Backpack")}
			for _, container in ipairs(containers) do
				if container then
					for _, child in ipairs(container:GetChildren()) do
						if child:IsA("Tool") then
							local level = getKeycardLevel(child)
							if level ~= nil and (keycardLevel == nil or level > keycardLevel) then
								keycardLevel = level
							end
						end
					end
				end
			end

			if keycardLevel == nil or keycardLevel < requiredLevel then
				playSound(SOUND_DENIED, promptPart)
				for _, group in ipairs(scannerGroups) do
					setGroupLights(group, Color3.fromRGB(255, 30, 30))
				end
				task.delay(0.4, function()
					for _, group in ipairs(scannerGroups) do
						restoreGroupLights(group)
					end
				end)
				return
			end

			for _, group in ipairs(scannerGroups) do
				task.spawn(function()
					openGroup(group)
				end)
			end
		end)
	end

	print(string.format("[DoorSystem] %s | Required Level: %d | Groups: %d | Prompts: %d", doorModel:GetFullName(), requiredLevel, #groups, #prompts))
end

local function setupAllDoors()
	local candidates = {}
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("Model") and containsDoorName(descendant) and #findDoorPanels(descendant) > 0 then
			table.insert(candidates, descendant)
		end
	end

	for _, candidate in ipairs(candidates) do
		local hasNestedCandidate = false
		for _, other in ipairs(candidates) do
			if other ~= candidate and other:IsDescendantOf(candidate) then
				hasNestedCandidate = true
				break
			end
		end
		if not hasNestedCandidate then
			setupDoor(candidate)
		end
	end
end

setupAllDoors()

local scanQueued = false
workspace.DescendantAdded:Connect(function()
	if scanQueued then
		return
	end
	scanQueued = true
	task.delay(0.15, function()
		scanQueued = false
		setupAllDoors()
	end)
end)
