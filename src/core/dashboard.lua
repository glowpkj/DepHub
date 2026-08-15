local game = game
local task = task
local type = type
local tostring = tostring
local tonumber = tonumber
local pcall = pcall
local os_clock = os.clock
local math_floor = math.floor
local string_match = string.match

local GetService = game.GetService
local Players = GetService(game, "Players")
local Stats = GetService(game, "Stats")
local RunService = GetService(game, "RunService")
local HttpService = GetService(game, "HttpService")

local Dashboard = {}
Dashboard.__index = Dashboard

local MANIFEST_URL = "https://raw.githubusercontent.com/glowpkj/DepHub/main/src/update-manifest.json"

local function safeCall(callback, fallback)
    local ok, result = pcall(callback)
    if ok then
        return result
    end
    return fallback
end

local function httpGet(url)
    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and type(result) == "string" and #result > 0 then
        return true, result
    end
    return false, nil
end

local function decode(source)
    local ok, result = pcall(function()
        return HttpService:JSONDecode(source)
    end)
    if ok and type(result) == "table" then
        return result
    end
    return nil
end

local function getPing()
    return safeCall(function()
        local network = Stats:FindFirstChild("Network")
        local serverStats = network and network:FindFirstChild("ServerStatsItem")
        local ping = serverStats and (serverStats:FindFirstChild("Data Ping") or serverStats:FindFirstChild("Ping"))
        if not ping then
            return nil
        end
        local raw = ping:GetValueString()
        return tonumber(string_match(raw, "[%d%.]+"))
    end, nil)
end

local function detectExecutor()
    return safeCall(function()
        if type(identifyexecutor) ~= "function" then
            return "Unknown"
        end
        local name, version = identifyexecutor()
        if name and version then
            return tostring(name) .. " " .. tostring(version)
        end
        return name and tostring(name) or "Unknown"
    end, "Unknown")
end

local function fetchManifest(placeId)
    local ok, source = httpGet(MANIFEST_URL .. "?dephubdashboard=" .. tostring(math_floor(os_clock() * 1000)))
    if not ok then
        return nil
    end

    local manifest = decode(source)
    local games = manifest and manifest.games
    local info = type(games) == "table" and games[tostring(placeId)] or nil

    if type(info) ~= "table" then
        return nil
    end

    local version = tostring(info.version or "Unknown")
    local commit = tostring(info.commit or manifest.commit or "Unknown")

    return {
        Version = version ~= "Unknown" and version:sub(1, 8) or version,
        VersionFull = version,
        Commit = commit ~= "Unknown" and commit:sub(1, 7) or commit,
        CommitFull = commit,
        GeneratedAt = tostring(manifest.generatedAt or "Unknown"),
        RecentUpdates = type(manifest.recentUpdates) == "table" and manifest.recentUpdates or {}
    }
end

function Dashboard.new(options)
    options = options or {}

    local self = setmetatable({}, Dashboard)
    self.Destroyed = false
    self.Started = false
    self.Interval = math.max(tonumber(options.Interval) or 1, 0.25)
    self.ManifestInterval = math.max(tonumber(options.ManifestInterval) or 30, 5)
    self.Executor = detectExecutor()
    self.ScriptVersion = options.ScriptVersion and tostring(options.ScriptVersion) or nil
    self.ScriptVersionFull = nil
    self.ScriptCommit = "Unknown"
    self.ScriptCommitFull = nil
    self.LatestUpdate = "Unknown"
    self.RecentUpdates = {}
    self.FPS = 0
    self.Ping = nil
    self.LastUpdate = 0
    self.LastManifestFetch = 0
    self.Connections = {}
    self.StartedAt = os_clock()
    self.Data = {}
    self.OnUpdate = options.OnUpdate
    return self
end

function Dashboard:RefreshManifest(force)
    local now = os_clock()
    if not force and now - self.LastManifestFetch < self.ManifestInterval then
        return
    end

    local manifest = fetchManifest(game.PlaceId)
    self.LastManifestFetch = now

    if not manifest then
        return
    end

    self.ScriptVersion = manifest.Version
    self.ScriptVersionFull = manifest.VersionFull
    self.ScriptCommit = manifest.Commit
    self.ScriptCommitFull = manifest.CommitFull
    self.LatestUpdate = manifest.GeneratedAt
    self.RecentUpdates = manifest.RecentUpdates
end

function Dashboard:Collect()
    if self.Destroyed then
        return nil
    end

    self:RefreshManifest(false)

    local playerCount = safeCall(function()
        return #Players:GetPlayers()
    end, 0)

    local maxPlayers = safeCall(function()
        return Players.MaxPlayers
    end, 0)

    local data = {
        Executor = self.Executor,
        Ping = getPing(),
        FPS = self.FPS,
        PlaceId = tostring(game.PlaceId),
        GameId = tostring(game.GameId),
        JobId = tostring(game.JobId),
        GameName = tostring(game.Name),
        ScriptVersion = self.ScriptVersion or "Unknown",
        ScriptVersionFull = self.ScriptVersionFull,
        ScriptCommit = self.ScriptCommit,
        ScriptCommitFull = self.ScriptCommitFull,
        LatestUpdate = self.LatestUpdate,
        RecentUpdates = self.RecentUpdates,
        Players = playerCount,
        MaxPlayers = maxPlayers,
        Uptime = math.max(os_clock() - self.StartedAt, 0),
        Timestamp = os_clock()
    }

    self.Ping = data.Ping
    self.LastUpdate = data.Timestamp
    self.Data = data

    if self.OnUpdate then
        pcall(self.OnUpdate, data)
    end

    return data
end

function Dashboard:Start()
    if self.Destroyed or self.Started then
        return not self.Destroyed
    end

    self.Started = true

    self:Collect()

    self.Connections[#self.Connections + 1] = RunService.Heartbeat:Connect(function(deltaTime)
        if deltaTime > 0 then
            local instant = 1 / deltaTime
            self.FPS = math_floor((self.FPS * 0.85) + (instant * 0.15) + 0.5)
        end
    end)

    task.spawn(function()
        while not self.Destroyed do
            task.wait(self.Interval)
            if not self.Destroyed then
                self:Collect()
            end
        end
    end)

    return true
end

function Dashboard:Get()
    return self.Data
end

function Dashboard:GetSnapshot()
    local snapshot = {}
    for key, value in pairs(self.Data) do
        snapshot[key] = value
    end
    return snapshot
end

function Dashboard:Destroy()
    if self.Destroyed then
        return
    end

    self.Destroyed = true
    self.Started = false

    for _, connection in ipairs(self.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    self.Connections = {}
    self.Data = {}
end

return Dashboard
