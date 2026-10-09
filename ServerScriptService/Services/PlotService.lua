local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameConfig"))

local PlotService = {}
PlotService.__index = PlotService

local plotFolder = nil
local plotsByPlayer = {}
local nextPlotId = 1

local function ensurePlotFolder()
    if plotFolder and plotFolder.Parent then
        return plotFolder
    end

    plotFolder = Workspace:FindFirstChild("Plots")
    if not plotFolder then
        plotFolder = Instance.new("Folder")
        plotFolder.Name = "Plots"
        plotFolder.Parent = Workspace
    end

    return plotFolder
end

local function addDecoration(parent, name, size, pos, color, material, transparency)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.Position = pos
    part.Color = color
    part.Material = material or Enum.Material.SmoothPlastic
    part.Transparency = transparency or 0
    part.Anchored = true
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = parent
    return part
end

local function createBasePlot(plotId)
    local plot = Instance.new("Model")
    plot.Name = "Plot_" .. tostring(plotId)
    plot.Parent = ensurePlotFolder()

    local ground = addDecoration(
        plot,
        "Ground",
        GameConfig.Plot.GroundSize,
        Vector3.new((plotId * GameConfig.Plot.PlotSpacing), 0, 0),
        Color3.fromRGB(52, 146, 82),
        Enum.Material.Grass,
        0
    )

    local border = addDecoration(
        plot,
        "OuterBorder",
        Vector3.new(78, 3, 78),
        ground.Position + Vector3.new(0, 1.5, 0),
        Color3.fromRGB(37, 37, 40),
        Enum.Material.SmoothPlastic,
        0.25
    )
    border.CanCollide = false

    local path = addDecoration(
        plot,
        "EntryPath",
        Vector3.new(18, 0.5, 28),
        ground.Position + Vector3.new(0, 0.35, 18),
        Color3.fromRGB(141, 141, 141),
        Enum.Material.Slate,
        0.05
    )
    path.CanCollide = false

    local spawnLocation = Instance.new("SpawnLocation")
    spawnLocation.Name = "Spawn"
    spawnLocation.Size = Vector3.new(8, 1, 8)
    spawnLocation.Anchored = true
    spawnLocation.Color = Color3.fromRGB(57, 169, 255)
    spawnLocation.Transparency = 0.3
    spawnLocation.Position = ground.Position + GameConfig.Plot.SpawnOffset
    spawnLocation.Parent = plot

    local minePad = addDecoration(
        plot,
        "MinePad",
        Vector3.new(32, 1.5, 24),
        ground.Position + Vector3.new(0, 1.3, -8),
        Color3.fromRGB(89, 89, 92),
        Enum.Material.Slate,
        0.05
    )
    minePad.CanCollide = true

    local mineWallLeft = addDecoration(
        plot,
        "MineWallLeft",
        Vector3.new(2, 8, 26),
        ground.Position + Vector3.new(-15, 4, -8),
        Color3.fromRGB(60, 62, 68),
        Enum.Material.Metal,
        0.1
    )
    mineWallLeft.CanCollide = true

    local mineWallRight = addDecoration(
        plot,
        "MineWallRight",
        Vector3.new(2, 8, 26),
        ground.Position + Vector3.new(15, 4, -8),
        Color3.fromRGB(60, 62, 68),
        Enum.Material.Metal,
        0.1
    )
    mineWallRight.CanCollide = true

    local mineWallBack = addDecoration(
        plot,
        "MineWallBack",
        Vector3.new(30, 8, 2),
        ground.Position + Vector3.new(0, 4, -20),
        Color3.fromRGB(60, 62, 68),
        Enum.Material.Metal,
        0.1
    )
    mineWallBack.CanCollide = true

    local mineTop = addDecoration(
        plot,
        "MineTop",
        Vector3.new(28, 1, 28),
        ground.Position + Vector3.new(0, 7, -8),
        Color3.fromRGB(72, 72, 78),
        Enum.Material.SmoothPlastic,
        0.2
    )
    mineTop.CanCollide = false

    local machineArea = addDecoration(
        plot,
        "MachineArea",
        Vector3.new(42, 1.2, 18),
        ground.Position + Vector3.new(0, 1.5, 16),
        Color3.fromRGB(78, 82, 90),
        Enum.Material.SmoothPlastic,
        0.1
    )
    machineArea.CanCollide = true

    local defenseArea = addDecoration(
        plot,
        "DefenseArea",
        Vector3.new(28, 1.2, 28),
        ground.Position + Vector3.new(18, 1.5, -20),
        Color3.fromRGB(81, 83, 88),
        Enum.Material.Slate,
        0.08
    )
    defenseArea.CanCollide = true

    local sign = addDecoration(
        plot,
        "MineSign",
        Vector3.new(12, 4, 1),
        ground.Position + Vector3.new(0, 5, -18),
        Color3.fromRGB(48, 48, 48),
        Enum.Material.SmoothPlastic,
        0.1
    )
    sign.CanCollide = false

    local signText = Instance.new("BillboardGui")
    signText.Name = "MineSignText"
    signText.Size = UDim2.new(0, 220, 0, 50)
    signText.AlwaysOnTop = true
    signText.StudsOffset = Vector3.new(0, 4, 0)
    signText.Parent = sign

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "MINE"
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.fromRGB(255, 219, 96)
    label.TextScaled = true
    label.Parent = signText

    plot:SetAttribute("PlotId", plotId)
    plot:SetAttribute("OwnerUserId", 0)
    return plot
end

function PlotService:Initialize(PlayerDataService)
    self.PlayerDataService = PlayerDataService
end

function PlotService:GetFreePlotId()
    local id = nextPlotId
    nextPlotId = nextPlotId + 1
    return id
end

function PlotService:AssignPlot(player)
    if plotsByPlayer[player] then
        return plotsByPlayer[player]
    end

    local plotId = self:GetFreePlotId()
    local plot = createBasePlot(plotId)
    plotsByPlayer[player] = plot

    local data = self.PlayerDataService:GetData(player)
    if data then
        data.plotId = plotId
        plot:SetAttribute("OwnerUserId", player.UserId)
    end

    local spawn = plot:FindFirstChild("Spawn")
    if spawn then
        spawn.Position = plot:FindFirstChild("Ground").Position + GameConfig.Plot.SpawnOffset
    end

    return plot
end

function PlotService:GetPlot(player)
    if plotsByPlayer[player] then
        return plotsByPlayer[player]
    end

    return self:AssignPlot(player)
end

function PlotService:GetPlotById(plotId)
    local plots = ensurePlotFolder():GetChildren()
    for _, plot in ipairs(plots) do
        if plot:IsA("Model") and plot:GetAttribute("PlotId") == plotId then
            return plot
        end
    end
    return nil
end

return PlotService
