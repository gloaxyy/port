print("[TracePurchaseFlow] Starting purchase trace...")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PurchaseTower = Remotes:WaitForChild("PurchaseTower")
local Players = game:GetService("Players")

task.wait(2)

-- Listen for purchase events
PurchaseTower.OnServerEvent:Connect(function(player, towerKey)
    print("[TracePurchaseFlow] PURCHASE EVENT FIRED!")
    print("[TracePurchaseFlow] Player:", player.Name)
    print("[TracePurchaseFlow] Tower:", towerKey)
    
    -- Check player attributes before
    print("[TracePurchaseFlow] Player attributes BEFORE:")
    for name, value in pairs(player:GetAttributes()) do
        if string.sub(name, 1, 4) == "INV_" then
            print("  ", name, "=", value)
        end
    end
    
    -- Wait a bit to see what happens
    task.wait(0.5)
    
    -- Check player attributes after
    print("[TracePurchaseFlow] Player attributes AFTER:")
    for name, value in pairs(player:GetAttributes()) do
        if string.sub(name, 1, 4) == "INV_" then
            print("  ", name, "=", value)
        end
    end
end)

print("[TracePurchaseFlow] Listening for purchases... Try buying a tower!")
