local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Modules = ServerScriptService:WaitForChild("Modules")

local DataManager = require(Modules:WaitForChild("DataManager"))
local SettingsManager = require(Modules:WaitForChild("SettingsManager"))
local StatsManager = require(Modules:WaitForChild("StatsManager"))
local MoneyManager = require(Modules:WaitForChild("MoneyManager"))
local InventoryManager = require(Modules:WaitForChild("InventoryManager"))
local PlotManager = require(Modules:WaitForChild("PlotManager"))
local BaseManager = require(Modules:WaitForChild("BaseManager"))
local EnemyManager = require(Modules:WaitForChild("EnemyManager"))
local TowerManager = require(Modules:WaitForChild("TowerManager"))
local WaveManager = require(Modules:WaitForChild("WaveManager"))
local SoundManager = require(Modules:WaitForChild("SoundManager"))
local ShopService = require(Modules:WaitForChild("ShopService"))
local TowerModelFactory = require(Modules:WaitForChild("TowerModelFactory"))
local AdminService = require(Modules:WaitForChild("AdminService"))
local QuestManager = require(Modules:WaitForChild("QuestManager"))

DataManager.Init()
SettingsManager.Init()
StatsManager.Init()
MoneyManager.Init()
InventoryManager.Init()
PlotManager.Init()
BaseManager.Init()
EnemyManager.Init()
TowerManager.Init()
WaveManager.Init()
SoundManager.Init()
ShopService.Init()
AdminService.Init()
QuestManager.Init()
TowerModelFactory.GenerateAll()

local TearingDown = {}

local function setupPlayer(player)
	if not DataManager.OnPlayerAdded(player) or not player.Parent then
		return
	end
	SettingsManager.OnPlayerAdded(player)
	StatsManager.OnPlayerAdded(player)
	MoneyManager.OnPlayerAdded(player)
	InventoryManager.OnPlayerAdded(player)
	PlotManager.OnPlayerAdded(player)
	BaseManager.OnPlayerAdded(player)
	ShopService.OnPlayerAdded(player)
	QuestManager.OnPlayerAdded(player)
end

local function teardownPlayer(player)
	if TearingDown[player] then
		return
	end
	TearingDown[player] = true
	local plotNumber = PlotManager.GetPlotNumber(player)
	if plotNumber then
		TowerManager.SnapshotPlayerTowers(player)
	end
	local saved = DataManager.SaveNow(player)
	if plotNumber then
		EnemyManager.ClearPlotEnemies(plotNumber)
		TowerManager.ClearTowersForPlot(plotNumber, "Despawn")
	end
	WaveManager.ResetPlayerWaveState(player)
	WaveManager.OnPlayerRemoving(player)
	SettingsManager.OnPlayerRemoving(player)
	ShopService.OnPlayerRemoving(player)
	BaseManager.OnPlayerRemoving(player)
	PlotManager.OnPlayerRemoving(player)
	InventoryManager.OnPlayerRemoving(player)
	MoneyManager.OnPlayerRemoving(player)
	StatsManager.OnPlayerRemoving(player)
	QuestManager.OnPlayerRemoving(player)
	if saved then
		DataManager.ReleaseProfile(player)
	else
		DataManager.ReleaseAfterSave(player)
	end
	TearingDown[player] = nil
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(setupPlayer, player)
end)

Players.PlayerRemoving:Connect(teardownPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, player)
end

print("[GameManager] Ready")