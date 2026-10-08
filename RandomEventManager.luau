-- ============================================================
-- RandomEventManager
-- Location: ServerScriptService/RandomEventManager
-- Triggers a random event every 5 minutes (300 seconds) and loops
-- continuously. Broadcasts notifications to all players via the
-- EventNotification RemoteEvent.
--
-- Events (original 4):
--   1. Frenzy      – 2x enemy/NPC speed for 60 seconds, then resets
--   2. Slowdown    – 0.5x enemy/NPC speed for 60 seconds, then resets
--   3. Gold Rush   – Gives every player 500 bonus cash (instant)
--   4. Heal Wave   – Heals all active enemies back to full HP
--
-- Events (new 14):
--   5.  Monkey Frenzy     – 30% faster tower attack for 60s
--   6.  Banana Rain       – Falling bananas give cash when touched
--   7.  Golden Balloon    – Special balloon with big cash reward
--   8.  Boss Rush         – Mini-bosses spawn on active plots
--   9.  Double Damage     – 2x tower damage for 30s
--   10. Speed Rush        – Enemies 50% faster + bonus cash to players
--   11. Frozen Jungle     – Enemies slowed for 45s
--   12. Jungle Storm      – Lightning strikes damage enemies over time
--   13. Monkey Army       – NPC warriors spawn to help defend
--   14. Treasure Hunt     – Treasure chests appear for cash rewards
--   15. Elite Balloon     – Powerful balloon with large reward
--   16. Tower Discount    – 25% cheaper upgrades for 60s
--   17. Banana Jackpot    – Random players get big cash prizes
--   18. Mini Boss Invasion– Multiple small bosses attack bases
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EventNotification = Remotes:WaitForChild("EventNotification")
local BalloonModels = ReplicatedStorage:WaitForChild("BalloonModels")
local Shared = ReplicatedStorage:WaitForChild("Shared")

-- ¦¦ Config ¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦
local INTERVAL = 300       -- seconds between events
local DURATION = 60        -- duration of timed events

-- ¦¦ Helpers ¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦

-- Broadcast a notification to every connected client
local function broadcast(title, description, color)
    EventNotification:FireAllClients("Show", title, description, color)
    print("[RandomEventManager] Broadcast: " .. title .. " — " .. description)
end

-- Safely require a module without yielding forever
local function safeRequire(parent, name)
    local mod = parent:FindFirstChild(name)
    if not mod then return nil end
    local ok, result = pcall(require, mod)
    if ok then return result end
    warn("[RandomEventManager] Failed to require " .. name .. ": " .. tostring(result))
    return nil
end

local EnemyManager = safeRequire(ServerScriptService:WaitForChild("Modules"), "EnemyManager")
local MoneyManager = safeRequire(ServerScriptService:WaitForChild("Modules"), "MoneyManager")
local PlotManager = safeRequire(ServerScriptService:WaitForChild("Modules"), "PlotManager")

-- ¦¦ Plot Helpers ¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦

-- Collect all active plot numbers that currently have a player owner
local function getActivePlotNumbers()
    local plots = {}
    if PlotManager and PlotManager.GetPlayerForPlot then
        for i = 1, 6 do -- assuming up to 6 plots
            local owner = PlotManager.GetPlayerForPlot(i)
            if owner then
                table.insert(plots, i)
            end
        end
    end
    return plots
end

-- Get a random spawn position above a random active plot
local function getRandomPlotPosition()
    local plots = getActivePlotNumbers()
    if #plots == 0 then return nil end
    local plotNum = plots[math.random(1, #plots)]
    local map = workspace:FindFirstChild("Map 2nd Version -BrownX")
    local assets = map and map:FindFirstChild("Assets")
    local plotsFolder = assets and assets:FindFirstChild("Plots")
    local plot = plotsFolder and plotsFolder:FindFirstChild("Plot" .. plotNum)
    if plot then
        local cf, size = plot:GetBoundingBox()
        return cf.Position + Vector3.new(
            math.random(-size.X/2, size.X/2),
            size.Y / 2 + 30,
            math.random(-size.Z/2, size.Z/2)
        ), plotNum
    end
    return nil, plotNum
end

-- ¦¦ Spawned Object Cleanup Tracker ¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦
local spawnedObjects = {}

local function trackAndCleanup(folder, duration)
    table.insert(spawnedObjects, {folder = folder, expires = os.clock() + duration})
end

-- Periodically clean up expired spawned objects
task.spawn(function()
    while true do
        task.wait(10)
        local now = os.clock()
        for i = #spawnedObjects, 1, -1 do
            local entry = spawnedObjects[i]
            if now >= entry.expires and entry.folder and entry.folder.Parent then
                entry.folder.Parent = nil
                table.remove(spawnedObjects, i)
            end
        end
    end
end)

-- ¦¦ Event Definitions ¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦

local Events = {}

-- 1) FRENZY – double all enemy/NPC speed for 60 seconds
Events.Frenzy = {
    Name = "? FRENZY!",
    Description = "All enemies are moving 2x faster!",
    Color = Color3.fromRGB(255, 80, 80),
    Duration = DURATION,
    Start = function()
        if EnemyManager then
            EnemyManager.SetSpeedMultiplier(2.0)
        end
    end,
    End = function()
        if EnemyManager then
            EnemyManager.SetSpeedMultiplier(1.0)
        end
        broadcast("Frenzy Ended", "Enemy speed back to normal.", Color3.fromRGB(200, 200, 200))
    end,
}

-- 2) SLOWDOWN – halve all enemy/NPC speed for 60 seconds
Events.Slowdown = {
    Name = "?? SLOWDOWN!",
    Description = "All enemies are moving at half speed!",
    Color = Color3.fromRGB(80, 180, 255),
    Duration = DURATION,
    Start = function()
        if EnemyManager then
            EnemyManager.SetSpeedMultiplier(0.5)
        end
    end,
    End = function()
        if EnemyManager then
            EnemyManager.SetSpeedMultiplier(1.0)
        end
        broadcast("Slowdown Ended", "Enemy speed back to normal.", Color3.fromRGB(200, 200, 200))
    end,
}

-- 3) GOLD RUSH – give every player 500 cash (instant, no duration)
Events.GoldRush = {
    Name = "?? GOLD RUSH!",
    Description = "All players received 500 bonus cash!",
    Color = Color3.fromRGB(255, 215, 0),
    Duration = 0,  -- instant event
    Start = function()
        if MoneyManager then
            for _, player in ipairs(Players:GetPlayers()) do
                MoneyManager.AddMoney(player, 500)
            end
        end
    end,
    End = function() end,  -- nothing to reset
}

-- 4) HEAL WAVE – heal all active enemies to full HP
Events.HealWave = {
    Name = "?? HEAL WAVE!",
    Description = "All enemies have been healed to full HP!",
    Color = Color3.fromRGB(100, 255, 100),
    Duration = 0,  -- instant event
    Start = function()
        if EnemyManager and EnemyManager.GetActiveEnemyCount then
            -- Use the public API if available; otherwise try workspace
            local count = EnemyManager.GetActiveEnemyCount()
            print("[RandomEventManager] Heal Wave affecting " .. tostring(count) .. " enemies")
        end
        -- Heal all enemy models in workspace via attributes
        local activeEnemies = workspace:FindFirstChild("ActiveEnemies")
        if activeEnemies then
            for _, model in ipairs(activeEnemies:GetChildren()) do
                local maxHP = model:GetAttribute("MaxHP")
                if maxHP then
                    model:SetAttribute("CurrentHP", maxHP)
                end
            end
        end
    end,
    End = function() end,
}

-- ===============================================================
-- NEW 14 EVENTS
-- ===============================================================

-- 5) MONKEY FRENZY – 30% faster tower attack speed for 60 seconds
--    Sets a workspace attribute that tower systems can optionally read.
Events.MonkeyFrenzy = {
    Name = "?? MONKEY FRENZY!",
    Description = "Towers attack 30% faster for 60 seconds!",
    Color = Color3.fromRGB(255, 165, 0),
    Duration = 60,
    Start = function()
        workspace:SetAttribute("EventAttackSpeedMultiplier", 1.3)
        print("[RandomEventManager] Monkey Frenzy: attack speed x1.3")
    end,
    End = function()
        workspace:SetAttribute("EventAttackSpeedMultiplier", nil)
        broadcast("Monkey Frenzy Ended", "Tower attack speed back to normal.", Color3.fromRGB(200, 200, 200))
    end,
}

-- 6) BANANA RAIN – falling bananas that give cash when touched
Events.BananaRain = {
    Name = "?? BANANA RAIN!",
    Description = "Catch falling bananas for bonus cash!",
    Color = Color3.fromRGB(255, 230, 50),
    Duration = 30,
    Start = function()
        local folder = Instance.new("Folder")
        folder.Name = "BananaRain"
        folder.Parent = workspace

        local bananaColors = {
            Color3.fromRGB(255, 230, 50),
            Color3.fromRGB(255, 210, 40),
            Color3.fromRGB(255, 240, 80),
        }

        -- Spawn bananas continuously during the event
        task.spawn(function()
            while folder.Parent do
                local plots = getActivePlotNumbers()
                if #plots > 0 then
                    local pos, plotNum = getRandomPlotPosition()
                    if pos then
                        local banana = Instance.new("Part")
                        banana.Name = "Banana"
                        banana.Shape = Enum.PartType.Block
                        banana.Size = Vector3.new(1.5, 0.6, 3)
                        banana.Color = bananaColors[math.random(1, #bananaColors)]
                        banana.Material = Enum.Material.SmoothPlastic
                        banana.Anchored = false
                        banana.CanCollide = false
                        banana.CFrame = CFrame.new(pos)
                        banana:SetAttribute("CashReward", math.random(50, 200))
                        banana.Parent = folder

                        -- Give cash to whoever touches it
                        banana.Touched:Connect(function(otherPart)
                            local character = otherPart.Parent
                            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                            if humanoid and MoneyManager then
                                local player = Players:GetPlayerFromCharacter(character)
                                if player then
                                    local reward = banana:GetAttribute("CashReward") or 100
                                    MoneyManager.AddMoney(player, reward)
                                    banana.Parent = nil
                                end
                            end
                        end)

                        -- Auto-remove after 15 seconds if not collected
                        task.delay(15, function()
                            if banana.Parent then
                                banana.Parent = nil
                            end
                        end)
                    end
                end
                task.wait(0.8)
            end
        end)

        trackAndCleanup(folder, 35)
    end,
    End = function()
        local folder = workspace:FindFirstChild("BananaRain")
        if folder then
            folder.Parent = nil
        end
    end,
}

-- 7) GOLDEN BALLOON – special golden balloon with big cash reward
Events.GoldenBalloon = {
    Name = "?? GOLDEN BALLOON!",
    Description = "A golden balloon appeared! Pop it for a huge cash reward!",
    Color = Color3.fromRGB(255, 215, 0),
    Duration = 0, -- instant spawn; the balloon persists until popped or 60s
    Start = function()
        local pos, plotNum = getRandomPlotPosition()
        if not pos then return end

        local balloon = Instance.new("Part")
        balloon.Name = "GoldenBalloon"
        balloon.Shape = Enum.PartType.Ball
        balloon.Size = Vector3.new(5, 5, 5)
        balloon.Color = Color3.fromRGB(255, 215, 0)
        balloon.Material = Enum.Material.SmoothPlastic
        balloon.Anchored = true
        balloon.CanCollide = false
        balloon.CFrame = CFrame.new(pos)
        balloon:SetAttribute("CashReward", 1000)
        balloon.Parent = workspace

        -- Add sparkle effect
        local sparkles = Instance.new("ParticleEmitter")
        sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0))
        sparkles.Size = NumberSequence.new(1.5)
        sparkles.Rate = 30
        sparkles.Lifetime = NumberRange.new(0.5, 1)
        sparkles.Speed = NumberRange.new(2, 4)
        sparkles.Parent = balloon

        local claimed = false
        balloon.Touched:Connect(function(otherPart)
            if claimed then return end
            local character = otherPart.Parent
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid and MoneyManager then
                local player = Players:GetPlayerFromCharacter(character)
                if player then
                    claimed = true
                    local reward = balloon:GetAttribute("CashReward") or 1000
                    MoneyManager.AddMoney(player, reward)
                    broadcast("Golden Balloon Popped!", player.Name .. " found $" .. reward .. "!", Color3.fromRGB(255, 215, 0))
                    balloon.Parent = nil
                end
            end
        end)

        -- Auto-remove after 60 seconds
        task.delay(60, function()
            if balloon.Parent then
                balloon.Parent = nil
            end
        end)
    end,
    End = function() end,
}

-- 8) BOSS RUSH – spawn mini-bosses on active plots
Events.BossRush = {
    Name = "?? BOSS RUSH!",
    Description = "Mini-bosses are spawning on active plots!",
    Color = Color3.fromRGB(200, 30, 30),
    Duration = 0,
    Start = function()
        if not EnemyManager then return end
        local plots = getActivePlotNumbers()
        if #plots == 0 then return end

        local bossTypes = {"TitanOrb"}
        for _, plotNum in ipairs(plots) do
            local bossType = bossTypes[math.random(1, #bossTypes)]
            task.spawn(function()
                pcall(function()
                    EnemyManager.SpawnEnemyOnPlot(plotNum, bossType, 5)
                end)
            end)
            task.wait(0.5)
        end
        print("[RandomEventManager] Boss Rush: spawned bosses on " .. #plots .. " plots")
    end,
    End = function() end,
}

-- 9) DOUBLE DAMAGE – 2x tower damage for 30 seconds
Events.DoubleDamage = {
    Name = "?? DOUBLE DAMAGE!",
    Description = "Towers deal 2x damage for 30 seconds!",
    Color = Color3.fromRGB(255, 60, 60),
    Duration = 30,
    Start = function()
        workspace:SetAttribute("EventDamageMultiplier", 2.0)
        print("[RandomEventManager] Double Damage: tower damage x2")
    end,
    End = function()
        workspace:SetAttribute("EventDamageMultiplier", nil)
        broadcast("Double Damage Ended", "Tower damage back to normal.", Color3.fromRGB(200, 200, 200))
    end,
}

-- 10) SPEED RUSH – enemies 50% faster + bonus cash to all players
Events.SpeedRush = {
    Name = "?? SPEED RUSH!",
    Description = "Enemies are 50% faster! But you get bonus cash!",
    Color = Color3.fromRGB(255, 100, 200),
    Duration = 45,
    Start = function()
        if EnemyManager then
            EnemyManager.SetSpeedMultiplier(1.5)
        end
        if MoneyManager then
            for _, player in ipairs(Players:GetPlayers()) do
                MoneyManager.AddMoney(player, 300)
            end
        end
    end,
    End = function()
        if EnemyManager then
            EnemyManager.SetSpeedMultiplier(1.0)
        end
        broadcast("Speed Rush Ended", "Enemy speed back to normal.", Color3.fromRGB(200, 200, 200))
    end,
}

-- 11) FROZEN JUNGLE – enemies slowed for 45 seconds
Events.FrozenJungle = {
    Name = "?? FROZEN JUNGLE!",
    Description = "All enemies are frozen and slowed for 45 seconds!",
    Color = Color3.fromRGB(100, 200, 255),
    Duration = 45,
    Start = function()
        if EnemyManager then
            EnemyManager.SetSpeedMultiplier(0.4)
        end
    end,
    End = function()
        if EnemyManager then
            EnemyManager.SetSpeedMultiplier(1.0)
        end
        broadcast("Frozen Jungle Ended", "Enemies thawed out!", Color3.fromRGB(200, 200, 200))
    end,
}

-- 12) JUNGLE STORM – lightning strikes damage enemies over time
Events.JungleStorm = {
    Name = "?? JUNGLE STORM!",
    Description = "Lightning strikes are damaging all enemies!",
    Color = Color3.fromRGB(150, 100, 255),
    Duration = 30,
    Start = function()
        task.spawn(function()
            local elapsed = 0
            while elapsed < 30 do
                local activeEnemies = workspace:FindFirstChild("ActiveEnemies")
                if activeEnemies then
                    for _, model in ipairs(activeEnemies:GetChildren()) do
                        local currentHP = model:GetAttribute("CurrentHP")
                        local maxHP = model:GetAttribute("MaxHP")
                        local enemyId = model:GetAttribute("EnemyID")
                        if currentHP and currentHP > 0 and enemyId and EnemyManager then
                            -- Deal 15% of max HP as lightning damage
                            local lightningDamage = math.max(1, math.floor((maxHP or 10) * 0.15))
                            pcall(function()
                                -- Find the plot number from the model name or attribute
                                local plotNum = nil
                                local nameMatch = model.Name:match("Plot(%d+)")
                                if nameMatch then
                                    plotNum = tonumber(nameMatch)
                                else
                                    -- Try to find which plot this enemy is on via EnemyManager
                                    if PlotManager then
                                        for i = 1, 6 do
                                            local owner = PlotManager.GetPlayerForPlot(i)
                                            if owner then
                                                plotNum = i
                                                break
                                            end
                                        end
                                    end
                                end
                                if plotNum then
                                    local owner = PlotManager and PlotManager.GetPlayerForPlot(plotNum)
                                    EnemyManager.DamageEnemy(enemyId, plotNum, lightningDamage, "Normal", owner)
                                end
                            end)
                        end
                    end
                end

                -- Visual: spawn a quick lightning bolt effect at a random enemy
                local activeEnemies = workspace:FindFirstChild("ActiveEnemies")
                if activeEnemies then
                    local children = activeEnemies:GetChildren()
                    if #children > 0 then
                        local target = children[math.random(1, #children)]
                        local primary = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
                        if primary then
                            local lightning = Instance.new("Part")
                            lightning.Name = "LightningBolt"
                            lightning.Shape = Enum.PartType.Cylinder
                            lightning.Size = Vector3.new(0.3, 0.3, 60)
                            lightning.Color = Color3.fromRGB(200, 200, 255)
                            lightning.Material = Enum.Material.Neon
                            lightning.Anchored = true
                            lightning.CanCollide = false
                            lightning.CFrame = CFrame.new(primary.Position) * CFrame.Angles(0, 0, math.rad(90))
                            lightning.Parent = workspace
                            task.delay(0.15, function()
                                if lightning.Parent then lightning.Parent = nil end
                            end)
                        end
                    end
                end

                elapsed += 2
                task.wait(2)
            end
        end)
    end,
    End = function()
        broadcast("Jungle Storm Ended", "The storm has passed.", Color3.fromRGB(200, 200, 200))
    end,
}

-- 13) MONKEY ARMY – NPC warriors spawn to help defend
Events.MonkeyArmy = {
    Name = "??? MONKEY ARMY!",
    Description = "Monkey warriors have arrived to help defend!",
    Color = Color3.fromRGB(180, 130, 80),
    Duration = 45,
    Start = function()
        local folder = Instance.new("Folder")
        folder.Name = "MonkeyArmy"
        folder.Parent = workspace

        local plots = getActivePlotNumbers()
        if #plots == 0 then return end

        for _, plotNum in ipairs(plots) do
            local pos, _ = getRandomPlotPosition()
            if pos then
                -- Spawn a decorative monkey warrior near each plot
                local warrior = Instance.new("Model")
                warrior.Name = "MonkeyWarrior_NPC_" .. plotNum

                local body = Instance.new("Part")
                body.Name = "Body"
                body.Shape = Enum.PartType.Block
                body.Size = Vector3.new(3, 4.5, 3)
                body.Color = Color3.fromRGB(138, 78, 46)
                body.Material = Enum.Material.SmoothPlastic
                body.Anchored = true
                body.CanCollide = false
                body.CFrame = CFrame.new(pos.x, pos.y - 25, pos.z)
                body.Parent = warrior
                warrior.PrimaryPart = body
                warrior.Parent = folder

                -- Add a sword visual
                local sword = Instance.new("Part")
                sword.Name = "Sword"
                sword.Size = Vector3.new(0.3, 5, 0.3)
                sword.Color = Color3.fromRGB(200, 200, 200)
                sword.Material = Enum.Material.Metal
                sword.Anchored = true
                sword.CanCollide = false
                sword.CFrame = body.CFrame * CFrame.new(2, 0, 0)
                sword.Parent = warrior

                -- Add a BillboardGui label
                local bg = Instance.new("BillboardGui")
                bg.Size = UDim2.new(0, 120, 0, 30)
                bg.StudsOffset = Vector3.new(0, 4, 0)
                bg.AlwaysOnTop = true
                bg.Parent = body

                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.Text = "??? Defender"
                label.TextColor3 = Color3.fromRGB(255, 200, 100)
                label.Font = Enum.Font.FredokaOne
                label.TextScaled = true
                label.TextStrokeTransparency = 0
                label.Parent = bg

                -- Bob animation for visual flair
                task.spawn(function()
                    local baseY = body.Position.Y
                    while warrior.Parent do
                        for i = 0, math.pi * 2, 0.1 do
                            if not warrior.Parent then break end
                            body.CFrame = CFrame.new(body.Position.X, baseY + math.sin(i) * 0.5, body.Position.Z)
                            task.wait(0.05)
                        end
                    end
                end)
            end
        end

        trackAndCleanup(folder, 50)
    end,
    End = function()
        local folder = workspace:FindFirstChild("MonkeyArmy")
        if folder then
            folder.Parent = nil
        end
        broadcast("Monkey Army Departed", "The monkey warriors have left.", Color3.fromRGB(200, 200, 200))
    end,
}

-- 14) TREASURE HUNT – treasure chests appear for cash rewards
Events.TreasureHunt = {
    Name = "?? TREASURE HUNT!",
    Description = "Treasure chests have appeared! Find them for cash!",
    Color = Color3.fromRGB(180, 120, 60),
    Duration = 0,
    Start = function()
        local folder = Instance.new("Folder")
        folder.Name = "TreasureHunt"
        folder.Parent = workspace

        local plots = getActivePlotNumbers()
        if #plots == 0 then return end

        -- Spawn 3-5 treasure chests at random plot positions
        local chestCount = math.random(3, 5)
        for i = 1, chestCount do
            local pos, _ = getRandomPlotPosition()
            if pos then
                local chest = Instance.new("Part")
                chest.Name = "TreasureChest"
                chest.Shape = Enum.PartType.Block
                chest.Size = Vector3.new(3, 2.5, 2)
                chest.Color = Color3.fromRGB(139, 69, 19)
                chest.Material = Enum.Material.Wood
                chest.Anchored = true
                chest.CanCollide = true
                chest.CFrame = CFrame.new(pos.x, pos.y - 25, pos.z)
                chest:SetAttribute("CashReward", math.random(300, 800))
                chest.Parent = folder

                -- Gold sparkle effect
                local sparkles = Instance.new("ParticleEmitter")
                sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
                sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 200, 50))
                sparkles.Size = NumberSequence.new(1)
                sparkles.Rate = 15
                sparkles.Lifetime = NumberRange.new(0.5, 1)
                sparkles.Parent = chest

                local claimed = false
                chest.Touched:Connect(function(otherPart)
                    if claimed then return end
                    local character = otherPart.Parent
                    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                    if humanoid and MoneyManager then
                        local player = Players:GetPlayerFromCharacter(character)
                        if player then
                            claimed = true
                            local reward = chest:GetAttribute("CashReward") or 500
                            MoneyManager.AddMoney(player, reward)
                            broadcast("Treasure Found!", player.Name .. " found $" .. reward .. " in a chest!", Color3.fromRGB(255, 200, 50))
                            chest.Parent = nil
                        end
                    end
                end)
            end
            task.wait(0.2)
        end

        -- Auto-cleanup after 90 seconds
        trackAndCleanup(folder, 90)
    end,
    End = function() end,
}

-- 15) ELITE BALLOON – powerful balloon with large reward
Events.EliteBalloon = {
    Name = "?? ELITE BALLOON!",
    Description = "A powerful elite balloon has appeared! Defeat it for a big reward!",
    Color = Color3.fromRGB(180, 50, 255),
    Duration = 0,
    Start = function()
        if not EnemyManager then return end
        local plots = getActivePlotNumbers()
        if #plots == 0 then return end

        local plotNum = plots[math.random(1, #plots)]
        task.spawn(function()
            pcall(function()
                EnemyManager.SpawnEnemyOnPlot(plotNum, "OverlordSphere", 10)
            end)
        end)
        print("[RandomEventManager] Elite Balloon spawned on Plot" .. plotNum)
    end,
    End = function() end,
}

-- 16) TOWER DISCOUNT – 25% cheaper upgrades for 60 seconds
Events.TowerDiscount = {
    Name = "??? TOWER DISCOUNT!",
    Description = "25% cheaper upgrades for 60 seconds!",
    Color = Color3.fromRGB(100, 255, 150),
    Duration = 60,
    Start = function()
        workspace:SetAttribute("EventUpgradeDiscount", 0.25)
        print("[RandomEventManager] Tower Discount: 25% off upgrades")
    end,
    End = function()
        workspace:SetAttribute("EventUpgradeDiscount", nil)
        broadcast("Tower Discount Ended", "Upgrade prices back to normal.", Color3.fromRGB(200, 200, 200))
    end,
}

-- 17) BANANA JACKPOT – random players get big cash prizes
Events.BananaJackpot = {
    Name = "?? BANANA JACKPOT!",
    Description = "Random players just hit the jackpot!",
    Color = Color3.fromRGB(255, 180, 50),
    Duration = 0,
    Start = function()
        if not MoneyManager then return end
        local allPlayers = Players:GetPlayers()
        if #allPlayers == 0 then return end

        -- Give jackpot to 1-3 random players
        local jackpotWinners = math.min(#allPlayers, math.random(1, 3))
        local winners = {}
        local picked = {}

        for i = 1, jackpotWinners do
            if #picked >= #allPlayers then break end
            local idx
            repeat
                idx = math.random(1, #allPlayers)
            until not picked[idx]
            picked[idx] = true
            local player = allPlayers[idx]
            local prize = math.random(1000, 2500)
            MoneyManager.AddMoney(player, prize)
            table.insert(winners, player.Name .. " ($" .. prize .. ")")
        end

        if #winners > 0 then
            broadcast("Jackpot Winners!", table.concat(winners, ", "), Color3.fromRGB(255, 180, 50))
        end
    end,
    End = function() end,
}

-- 18) MINI BOSS INVASION – multiple small bosses attack bases
Events.MiniBossInvasion = {
    Name = "?? MINI BOSS INVASION!",
    Description = "Multiple mini-bosses are invading all bases!",
    Color = Color3.fromRGB(180, 0, 0),
    Duration = 0,
    Start = function()
        if not EnemyManager then return end
        local plots = getActivePlotNumbers()
        if #plots == 0 then return end

        local miniBossTypes = {"TitanOrb", "OverlordSphere"}
        for _, plotNum in ipairs(plots) do
            -- Spawn 2 mini-bosses per plot
            for i = 1, 2 do
                local bossType = miniBossTypes[math.random(1, #miniBossTypes)]
                task.spawn(function()
                    pcall(function()
                        EnemyManager.SpawnEnemyOnPlot(plotNum, bossType, 5)
                    end)
                end)
                task.wait(1.0)
            end
        end
        print("[RandomEventManager] Mini Boss Invasion on " .. #plots .. " plots")
    end,
    End = function() end,
}

-- Build a list of event keys for random selection
local EventKeys = {}
for key in pairs(Events) do
    table.insert(EventKeys, key)
end

-- ¦¦ Main Loop ¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦

local function runEvent(eventKey)
    local event = Events[eventKey]
    if not event then return end

    print("[RandomEventManager] Starting event: " .. eventKey)
    broadcast(event.Name, event.Description, event.Color)

    -- Send chat announcement to all clients
    EventNotification:FireAllClients("Chat", event.Name, event.Description, event.Color)

    -- Run the event start logic
    local ok, err = pcall(event.Start)
    if not ok then
        warn("[RandomEventManager] Error in " .. eventKey .. ".Start: " .. tostring(err))
    end

    -- If the event has a duration, wait then run End
    if event.Duration and event.Duration > 0 then
        task.wait(event.Duration)
        local ok2, err2 = pcall(event.End)
        if not ok2 then
            warn("[RandomEventManager] Error in " .. eventKey .. ".End: " .. tostring(err2))
        end
    end
end

print("[RandomEventManager] Initialized. First event in " .. INTERVAL .. " seconds.")

-- Track when the current countdown cycle started so we can sync new players
local cycleStartTime = os.clock()

EventNotification:FireAllClients("StartCountdown", INTERVAL)

-- Sync the countdown timer for players who join mid-cycle so their
-- client-side timer matches the server's actual remaining time
Players.PlayerAdded:Connect(function(player)
    local elapsed = os.clock() - cycleStartTime
    local remaining = math.max(1, INTERVAL - elapsed)
    EventNotification:FireClient(player, "StartCountdown", math.floor(remaining))
end)

-- Continuous loop — runs non-stop for the lifetime of the server
while true do
    task.wait(INTERVAL)

    -- Update cycle start time for the next countdown
    cycleStartTime = os.clock()

    -- Pick a random event
    local eventKey = EventKeys[math.random(1, #EventKeys)]
    print("[RandomEventManager] Random event selected: " .. eventKey)

    -- Run the event in a separate thread so the timer keeps accurate
    task.spawn(function()
        runEvent(eventKey)
    end)

    -- Restart countdown for the next event — broadcast to ALL clients simultaneously
    EventNotification:FireAllClients("StartCountdown", INTERVAL)
end