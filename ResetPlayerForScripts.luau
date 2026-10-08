print("[ResetPlayerForScripts] Resetting player to copy scripts...")

local Players = game:GetService("Players")

task.wait(1)

for _, player in Players:GetPlayers() do
    print("[ResetPlayerForScripts] Resetting character for:", player.Name)
    player:LoadCharacter()
end

print("[ResetPlayerForScripts] Character reset complete")
script:Destroy()
