local type = type
local tostring = tostring
local pcall = pcall
local tonumber = tonumber
local os_clock = os.clock

local Runtime = {}
Runtime.__index = Runtime

function Runtime.new(options)
    options = options or {}

    local Scheduler = options.Scheduler
    local HealthMonitor = options.HealthMonitor
    local Dashboard = options.Dashboard

    local self = setmetatable({}, Runtime)
    self.Destroyed = false
    self.Started = false
    self.StartedAt = os_clock()
    self.ErrorCount = 0
    self.LastError = nil
    self.Health = "Healthy"
    self.Events = {}
    self.Scheduler = type(Scheduler) == "table" and Scheduler.new(options.SchedulerOptions or {}) or nil
    self.HealthMonitor = type(HealthMonitor) == "table" and HealthMonitor.new(options.HealthOptions or {}) or nil
    self.Dashboard = type(Dashboard) == "table" and Dashboard.new(options.DashboardOptions or {}) or nil
    return self
end

function Runtime:On(name, callback)
    if self.Destroyed or type(name) ~= "string" or type(callback) ~= "function" then
        return function() end
    end

    local listeners = self.Events[name]
    if not listeners then
        listeners = {}
        self.Events[name] = listeners
    end

    local connection = {Connected = true, Callback = callback}
    listeners[connection] = true

    return function()
        if not connection.Connected then
            return
        end
        connection.Connected = false
        listeners[connection] = nil
    end
end

function Runtime:Emit(name, ...)
    if self.Destroyed then
        return
    end

    local listeners = self.Events[name]
    if not listeners then
        return
    end

    for connection in pairs(listeners) do
        if connection.Connected then
            pcall(connection.Callback, ...)
        end
    end
end

function Runtime:Register(name, callback, options)
    if self.Destroyed or not self.Scheduler then
        return nil
    end

    local state = self.Scheduler:Register(name, callback, options)
    if state then
        self:Emit("TaskRegistered", state)
    end
    return state
end

function Runtime:SetEnabled(name, enabled)
    if self.Destroyed or not self.Scheduler then
        return false
    end
    return self.Scheduler:SetEnabled(name, enabled)
end

function Runtime:IsEnabled(name)
    return self.Scheduler ~= nil and self.Scheduler:Get(name) ~= nil and self.Scheduler:Get(name).Enabled == true
end

function Runtime:GetTask(name)
    if not self.Scheduler then
        return nil
    end
    return self.Scheduler:Get(name)
end

function Runtime:Start()
    if self.Destroyed then
        return false
    end

    if self.Started then
        return true
    end

    self.Started = true
    self.StartedAt = os_clock()

    if self.Dashboard then
        self.Dashboard:Start()
    end

    if self.HealthMonitor then
        self.HealthMonitor:Start()
    end

    if self.Scheduler then
        self.Scheduler:Start()
    end

    self:Emit("Started")
    return true
end

function Runtime:GetSnapshot()
    local schedulerSnapshot = self.Scheduler and self.Scheduler:GetSnapshot() or {}
    local healthSnapshot = self.HealthMonitor and self.HealthMonitor:GetSnapshot() or {Status = "Unavailable"}
    local dashboardSnapshot = self.Dashboard and self.Dashboard:GetSnapshot() or {}

    self.Health = healthSnapshot.Status or "Unknown"

    return {
        Health = self.Health,
        Started = self.Started,
        StartedAt = self.StartedAt,
        Uptime = math.max(os_clock() - self.StartedAt, 0),
        ErrorCount = self.ErrorCount,
        LastError = self.LastError,
        Tasks = schedulerSnapshot,
        HealthMonitor = healthSnapshot,
        Dashboard = dashboardSnapshot
    }
end

function Runtime:Destroy()
    if self.Destroyed then
        return
    end

    self.Destroyed = true
    self.Started = false

    if self.Scheduler then
        pcall(self.Scheduler.Destroy, self.Scheduler)
    end

    if self.HealthMonitor then
        pcall(self.HealthMonitor.Destroy, self.HealthMonitor)
    end

    if self.Dashboard then
        pcall(self.Dashboard.Destroy, self.Dashboard)
    end

    self.Scheduler = nil
    self.HealthMonitor = nil
    self.Dashboard = nil
    self.Events = {}
    self.Health = "Destroyed"
end

return Runtime
