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

local function log(message)
    local text = "[DEPHUB] " .. tostring(message)
    pcall(print, text)
end

local function logWarn(message)
    local text = "[DEPHUB] " .. tostring(message)
    pcall(warn, text)
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
    ["119048529960596"] = "https://raw.githubusercontent.com/glowpkj/DepHub/main/src/games/rt3.lua"
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

local function compileAndRun(source, sourceName)
    local compiler = loadstring
    if type(compiler) ~= "function" then
        logWarn("loadstring indisponivel. Nao foi possivel executar " .. sourceName .. ".")
        return false
    end

    log("Compilando " .. sourceName .. " (" .. tostring(#source) .. " bytes)")

    local okCompile, chunk, compileError = pcall(compiler, source)
    if not okCompile then
        logWarn("Falha interna ao compilar " .. sourceName .. ": " .. tostring(chunk))
        return false
    end

    if type(chunk) ~= "function" then
        logWarn("Falha de compilacao em " .. sourceName .. ": " .. tostring(compileError))
        return false
    end

    log("Compilacao concluida: " .. sourceName)

    local okRun, result = pcall(chunk)
    if not okRun then
        logWarn("Erro executando " .. sourceName .. ": " .. tostring(result))
        return false
    end

    log("Execucao concluida: " .. sourceName)
    return true, result
end

local function executePayload()
    local placeId = tostring(game.PlaceId)
    local gameId = tostring(game.GameId)
    local targetUrl = GAME_SCRIPTS[placeId] or GAME_SCRIPTS[gameId]

    if not targetUrl then
        logWarn("Nenhum script especifico encontrado para este jogo.")
        return false
    end

    log("Script selecionado: " .. targetUrl)
    log("Baixando payload...")

    local okHttp, source = httpGet(targetUrl)
    if not okHttp then
        logWarn("Falha no download: " .. tostring(source))
        return false
    end

    log("Download concluido: " .. tostring(#source) .. " bytes")
    return compileAndRun(source, targetUrl)
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
else
    logWarn("DepHub nao foi carregado.")
end
