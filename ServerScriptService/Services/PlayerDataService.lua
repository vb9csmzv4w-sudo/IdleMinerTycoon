local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local OreConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("OreConfig"))
local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameConfig"))

local PlayerDataService = {}
PlayerDataService.__index = PlayerDataService

local dataStore = DataStoreService:GetDataStore(GameConfig.DataStoreName)
local playerDataCache = {}

local function clampNumber(value, minValue, maxValue)
    if value == nil then
        return minValue
    end
    value = tonumber(value) or minValue
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function createDefaultInventory()
    local inv = {}
    for _, oreName in ipairs(OreConfig.GetOreNames()) do
        inv[oreName] = 0
    end
    return inv
end

local function createDefaultData()
    return {
        cash = GameConfig.Player.StartingCash,
        cashEarned = 0,
        cashSpent = 0,
        rebirth = 0,
        pickaxe = GameConfig.Player.DefaultPickaxe,
        backpack = GameConfig.Player.DefaultBackpack,
        inventory = createDefaultInventory(),
        ownedPickaxes = {
            GameConfig.Player.DefaultPickaxe,
        },
        ownedBackpacks = {
            GameConfig.Player.DefaultBackpack,
        },
        plotId = nil,
        stats = {
            totalMined = 0,
            totalSold = 0,
            totalRebirths = 0,
        },
        lastSaved = 0,
    }
end

local function normalizeData(raw)
    local data = createDefaultData()

    if type(raw) ~= "table" then
        return data
    end

    data.cash = clampNumber(raw.cash, 0, GameConfig.Validation.MaxCash)
    data.cashEarned = clampNumber(raw.cashEarned, 0, GameConfig.Validation.MaxCash)
    data.cashSpent = clampNumber(raw.cashSpent, 0, GameConfig.Validation.MaxCash)
    data.rebirth = math.max(0, math.floor(raw.rebirth or 0))
    data.pickaxe = raw.pickaxe or GameConfig.Player.DefaultPickaxe
    data.backpack = raw.backpack or GameConfig.Player.DefaultBackpack

    if type(raw.ownedPickaxes) == "table" then
        data.ownedPickaxes = raw.ownedPickaxes
    end
    if type(raw.ownedBackpacks) == "table" then
        data.ownedBackpacks = raw.ownedBackpacks
    end

    data.inventory = createDefaultInventory()
    if type(raw.inventory) == "table" then
        for _, oreName in ipairs(OreConfig.GetOreNames()) do
            local value = raw.inventory[oreName]
            if type(value) == "number" then
                data.inventory[oreName] = clampNumber(value, 0, GameConfig.Validation.MaxInventoryPerOre)
            end
        end
    end

    if type(raw.stats) == "table" then
        data.stats.totalMined = math.max(0, math.floor(raw.stats.totalMined or 0))
        data.stats.totalSold = math.max(0, math.floor(raw.stats.totalSold or 0))
        data.stats.totalRebirths = math.max(0, math.floor(raw.stats.totalRebirths or 0))
    end

    data.plotId = raw.plotId
    data.lastSaved = raw.lastSaved or 0

    return data
end

function PlayerDataService:Initialize()
    Players.PlayerAdded:Connect(function(player)
        self:LoadPlayer(player)
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        self:LoadPlayer(player)
    end
end

function PlayerDataService:LoadPlayer(player)
    local loaded = nil
    local success, result = pcall(function()
        return dataStore:GetAsync("player_" .. player.UserId)
    end)

    if success then
        loaded = result
    end

    local data = normalizeData(loaded)
    playerDataCache[player] = data

    if player:GetAttribute("Cash") == nil then
        player:SetAttribute("Cash", data.cash)
    else
        player:SetAttribute("Cash", data.cash)
    end

    return data
end

function PlayerDataService:GetData(player)
    if not player then return nil end
    if playerDataCache[player] == nil then
        self:LoadPlayer(player)
    end
    return playerDataCache[player]
end

function PlayerDataService:SavePlayer(player)
    local data = self:GetData(player)
    if not data then
        return false
    end

    local success, result = pcall(function()
        return dataStore:UpdateAsync("player_" .. player.UserId, function()
            return {
                cash = data.cash,
                cashEarned = data.cashEarned,
                cashSpent = data.cashSpent,
                rebirth = data.rebirth,
                pickaxe = data.pickaxe,
                backpack = data.backpack,
                inventory = data.inventory,
                ownedPickaxes = data.ownedPickaxes,
                ownedBackpacks = data.ownedBackpacks,
                plotId = data.plotId,
                stats = data.stats,
                lastSaved = os.clock(),
            }
        end)
    end)

    if success then
        player:SetAttribute("Cash", data.cash)
        return true
    end

    warn("Save failed for player " .. player.Name .. ": " .. tostring(result))
    return false
end

function PlayerDataService:AddCash(player, amount)
    local data = self:GetData(player)
    if not data then
        return false
    end

    local value = tonumber(amount) or 0
    if value <= 0 then
        return false
    end

    data.cash = clampNumber(data.cash + value, 0, GameConfig.Validation.MaxCash)
    data.cashEarned = clampNumber(data.cashEarned + value, 0, GameConfig.Validation.MaxCash)
    player:SetAttribute("Cash", data.cash)
    return true
end

function PlayerDataService:RemoveCash(player, amount)
    local data = self:GetData(player)
    if not data then
        return false
    end

    local value = tonumber(amount) or 0
    if value <= 0 then
        return false
    end

    if data.cash < value then
        return false
    end

    data.cash = clampNumber(data.cash - value, 0, GameConfig.Validation.MaxCash)
    data.cashSpent = clampNumber(data.cashSpent + value, 0, GameConfig.Validation.MaxCash)
    player:SetAttribute("Cash", data.cash)
    return true
end

function PlayerDataService:SetCash(player, amount)
    local data = self:GetData(player)
    if not data then
        return false
    end

    local value = clampNumber(tonumber(amount) or 0, 0, GameConfig.Validation.MaxCash)
    data.cash = value
    player:SetAttribute("Cash", data.cash)
    return true
end

function PlayerDataService:RefreshCashAttribute(player)
    local data = self:GetData(player)
    if data then
        player:SetAttribute("Cash", data.cash)
    end
end

Players.PlayerRemoving:Connect(function(player)
    PlayerDataService:SavePlayer(player)
    playerDataCache[player] = nil
end)

return PlayerDataService
