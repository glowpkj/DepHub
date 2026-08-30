local game = game
local task = task
local type = type
local tostring = tostring
local tonumber = tonumber
local pcall = pcall
local math_random = math.random
local os_clock = os.clock

local GetService = game.GetService
local Players = GetService(game, "Players")
local HttpService = GetService(game, "HttpService")
local TeleportService = GetService(game, "TeleportService")

local LocalPlayer = Players.LocalPlayer

local MANIFEST_URL = "https://raw.githubusercontent.com/glowpkj/DepHub/main/src/update-manifest.json"
local SERVERS_URL = "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100"
local COMPARE_URL = "https://api.github.com/repos/glowpkj/DepHub/compare/%s...%s"

local Updater = {}
Updater.__index = Updater

local function silent()
end

local updateLog = silent
local updateWarn = silent

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
    self.GameId = tostring(options.GameId or game.GameId)
    self.ManifestId = tostring(options.ManifestId or self.GameId)
    self.CurrentVersion = options.CurrentVersion and tostring(options.CurrentVersion) or nil
    self.CurrentCommit = options.CurrentCommit and tostring(options.CurrentCommit) or nil
    self.PollInterval = tonumber(options.PollInterval) or 15
    self.Mode = options.Mode or "serverhop"
    self.StartupGrace = tonumber(options.StartupGrace) or 90
    self.StartedAt = os_clock()
    self.CancelledVersions = {}
    self.RejectedVersions = {}
    self.Destroyed = false
    self.PendingUpdate = nil
    self.ActionInProgress = false
    return self
end

function Updater:FetchVersion()
    local ok, source = httpGet(MANIFEST_URL .. "?dephubupdate=" .. tostring(math_random(1000000, 9999999)))
    if not ok then
        return false, source
    end

    local decoded, manifest = decode(source)
    if not decoded then
        return false, manifest
    end

    local games = manifest.games
    local info = type(games) == "table" and (games[self.ManifestId] or games[self.PlaceId]) or nil
    if type(info) ~= "table" or not info.version then
        return false, "Jogo sem versao registrada"
    end

    local commit = tostring(info.commit or manifest.commit or "")
    local files = type(info.files) == "table" and info.files or {}

    return true, {
        Version = tostring(info.version),
        Name = tostring(info.name or "DepHub"),
        Commit = commit,
        Files = files
    }
end

function Updater:ValidateBackendChange(info)
    if not self.CurrentCommit or self.CurrentCommit == "" then
        return false
    end

    if not info.Commit or info.Commit == "" then
        return false
    end

    if self.CurrentCommit == info.Commit then
        return false
    end

    local url = string.format(COMPARE_URL, self.CurrentCommit, info.Commit)
    local ok, source = httpGet(url)
    if not ok then
        return false
    end

    local decoded, compareData = decode(source)
    if not decoded then
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

    return #changedTracked > 0
end

-- Without a frontend, detected updates wait for explicit action.
function Updater:Cancel()
    if self.ActionInProgress then return end
    if self.PendingUpdate then
        self.CancelledVersions[self.PendingUpdate.Version] = true
        self.PendingUpdate = nil
    end
end

function Updater:ApplyPending()
    if self.Destroyed or self.ActionInProgress or not self.PendingUpdate then return false end
    return self:Teleport()
end

function Updater:GetServer()
    local url = string.format(SERVERS_URL, self.PlaceId)
    local ok, source = httpGet(url)
    if not ok then
        return false, source
    end

    local decoded, data = decode(source)
    if not decoded then
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
        return false, "Nenhum servidor disponivel"
    end

    return true, candidates[math_random(1, #candidates)]
end

function Updater:Teleport()
    if self.Destroyed or self.ActionInProgress then
        return false
    end

    self.ActionInProgress = true
    self.PendingUpdate = nil

    if self.Mode == "rejoin" then
        local ok = pcall(function()
            TeleportService:Teleport(tonumber(self.PlaceId), LocalPlayer)
        end)
        if not ok then self.ActionInProgress = false end
        return ok
    end

    local ok, jobId = self:GetServer()
    if ok and jobId then
        local teleported = pcall(function()
            TeleportService:TeleportToPlaceInstance(tonumber(self.PlaceId), jobId, LocalPlayer)
        end)
        if teleported then
            return true
        end
    end

    local teleported = pcall(function()
        TeleportService:Teleport(tonumber(self.PlaceId), LocalPlayer)
    end)
    if not teleported then self.ActionInProgress = false end
    return teleported
end

function Updater:Check()
    if self.Destroyed or self.PendingUpdate or self.ActionInProgress then
        return
    end

    local ok, info = self:FetchVersion()
    if not ok then
        return
    end

    local startupAge = os_clock() - self.StartedAt

    if not self.CurrentVersion then
        self.CurrentVersion = info.Version
        self.CurrentCommit = info.Commit
        return
    end

    if info.Version == self.CurrentVersion then
        return
    end

    if startupAge < self.StartupGrace then
        self.CurrentVersion = info.Version
        self.CurrentCommit = info.Commit
        return
    end

    if self.CancelledVersions[info.Version] or self.RejectedVersions[info.Version] then
        return
    end

    if not self:ValidateBackendChange(info) then
        self.RejectedVersions[info.Version] = true
        return
    end

    self.PendingUpdate = info
end

function Updater:Start()
    if self.Destroyed then
        return
    end

    task.spawn(function()
        task.wait(5)
        if self.Destroyed then
            return
        end

        self:Check()

        while not self.Destroyed do
            task.wait(self.PollInterval)
            if not self.Destroyed then
                self:Check()
            end
        end
    end)
end

function Updater:Destroy()
    if self.Destroyed then
        return
    end

    self.Destroyed = true
    self.PendingUpdate = nil
end

return Updater
