--[[
	RedLineUtil
	Server-only authoritative geometry checks for the RedLine containment boundary.

	Boundary: Z = 92.57
	Inside  (safe)   = Z > 92.57  (Class-D spawn side, where they should stay)
	Outside (danger) = Z < 92.57  (crossed the red line into security area)

	This module must only ever be required from server-side scripts.
	Never trust a client-reported position — always use the server's own
	view of the player's Character / HumanoidRootPart.
]]

local REDLINE_Z = 92.57

local RedLineUtil = {}

RedLineUtil.REDLINE_Z = REDLINE_Z

-- Returns true if the world position is inside the RedLine boundary (safe zone).
function RedLineUtil.IsPositionInside(position: Vector3): boolean
	return position.Z > REDLINE_Z
end

-- Returns true if the world position is outside the RedLine boundary (danger zone).
function RedLineUtil.IsPositionOutside(position: Vector3): boolean
	return position.Z < REDLINE_Z
end

-- Returns true if the player's server-known character position is inside the RedLine.
-- Defaults to INSIDE (protected) when character / HumanoidRootPart is unavailable.
function RedLineUtil.IsPlayerInside(player: Player): boolean
	if not player or not player.Parent then
		return true
	end

	local character = player.Character
	if not character then
		return true
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return true
	end

	return RedLineUtil.IsPositionInside(hrp.Position)
end

-- Returns true if the player's server-known character position is outside the RedLine.
-- Defaults to INSIDE (not outside) when character / HumanoidRootPart is unavailable.
function RedLineUtil.IsPlayerOutside(player: Player): boolean
	return not RedLineUtil.IsPlayerInside(player)
end

return RedLineUtil
