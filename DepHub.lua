local game = game
local task = task
local type = type
local tostring = tostring
local pcall = pcall
local ipairs = ipairs
local math_floor = math.floor

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local env = type(getgenv) == "function" and getgenv() or _G
local BASE_URL = "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
local VERSION = "0.0.2"
local CACHE_KEY = "__DEPHUB_SOURCE_CACHE"
local EXECUTED_KEY = "__DEPHUB_LOADER_EXECUTED"
local STATE_KEY = "__DEPHUB_LOADER_STATE"

local function allowedLog(message)
    pcall(print, "[DEPHUB] " .. tostring(message))
end

local function detectExecutor()
    local ok, name = pcall(function()
        if type(identifyexecutor) == "function" then return identifyexecutor() end
        if type(getexecutorname) == "function" then return getexecutorname() end
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
    if type(state) ~= "table" then return end
    for _, target in ipairs({state.BloxFruits, state.BloxFruitsUI, state.Updater, state.Runtime, state.Window}) do
        if type(target) == "table" and type(target.Destroy) == "function" then
            pcall(target.Destroy, target)
        end
    end
    state.BloxFruits = nil
    state.BloxFruitsUI = nil
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
env[STATE_KEY] = {status = "running", startedAt = os.clock(), Version = VERSION}
env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.Version = VERSION
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
    if loading then pcall(loading.Destroy, loading) end
    env.__DEPHUB_LOADING_INSTANCE = nil
    cleanupRuntime()
    env.__DEPHUB.Loader.MarkFailed(reason)
    return false
end

local function httpGet(path, useCache)
    local cache = env[CACHE_KEY]
    if type(cache) ~= "table" then
        cache = {}
        env[CACHE_KEY] = cache
    end
    if useCache ~= false and type(cache[path]) == "string" and #cache[path] > 0 then
        return true, cache[path]
    end
    local ok, result = pcall(function() return game:HttpGet(BASE_URL .. path) end)
    if not ok or type(result) ~= "string" or #result == 0 then
        return false, ok and "Resposta HTTP vazia" or tostring(result)
    end
    if useCache ~= false then cache[path] = result end
    return true, result
end

local function compareVersions(localVersion, remoteVersion)
    local function parts(value)
        local a, b, c = tostring(value or "0.0.0"):match("^(%d+)%.(%d+)%.(%d+)")
        return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
    end
    local la, lb, lc = parts(localVersion)
    local ra, rb, rc = parts(remoteVersion)
    if ra ~= la then return ra > la and 1 or -1 end
    if rb ~= lb then return rb > lb and 1 or -1 end
    if rc ~= lc then return rc > lc and 1 or -1 end
    return 0
end

local function compile(source)
    if type(loadstring) ~= "function" then return false, "loadstring indisponivel" end
    local ok, chunk, compileError = pcall(loadstring, source)
    if not ok or type(chunk) ~= "function" then return false, tostring(compileError or chunk) end
    return true, chunk
end

local function loadModule(path, useCache)
    local okSource, source = httpGet(path, useCache)
    if not okSource then return false, source end
    local okCompile, chunk = compile(source)
    if not okCompile then return false, chunk end
    local okRun, result = pcall(chunk)
    if not okRun then return false, tostring(result) end
    return true, result
end

local okVersion, remoteVersion = httpGet("src/version.txt", false)
if okVersion then
    remoteVersion = tostring(remoteVersion):match("[%d%.]+") or VERSION
    env.__DEPHUB.RemoteVersion = remoteVersion
    local comparison = compareVersions(VERSION, remoteVersion)
    if comparison < 0 then
        allowedLog("Nova build detectada: " .. remoteVersion .. ". O loader usa os arquivos atuais da branch main.")
    end
end

local gameId = tostring(game.GameId)
local placeId = tostring(game.PlaceId)
local targets = {
    ["994732206"] = {Core = "src/games/bloxfruits.lua"},
    ["85211729168715"] = {Core = "src/games/bloxfruits.lua"},
    ["119048529960596"] = {Core = "src/games/rt3.lua"}
}
local target = targets[gameId]

local loading
local okLoading, Loading = loadModule("src/ui/loading.lua", false)
if okLoading and type(Loading) == "table" and type(Loading.new) == "function" then
    env.__DEPHUB_UI_LOADING = Loading
    local okInstance, instance = pcall(function()
        return Loading.new({Title = "DEPHUB", Status = "Aguardando jogo carregar...", LogoId = "rbxassetid://79507712997362", DisplayOrder = 10000, OpenDuration = 0.2})
    end)
    if okInstance and instance then
        loading = instance
        env.__DEPHUB_LOADING_INSTANCE = instance
        pcall(instance.SetProgress, instance, 0.08, "Aguardando jogo carregar...")
    end
end

if not game:IsLoaded() then game.Loaded:Wait() end
local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui") or localPlayer:WaitForChild("PlayerGui", 30)
if not playerGui then return fail("Jogo nao inicializou completamente", loading) end
task.wait()
allowedLog("Executor: " .. env.__DEPHUB.Executor)
allowedLog("PlaceId: " .. placeId)
allowedLog("GameId: " .. gameId)
allowedLog("Versao local: " .. VERSION .. " | Versao remota: " .. tostring(env.__DEPHUB.RemoteVersion or VERSION))
if not target then return fail("Jogo nao suportado", loading) end
if loading then pcall(loading.SetProgress, loading, 0.22, "Jogo carregado. Preparando modulo...") end

local okCore, coreResult = loadModule(target.Core, false)
if not okCore then return fail(coreResult, loading) end
if loading then pcall(loading.SetProgress, loading, 0.72, "Modulo do jogo inicializado...") end

env.__DEPHUB.BloxFruits = gameId ~= "119048529960596" and coreResult or nil

if gameId ~= "119048529960596" then
    if type(coreResult) ~= "table" then return fail(coreResult, loading) end
end

if loading then pcall(loading.SetProgress, loading, 0.92, "Finalizando inicializacao...") end
env[EXECUTED_KEY] = true
env[STATE_KEY].status = "success"
env[STATE_KEY].finishedAt = os.clock()
if loading then
    task.spawn(function()
        pcall(loading.Complete, loading, "Inicializacao concluida")
        env.__DEPHUB_LOADING_INSTANCE = nil
    end)
end
allowedLog("DepHub carregado com sucesso na versao " .. VERSION)

task.defer(function()
    local ok, updaterModule = loadModule("src/core/updater.lua", true)
    if not ok or type(updaterModule) ~= "table" or type(updaterModule.new) ~= "function" then return end
    local okNew, updater = pcall(function()
        return updaterModule.new({PlaceId = game.PlaceId, GameId = game.GameId, PollInterval = 15, Countdown = 12, Mode = "serverhop"})
    end)
    if okNew and updater then
        env.__DEPHUB.Updater = updater
        pcall(updater.Start, updater)
    end
end)

return true
