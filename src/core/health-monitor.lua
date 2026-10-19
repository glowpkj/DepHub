local task = task
local type = type
local tostring = tostring
local pcall = pcall
local os_clock = os.clock

local HealthMonitor = {}
HealthMonitor.__index = HealthMonitor

function HealthMonitor.new(options)
    options = options or {}

    local self = setmetatable({}, HealthMonitor)
    self.Destroyed = false
    self.Started = false
    self.Interval = math.max(tonumber(options.Interval) or 2, 0.25)
    self.MaxErrors = tonumber(options.MaxErrors) or 5
    self.Checks = {}
    self.Results = {}
    self.ErrorCount = 0
    self.LastError = nil
    self.Status = "Healthy"
    self.StartedAt = os_clock()
    self.OnChanged = options.OnChanged
    return self
end

function HealthMonitor:Register(name, callback)
    if self.Destroyed or type(name) ~= "string" or type(callback) ~= "function" then
        return false
    end

    self.Checks[name] = {
        Callback = callback,
        Errors = 0,
        Failures = 0,
        LastRun = 0,
        LastSuccess = 0,
        LastError = nil,
        Healthy = true
    }

    return true
end

-- A check that returns false is a normal negative report; only a raised error is a
-- fault. Conflating the two made a legitimately-false check look permanently
-- Unhealthy once it crossed MaxErrors.
function HealthMonitor:RunCheck(name, check)
    local ok, result = pcall(check.Callback, check)
    check.LastRun = os_clock()

    if not ok then
        check.Errors = check.Errors + 1
        check.LastError = tostring(result)
        check.Healthy = false
        self.ErrorCount = self.ErrorCount + 1
        self.LastError = check.LastError
        self.Results[name] = false
        return false
    end

    check.Errors = 0
    check.LastError = nil
    if result == false then
        check.Failures = check.Failures + 1
        check.Healthy = false
    else
        check.Failures = 0
        check.Healthy = true
        check.LastSuccess = os_clock()
    end
    self.Results[name] = check.Healthy
    return check.Healthy
end

function HealthMonitor:Evaluate()
    if self.Destroyed then
        self.Status = "Destroyed"
        return self.Status
    end

    local unhealthy = 0
    local registered = 0

    for name, check in pairs(self.Checks) do
        registered = registered + 1
        if not self:RunCheck(name, check) then
            unhealthy = unhealthy + 1
        end
    end

    if registered == 0 then
        self.Status = "Healthy"
    elseif unhealthy == 0 then
        self.Status = "Healthy"
    elseif unhealthy < registered then
        self.Status = "Degraded"
    else
        self.Status = "Unhealthy"
    end

    if self.OnChanged then
        pcall(self.OnChanged, self.Status, self.Results)
    end

    return self.Status
end

function HealthMonitor:Start()
    if self.Destroyed then
        return false
    end

    if self.Started then
        return true
    end

    self.Started = true

    task.spawn(function()
        while not self.Destroyed do
            self:Evaluate()
            -- Jitter the evaluation cadence so the health loop is not perfectly periodic.
            task.wait(self.Interval * (1 + (math.random() * 2 - 1) * 0.15))
        end
    end)

    return true
end

function HealthMonitor:GetSnapshot()
    local checks = {}

    for name, check in pairs(self.Checks) do
        checks[name] = {
            Healthy = check.Healthy,
            Errors = check.Errors,
            Failures = check.Failures,
            LastError = check.LastError,
            LastRun = check.LastRun,
            LastSuccess = check.LastSuccess
        }
    end

    return {
        Status = self.Status,
        ErrorCount = self.ErrorCount,
        LastError = self.LastError,
        Uptime = math.max(os_clock() - self.StartedAt, 0),
        Checks = checks
    }
end

function HealthMonitor:Destroy()
    if self.Destroyed then
        return
    end

    self.Destroyed = true
    self.Started = false
    self.Checks = {}
    self.Results = {}
    self.Status = "Destroyed"
end

return HealthMonitor
