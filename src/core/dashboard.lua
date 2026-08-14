local game = game
local task = task
local type = type
local tostring = tostring
local tonumber = tonumber
local pcall = pcall
local os_clock = os.clock

local GetService = game.GetService
local Players = GetService(game, "Players")
local Stats = GetService(game, "Stats")
local RunService = GetService(game, "RunService")

local LocalPlayer = Players.LocalPlayer

local Dashboard = {}
Dashboard.__index = Dashboard

local function safeCall(callback, fallback)
    local ok, result = pcall(callback)
    if ok then
        return result
    end
    return fallback
end

local function getPing()
    local value = safeCall(function()
        local network = Stats:FindFirstChild("Network")
        if not network then
            return nil
        end

        local serverStats = network:FindFirstChild("ServerStatsItem")
        if not serverStats then
            return nil
        end

        local ping = serverStats:FindFirstChild("Data Ping") or serverStats:FindFirstChild("Ping")
        if not ping then
            return nil
        end

        local stringValue = ping:GetValueString()
        local numericValue = tonumber(stringValue:match("[%d%.]+"))
        return numericValue
    end, nil)

    return value
end

function Dashboard.new(options)
    options = options or {}

    local self = setmetatable({}, Dashboard)
    self.Destroyed = false
    self.Started = false
    self.Interval = math.max(tonumber(options.Interval) or 1, 0.25)
    self.Executor = safeCall(function()
        local identify = identifyexecutor
        if type(identify) == "function" then
            local name, version = identify()
            if name and version then
                return tostring(name) .. " " .. tostring(version)
            end
            if name then
                return tostring(name)
            end
        end
        return "Unknown"
    end, "Unknown")
    self.FPS = 0
    self.Ping = nil
    self.LastUpdate = 0
    self.Connections = {}
    self.StartedAt = os_clock()
    self.Data = {}
    self.OnUpdate = options.OnUpdate
    return self
end

function Dashboard:SampleFPS()
    local elapsed = safeCall(function()
        return RunService.Heartbeat:Wait()
    end, nil)

    if elapsed and elapsed > 0 then
        self.FPS = math.floor((1 / elapsed) + 0.5)
    end
end

function Dashboard:Collect()
    if self.Destroyed then
        return nil
    end

    local placeVersion = safeCall(function()
        return game.PlaceVersion
    end, nil)

    local playerCount = safeCall(function()
        return #Players:GetPlayers()
    end, 0)

    local maxPlayers = safeCall(function()
        return Players.MaxPlayers
    end, 0)

    local ping = getPing()
    local data = {
        Executor = self.Executor,
        Ping = ping,
        FPS = self.FPS,
        PlaceId = tostring(game.PlaceId),
        GameId = tostring(game.GameId),
        JobId = tostring(game.JobId),
        GameName = tostring(game.Name),
        PlaceVersion = placeVersion and tostring(placeVersion) or "Unknown",
        Players = playerCount,
        MaxPlayers = maxPlayers,
        Uptime = math.max(os_clock() - self.StartedAt, 0),
        Timestamp = os_clock()
    }

    self.Ping = ping
    self.LastUpdate = os_clock()
    self.Data = data

    if self.OnUpdate then
        pcall(self.OnUpdate, data)
    end

    return data
end

function Dashboard:Start()
    if self.Destroyed then
        return false
    end

    if self.Started then
        return true
    end

    self.Started = true

    task.spawn(function()
        local lastFpsSample = os_clock()
        local frames = 0

        self.Connections[#self.Connections + 1] = RunService.Heartbeat:Connect(function()
            frames = frames + 1
            local now = os_clock()
            local elapsed = now - lastFpsSample
            if elapsed >= 1 then
                self.FPS = math.floor((frames / elapsed) + 0.5)
                frames = 0
                lastFpsSample = now
            end
        end)

        while not self.Destroyed do
            self:Collect()
            task.wait(self.Interval)
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
