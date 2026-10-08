print("[ResetPlayerCharacter] Resetting player character...")

local Players = game:GetService("Players")

task.wait(1)

for _, player in Players:GetPlayers() do
    print("[ResetPlayerCharacter] Resetting character for:", player.Name)
    player:LoadCharacter()
end

print("[ResetPlayerCharacter] Character reset complete")
script:Destroy()
