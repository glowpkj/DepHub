local task = task
local type = type
local tostring = tostring
local pcall = pcall
local os_clock = os.clock

local Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler.new(options)
    options = options or {}

    local self = setmetatable({}, Scheduler)
    self.Tasks = {}
    self.Order = {}
    self.Destroyed = false
    self.Started = false
    self.NextId = 0
    self.DefaultInterval = tonumber(options.DefaultInterval) or 0.1
    self.MaxErrors = tonumber(options.MaxErrors) or 5
    self.OnError = type(options.OnError) == "function" and options.OnError or nil
    return self
end

-- Re-registering an existing name must not silently keep the stale callback:
-- backends re-register tasks after respawns with fresh upvalues. Swap the body in
-- place, bump the version (which retires the current thread) and restart if live.
function Scheduler:Register(name, callback, options)
    if self.Destroyed or type(name) ~= "string" or type(callback) ~= "function" then
        return nil
    end

    local existing = self.Tasks[name]
    if existing then
        existing.Callback = callback
        existing.Version = existing.Version + 1
        existing.Started = false
        if options then
            if options.Interval ~= nil then existing.Interval = math.max(tonumber(options.Interval) or existing.Interval, 0.01) end
            if options.Priority ~= nil then existing.Priority = tonumber(options.Priority) or existing.Priority end
            if options.Enabled ~= nil then existing.Enabled = options.Enabled ~= false end
        end
        if self.Started and existing.Enabled then
            self:StartTask(existing)
        end
        return existing
    end

    options = options or {}
    self.NextId = self.NextId + 1

    local state = {
        Id = self.NextId,
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
        Started = false,
        RunningVersion = nil,
        Version = 0,
        Destroyed = false
    }

    self.Tasks[name] = state
    self.Order[#self.Order + 1] = state

    if self.Started and state.Enabled then
        self:StartTask(state)
    end

    return state
end

function Scheduler:SetEnabled(name, enabled)
    local state = self.Tasks[name]
    if not state or self.Destroyed then
        return false
    end

    state.Enabled = enabled == true
    state.Version = state.Version + 1
    state.RunningVersion = nil

    if state.Enabled and self.Started then
        self:StartTask(state)
    end

    return true
end

function Scheduler:Run(state)
    if self.Destroyed or state.Destroyed or not state.Enabled or state.Running then
        return false
    end

    state.Running = true
    state.LastRun = os_clock()

    local ok, err = pcall(state.Callback, state)
    state.Running = false

    if ok then
        state.Errors = 0
        state.LastError = nil
        state.LastSuccess = os_clock()
        return true
    end

    state.Errors = state.Errors + 1
    state.LastError = tostring(err)

    if state.Errors >= self.MaxErrors then
        state.Enabled = false
    end

    if self.OnError then
        pcall(self.OnError, state, state.LastError)
    end

    return false
end

-- A task can have at most one live thread per Version. The old guard
-- (`state.Started and state.Enabled`) skipped restarting when the previous thread
-- was still parked in task.wait, leaving an enabled task with no runner.
function Scheduler:StartTask(state)
    if self.Destroyed or state.Destroyed then
        return
    end

    if state.RunningVersion == state.Version and state.Started then
        return
    end

    state.Started = true
    local version = state.Version
    state.RunningVersion = version

    task.spawn(function()
        while not self.Destroyed and not state.Destroyed and state.Version == version do
            if state.Enabled then
                self:Run(state)
            end
            task.wait(state.Interval)
        end
        if state.RunningVersion == version then
            state.Started = false
            state.RunningVersion = nil
        end
    end)
end

function Scheduler:Start()
    if self.Destroyed then
        return false
    end

    if self.Started then
        return true
    end

    self.Started = true

    table.sort(self.Order, function(a, b)
        return a.Priority > b.Priority
    end)

    for _, state in ipairs(self.Order) do
        if state.Enabled then
            self:StartTask(state)
        end
    end

    return true
end

function Scheduler:Stop(name)
    local state = self.Tasks[name]
    if not state then
        return false
    end

    state.Enabled = false
    state.Version = state.Version + 1
    state.RunningVersion = nil
    return true
end

function Scheduler:Get(name)
    return self.Tasks[name]
end

function Scheduler:GetSnapshot()
    local result = {}

    for _, state in ipairs(self.Order) do
        result[#result + 1] = {
            Name = state.Name,
            Enabled = state.Enabled,
            Running = state.Running,
            Errors = state.Errors,
            LastError = state.LastError,
            LastRun = state.LastRun,
            LastSuccess = state.LastSuccess,
            Priority = state.Priority,
            Interval = state.Interval
        }
    end

    return result
end

function Scheduler:Destroy()
    if self.Destroyed then
        return
    end

    self.Destroyed = true

    for _, state in ipairs(self.Order) do
        state.Destroyed = true
        state.Enabled = false
        state.Version = state.Version + 1
        state.RunningVersion = nil
    end

    self.Tasks = {}
    self.Order = {}
end

return Scheduler
