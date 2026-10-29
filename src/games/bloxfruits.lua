local game = game
local type = type
local tostring = tostring

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local env = type(getgenv) == "function" and getgenv() or _G
local report = (env.__DEPHUB and type(env.__DEPHUB.Log) == "function") and env.__DEPHUB.Log or function() end

-- Backend for the vendored open-source Blox Fruits script.
--
-- It owns no presentation: the DepHub frontend renders from this contract and
-- the feature state lives in the adapter's control registry. Every method is a
-- thin forwarder, so there is exactly one source of truth for a toggle.

local OSS_PATH = "src/games/features/bloxfruits/oss/"
local VERSION = "1.0.0"

local previous = type(env.__DEPHUB_BLOXFRUITS_OSS) == "table" and env.__DEPHUB_BLOXFRUITS_OSS or nil
if previous and type(previous.Destroy) == "function" then pcall(previous.Destroy, previous) end

local sourceBase = (env.__DEPHUB or {}).SourceBaseURL or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"

-- Prefer the bundle's resolver published on the shared environment. It is only
-- present in a bundled build; a source checkout resolves through the loader's
-- own fetch path, so fall back to the executor primitives in that order.
local function fetch(path)
    local url = sourceBase .. path
    local resolver = (type(env.__dephubHttpGet) == "function" and env.__dephubHttpGet)
        or (type(env.__DEPHUB_HTTP_GET) == "function" and env.__DEPHUB_HTTP_GET)
        or (type(_G.__dephubHttpGet) == "function" and _G.__dephubHttpGet)
        or (type(_G.__DEPHUB_HTTP_GET) == "function" and _G.__DEPHUB_HTTP_GET)
    if resolver then
        local ok, source = pcall(resolver, url)
        if ok and type(source) == "string" and #source > 0 then return true, source end
    end
    local ok, source = pcall(function() return game:HttpGet(url) end)
    if ok and type(source) == "string" and #source > 0 then return true, source end
    return false, tostring(source)
end

local function loadFactory(path)
    local okFetch, source = fetch(path)
    if not okFetch then return false, "fetch: " .. tostring(source) end
    local chunk, chunkError = loadstring(source)
    if not chunk then return false, "compile: " .. tostring(chunkError) end
    local okRun, factory = pcall(chunk)
    if not okRun or type(factory) ~= "table" then return false, "run: " .. tostring(factory) end
    return true, factory
end

-- The adapter's LoadSource contract is "hand me the source string", while fetch
-- reports (ok, source). Wrap so a missing module surfaces the failing path.
local function loadSource(path)
    local ok, source = fetch(path)
    if ok then return source end
    return nil, tostring(source)
end

local LocalPlayer = game:GetService("Players").LocalPlayer
if not LocalPlayer then
    report("BloxFruits: LocalPlayer ausente")
    return false
end

local okFactory, Adapter = loadFactory(OSS_PATH .. "adapter.lua")
if not okFactory then
    report("BloxFruits: adapter falhou: " .. tostring(Adapter))
    return false
end

local Context = {
    Vendors = {game = game, task = task},
    Env = env,
    Sea = "Sea1",
    Version = VERSION,
    Warn = report,
    PathPrefix = OSS_PATH,
    LoadSource = loadSource
}

local okNew, State = pcall(Adapter.new, Context)
if not okNew or type(State) ~= "table" then
    report("BloxFruits: OSS nao inicializou: " .. tostring(State))
    return false
end

env.__DEPHUB_BLOXFRUITS_OSS = State
env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.BloxFruits = State
env.__DEPHUB.BloxFruitsOSS = State

-- Public toggles: one per control the modules registered, so a frontend can
-- mirror them with the generic SetToggle/GetToggle path it already uses.
State.Toggles = {}
State.ToggleLabels = {}
for _, definition in ipairs(State:ListControls()) do
    if definition.kind == "toggle" then
        State.Toggles[definition.key] = definition.get() == true
        State.ToggleLabels[definition.key] = definition.page .. " / " .. definition.title
    end
end

function State:SetToggle(name, enabled)
    if self.Destroyed or type(name) ~= "string" then return false end
    local control = self:GetControl(name)
    if not control or control.kind ~= "toggle" then return false end
    self:SetControl(name, enabled == true)
    self.Toggles[name] = control.get() == true
    return true
end

function State:GetToggle(name)
    if self.Destroyed then return false end
    local control = self:GetControl(name)
    if not control then return self.Toggles[name] == true end
    return control.get() == true
end

function State:GetValue(name, fallback)
    local value = self:GetControlValue(name)
    if value == nil then return fallback end
    return value
end

function State:SetValue(name, value)
    return self:SetControl(name, value)
end

-- Core.spawn hands every loop back so the frontend's Rejoin can restart the
-- work the game cancelled on teleport (resume.lua used to call this).
local CoreThreads = (State.Core and State.Core._threads) or {}

local function resumeAll()
    local resumed = 0
    for _, thread in ipairs(CoreThreads) do
        if type(thread) == "thread" and coroutine.status(thread) == "suspended" then
            local ok = pcall(task.spawn, thread)
            if ok then resumed += 1 end
        end
    end
    return resumed
end

State.ResumeAll = resumeAll

function State:Rejoin()
    self:ResumeAll()
    return true
end

function State:ServerHop()
    local ok, module = pcall(function() return self.Modules and self.Modules.events end)
    if ok and type(module) == "table" and type(module.serverHop) == "function" then
        pcall(module.serverHop, module)
        return true
    end
    return false
end

function State:Destroy()
    if self.Destroyed then return end
    pcall(function() self:Unload() end)
    self.Destroyed = true
    if env.__DEPHUB_BLOXFRUITS_OSS == self then env.__DEPHUB_BLOXFRUITS_OSS = nil end
    if env.__DEPHUB and env.__DEPHUB.BloxFruits == self then env.__DEPHUB.BloxFruits = nil end
    if env.__DEPHUB and env.__DEPHUB.BloxFruitsOSS == self then env.__DEPHUB.BloxFruitsOSS = nil end
end

return State
