-- Steal An Exu -- Auto Hop Server.
-- Troca de servidor somente quando workspace.Runtime fica sem Exus por um periodo estavel.

local game = game
local task = task
local type = type
local tostring = tostring
local tonumber = tonumber
local pcall = pcall
local table = table
local math = math

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local env = type(getgenv) == "function" and getgenv() or _G

local POLL_INTERVAL = 0.25
local EMPTY_GRACE = 0
local RETRY_INTERVAL = 2
local MAX_PAGES = 5
local SERVER_LIMIT = 100
local MAX_CANDIDATES = 10

local AutoHop = {}
AutoHop.__index = AutoHop

local function log(self, ...)
    local parts = {}
    for index = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(index, ...))
    end
    local message = "[StealAnExu] Auto Hop: " .. table.concat(parts, " ")
    self.DebugLog[#self.DebugLog + 1] = message
    if #self.DebugLog > 100 then table.remove(self.DebugLog, 1) end
    print(message)
    local diag = env.__DEPHUB and env.__DEPHUB.Diagnostics
    if type(diag) == "table" and type(diag.Note) == "function" then
        pcall(diag.Note, diag, message)
    end
end

local function hasPrompt(model)
    local root = model and model:FindFirstChild("Root")
    if not root and model then
        local ok, nested = pcall(function() return model:FindFirstChild("Root", true) end)
        if ok then root = nested end
    end
    if not root then return false end

    local prompt = root:FindFirstChild("ProximityPrompt")
    if not prompt then
        local ok, nested = pcall(function()
            return root:FindFirstChildWhichIsA("ProximityPrompt", true)
        end)
        if ok then prompt = nested end
    end

    return prompt ~= nil
end

function AutoHop.new(options)
    options = options or {}
    local self = setmetatable({
        Enabled = false,
        Destroyed = false,
        Hopping = false,
        Thread = nil,
        RunId = 0,
        EmptySince = nil,
        NextAttempt = 0,
        PendingServerId = nil,
        HopStartedAt = nil,
        LastError = nil,
        LastStatus = "idle",
        DebugLog = {},
        PlaceId = tonumber(options.placeId) or game.PlaceId,
        EmptyGrace = tonumber(options.emptyGrace) or EMPTY_GRACE,
        TeleportConnection = nil,
        PlayerTeleportConnection = nil,
        TeleportStarted = false,
        FallbackAttempted = false,
        TeleportStartedAt = nil,
        TargetProvider = options.targetProvider,
        ScopeProvider = options.scopeProvider,
        PendingProvider = options.pendingProvider,
        LastScopeKey = nil,
    }, AutoHop)

    local function failedTeleport(source, reason, placeId)
        if self.Destroyed or not self.Hopping then return end
        local visited = env.__DEPHUB_STEALANEXU_VISITED_SERVERS
        if type(visited) == "table" and self.PendingServerId then
            visited[self.PendingServerId] = nil
        end
        self.PendingServerId = nil
        self.HopStartedAt = nil
        self.TeleportStartedAt = nil
        self.TeleportStarted = false
        self.FallbackAttempted = false
        self.Hopping = false
        self.LastError = tostring(reason or "teleporte recusado")
        self.LastStatus = "teleport failed"
        self.NextAttempt = os.clock() + RETRY_INTERVAL
        log(self, source, "falha:", self.LastError, "| placeId =", tostring(placeId))
    end

    local ok, connection = pcall(function()
        return TeleportService.TeleportInitFailed:Connect(function(player, result, message, placeId)
            if player ~= LocalPlayer then return end
            failedTeleport("TeleportInitFailed", tostring(result) .. ": " .. tostring(message), placeId)
        end)
    end)
    if ok then
        self.TeleportConnection = connection
    else
        log(self, "nao foi possivel conectar TeleportInitFailed:", tostring(connection))
    end

    local playerOk, playerConnection = pcall(function()
        return LocalPlayer.OnTeleport:Connect(function(state, placeId, spawnName)
            if self.Destroyed or not self.Hopping then return end
            local stateName = tostring(state)
            log(self, "Player.OnTeleport:", stateName,
                "| placeId =", tostring(placeId),
                "| spawn =", tostring(spawnName))

            if stateName:find("Started", 1, true)
                or stateName:find("WaitingForServer", 1, true)
                or stateName:find("InProgress", 1, true)
            then
                self.TeleportStarted = true
                self.TeleportStartedAt = os.clock()
                self.LastStatus = stateName
            elseif stateName:find("Failed", 1, true) then
                failedTeleport("Player.OnTeleport", stateName, placeId)
            end
        end)
    end)
    if playerOk then
        self.PlayerTeleportConnection = playerConnection
    else
        log(self, "nao foi possivel conectar Player.OnTeleport:", tostring(playerConnection))
    end

    return self
end

function AutoHop:IsEnabled()
    return self.Enabled == true
end

function AutoHop:Logs()
    return self.DebugLog
end

function AutoHop:RuntimeCount()
    if type(self.TargetProvider) == "function" then
        local ok, targets, reason = pcall(self.TargetProvider)
        if not ok then return nil, tostring(targets) end
        if type(targets) ~= "table" then return nil, reason or "mapeamento de terreiros indisponivel" end
        if #targets == 0 and reason ~= nil then return nil, reason end
        return #targets
    end

    local workspace = game:GetService("Workspace")
    local runtime = workspace:FindFirstChild("Runtime")
    if not runtime then return nil, "workspace.Runtime ainda nao apareceu" end

    local count = 0
    for _, model in ipairs(runtime:GetChildren()) do
        if hasPrompt(model) then count = count + 1 end
    end

    return count
end

function AutoHop:_scopeKey()
    if type(self.ScopeProvider) ~= "function" then return "all" end
    local ok, key = pcall(self.ScopeProvider)
    if not ok then return "scope-error" end
    return tostring(key or "")
end

function AutoHop:_httpGet(url)
    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok or type(result) ~= "string" or result == "" then
        return false, tostring(result)
    end
    return true, result
end

function AutoHop:_serverCandidates()
    local placeId = tonumber(self.PlaceId or game.PlaceId)
    if not placeId then return {}, "PlaceId invalido" end

    local visited = env.__DEPHUB_STEALANEXU_VISITED_SERVERS
    if type(visited) ~= "table" then
        visited = {}
        env.__DEPHUB_STEALANEXU_VISITED_SERVERS = visited
    end
    if game.JobId and game.JobId ~= "" then visited[game.JobId] = true end

    local candidates = {}
    local seen = {}
    local cursor = nil

    for _ = 1, MAX_PAGES do
        local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=%d"):format(
            tostring(placeId),
            SERVER_LIMIT
        )
        if cursor then
            local encoded = cursor
            pcall(function() encoded = HttpService:UrlEncode(cursor) end)
            url = url .. "&cursor=" .. encoded
        end

        local ok, body = self:_httpGet(url)
        if not ok then return candidates, body end

        local decoded, data = pcall(function() return HttpService:JSONDecode(body) end)
        if not decoded or type(data) ~= "table" then
            return candidates, "resposta JSON invalida ao listar servidores"
        end

        if type(data.data) == "table" then
            for _, server in ipairs(data.data) do
                if type(server) == "table"
                    and type(server.id) == "string"
                    and server.id ~= ""
                    and server.id ~= game.JobId
                    and not visited[server.id]
                    and not seen[server.id]
                    and tonumber(server.playing)
                    and tonumber(server.maxPlayers)
                    and tonumber(server.playing) < tonumber(server.maxPlayers)
                then
                    seen[server.id] = true
                    candidates[#candidates + 1] = {
                        id = server.id,
                        playing = tonumber(server.playing),
                        maxPlayers = tonumber(server.maxPlayers),
                    }
                end
            end
        end

        if #candidates >= MAX_CANDIDATES then break end
        cursor = data.nextPageCursor
        if type(cursor) ~= "string" or cursor == "" then break end
    end

    table.sort(candidates, function(a, b)
        if a.playing == b.playing then return a.maxPlayers < b.maxPlayers end
        return a.playing < b.playing
    end)

    return candidates
end

function AutoHop:Hop()
    if self.Destroyed or self.Hopping then return false end
    self.Hopping = true
    self.HopStartedAt = os.clock()
    self.TeleportStarted = false
    self.TeleportStartedAt = nil
    self.FallbackAttempted = false
    self.LastStatus = "searching server"
    log(self, "Runtime vazio; buscando servidores publicos.",
        "| PlaceId =", self.PlaceId, "| JobId atual =", tostring(game.JobId))

    local candidates, reason = self:_serverCandidates()
    if self.Destroyed or not self.Enabled then
        self.Hopping = false
        self.HopStartedAt = nil
        self.LastStatus = "idle"
        return false
    end
    if #candidates == 0 then
        self.Hopping = false
        self.HopStartedAt = nil
        self.TeleportStarted = false
        self.FallbackAttempted = false
        self.LastError = reason or "nenhum servidor novo com vagas encontrado"
        self.LastStatus = "waiting for server"
        self.NextAttempt = os.clock() + RETRY_INTERVAL
        log(self, self.LastError)
        return false
    end

    local pool = {}
    for index = 1, math.min(#candidates, MAX_CANDIDATES) do
        pool[#pool + 1] = candidates[index]
    end
    local selected = pool[math.random(1, #pool)]

    local visited = env.__DEPHUB_STEALANEXU_VISITED_SERVERS
    if type(visited) == "table" then visited[selected.id] = true end
    self.PendingServerId = selected.id

    log(self, "alvo selecionado:", selected.id,
        "| players =", selected.playing .. "/" .. selected.maxPlayers,
        "| metodo = TeleportToPlaceInstance")

    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(self.PlaceId, selected.id, LocalPlayer)
    end)

    if not ok then
        if type(visited) == "table" then visited[selected.id] = nil end
        self.PendingServerId = nil
        self.HopStartedAt = nil
        self.TeleportStarted = false
        self.TeleportStartedAt = nil
        self.FallbackAttempted = false
        self.Hopping = false
        self.LastError = tostring(err)
        self.LastStatus = "teleport failed"
        self.NextAttempt = os.clock() + RETRY_INTERVAL
        log(self, "teleporte falhou:", self.LastError)
        return false
    end

    self.LastError = nil
    self.LastStatus = "request accepted; awaiting teleport state"
    log(self, "pedido de teleporte aceito localmente para", selected.id,
        "| aguardando Player.OnTeleport/TeleportInitFailed.")
    return true
end

function AutoHop:_loop(runId)
    self.LastScopeKey = self:_scopeKey()
    log(self, "monitor iniciado; aguardando selecao ficar vazia por", self.EmptyGrace, "segundos.")
    while self.Enabled and not self.Destroyed and self.RunId == runId do
        local scopeKey = self:_scopeKey()
        if scopeKey ~= self.LastScopeKey then
            self.LastScopeKey = scopeKey
            self.EmptySince = nil
            self.NextAttempt = 0
            self.LastStatus = "selection changed"
            log(self, "selecao alterada; monitor reiniciado.")
        end

        local count, reason = self:RuntimeCount()
        local pending = 0
        if count ~= nil and type(self.PendingProvider) == "function" then
            local okPending, value = pcall(self.PendingProvider)
            if okPending then pending = tonumber(value) or 0 end
        end

        if count == nil then
            self.EmptySince = nil
            self.LastStatus = "waiting for Runtime"
            self.LastError = reason
        elseif self.Hopping and not self.TeleportStarted and self.HopStartedAt
            and os.clock() - self.HopStartedAt >= 10 and not self.FallbackAttempted then
            self.FallbackAttempted = true
            self.LastStatus = "target teleport gave no state; trying random server"
            log(self, "nenhum evento Player.OnTeleport apos 10s; tentando fallback Teleport(placeId).")
            local okFallback, fallbackError = pcall(function()
                TeleportService:Teleport(self.PlaceId, LocalPlayer)
            end)
            if okFallback then
                self.HopStartedAt = os.clock()
                log(self, "fallback Teleport solicitado; aguardando estado.")
            else
                local visited = env.__DEPHUB_STEALANEXU_VISITED_SERVERS
                if type(visited) == "table" and self.PendingServerId then
                    visited[self.PendingServerId] = nil
                end
                self.PendingServerId = nil
                self.HopStartedAt = nil
                self.Hopping = false
                self.NextAttempt = os.clock() + RETRY_INTERVAL
                self.LastStatus = "teleport failed"
                self.LastError = "fallback Teleport falhou: " .. tostring(fallbackError)
                log(self, self.LastError)
            end
        elseif self.Hopping and self.FallbackAttempted and not self.TeleportStarted
            and self.HopStartedAt and os.clock() - self.HopStartedAt >= 15 then
            local visited = env.__DEPHUB_STEALANEXU_VISITED_SERVERS
            if type(visited) == "table" and self.PendingServerId then visited[self.PendingServerId] = nil end
            self.PendingServerId = nil
            self.HopStartedAt = nil
            self.Hopping = false
            self.NextAttempt = os.clock() + RETRY_INTERVAL
            self.LastStatus = "teleport timeout"
            self.LastError = "nenhum metodo iniciou o teleporte; nova tentativa em 10s"
            log(self, self.LastError)
        elseif self.Hopping and self.TeleportStarted and self.TeleportStartedAt
            and os.clock() - self.TeleportStartedAt >= 30 then
            local visited = env.__DEPHUB_STEALANEXU_VISITED_SERVERS
            if type(visited) == "table" and self.PendingServerId then visited[self.PendingServerId] = nil end
            self.PendingServerId = nil
            self.HopStartedAt = nil
            self.TeleportStartedAt = nil
            self.TeleportStarted = false
            self.Hopping = false
            self.NextAttempt = os.clock() + RETRY_INTERVAL
            self.LastStatus = "teleport timeout"
            self.LastError = "teleporte iniciou mas nao concluiu em 30s; tentando novamente"
            log(self, self.LastError)
        elseif pending > 0 then
            self.EmptySince = nil
            self.LastStatus = "waiting for Auto Sell"
            self.LastError = nil
        elseif count > 0 then
            if self.EmptySince ~= nil then
                log(self, count, "Exus detectados; monitor de vazio reiniciado.")
            end
            self.EmptySince = nil
            self.LastStatus = "farming"
            self.LastError = nil
        else
            if self.EmptySince == nil then
                self.EmptySince = os.clock()
                self.LastStatus = "Runtime empty; hopping"
                log(self, "nenhum Exu nos terreiros selecionados; iniciando troca imediatamente.")
            end
            if os.clock() - self.EmptySince >= self.EmptyGrace and os.clock() >= self.NextAttempt then
                self:Hop()
            end
        end

        task.wait(POLL_INTERVAL)
    end

    if self.RunId == runId then
        self.Thread = nil
        if not self.Hopping then self.LastStatus = self.Enabled and self.LastStatus or "idle" end
    end
end

function AutoHop:SetEnabled(enabled)
    if self.Destroyed then return false end
    enabled = enabled == true
    if enabled == self.Enabled then return true end

    self.Enabled = enabled
    self.RunId = self.RunId + 1
    local runId = self.RunId

    if enabled then
        self.EmptySince = nil
        self.NextAttempt = 0
        self.LastError = nil
        self.LastStatus = "monitoring"
        self.Thread = task.spawn(function()
            local ok, err = pcall(function() self:_loop(runId) end)
            if not ok and self.RunId == runId then
                self.Enabled = false
                self.Thread = nil
                self.LastError = tostring(err)
                self.LastStatus = "error"
                log(self, "loop interrompido:", self.LastError)
            end
        end)
    else
        self.Hopping = false
        self.EmptySince = nil
        self.LastStatus = "idle"
        log(self, "desligado.")
    end

    return true
end

function AutoHop:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self.Enabled = false
    self.Hopping = false
    self.RunId = self.RunId + 1
    if self.TeleportConnection then
        pcall(function() self.TeleportConnection:Disconnect() end)
        self.TeleportConnection = nil
    end
    if self.PlayerTeleportConnection then
        pcall(function() self.PlayerTeleportConnection:Disconnect() end)
        self.PlayerTeleportConnection = nil
    end
    self.DebugLog = {}
end

return AutoHop
