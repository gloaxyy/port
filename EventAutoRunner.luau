-- EventAutoRunner (Server-side)
-- Fires the map events automatically on a timer so the whole server
-- experiences them without an admin triggering each one.
--   * ~2 minutes after the server starts, then every EVENT_INTERVAL seconds,
--     a random event (lava/toxic/hacker/frost/disco/candy/aura) runs for the
--     EventService DURATION (120s).
--   * Admins can still force specific events via AdminCommandService; the
--     runner only ever starts events, never stops admin-run ones.

local ServerScriptService = game:GetService("ServerScriptService")

local FIRST_DELAY = 120     -- seconds after server start before the first event
local EVENT_INTERVAL = 420  -- seconds between events (7 minutes)

local EventService = require(ServerScriptService:WaitForChild("EventService", 60))
if not EventService then
	warn("[EventAutoRunner] EventService module not found - auto events disabled")
	return
end

print("[EventAutoRunner] loaded - first random event in " .. tostring(FIRST_DELAY)
	.. "s, then every " .. tostring(EVENT_INTERVAL) .. "s")

task.spawn(function()
	task.wait(FIRST_DELAY)
	while true do
		local ok, msg = pcall(EventService.Start, "random")
		if ok then
			print("[EventAutoRunner] auto event: " .. tostring(msg))
		else
			warn("[EventAutoRunner] auto event failed: " .. tostring(msg))
		end
		task.wait(EVENT_INTERVAL)
	end
end)