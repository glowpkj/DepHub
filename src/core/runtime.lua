local task = task
local type = type
local tostring = tostring
local pcall = pcall
local os_clock = os.clock

local Runtime = {}
Runtime.__index = Runtime

function Runtime.new(options)
    options = options or {}

    local self = setmetatable({}, Runtime)
    self.Destroyed = false
    self.Tasks = {}
    self.TaskOrder = {}
    self.NextTaskId = 0
    self.Connections = {}
    self.Services = {}
    self.StartedAt = os_clock()
    self.ErrorCount = 0
    self.LastError = nil
    self.Health = "Healthy"
    self.Events = {}
    self.MaxTaskErrors = tonumber(options.MaxTaskErrors) or 5
    self.DefaultInterval = tonumber(options.DefaultInterval) or 0.1

    return self
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

function Runtime:On(name, callback)
    if self.Destroyed or type(name) ~= "string" or type(callback) ~= "function" then
        return function() end
    end

    local listeners = self.Events[name]
    if not listeners then
        listeners = {}
        self.Events[name] = listeners
    end

    local connection = {
        Connected = true,
        Callback = callback
    }

    listeners[connection] = true

    return function()
        if not connection.Connected then
            return
        end
        connection.Connected = false
        listeners[connection] = nil
    end
end

function Runtime:Register(name, callback, options)
    if self.Destroyed or type(name) ~= "string" or type(callback) ~= "function" then
        return nil
    end

    if self.Tasks[name] then
        return self.Tasks[name]
    end

    options = options or {}

    self.NextTaskId = self.NextTaskId + 1

    local taskState = {
        Id = self.NextTaskId,
        Name = name,
        Callback = callback,
        Interval = math.max(tonumber(options.Interval) or self.DefaultInterval, 0.01),
        Priority = tonumber(options.Priority) or 0,
        Enabled = options.Enabled ~= false,
        Running = false,
        Errors = 0,
        LastError = nil,
        LastRun = 0,
        LastSuccess = 0,
        Destroyed = false,
        Version = 0
    }

    self.Tasks[name] = taskState
    self.TaskOrder[#self.TaskOrder + 1] = taskState

    return taskState
end

function Runtime:SetEnabled(name, enabled)
    local taskState = self.Tasks[name]
    if not taskState or self.Destroyed then
        return false
    end

    taskState.Enabled = enabled == true
    taskState.Version = taskState.Version + 1
    return true
end

function Runtime:IsEnabled(name)
    local taskState = self.Tasks[name]
    return taskState ~= nil and taskState.Enabled == true
end

function Runtime:GetTask(name)
    return self.Tasks[name]
end

function Runtime:RunTask(taskState)
    if self.Destroyed or taskState.Destroyed or not taskState.Enabled or taskState.Running then
        return
    end

    taskState.Running = true
    taskState.LastRun = os_clock()

    local ok, err = pcall(taskState.Callback, taskState)

    taskState.Running = false

    if ok then
        taskState.Errors = 0
        taskState.LastError = nil
        taskState.LastSuccess = os_clock()
        return true
    end

    taskState.Errors = taskState.Errors + 1
    taskState.LastError = tostring(err)
    self.ErrorCount = self.ErrorCount + 1
    self.LastError = taskState.LastError

    if taskState.Errors >= self.MaxTaskErrors then
        taskState.Enabled = false
        self:Emit("TaskSuspended", taskState.Name, taskState.LastError)
    end

    return false
end

function Runtime:StartTask(taskState)
    local version = taskState.Version

    task.spawn(function()
        while not self.Destroyed and not taskState.Destroyed and taskState.Version == version do
            if taskState.Enabled then
                self:RunTask(taskState)
            end
            task.wait(taskState.Interval)
        end
    end)
end

function Runtime:Start()
    if self.Destroyed then
        return false
    end

    if self.Started then
        return true
    end

    self.Started = true

    table.sort(self.TaskOrder, function(a, b)
        return a.Priority > b.Priority
    end)

    for _, taskState in ipairs(self.TaskOrder) do
        if taskState.Enabled then
            self:StartTask(taskState)
        end
    end

    self:Emit("Started")
    return true
end

function Runtime:RecalculateHealth()
    if self.Destroyed then
        self.Health = "Destroyed"
        return self.Health
    end

    local suspended = 0
    local running = 0

    for _, taskState in ipairs(self.TaskOrder) do
        if taskState.Enabled then
            running = running + 1
        elseif taskState.Errors >= self.MaxTaskErrors then
            suspended = suspended + 1
        end
    end

    if suspended > 0 then
        self.Health = "Degraded"
    else
        self.Health = "Healthy"
    end

    self:Emit("HealthChanged", self.Health, running, suspended)
    return self.Health
end

function Runtime:GetSnapshot()
    local tasks = {}

    for _, taskState in ipairs(self.TaskOrder) do
        tasks[#tasks + 1] = {
            Name = taskState.Name,
            Enabled = taskState.Enabled,
            Running = taskState.Running,
            Errors = taskState.Errors,
            LastError = taskState.LastError,
            LastRun = taskState.LastRun,
            LastSuccess = taskState.LastSuccess,
            Priority = taskState.Priority,
            Interval = taskState.Interval
        }
    end

    return {
        Health = self:RecalculateHealth(),
        StartedAt = self.StartedAt,
        Uptime = math.max(os_clock() - self.StartedAt, 0),
        ErrorCount = self.ErrorCount,
        LastError = self.LastError,
        Tasks = tasks
    }
end

function Runtime:Destroy()
    if self.Destroyed then
        return
    end

    self.Destroyed = true

    for _, taskState in ipairs(self.TaskOrder) do
        taskState.Destroyed = true
        taskState.Enabled = false
        taskState.Version = taskState.Version + 1
    end

    for _, disconnect in ipairs(self.Connections) do
        pcall(disconnect)
    end

    self.Connections = {}
    self.Events = {}
    self.Tasks = {}
    self.TaskOrder = {}
    self.Services = {}
    self.Health = "Destroyed"
end

return Runtime
