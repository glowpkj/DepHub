local game = game
local task = task
local type = type
local tostring = tostring
local tonumber = tonumber
local ipairs = ipairs
local pcall = pcall

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local env = type(getgenv) == "function" and getgenv() or _G

-- Optional chunk argument lets a one-line loadstring select the same revision for every module.
local sourceRef = tostring((...) or env.__DEPHUB_SOURCE_REF or "main")
local BASE_URL = "https://raw.githubusercontent.com/glowpkj/DepHub/" .. sourceRef .. "/"
local VERSION = "0.0.43"
local CACHE_KEY = "__DEPHUB_SOURCE_CACHE"
local EXECUTED_KEY = "__DEPHUB_LOADER_EXECUTED"
local STATE_KEY = "__DEPHUB_LOADER_STATE"

local placeId = tostring(game.PlaceId)
local gameId = tostring(game.GameId)

local function log(message)
    pcall(print, tostring(message))
end

local function detectExecutor()
    local ok, name = pcall(function()
        if type(identifyexecutor) == "function" then return identifyexecutor() end
        if type(getexecutorname) == "function" then return getexecutorname() end
        return "Desconhecido"
    end)
    return ok and tostring(name) or "Desconhecido"
end

-- Backend state keys published by the game modules and by the loader below.
local BACKEND_KEYS = {
    "AOTR", "TSB", "MM2", "NoobPiece", "BloxFruits", "Universal", "Runtime", "Volleyball42"
}

-- Extra session handles the loader creates and must tear down on re-execution.
-- Window/UIGuard are legacy names from the removed frontend: kept so a session
-- started by an older version is fully cleaned up when the loader runs again.
local HANDLE_KEYS = {
    "Updater", "Window", "UIGuard", "TempUI", "UI", "Scheduler", "HealthMonitor", "Dashboard", "AntiAFK"
}

-- Legacy globals that older revisions wrote directly to the shared environment.
local LEGACY_GLOBALS = {
    "__DEPHUB_UNIVERSAL", "__DEPHUB_TSB", "__DEPHUB_TSB_FRONTEND",
    "__DEPHUB_MM2", "__DEPHUB_AOTR", "__DEPHUB_MM2_FRONTEND",
    "__DEPHUB_AOTR_FRONTEND", "__DEPHUB_NOOBPIECE", "__DEPHUB_UI_GUARD",
    "__DEPHUB_DASHBOARD"
}

local function cleanupRuntime()
    local oldLoading = env.__DEPHUB_LOADING_INSTANCE
    if oldLoading then
        pcall(oldLoading.Destroy, oldLoading)
        env.__DEPHUB_LOADING_INSTANCE = nil
    end

    env.__DEPHUB_UNIVERSAL = nil
    env.__DEPHUB_FRONTEND = nil
    env.__DEPHUB_UI_MODULES = nil
    env.__DEPHUB_UI_LOADING = nil

    local state = env.__DEPHUB
    if type(state) == "table" then
        for _, key in ipairs(BACKEND_KEYS) do
            local target = state[key]
            if type(target) == "table" and type(target.Destroy) == "function" then pcall(target.Destroy, target) end
            state[key] = nil
        end
        for _, key in ipairs(HANDLE_KEYS) do
            local target = state[key]
            if type(target) == "table" and type(target.Destroy) == "function" then pcall(target.Destroy, target) end
            state[key] = nil
        end
        state.Frontend = nil
        state.UILibrary = nil
        state.UI = nil
    end

    for _, key in ipairs(LEGACY_GLOBALS) do
        env[key] = nil
    end
end

local function sessionHealthy()
    local state = env.__DEPHUB
    if type(state) ~= "table" then return false end
    local backend = state.AOTR or state.TSB or state.MM2 or state.NoobPiece
        or state.BloxFruits or state.Universal or state.Runtime or state.Volleyball42
    return type(backend) == "table" and not backend.Destroyed
end

local previousState = env[STATE_KEY]
if type(previousState) == "table" and previousState.status == "running" then
    log("Inicializacao em andamento. Aguarde antes de executar novamente.")
    return false
end
if env[EXECUTED_KEY]
    and type(previousState) == "table"
    and previousState.status == "success"
    and previousState.Version == VERSION
    and previousState.PlaceId == placeId
    and previousState.GameId == gameId
    and previousState.SourceRef == sourceRef
    and sessionHealthy() then
    return true
end

cleanupRuntime()
env[EXECUTED_KEY] = false

env[STATE_KEY] = {
    status = "running", startedAt = os.clock(), Version = VERSION,
    PlaceId = placeId, GameId = gameId, SourceRef = sourceRef
}

-- Public contract kept small on purpose: anti-cheats that enumerate getgenv()
-- should see only Mode/Backend/Version plus the source base the backends and
-- updater fetch from. Diagnostics live behind __DEPHUB.Debug(), which is only
-- materialised on demand.
env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.Version = VERSION
env.__DEPHUB.SourceBaseURL = BASE_URL
-- Backends report internal failures here so a silent `return false` becomes a
-- concrete reason in the console instead of a bare "Falha desconhecida".
env.__DEPHUB.Log = log
local session = env[STATE_KEY]

env.__DEPHUB.Debug = function()
    return {
        Executor = detectExecutor(),
        RemoteVersion = env.__DEPHUB.RemoteVersion,
        State = env[STATE_KEY],
        Cache = env[CACHE_KEY],
        Version = VERSION
    }
end

local function fail(reason)
    local message = tostring(reason or "Falha desconhecida")
    log("Falha: " .. message)
    if env[STATE_KEY] ~= session then return false end
    cleanupRuntime()
    if env[STATE_KEY] == session then
        local state = env[STATE_KEY]
        if type(state) == "table" then
            state.status = "failed"
            state.error = message
            state.finishedAt = os.clock()
        end
        env[EXECUTED_KEY] = false
    end
    return false
end

local function getCache()
    local cache = env[CACHE_KEY]
    if type(cache) ~= "table" or cache.Version ~= VERSION or cache.SourceRef ~= sourceRef or type(cache.Sources) ~= "table" then
        cache = {Version = VERSION, SourceRef = sourceRef, Sources = {}}
        env[CACHE_KEY] = cache
    end
    return cache.Sources
end

local function performRequest(url)
    local requestFunctions = {
    }
    if type(request) == "function" then requestFunctions[#requestFunctions+1] = request end
    if type(http_request) == "function" then requestFunctions[#requestFunctions+1] = http_request end
    if type(syn) == "table" and type(syn.request) == "function" then requestFunctions[#requestFunctions+1] = syn.request end
    local lastError = "Resposta HTTP vazia"
    for attempt = 1, 2 do
        for _, requestFunction in ipairs(requestFunctions) do
            if requestFunction then
                local ok, response = pcall(requestFunction, {Url = url, Method = "GET"})
                if ok and type(response) == "table" then
                    local body = response.Body or response.body
                    local status = tonumber(response.StatusCode or response.status_code or 200) or 200
                    if status >= 200 and status < 400 and type(body) == "string" and #body > 0 then return true, body end
                    lastError = "HTTP " .. tostring(status)
                elseif not ok then
                    lastError = tostring(response)
                end
            end
        end
        -- Some executors expose HttpGet as a global helper, others only as a
        -- DataModel member. Try the global first, then the member, and never
        -- assume the member exists (reading or writing it can error).
        if type(HttpGet) == "function" then
            local ok, result = pcall(HttpGet, url)
            if ok and type(result) == "string" and #result > 0 then return true, result end
            lastError = ok and "Resposta HTTP vazia" or tostring(result)
        end
        local memberOk, memberHttpGet = pcall(function() return game.HttpGet end)
        if memberOk and type(memberHttpGet) == "function" then
            local ok, result = pcall(function() return game:HttpGet(url) end)
            if ok and type(result) == "string" and #result > 0 then return true, result end
            lastError = ok and "Resposta HTTP vazia" or tostring(result)
        end
        if attempt < 2 then task.wait(0.1 + math.random() * 0.08) end
    end
    return false, lastError
end

local function httpGet(path, useCache)
    local cache = getCache()
    if useCache ~= false and type(cache[path]) == "string" and #cache[path] > 0 then return true, cache[path] end
    local ok, result = performRequest(BASE_URL .. path)
    if not ok then return false, result end
    if useCache ~= false then cache[path] = result end
    return true, result
end

local function compile(source)
    if type(loadstring) ~= "function" then return false, "loadstring indisponivel" end
    local ok, chunk, compileError = pcall(loadstring, source)
    if not ok or type(chunk) ~= "function" then return false, tostring(compileError or chunk) end
    return true, chunk
end

local function loadModule(path, useCache)
    if env[STATE_KEY] ~= session then return false, "Sessao substituida" end
    local okSource, source = httpGet(path, useCache)
    if not okSource then return false, source end
    if env[STATE_KEY] ~= session then return false, "Sessao substituida" end
    local okCompile, chunk = compile(source)
    if not okCompile then return false, chunk end
    local okRun, result = pcall(chunk)
    if not okRun then return false, tostring(result) end
    return true, result
end

local executorName = detectExecutor()
log("Iniciando loader v" .. VERSION)
log("Executor detectado: " .. tostring(executorName))
log("PlaceId: " .. placeId)
log("GameId: " .. gameId)

local okVersion, remoteVersion = httpGet("src/version.txt", false)
if okVersion then env.__DEPHUB.RemoteVersion = tostring(remoteVersion):match("[%d%.]+") or VERSION end

local targets = {
    ["13379208636"] = {Core = "src/games/aotr.lua", AOTR = true},
    ["4658598196"] = {Core = "src/games/aotr.lua", AOTR = true},
    ["994732206"] = {Core = "src/games/bloxfruits.lua"},
    ["85211729168715"] = {Core = "src/games/bloxfruits.lua"},
    ["119048529960596"] = {Core = "src/games/rt3.lua"},
    ["10449761463"] = {Core = "src/games/tsb.lua", TSB = true},
    ["3808081382"] = {Core = "src/games/tsb.lua", TSB = true},
    ["142823291"] = {Core = "src/games/mm2.lua", MM2 = true},
    ["66654135"] = {Core = "src/games/mm2.lua", MM2 = true},
    ["84822469255086"] = {Core = "src/games/noobpiece.lua", NoobPiece = true},
    ["3840352284"] = {Core = "src/games/volleyball42.lua", Volleyball42 = true},
    ["1316421563"] = {Core = "src/games/volleyball42.lua", Volleyball42 = true}
}

-- AOT:R routes lobby by PlaceId and mission places by universe GameId.
-- Source: https://www.roblox.com/games/13379208636/Attack-on-Titan-Revolution
local gameName = tostring(game.Name or ""):lower()
local isAOTRName = gameName:find("attack on titan") ~= nil and gameName:find("revolution") ~= nil
local target = targets[placeId] or targets[gameId] or (isAOTRName and {Core = "src/games/aotr.lua", AOTR = true}) or {Core = "src/games/universal.lua", Universal = true}
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait()

local okCore, coreResult = loadModule(target.Core, false)
if not okCore then
    return fail("Core " .. tostring(target.Core) .. " falhou: " .. tostring(coreResult))
end
local isRT3 = target.Core == "src/games/rt3.lua"
local isTSB = target.TSB == true
local isMM2 = target.MM2 == true
local isAOTR = target.AOTR == true
local isNoobPiece = target.NoobPiece == true
local isVolleyball42 = target.Volleyball42 == true

if isRT3 then
    if coreResult ~= true then return fail("Modulo RT3 nao inicializou") end
elseif type(coreResult) ~= "table" then
    return fail("Core " .. tostring(target.Core) .. " retornou " .. typeof(coreResult) .. " (" .. tostring(coreResult) .. ")")
end

env.__DEPHUB.Universal = target.Universal and coreResult or nil
env.__DEPHUB.BloxFruits = not target.Universal and not isRT3 and not isTSB and not isMM2 and not isAOTR and not isNoobPiece and not isVolleyball42 and coreResult or nil
env.__DEPHUB.TSB = isTSB and coreResult or nil
env.__DEPHUB.MM2 = isMM2 and coreResult or nil
env.__DEPHUB.AOTR = isAOTR and coreResult or nil
env.__DEPHUB.NoobPiece = isNoobPiece and coreResult or nil
env.__DEPHUB.Volleyball42 = isVolleyball42 and coreResult or nil

local mode
local backend
if target.Universal then mode = "Universal" backend = coreResult
elseif isRT3 then mode = "RT3" backend = env.__DEPHUB.Runtime
elseif isTSB then mode = "TSB" backend = coreResult
elseif isMM2 then mode = "MM2" backend = coreResult
elseif isAOTR then mode = "AOTR" backend = coreResult
elseif isNoobPiece then mode = "NoobPiece" backend = coreResult
elseif isVolleyball42 then mode = "Volleyball42" backend = coreResult
else mode = "BloxFruits" backend = coreResult end

env.__DEPHUB.Mode = mode
env.__DEPHUB.Backend = backend

if env[STATE_KEY] ~= session then return false end

local okUILibrary, uiModule = loadModule("src/core/nebulatech.lua", false)
if okUILibrary and type(uiModule) == "table" and type(uiModule.new) == "function" then
    env.__DEPHUB.UILibrary = uiModule
end

-- The shared NebulaTech library is loaded once and used by the common frontend
-- for every game backend. UI loading remains optional for headless executors.
local okTempUI, tempUIModule = loadModule("src/core/temp-ui.lua", false)
if okTempUI and type(tempUIModule) == "table" and type(tempUIModule.Mount) == "function" then
    local okMount, tempUI = pcall(tempUIModule.Mount, env)
    if okMount and type(tempUI) == "table" then
        env.__DEPHUB.TempUI = tempUI
    end
end

env[EXECUTED_KEY] = true
env[STATE_KEY].status = "success"
env[STATE_KEY].finishedAt = os.clock()

task.defer(function()
    if env[STATE_KEY] ~= session or session.status ~= "success" then return end
    local ok, updaterModule = loadModule("src/core/updater.lua", false)
    if not ok or type(updaterModule) ~= "table" or type(updaterModule.new) ~= "function" then return end
    local okNew, updater = pcall(function()
        return updaterModule.new({PlaceId = game.PlaceId, GameId = game.GameId, PollInterval = 30, Mode = "serverhop"})
    end)
    if okNew and updater then
        if env[STATE_KEY] ~= session then
            if type(updater.Destroy) == "function" then updater:Destroy() end
            return
        end
        env.__DEPHUB.Updater = updater
        pcall(updater.Start, updater)
    end
end)

return true