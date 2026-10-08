local Teams = game:GetService("Teams")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("SCPConfig"))
local teamSelectEvent = ReplicatedStorage:WaitForChild("TeamSelectEvent")

-- ===== ANTI-SPAM COOLDOWN =====
local COOLDOWN_TIME = Config.COOLDOWN_TIME
local playerCooldowns = {}

-- SHIFTLOCK 

game.StarterPlayer.EnableMouseLockOption = false

--


-- ===== SPAWN POINTS =====
local spawnFolder = Workspace:FindFirstChild("TeamSpawns")

local function getSpawnForTeam(teamName)
    if not spawnFolder then return nil end
    for _, spawn in ipairs(spawnFolder:GetChildren()) do
        if spawn:GetAttribute("TeamName") == teamName then
            return spawn
        end
    end
    return nil
end

-- ===== GET TEAM CONFIG =====
local function getTeamConfig(teamName)
    for _, teamData in ipairs(Config.Teams) do
        if teamData.name == teamName then
            return teamData
        end
    end
    return nil
end

-- ===== XP SYSTEM (with DataStore saving) =====
local DataStoreService = game:GetService("DataStoreService")

local xpStore = nil
pcall(function()
    xpStore = DataStoreService:GetDataStore("PlayerXP_v1")
end)

local function loadXP(player)
    if not xpStore then return nil, false end
    local ok, data = pcall(function()
        return xpStore:GetAsync("XP_" .. player.UserId)
    end)
    if not ok then
        warn("[XP] Failed to load XP for " .. player.Name)
        return nil, false
    end
    if typeof(data) == "number" then
        return math.max(0, math.floor(data)), true
    end
    return nil, true
end

local function saveXP(player)
    if not xpStore or player:GetAttribute("XPDataLoaded") ~= true then return end
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then return end
    local xp = leaderstats:FindFirstChild("XP")
    if not xp then return end
    pcall(function()
        xpStore:SetAsync("XP_" .. player.UserId, xp.Value)
    end)
end

local function setupXP(player)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local xp = Instance.new("IntValue")
    xp.Name = "XP"
    xp.Value = 0
    xp.Parent = leaderstats

    xp.Changed:Connect(function(newVal)
        player:SetAttribute("SavedXP", newVal)
    end)

    task.spawn(function()
        local saved, loaded = loadXP(player)
        if not loaded then
            saved = player:GetAttribute("SavedXP") or 3000
        else
            saved = saved or 3000
        end

        if not player.Parent or not xp.Parent then return end

        xp.Value = math.max(0, math.floor(saved))
        player:SetAttribute("XPDataLoaded", loaded)
        player:SetAttribute("XPReady", true)

        while player.Parent and xp.Parent do
            task.wait(60)
            if player.Parent and xp.Parent then
                xp.Value = xp.Value + Config.XP_PER_MINUTE
            end
        end
    end)
end

-- ===== TEAM SELECTION HANDLER =====
teamSelectEvent.OnServerEvent:Connect(function(player, teamName, securityRank)
    if typeof(teamName) ~= "string" then return end

    local team = Teams:FindFirstChild(teamName)
    if not team then return end

    -- Anti-spam check
    local now = os.time()
    local lastChange = playerCooldowns[player.UserId] or 0
    if now - lastChange < COOLDOWN_TIME then
        local remaining = COOLDOWN_TIME - (now - lastChange)
        teamSelectEvent:FireClient(player, "cooldown", remaining)
        return
    end

    local teamConfig = getTeamConfig(teamName)
    if teamConfig and teamConfig.maxPlayers then
        local currentMembers = #team:GetPlayers()
        local alreadyOnTeam = player.Team == team
        if currentMembers >= teamConfig.maxPlayers and not alreadyOnTeam then
            teamSelectEvent:FireClient(player, "full", {
                teamName = team.Name,
                maxPlayers = teamConfig.maxPlayers,
            })
            return
        end
    end

    -- Check XP requirement
    if teamConfig then
        local playerXP = 0
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            local xpVal = leaderstats:FindFirstChild("XP")
            if xpVal then playerXP = xpVal.Value end
        end

        -- Check team XP requirement
        if teamConfig.xpRequired and playerXP < teamConfig.xpRequired then
            teamSelectEvent:FireClient(player, "locked", teamConfig.xpRequired)
            return
        end

        -- Check Security rank XP requirement
        if teamConfig.hasXP and typeof(securityRank) == "string" then
            for _, rank in ipairs(Config.SecurityRanks) do
                if rank.name == securityRank then
                    if playerXP < rank.xpRequired then
                        teamSelectEvent:FireClient(player, "locked", rank.xpRequired)
                        return
                    end
                    player:SetAttribute("SecurityRank", securityRank)
                    break
                end
            end
        end
    end

    -- Clear SecurityRank when switching to a team without XP ranks
    if not teamConfig.hasXP then
        player:SetAttribute("SecurityRank", nil)
    end

    playerCooldowns[player.UserId] = now
    player.Team = team
    player:LoadCharacter()
    teamSelectEvent:FireClient(player, "success", team.Name)
end)

-- ===== TEAM OUTFITS =====
local CLASSD_SHIRT_ID = "rbxassetid://278872200"
local CLASSD_PANTS_ID = "rbxassetid://278872148"

local SKIN_TONE = Color3.fromRGB(241, 194, 154) -- fallback only

-- ===== PLAYER'S REAL AVATAR HEAD COLOR =====
-- Reads the player's saved avatar head color instead of forcing a fixed skin tone.
local function getPlayerHeadColor(player, character)
    -- Best source: the player's saved avatar description
    local ok, description = pcall(function()
        return Players:GetHumanoidDescriptionFromUserId(player.UserId)
    end)
    if ok and description then
        return description.HeadColor
    end

    -- Fallback: the head color the character spawned with (before we overwrite it)
    if character then
        local head = character:FindFirstChild("Head")
        if head and head:IsA("BasePart") then
            return head.Color
        end

        local bodyColors = character:FindFirstChildOfClass("BodyColors")
        if bodyColors then
            return bodyColors.HeadColor3
        end
    end

    return SKIN_TONE
end

-- Per-team outfit definitions using BodyColors for distinct uniforms
local TEAM_OUTFITS = {
    ["Class-D"] = {
        torso = Color3.fromRGB(255, 136, 0),
        arms = Color3.fromRGB(255, 136, 0),
        legs = Color3.fromRGB(128, 68, 0),
        head = SKIN_TONE,
        shirt = CLASSD_SHIRT_ID,
        pants = CLASSD_PANTS_ID,
    },
    ["Scientific Department"] = {
        torso = Color3.fromRGB(245, 245, 245),
        arms = Color3.fromRGB(245, 245, 245),
        legs = Color3.fromRGB(40, 40, 40),
		head = SKIN_TONE,
		shirt = "rbxassetid://856797600",
		pants = "rbxassetid://856841165",
    },
    ["Security Department"] = {
        torso = Color3.fromRGB(0, 51, 102),
        arms = Color3.fromRGB(0, 51, 102),
        legs = Color3.fromRGB(20, 20, 20),
		head = SKIN_TONE,
		shirt = "http://www.roblox.com/asset/?id=303224842",
		pants = "http://www.roblox.com/asset/?id=303225003",
    },
    ["Nu-7"] = {
        torso = Color3.fromRGB(120, 0, 0),
        arms = Color3.fromRGB(80, 0, 0),
        legs = Color3.fromRGB(25, 25, 25),
		head = SKIN_TONE,
		shirt = "rbxassetid://405852280",
		pants = "rbxassetid://405852314",
    },
    ["Intelligence Agency"] = {
        torso = Color3.fromRGB(60, 0, 60),
        arms = Color3.fromRGB(40, 0, 40),
        legs = Color3.fromRGB(15, 15, 15),
		head = SKIN_TONE,
		shirt = "rbxassetid://913960681",
		pants = "rbxassetid://913956907",
    },
    ["Internal Security Department"] = {
        torso = Color3.fromRGB(45, 45, 45),
        arms = Color3.fromRGB(30, 30, 30),
        legs = Color3.fromRGB(10, 10, 10),
		head = SKIN_TONE,
		shirt = "rbxassetid://9535276249",
		pants = "rbxassetid://9535279039",
    },
    ["Rapid Response Team"] = {
        torso = Color3.fromRGB(0, 80, 0),
        arms = Color3.fromRGB(0, 60, 0),
        legs = Color3.fromRGB(20, 20, 20),
		head = SKIN_TONE,
		shirt = "http://www.roblox.com/asset/?id=6038339752",
		pants = "http://www.roblox.com/asset/?id=6038340191",
    },
    ["Chaos Insurgency"] = {
        torso = Color3.fromRGB(0, 45, 0),
        arms = Color3.fromRGB(0, 35, 0),
        legs = Color3.fromRGB(15, 15, 15),
		head = SKIN_TONE,
		shirt = "http://www.roblox.com/asset/?id=5060442568",
		pants = "http://www.roblox.com/asset/?id=5060446224",
    },
    ["Neutral"] = {
        torso = Color3.fromRGB(163, 162, 165),
        arms = Color3.fromRGB(163, 162, 165),
        legs = Color3.fromRGB(99, 95, 98),
        head = SKIN_TONE,
    },
}

local function applyTeamOutfit(character, teamName, player)
    -- Remove existing shirt and pants
    local existingShirt = character:FindFirstChildOfClass("Shirt")
    if existingShirt then existingShirt:Destroy() end

    local existingPants = character:FindFirstChildOfClass("Pants")
    if existingPants then existingPants:Destroy() end

    -- The player's real avatar head color (not a fixed skin tone)
    local playerHeadColor = getPlayerHeadColor(player, character)

    local outfit = TEAM_OUTFITS[teamName]
    if not outfit then
        -- Fall back to team color from config
        local teamConfig = getTeamConfig(teamName)
        if not teamConfig then return end
        outfit = {
            torso = teamConfig.color,
            arms = teamConfig.color,
            legs = Color3.new(teamConfig.color.R * 0.5, teamConfig.color.G * 0.5, teamConfig.color.B * 0.5),
            head = playerHeadColor,
        }
    end

    -- Apply BodyColors matching the team outfit
    local bodyColors = character:FindFirstChildOfClass("BodyColors")
    if not bodyColors then
        bodyColors = Instance.new("BodyColors")
        bodyColors.Name = "BodyColors"
        bodyColors.Parent = character
    end

    bodyColors.TorsoColor3 = outfit.torso
    bodyColors.LeftArmColor3 = outfit.arms
    bodyColors.RightArmColor3 = outfit.arms
    bodyColors.HeadColor3 = playerHeadColor
    bodyColors.LeftLegColor3 = outfit.legs
    bodyColors.RightLegColor3 = outfit.legs

    -- Apply shirt/pants if the outfit defines them
    if outfit.shirt then
        local shirt = Instance.new("Shirt")
        shirt.ShirtTemplate = outfit.shirt
        shirt.Name = "Shirt"
        shirt.Parent = character
    end

    if outfit.pants then
        local pants = Instance.new("Pants")
        pants.PantsTemplate = outfit.pants
        pants.Name = "Pants"
        pants.Parent = character
    end
end

-- ===== TEAM NAME TAG (BillboardGui above head, SCP:RP style) =====
local function applyTeamNameTag(character, team, player)
    local head = character:WaitForChild("Head", 5)
    if not head then return end

    local existingTag = head:FindFirstChild("TeamNameTag")
    if existingTag then existingTag:Destroy() end

    local existingNameTag = head:FindFirstChild("PlayerNameTag")
    if existingNameTag then existingNameTag:Destroy() end

    if not team or team.Name == "Neutral" then return end

    local teamColor = team.TeamColor.Color

    -- ===== TEAM NAME TAG =====
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "TeamNameTag"
    billboard.Size = UDim2.fromScale(2.808, 0.612)
    billboard.StudsOffset = Vector3.new(0, 1.88, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 40
    billboard.Parent = head

    local card = Instance.new("Frame")
    card.Name = "Card"
    card.Size = UDim2.fromScale(1, 1)
    card.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
    card.BackgroundTransparency = 0.4
    card.BorderSizePixel = 0
    card.Parent = billboard

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 3)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = teamColor
    stroke.Thickness = 0.7
    stroke.Transparency = 0.2
    stroke.Parent = card

    local accent = Instance.new("Frame")
    accent.Name = "AccentBar"
    accent.Size = UDim2.new(0, 2, 1, -4)
    accent.Position = UDim2.new(0, 2, 0, 2)
    accent.BackgroundColor3 = teamColor
    accent.BorderSizePixel = 0
    accent.Parent = card

    local accentCorner = Instance.new("UICorner")
    accentCorner.CornerRadius = UDim.new(1, 0)
    accentCorner.Parent = accent

    local label = Instance.new("TextLabel")
    label.Name = "NameLabel"
    label.Size = UDim2.new(1, -8, 1, -2)
    label.Position = UDim2.new(0, 7, 0, 1)
    label.BackgroundTransparency = 1
    label.Text = string.upper(team.Name)
    label.TextColor3 = Color3.fromRGB(235, 235, 240)
    label.TextStrokeTransparency = 0.55
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Font = Enum.Font.GothamMedium
    label.TextScaled = true
    label.RichText = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = card

    -- ===== PLAYER NAME TAG (below team tag) =====
    local nameBillboard = Instance.new("BillboardGui")
    nameBillboard.Name = "PlayerNameTag"
    nameBillboard.Size = UDim2.fromScale(2.808, 0.45)
    nameBillboard.StudsOffset = Vector3.new(0, 1.3, 0)
    nameBillboard.AlwaysOnTop = true
    nameBillboard.MaxDistance = 40
    nameBillboard.Parent = head

    local nameCard = Instance.new("Frame")
    nameCard.Name = "Card"
    nameCard.Size = UDim2.fromScale(1, 1)
    nameCard.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
    nameCard.BackgroundTransparency = 0.5
    nameCard.BorderSizePixel = 0
    nameCard.Parent = nameBillboard

    local nameCorner = Instance.new("UICorner")
    nameCorner.CornerRadius = UDim.new(0, 3)
    nameCorner.Parent = nameCard

    local nameStroke = Instance.new("UIStroke")
    nameStroke.Color = teamColor
    nameStroke.Thickness = 0.5
    nameStroke.Transparency = 0.3
    nameStroke.Parent = nameCard

    local nameAccent = Instance.new("Frame")
    nameAccent.Name = "AccentBar"
    nameAccent.Size = UDim2.new(0, 2, 1, -4)
    nameAccent.Position = UDim2.new(0, 2, 0, 2)
    nameAccent.BackgroundColor3 = teamColor
    nameAccent.BorderSizePixel = 0
    nameAccent.Parent = nameCard

    local nameAccentCorner = Instance.new("UICorner")
    nameAccentCorner.CornerRadius = UDim.new(1, 0)
    nameAccentCorner.Parent = nameAccent

    local playerName = player and player.Name or "Unknown"
    local playerLabel = Instance.new("TextLabel")
    playerLabel.Name = "PlayerNameLabel"
    playerLabel.Size = UDim2.new(1, -8, 1, -2)
    playerLabel.Position = UDim2.new(0, 7, 0, 1)
    playerLabel.BackgroundTransparency = 1
    playerLabel.Text = playerName
    playerLabel.TextColor3 = Color3.fromRGB(200, 200, 205)
    playerLabel.TextStrokeTransparency = 0.6
    playerLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    playerLabel.Font = Enum.Font.GothamMedium
    playerLabel.TextScaled = true
    playerLabel.TextXAlignment = Enum.TextXAlignment.Left
    playerLabel.Parent = nameCard
end

-- ===== PLAYER SETUP =====
local function onPlayerAdded(player)
    -- Set player to Neutral team (no team selected yet)
    local neutralTeam = Teams:FindFirstChild("Neutral")
    if neutralTeam then
        player.Team = neutralTeam
    end

    setupXP(player)

    player.CharacterAdded:Connect(function(character)
        local hrp = character:WaitForChild("HumanoidRootPart")
        local teamName = player.Team and player.Team.Name or nil

        -- Apply team outfit
        applyTeamOutfit(character, teamName, player)

        -- Show team name tag above head
        applyTeamNameTag(character, player.Team, player)

        local spawn = teamName and getSpawnForTeam(teamName)
        if not spawn or teamName == "Neutral" then
            spawn = Workspace:FindFirstChild("SpawnLocation")
        end
        if spawn and hrp then
            task.wait(0.03)
            if hrp and hrp.Parent then
                hrp.CFrame = spawn.CFrame + Vector3.new(0, 5, 0)
            end
        end
    end)
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- Handle players already in game
for _, player in ipairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end

-- ===== CLEANUP ON LEAVE (save XP) =====
Players.PlayerRemoving:Connect(function(player)
    playerCooldowns[player.UserId] = nil
    saveXP(player)
end)

-- Save everyone's XP when the server shuts down
game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        saveXP(player)
    end
end)
