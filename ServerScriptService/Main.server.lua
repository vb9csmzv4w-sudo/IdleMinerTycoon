local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Ensure Shared folder exists
local SharedFolder = ReplicatedStorage:FindFirstChild("Shared")
if not SharedFolder then
    SharedFolder = Instance.new("Folder")
    SharedFolder.Name = "Shared"
    SharedFolder.Parent = ReplicatedStorage
end

-- Ensure Remotes folder exists
local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not RemotesFolder then
    RemotesFolder = Instance.new("Folder")
    RemotesFolder.Name = "Remotes"
    RemotesFolder.Parent = ReplicatedStorage
end

local remoteNames = {
    "RequestMine",
    "RequestPurchase",
    "RequestSell",
    "UpdateUI",
}

for _, name in ipairs(remoteNames) do
    if not RemotesFolder:FindFirstChild(name) then
        local remote = Instance.new("RemoteEvent")
        remote.Name = name
        remote.Parent = RemotesFolder
    end
end

-- Ensure Services folder exists under Main
local ServicesFolder = script:FindFirstChild("Services")
if not ServicesFolder then
    ServicesFolder = Instance.new("Folder")
    ServicesFolder.Name = "Services"
    ServicesFolder.Parent = script
end

-- Load modules
local PlayerDataService = require(ServicesFolder:WaitForChild("PlayerDataService"))
local PlotService = require(ServicesFolder:WaitForChild("PlotService"))
local InventoryService = require(ServicesFolder:WaitForChild("InventoryService"))
local EconomyService = require(ServicesFolder:WaitForChild("EconomyService"))
local MiningService = require(ServicesFolder:WaitForChild("MiningService"))

PlayerDataService:Initialize()
PlotService:Initialize(PlayerDataService)
InventoryService:Initialize(PlayerDataService)
EconomyService:Initialize(PlayerDataService, InventoryService)
MiningService:Initialize(PlotService, InventoryService, PlayerDataService)

local RequestMine = RemotesFolder:WaitForChild("RequestMine")
local RequestPurchase = RemotesFolder:WaitForChild("RequestPurchase")
local RequestSell = RemotesFolder:WaitForChild("RequestSell")
local UpdateUI = RemotesFolder:WaitForChild("UpdateUI")

local function buildPlayerPayload(player)
    local data = PlayerDataService:GetData(player)
    local inventory = data.inventory
    local OreConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("OreConfig"))
    local BackpackConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BackpackConfig"))

    local totalOre = 0
    for _, oreName in ipairs(OreConfig.GetOreNames()) do
        totalOre += inventory[oreName] or 0
    end

    return {
        cash = data.cash,
        pickaxe = data.pickaxe,
        backpack = data.backpack,
        totalOre = totalOre,
        totalCapacity = BackpackConfig.GetByName(data.backpack).Capacity,
        inventory = inventory,
    }
end

local function sendUI(player)
    UpdateUI:FireClient(player, buildPlayerPayload(player))
end

local function setupPlayer(player)
    local data = PlayerDataService:GetData(player)
    local plot = PlotService:AssignPlot(player)
    MiningService:SeedPlot(plot)

    player:SetAttribute("Cash", data.cash)
    sendUI(player)
end

Players.PlayerAdded:Connect(function(player)
    setupPlayer(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
    setupPlayer(player)
end

RequestMine.OnServerEvent:Connect(function(player, payload)
    if typeof(payload) ~= "table" then
        return
    end

    local nodeId = payload.nodeId
    if type(nodeId) ~= "string" then
        return
    end

    local ok = MiningService:TryMine(player, nodeId)
    if ok then
        sendUI(player)
    end
end)

RequestPurchase.OnServerEvent:Connect(function(player, purchaseType, itemName)
    if purchaseType == "Pickaxe" then
        local ok = EconomyService:BuyPickaxe(player, itemName)
        if ok then
            sendUI(player)
        end
    elseif purchaseType == "Backpack" then
        local ok = EconomyService:BuyBackpack(player, itemName)
        if ok then
            sendUI(player)
        end
    end
end)

RequestSell.OnServerEvent:Connect(function(player)
    local ok = EconomyService:SellOres(player)
    if ok then
        sendUI(player)
    end
end)

task.spawn(function()
    while true do
        task.wait(30)
        for _, player in ipairs(Players:GetPlayers()) do
            if player then
                PlayerDataService:SavePlayer(player)
                sendUI(player)
            end
        end
    end
end)

print("Main.server.lua initialized successfully")
