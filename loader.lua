local Loader = {}
Loader.__index = Loader

local function createEnvironment()
    local env = {}
    local metatable = {
        __index = function(_, key)
            return rawget(env, key) or getgenv()[key]
        end,
        __newindex = function(_, key, value)
            rawset(env, key, value)
        end,
        __metatable = "locked"
    }
    setmetatable(env, metatable)
    return env
end

function Loader.new()
    local self = setmetatable({}, Loader)
    self.environment = createEnvironment()
    self.connections = {}
    self.executed = false
    return self
end

function Loader:cleanup()
    for _, connection in ipairs(self.connections) do
        pcall(function()
            if connection and connection.Disconnect then
                connection:Disconnect()
            end
        end)
    end
    self.connections = {}
    if self.environment then
        for key in pairs(self.environment) do
            self.environment[key] = nil
        end
        self.environment = nil
    end
    collectgarbage("collect")
end

function Loader:execute(scriptSource)
    if self.executed then
        return false, "Loader already executed"
    end

    local success, errorMessage = pcall(function()
        local func, err = loadstring(scriptSource)
        if not func then
            error("Loadstring failed: " .. tostring(err))
        end
        setfenv(func, self.environment)
        func()
    end)

    if not success then
        self:cleanup()
        return false, errorMessage
    end

    self.executed = true
    return true, "Execution successful"
end

function Loader:fetchScript(url)
    local success, result = pcall(function()
        return game:HttpGet(url)
    end)
    if success and result then
        return true, result
    end
    return false, "Failed to fetch script from URL"
end

local function waitForGameReady()
    local startTime = tick()
    while tick() - startTime < 10 do
        local success, result = pcall(function()
            return game:IsLoaded()
        end)
        if success and result then
            return true
        end
        task.wait(0.1)
    end
    return false
end

local loader = Loader.new()

if waitForGameReady() then
    local url = "https://raw.githubusercontent.com/glowpkj/DepHub/refs/heads/main/main"
    local fetchSuccess, scriptContent = loader:fetchScript(url)
    
    if fetchSuccess then
        local execSuccess, execMessage = loader:execute(scriptContent)
        if execSuccess then
            print("Loader: Script executed successfully")
        else
            warn("Loader: Execution failed - " .. tostring(execMessage))
        end
    else
        warn("Loader: Failed to fetch script - " .. tostring(scriptContent))
    end
else
    warn("Loader: Game did not load in time")
end

return loader
