local game = game
local task = task
local tostring = tostring
local type = type
local pcall = pcall
local warn = warn
local print = print

local GetService = game.GetService
local Players = GetService(game, "Players")
local localPlayer = Players.LocalPlayer

local getgenvFn = type(getgenv) == "function" and getgenv or nil
local env = getgenvFn and getgenvFn() or _G
local BASE_URL = "https://raw.githubusercontent.com/glowpkj/DepHub/main/"

local function log(message)
    pcall(print, "[DEPHUB] " .. tostring(message))
end

local function logWarn(message)
    pcall(warn, "[DEPHUB] " .. tostring(message))
end

local function detectExecutor()
    local ok, name, version = pcall(function()
        if type(identifyexecutor) == "function" then
            local executorName, executorVersion = identifyexecutor()
            return executorName, executorVersion
        end
        if type(getexecutorname) == "function" then
            return getexecutorname(), nil
        end
        return nil, nil
    end)
    if ok and name then
        return tostring(name), version and tostring(version) or nil
    end
    return "Desconhecido", nil
end

local function capability(name, value)
    return name .. ": " .. (type(value) == "function" and "OK" or "N/A")
end

local executorName, executorVersion = detectExecutor()

log("Loader iniciado")
log("Executor: " .. executorName .. (executorVersion and " " .. executorVersion or ""))
log("PlaceId: " .. tostring(game.PlaceId))
log("GameId: " .. tostring(game.GameId))
log(capability("loadstring", loadstring))
log(capability("getgenv", getgenvFn))
log(capability("request", request))
log(capability("http_request", http_request))
log(capability("identifyexecutor", identifyexecutor))

if env.__DEPHUB_LOADER_EXECUTED then
    logWarn("Loader ja foi executado nesta sessao.")
    return
end

env.__DEPHUB_LOADER_EXECUTED = true
env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.Executor = executorName
env.__DEPHUB.ExecutorVersion = executorVersion
env.__DEPHUB.Capabilities = {
    loadstring = type(loadstring) == "function",
    getgenv = getgenvFn ~= nil,
    request = type(request) == "function",
    http_request = type(http_request) == "function",
    identifyexecutor = type(identifyexecutor) == "function"
}

local GAME_SCRIPTS = {
    ["119048529960596"] = "src/games/rt3.lua"
}

local function httpGet(url)
    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and type(result) == "string" and #result > 0 then
        return true, result
    end
    if not ok then
        return false, tostring(result)
    end
    return false, "Resposta HTTP vazia"
end

local function compile(source, sourceName)
    if type(loadstring) ~= "function" then
        logWarn("loadstring indisponivel para " .. sourceName)
        return false
    end

    local okCompile, chunk, compileError = pcall(loadstring, source)
    if not okCompile then
        logWarn("Falha interna ao compilar " .. sourceName .. ": " .. tostring(chunk))
        return false
    end
    if type(chunk) ~= "function" then
        logWarn("Falha de compilacao em " .. sourceName .. ": " .. tostring(compileError))
        return false
    end
    return true, chunk
end

local function loadModule(path)
    local url = BASE_URL .. path
    log("Baixando modulo: " .. path)

    local okHttp, source = httpGet(url)
    if not okHttp then
        logWarn("Falha no download de " .. path .. ": " .. tostring(source))
        return nil
    end

    local okCompile, chunk = compile(source, path)
    if not okCompile then
        return nil
    end

    local okRun, result = pcall(chunk)
    if not okRun then
        logWarn("Erro executando " .. path .. ": " .. tostring(result))
        return nil
    end

    return result
end

local function executePayload()
    local placeId = tostring(game.PlaceId)
    local gameId = tostring(game.GameId)
    local path = GAME_SCRIPTS[placeId] or GAME_SCRIPTS[gameId]

    if not path then
        logWarn("Nenhum script especifico encontrado para este jogo.")
        return false
    end

    local url = BASE_URL .. path
    log("Script selecionado: " .. url)
    log("Baixando payload...")

    local okHttp, source = httpGet(url)
    if not okHttp then
        logWarn("Falha no download: " .. tostring(source))
        return false
    end

    log("Download concluido: " .. tostring(#source) .. " bytes")

    local okCompile, chunk = compile(source, url)
    if not okCompile then
        return false
    end

    log("Compilacao concluida: " .. url)

    local okRun, result = pcall(chunk)
    if not okRun then
        logWarn("Erro executando payload: " .. tostring(result))
        return false
    end

    log("Execucao concluida: " .. url)
    return true
end

local function startUpdater()
    local updater = loadModule("src/core/updater.lua")
    if type(updater) ~= "table" or type(updater.new) ~= "function" then
        logWarn("Updater indisponivel.")
        return
    end

    local instance = updater.new({
        PlaceId = game.PlaceId,
        PollInterval = 60,
        Countdown = 12,
        Mode = "serverhop"
    })

    env.__DEPHUB.Updater = instance
    instance:Start()
    log("Monitor de atualizacao iniciado: 60s")
end

if not localPlayer then
    logWarn("LocalPlayer indisponivel. Abortando carregamento.")
    return
end

local ok, result = pcall(executePayload)
if not ok then
    logWarn("Falha inesperada no loader: " .. tostring(result))
elseif result then
    log("========================================")
    log("DepHub carregado com sucesso")
    log("========================================")
    task.spawn(startUpdater)
else
    logWarn("DepHub nao foi carregado.")
end
