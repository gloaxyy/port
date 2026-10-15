
]]

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ServerScriptService = game:GetService("ServerScriptService")

local RedLineUtil = require(ServerScriptService:WaitForChild("RedLineUtil"))


local CHECK_INTERVAL = 0.25
local DAMAGE_PER_CHECK = 0 -- Damage dealt each check when outside the zone
local TARGET_TEAM = "Class-D"
local FORCEFIELD_NAME = "RedLineForceField"


local function getTargetTeam(): Team?
	return Teams:FindFirstChild(TARGET_TEAM)
end

local function ensureForceField(character: Model)
	if character:FindFirstChild(FORCEFIELD_NAME) then return end
	local ff = Instance.new("ForceField")
	ff.Name = FORCEFIELD_NAME
	ff.Visible = false
	ff.Parent = character
end

local function removeForceField(character: Model)
	local ff = character:FindFirstChild(FORCEFIELD_NAME)
	if ff then
		ff:Destroy()
	end
end

local function updatePlayer(player: Player)
	-- Only affect Class-D players
	local team = player.Team
	if not team or team.Name ~= TARGET_TEAM then
		local character = player.Character
		if character then
			removeForceField(character)
		end
		return
	end

	local character = player.Character
	if not character or not character.Parent then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid or humanoid.Health <= 0 then return end

	if RedLineUtil.IsPositionInside(hrp.Position) then
		-- Inside the zone: invulnerable
		ensureForceField(character)
	else
		-- Outside the zone: remove protection and take damage
		removeForceField(character)
		if DAMAGE_PER_CHECK > 0 then
			humanoid:TakeDamage(DAMAGE_PER_CHECK)
		end
	end
end


local function updateAllPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		local ok, err = pcall(updatePlayer, player)
		if not ok then
			warn("[RedLineSystem] error updating player " .. player.Name .. ": " .. tostring(err))
		end
	end
end

updateAllPlayers()

-- Main monitoring loop
while task.wait(CHECK_INTERVAL) do
	updateAllPlayers()
end
