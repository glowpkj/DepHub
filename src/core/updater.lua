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

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local MANIFEST_URL = "https://raw.githubusercontent.com/glowpkj/DepHub/main/src/update-manifest.json"
local SERVERS_URL = "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100"
local COMPARE_URL = "https://api.github.com/repos/glowpkj/DepHub/compare/%s...%s"

local Updater = {}
Updater.__index = Updater

local function updateLog(message)
    pcall(print, "[DEPHUB UPDATE] " .. tostring(message))
end

local function updateWarn(message)
    pcall(warn, "[DEPHUB UPDATE] " .. tostring(message))
end

local function httpGet(url)
    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and type(result) == "string" and #result > 0 then
        return true, result
    end
    return false, ok and "Resposta vazia" or tostring(result)
end

local function decode(source)
    local ok, result = pcall(function()
        return HttpService:JSONDecode(source)
    end)
    if ok and type(result) == "table" then
        return true, result
    end
    return false, ok and "JSON invalido" or tostring(result)
end

local function label(parent, text, size, position, textSize, color, font)
    local object = Instance.new("TextLabel")
    object.Size = size
    object.Position = position
    object.BackgroundTransparency = 1
    object.Text = text
    object.TextColor3 = color
    object.Font = font or Enum.Font.Gotham
    object.TextSize = textSize
    object.TextWrapped = true
    object.TextXAlignment = Enum.TextXAlignment.Center
    object.TextYAlignment = Enum.TextYAlignment.Center
    object.Parent = parent
    return object
end

local function buildSet(list)
    local result = {}
    if type(list) ~= "table" then
        return result
    end
    for _, value in ipairs(list) do
        if type(value) == "string" then
            result[value] = true
        end
    end
    return result
end

function Updater.new(options)
    options = options or {}
    local self = setmetatable({}, Updater)
    self.PlaceId = tostring(options.PlaceId or game.PlaceId)
    self.CurrentVersion = options.CurrentVersion and tostring(options.CurrentVersion) or nil
    self.CurrentCommit = options.CurrentCommit and tostring(options.CurrentCommit) or nil
    self.PollInterval = tonumber(options.PollInterval) or 15
    self.Countdown = tonumber(options.Countdown) or 12
    self.Mode = options.Mode or "serverhop"
    self.CancelledVersions = {}
    self.RejectedVersions = {}
    self.Destroyed = false
    self.PromptOpen = false
    self.PromptVersion = nil
    self.ActionInProgress = false
    self.ScreenGui = nil
    self.Connections = {}
    return self
end

function Updater:FetchVersion()
    updateLog("Verificando atualização...")

    local ok, source = httpGet(MANIFEST_URL .. "?dephubupdate=" .. tostring(math_random(1000000, 9999999)))
    if not ok then
        updateWarn("Falha ao baixar manifest: " .. tostring(source))
        return false, source
    end

    local decoded, manifest = decode(source)
    if not decoded then
        updateWarn("Manifest inválido: " .. tostring(manifest))
        return false, manifest
    end

    local games = manifest.games
    local info = type(games) == "table" and games[self.PlaceId] or nil
    if type(info) ~= "table" or not info.version then
        updateWarn("Jogo sem versão registrada no manifest.")
        return false, "Jogo sem versao registrada"
    end

    local commit = tostring(info.commit or manifest.commit or "")
    local files = type(info.files) == "table" and info.files or {}

    updateLog("Versão remota: " .. tostring(info.version))
    updateLog("Commit remoto: " .. (commit ~= "" and commit or "desconhecido"))

    return true, {
        Version = tostring(info.version),
        Name = tostring(info.name or "DepHub"),
        Commit = commit,
        Files = files
    }
end

function Updater:ValidateBackendChange(info)
    if not self.CurrentCommit or self.CurrentCommit == "" then
        updateWarn("Commit atual indisponível; não é possível validar mudança real.")
        return false
    end

    if not info.Commit or info.Commit == "" then
        updateWarn("Commit remoto indisponível; atualização rejeitada.")
        return false
    end

    if self.CurrentCommit == info.Commit then
        updateLog("Manifest mudou, mas o commit de origem continua igual. Ignorando falso update.")
        return false
    end

    local url = string.format(COMPARE_URL, self.CurrentCommit, info.Commit)
    updateLog("Validando mudanças entre commits...")

    local ok, source = httpGet(url)
    if not ok then
        updateWarn("Não foi possível validar o diff: " .. tostring(source))
        return false
    end

    local decoded, compareData = decode(source)
    if not decoded then
        updateWarn("Resposta de comparação inválida: " .. tostring(compareData))
        return false
    end

    local trackedFiles = buildSet(info.Files)
    local changedTracked = {}

    if type(compareData.files) == "table" then
        for _, file in ipairs(compareData.files) do
            local filename = type(file) == "table" and file.filename or nil
            if filename and trackedFiles[filename] then
                changedTracked[#changedTracked + 1] = filename
            end
        end
    end

    if #changedTracked == 0 then
        updateLog("Nenhuma alteração em código rastreado. Ignorando update fake/UI-only.")
        return false
    end

    updateLog("Mudanças válidas detectadas: " .. tostring(#changedTracked))
    for _, filename in ipairs(changedTracked) do
        updateLog("  - " .. filename)
    end

    return true
end

function Updater:DestroyPrompt()
    for _, connection in self.Connections do
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
    end
    self.Connections = {}

    if self.ScreenGui then
        self.ScreenGui:Destroy()
        self.ScreenGui = nil
    end

    self.PromptOpen = false
    self.PromptVersion = nil
end

function Updater:Cancel()
    if self.ActionInProgress then
        return
    end

    if self.PromptVersion then
        self.CancelledVersions[self.PromptVersion] = true
    end

    updateLog("Atualização cancelada pelo usuário.")
    self:DestroyPrompt()
end

function Updater:CreatePrompt(info)
    if self.Destroyed or self.PromptOpen or self.CancelledVersions[info.Version] then
        return
    end

    self.PromptOpen = true
    self.PromptVersion = info.Version

    local existing = PlayerGui:FindFirstChild("DepHubUpdatePrompt")
    if existing then
        existing:Destroy()
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "DepHubUpdatePrompt"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 10001
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = PlayerGui
    self.ScreenGui = gui

    local backdrop = Instance.new("Frame")
    backdrop.Size = UDim2.fromScale(1, 1)
    backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    backdrop.BackgroundTransparency = 0.35
    backdrop.BorderSizePixel = 0
    backdrop.Parent = gui

    local card = Instance.new("Frame")
    card.Size = UDim2.fromOffset(440, 240)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    card.BorderSizePixel = 0
    card.Parent = backdrop

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(45, 45, 45)
    stroke.Parent = card

    label(card, "DEPHUB ATUALIZADO", UDim2.new(1, -40, 0, 34), UDim2.fromOffset(20, 20), 19, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)
    label(card, "Uma nova versão do script está disponível.", UDim2.new(1, -40, 0, 28), UDim2.fromOffset(20, 58), 12, Color3.fromRGB(155, 155, 155))
    label(card, info.Name, UDim2.new(1, -40, 0, 22), UDim2.fromOffset(20, 88), 11, Color3.fromRGB(100, 100, 100), Enum.Font.GothamBold)

    local countdown = label(card, "Atualizando em " .. tostring(self.Countdown) .. "s", UDim2.new(1, -40, 0, 30), UDim2.fromOffset(20, 118), 14, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)

    local cancel = Instance.new("TextButton")
    cancel.Size = UDim2.fromOffset(180, 38)
    cancel.Position = UDim2.new(0.5, 0, 1, -18)
    cancel.AnchorPoint = Vector2.new(0.5, 1)
    cancel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    cancel.BorderSizePixel = 0
    cancel.Text = "CANCELAR"
    cancel.TextColor3 = Color3.fromRGB(190, 190, 190)
    cancel.Font = Enum.Font.GothamBold
    cancel.TextSize = 11
    cancel.AutoButtonColor = false
    cancel.Parent = card

    local cancelCorner = Instance.new("UICorner")
    cancelCorner.CornerRadius = UDim.new(0, 8)
    cancelCorner.Parent = cancel

    self.Connections[#self.Connections + 1] = cancel.MouseButton1Click:Connect(function()
        self:Cancel()
    end)

    updateLog("Atualização confirmada. Countdown iniciado: " .. tostring(self.Countdown) .. "s")

    task.spawn(function()
        for remaining = self.Countdown, 0, -1 do
            if self.Destroyed or not self.PromptOpen or self.PromptVersion ~= info.Version then
                return
            end

            countdown.Text = remaining > 0 and "Atualizando em " .. tostring(remaining) .. "s" or "Atualizando..."

            if remaining > 0 then
                task.wait(1)
            end
        end

        if self.Destroyed or not self.PromptOpen or self.PromptVersion ~= info.Version then
            return
        end

        self:Teleport(info)
    end)
end

function Updater:GetServer()
    local url = string.format(SERVERS_URL, self.PlaceId)
    updateLog("Procurando servidor para hop...")

    local ok, source = httpGet(url)
    if not ok then
        updateWarn("Falha ao obter servidores: " .. tostring(source))
        return false, source
    end

    local decoded, data = decode(source)
    if not decoded then
        updateWarn("Lista de servidores inválida: " .. tostring(data))
        return false, data
    end

    local candidates = {}
    if type(data.data) == "table" then
        for _, server in data.data do
            if type(server) == "table" and server.id and tonumber(server.playing) and tonumber(server.maxPlayers) then
                if server.id ~= game.JobId and server.playing < server.maxPlayers then
                    candidates[#candidates + 1] = server.id
                end
            end
        end
    end

    if #candidates == 0 then
        updateWarn("Nenhum servidor alternativo disponível.")
        return false, "Nenhum servidor disponivel"
    end

    return true, candidates[math_random(1, #candidates)]
end

function Updater:Teleport(info)
    if self.ActionInProgress then
        return
    end

    self.ActionInProgress = true
    self:DestroyPrompt()

    if self.Mode == "rejoin" then
        updateLog("Atualização válida. Iniciando rejoin...")
        local teleported = pcall(function()
            TeleportService:Teleport(tonumber(self.PlaceId), LocalPlayer)
        end)
        if not teleported then
            updateWarn("Rejoin falhou.")
        end
        return
    end

    local ok, jobId = self:GetServer()
    if ok and jobId then
        updateLog("Atualização válida. Iniciando server hop...")
        local teleported = pcall(function()
            TeleportService:TeleportToPlaceInstance(tonumber(self.PlaceId), jobId, LocalPlayer)
        end)
        if teleported then
            return
        end
        updateWarn("Server hop falhou; tentando rejoin.")
    end

    pcall(function()
        TeleportService:Teleport(tonumber(self.PlaceId), LocalPlayer)
    end)
end

function Updater:Check()
    if self.Destroyed or self.PromptOpen or self.ActionInProgress then
        return
    end

    local ok, info = self:FetchVersion()
    if not ok then
        return
    end

    if not self.CurrentVersion then
        self.CurrentVersion = info.Version
        self.CurrentCommit = info.Commit
        updateLog("Versão inicial registrada: " .. tostring(info.Version))
        return
    end

    if info.Version == self.CurrentVersion then
        return
    end

    if self.CancelledVersions[info.Version] then
        return
    end

    if self.RejectedVersions[info.Version] then
        return
    end

    updateLog("Diferença de versão detectada. Validando mudança real no backend...")

    if not self:ValidateBackendChange(info) then
        self.RejectedVersions[info.Version] = true
        return
    end

    self:CreatePrompt(info)
end

function Updater:Start()
    if self.Destroyed then
        return
    end

    updateLog("Updater iniciado. Intervalo: " .. tostring(self.PollInterval) .. "s")

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

    updateLog("Updater encerrado.")
    self.Destroyed = true
    self:DestroyPrompt()
end

return Updater
