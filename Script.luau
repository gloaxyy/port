--[[
	RedLine Touched Handler
	Connects to all RedLine parts in the workspace and marks Class-D players
	as escaped when they touch the boundary line.
]]

local Players = game:GetService("Players")
local TARGET_TEAM = "Class-D"

local function onRedLineTouched(hit: BasePart)
	local character = hit.Parent
	if not character then return end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	local team = player.Team
	if not team or team.Name ~= TARGET_TEAM then return end

	character:SetAttribute("Escaped", true)
end

-- Connect to all existing RedLine parts
for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("BasePart") and descendant.Name == "RedLine" then
		descendant.Touched:Connect(onRedLineTouched)
	end
end

-- Connect to RedLine parts added later
workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("BasePart") and descendant.Name == "RedLine" then
		descendant.Touched:Connect(onRedLineTouched)
	end
end)