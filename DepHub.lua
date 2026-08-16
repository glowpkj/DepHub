local game = game
local task = task
local type = type
local tostring = tostring
local pcall = pcall
local pairs = pairs
local ipairs = ipairs

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local env = type(getgenv) == "function" and getgenv() or _G
local BASE_URL = "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
local CACHE_KEY = "__DEPHUB_SOURCE_CACHE"
local EXECUTED_KEY = "__DEPHUB_LOADER_EXECUTED"
local STATE_KEY = "__DEPHUB_LOADER_STATE"

local function allowedLog(message)
    pcall(print, "[DEPHUB] " .. tostring(message))
end

local function detectExecutor()
    local ok, name = pcall(function()
        if type(identifyexecutor) == "function" then
            return identifyexecutor()
        end
        if type(getexecutorname) == "function" then
            return getexecutorname()
        end
        return "Desconhecido"
    end)
    return ok and tostring(name) or "Desconhecido"
end

local function cleanupRuntime()
    local oldLoading = env.__DEPHUB_LOADING_INSTANCE
    if oldLoading then
        pcall(oldLoading.Destroy, oldLoading)
        env.__DEPHUB_LOADING_INSTANCE = nil
    end

    local state = env.__DEPHUB
    if type(state) ~= "table" then
        return
    end

    local targets = {
        state.BloxFruitsUI,
        state.BloxFruits,
        state.Updater,
        state.Runtime,
        state.Window
    }

    for _, target in ipairs(targets) do
        if type(target) == "table" and type(target.Destroy) == "function" then
            pcall(target.Destroy, target)
        end
    end

    state.BloxFruitsUI = nil
    state.BloxFruits = nil
    state.Updater = nil
    state.Runtime = nil
    state.Window = nil
end

local previousState = env[STATE_KEY]
if env[EXECUTED_KEY] and type(previousState) == "table" and previousState.status == "success" then
    allowedLog("Loader ja foi executado com sucesso nesta sessao.")
    return
end

cleanupRuntime()
env[EXECUTED_KEY] = false
env[STATE_KEY] = {
    status = "running",
    startedAt = os.clock()
}

env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.Executor = detectExecutor()
env.__DEPHUB.Loader = env.__DEPHUB.Loader or {}
env.__DEPHUB.Loader.State = env[STATE_KEY]

env.__DEPHUB.Loader.MarkFailed = function(reason)
    local state = env[STATE_KEY]
    if type(state) == "table" then
        state.status = "failed"
        state.error = tostring(reason or "Falha desconhecida")
        state.finishedAt = os.clock()
    end
    env[EXECUTED_KEY] = false
end

local function fail(reason, loading)
    if loading then
        pcall(loading.Destroy, loading)
    end
    env.__DEPHUB_LOADING_INSTANCE = nil
    cleanupRuntime()
    env.__DEPHUB.Loader.MarkFailed(reason)
    return false
end

local function httpGet(path)
    local cache = env[CACHE_KEY]
    if type(cache) ~= "table" then
        cache = {}
        env[CACHE_KEY] = cache
    end

    local cached = cache[path]
    if type(cached) == "string" and #cached > 0 then
        return true, cached
    end

    local ok, result = pcall(function()
        return game:HttpGet(BASE_URL .. path)
    end)

    if not ok or type(result) ~= "string" or #result == 0 then
        return false, ok and "Resposta HTTP vazia" or tostring(result)
    end

    cache[path] = result
    return true, result
end

local function prefetch(path)
    local state = {
        Done = false,
        Ok = false,
        Source = nil,
        Error = nil
    }

    local cache = env[CACHE_KEY]
    if type(cache) == "table" and type(cache[path]) == "string" and #cache[path] > 0 then
        state.Done = true
        state.Ok = true
        state.Source = cache[path]
        return state
    end

    task.spawn(function()
        local ok, source = httpGet(path)
        state.Ok = ok
        state.Source = ok and source or nil
        state.Error = ok and nil or source
        state.Done = true
    end)

    return state
end

local function waitPrefetch(state)
    while not state.Done do
        task.wait()
    end
    return state.Ok, state.Source, state.Error
end

local function compile(source)
    if type(loadstring) ~= "function" then
        return false, "loadstring indisponivel"
    end

    local ok, chunk, compileError = pcall(loadstring, source)
    if not ok or type(chunk) ~= "function" then
        return false, tostring(compileError or chunk)
    end

    return true, chunk
end

local function loadModule(path)
    local okSource, source = httpGet(path)
    if not okSource then
        return false, source
    end

    local okCompile, chunk = compile(source)
    if not okCompile then
        return false, chunk
    end

    local okRun, result = pcall(chunk)
    if not okRun then
        return false, tostring(result)
    end

    return true, result
end

local gameId = tostring(game.GameId)
local placeId = tostring(game.PlaceId)

local targets = {
    ["994732206"] = {
        Core = "src/games/bloxfruits.lua"
    },
    ["119048529960596"] = {
        Core = "src/games/rt3.lua",
        UI = "src/ui/init.lua"
    }
}

local target = targets[gameId]
local corePrefetch = target and prefetch(target.Core) or nil
local uiPrefetch = target and target.UI and prefetch(target.UI) or nil

local loading

do
    local ok, Loading = loadModule("src/ui/loading.lua")
    if ok and type(Loading) == "table" and type(Loading.new) == "function" then
        env.__DEPHUB_UI_LOADING = Loading
        local okLoading, instance = pcall(function()
            return Loading.new({
                Title = "DEPHUB",
                Status = "Aguardando jogo carregar...",
                LogoId = "rbxassetid://79507712997362",
                DisplayOrder = 10000,
                OpenDuration = 0.2
            })
        end)
        if okLoading and instance then
            loading = instance
            env.__DEPHUB_LOADING_INSTANCE = instance
            pcall(instance.SetProgress, instance, 0.08, "Aguardando jogo carregar...")
        end
    end
end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui") or localPlayer:WaitForChild("PlayerGui", 30)
if not playerGui then
    return fail("Jogo nao inicializou completamente", loading)
end

task.wait()
task.wait()

allowedLog("Executor: " .. tostring(env.__DEPHUB.Executor))
allowedLog("PlaceId: " .. placeId)
allowedLog("GameId: " .. gameId)

if not target then
    return fail("Jogo nao suportado", loading)
end

if loading then
    pcall(loading.SetProgress, loading, 0.22, "Jogo carregado. Preparando modulo...")
end

local okCoreSource, coreSource, coreError = waitPrefetch(corePrefetch)
if not okCoreSource then
    return fail(coreError, loading)
end

local uiSource
if uiPrefetch then
    local okUISource, source, uiError = waitPrefetch(uiPrefetch)
    if not okUISource then
        return fail(uiError, loading)
    end
    uiSource = source
end

if loading then
    pcall(loading.SetProgress, loading, 0.42, "Inicializando modulo do jogo...")
end

local okCoreCompile, coreChunk = compile(coreSource)
if not okCoreCompile then
    return fail(coreChunk, loading)
end

local okCoreRun, coreResult = pcall(coreChunk)
if not okCoreRun then
    return fail(coreResult, loading)
end

if gameId == "994732206" then
    if type(coreResult) ~= "table" then
        return fail(coreResult, loading)
    end

    env.__DEPHUB.BloxFruits = coreResult
else
    if coreResult ~= true then
        return fail(coreResult, loading)
    end
end

if loading then
    pcall(loading.SetProgress, loading, 0.92, "Finalizando inicializacao...")
end

env[EXECUTED_KEY] = true
env[STATE_KEY].status = "success"
env[STATE_KEY].finishedAt = os.clock()

if loading then
    task.spawn(function()
        pcall(loading.Complete, loading, "Inicializacao concluida")
        env.__DEPHUB_LOADING_INSTANCE = nil
    end)
end

allowedLog("DepHub carregado com sucesso")

task.defer(function()
    local ok, updaterModule = loadModule("src/core/updater.lua")
    if not ok or type(updaterModule) ~= "table" or type(updaterModule.new) ~= "function" then
        return
    end

    local okNew, updater = pcall(function()
        return updaterModule.new({
            PlaceId = game.PlaceId,
            GameId = game.GameId,
            PollInterval = 15,
            Countdown = 12,
            Mode = "serverhop"
        })
    end)

    if okNew and updater then
        env.__DEPHUB.Updater = updater
        pcall(updater.Start, updater)
    end
end)

return true
