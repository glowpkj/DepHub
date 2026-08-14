local game = game
local task = task
local type = type
local tostring = tostring
local tonumber = tonumber
local pcall = pcall
local math_random = math.random

local GetService = game.GetService
local Players = GetService(game, "Players")
local HttpService = GetService(game, "HttpService")
local TeleportService = GetService(game, "TeleportService")
local TweenService = GetService(game, "TweenService")
local UserInputService = GetService(game, "UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local BASE_URL = "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
local MANIFEST_URL = BASE_URL .. "src/update-manifest.json"

local Updater = {}
Updater.__index = Updater

local function httpGet(Url)
    local ok, result = pcall(function()
        return game:HttpGet(Url)
    end)

    if ok and type(result) == "string" and #result > 0 then
        return true, result
    end

    return false, ok and "Resposta vazia" or tostring(result)
end

local function decodeManifest(Source)
    local ok, data = pcall(function()
        return HttpService:JSONDecode(Source)
    end)

    if ok and type(data) == "table" then
        return true, data
    end

    return false, ok and "Manifesto invalido" or tostring(data)
end

local function createLabel(Parent, Text, Size, Position, TextSize, Color)
    local Label = Instance.new("TextLabel")
    Label.Size = Size
    Label.Position = Position
    Label.BackgroundTransparency = 1
    Label.Text = Text
    Label.TextColor3 = Color
    Label.Font = Enum.Font.Gotham
    Label.TextSize = TextSize
    Label.TextWrapped = true
    Label.TextXAlignment = Enum.TextXAlignment.Center
    Label.TextYAlignment = Enum.TextYAlignment.Center
    Label.Parent = Parent
    return Label
end

function Updater.new(Options)
    Options = Options or {}

    local Self = setmetatable({}, Updater)
    Self.PlaceId = tostring(Options.PlaceId or game.PlaceId)
    Self.CurrentVersion = tostring(Options.CurrentVersion or "unknown")
    Self.PollInterval = tonumber(Options.PollInterval) or 60
    Self.Countdown = tonumber(Options.Countdown) or 12
    Self.Mode = Options.Mode or "serverhop"
    Self.CancelledVersions = {}
    Self.Destroyed = false
    Self.PromptOpen = false
    Self.PromptVersion = nil
    Self.Connections = {}
    Self.ScreenGui = nil
    Self.CountdownLabel = nil
    Self.StatusLabel = nil
    Self.ActionInProgress = false
    return Self
end

function Updater:FetchVersion()
    local ok, source = httpGet(MANIFEST_URL)
    if not ok then
        return false, source
    end

    local decoded, manifest = decodeManifest(source)
    if not decoded then
        return false, manifest
    end

    local games = manifest.games
    local gameInfo = type(games) == "table" and games[self.PlaceId] or nil
    if type(gameInfo) ~= "table" or not gameInfo.version then
        return false, "Nenhuma versao registrada para este jogo"
    end

    return true, {
        Version = tostring(gameInfo.version),
        Name = tostring(gameInfo.name or "DepHub"),
        Commit = tostring(manifest.commit or "")
    }
end

function Updater:DestroyPrompt()
    if self.Destroyed then
        return
    end

    for _, connection in self.Connections do
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
    end
    self.Connections = {}

    if self.ScreenGui then
        local Gui = self.ScreenGui
        self.ScreenGui = nil
        TweenService:Create(Gui, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
            GroupTransparency = 1
        }):Play()
        task.delay(0.22, function()
            if Gui then
                Gui:Destroy()
            end
        end)
    end

    self.PromptOpen = false
    self.CountdownLabel = nil
    self.StatusLabel = nil
end

function Updater:Cancel()
    if self.ActionInProgress then
        return
    end

    if self.PromptVersion then
        self.CancelledVersions[self.PromptVersion] = true
    end

    self:DestroyPrompt()
end

function Updater:CreatePrompt(Info)
    if self.Destroyed or self.PromptOpen or self.CancelledVersions[Info.Version] then
        return
    end

    self.PromptOpen = true
    self.PromptVersion = Info.Version

    local Existing = PlayerGui:FindFirstChild("DepHubUpdatePrompt")
    if Existing then
        Existing:Destroy()
    end

    local Gui = Instance.new("ScreenGui")
    Gui.Name = "DepHubUpdatePrompt"
    Gui.IgnoreGuiInset = true
    Gui.ResetOnSpawn = false
    Gui.DisplayOrder = 10001
    Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    Gui.Parent = PlayerGui
    self.ScreenGui = Gui

    local Backdrop = Instance.new("Frame")
    Backdrop.Size = UDim2.fromScale(1, 1)
    Backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Backdrop.BackgroundTransparency = 0.35
    Backdrop.BorderSizePixel = 0
    Backdrop.Parent = Gui

    local Card = Instance.new("Frame")
    Card.Size = UDim2.fromOffset(440, 240)
    Card.Position = UDim2.fromScale(0.5, 0.5)
    Card.AnchorPoint = Vector2.new(0.5, 0.5)
    Card.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    Card.BorderSizePixel = 0
    Card.Parent = Backdrop

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 12)
    Corner.Parent = Card

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(45, 45, 45)
    Stroke.Thickness = 1
    Stroke.Parent = Card

    createLabel(Card, "DEPHUB ATUALIZADO", UDim2.new(1, -40, 0, 34), UDim2.fromOffset(20, 20), 19, Color3.fromRGB(255, 255, 255))
    createLabel(Card, "Uma nova versão do script está disponível.", UDim2.new(1, -40, 0, 32), UDim2.fromOffset(20, 58), 12, Color3.fromRGB(155, 155, 155))
    createLabel(Card, "Versão atualizada detectada", UDim2.new(1, -40, 0, 22), UDim2.fromOffset(20, 94), 11, Color3.fromRGB(100, 100, 100))

    local Countdown = createLabel(Card, "Atualizando em " .. tostring(self.Countdown) .. "s", UDim2.new(1, -40, 0, 30), UDim2.fromOffset(20, 118), 14, Color3.fromRGB(255, 255, 255))
    self.CountdownLabel = Countdown

    local CancelButton = Instance.new("TextButton")
    CancelButton.Size = UDim2.fromOffset(180, 38)
    CancelButton.Position = UDim2.fromScale(0.5, 1, 0, -18)
    CancelButton.AnchorPoint = Vector2.new(0.5, 1)
    CancelButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    CancelButton.BorderSizePixel = 0
    CancelButton.Text = "CANCELAR"
    CancelButton.TextColor3 = Color3.fromRGB(190, 190, 190)
    CancelButton.Font = Enum.Font.GothamBold
    CancelButton.TextSize = 11
    CancelButton.AutoButtonColor = false
    CancelButton.Parent = Card

    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.CornerRadius = UDim.new(0, 8)
    ButtonCorner.Parent = CancelButton

    local ButtonStroke = Instance.new("UIStroke")
    ButtonStroke.Color = Color3.fromRGB(50, 50, 50)
    ButtonStroke.Parent = CancelButton

    self.Connections[#self.Connections + 1] = CancelButton.MouseButton1Click:Connect(function()
        self:Cancel()
    end)

    task.spawn(function()
        for Remaining = self.Countdown, 0, -1 do
            if self.Destroyed or not self.PromptOpen or self.PromptVersion ~= Info.Version then
                return
            end

            Countdown.Text = Remaining > 0 and "Atualizando em " .. tostring(Remaining) .. "s" or "Atualizando..."

            if Remaining > 0 then
                task.wait(1)
            end
        end

        if self.Destroyed or not self.PromptOpen or self.PromptVersion ~= Info.Version then
            return
        end

        self:UpdateNow(Info)
    end)
end

function Updater:GetServer()
    local Url = "https://games.roblox.com/v1/games/" .. tostring(self.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100"
    local ok, source = httpGet(Url)
    if not ok then
        return false, source
    end

    local decoded, data = decodeManifest(source)
    if not decoded then
        return false, data
    end

    if type(data.data) ~= "table" then
        return false, "Lista de servidores invalida"
    end

    local candidates = {}
    for _, server in data.data do
        if type(server) == "table" and server.id and tonumber(server.playing) and tonumber(server.maxPlayers) then
            if server.id ~= game.JobId and server.playing < server.maxPlayers then
                candidates[#candidates + 1] = server.id
            end
        end
    end

    if #candidates == 0 then
        return false, "Nenhum servidor disponivel"
    end

    return true, candidates[math_random(1, #candidates)]
end

function Updater:Teleport()
    if self.ActionInProgress then
        return
    end

    self.ActionInProgress = true
    self:DestroyPrompt()

    if self.Mode == "rejoin" then
        pcall(function()
            TeleportService:Teleport(tonumber(self.PlaceId), LocalPlayer)
        end)
        return
    end

    local ok, JobId = self:GetServer()
    if ok and JobId then
        local success = pcall(function()
            TeleportService:TeleportToPlaceInstance(tonumber(self.PlaceId), JobId, LocalPlayer)
        end)
        if success then
            return
        end
    end

    pcall(function()
        TeleportService:Teleport(tonumber(self.PlaceId), LocalPlayer)
    end)
end

function Updater:UpdateNow(Info)
    if self.Destroyed or self.ActionInProgress then
        return
    end

    self:Teleport()
end

function Updater:Check()
    if self.Destroyed or self.PromptOpen or self.ActionInProgress then
        return
    end

    local ok, Info = self:FetchVersion()
    if not ok then
        return
    end

    if Info.Version == self.CurrentVersion then
        return
    end

    if self.CancelledVersions[Info.Version] then
        return
    end

    self:CreatePrompt(Info)
end

function Updater:Start()
    if self.Destroyed then
        return
    end

    task.spawn(function()
        task.wait(5)
        self:Check()

        while not self.Destroyed do
            task.wait(self.PollInterval)
            self:Check()
        end
    end)
end

function Updater:Destroy()
    if self.Destroyed then
        return
    end

    self.Destroyed = true
    self:DestroyPrompt()
end

return Updater
