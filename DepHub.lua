local game = game
local task = task
local tostring = tostring
local type = type
local pcall = pcall
local warn = warn
local print = print
local os_clock = os.clock

local GetService = game.GetService
local Players = GetService(game, "Players")
local localPlayer = Players.LocalPlayer

local getgenvFn = type(getgenv) == "function" and getgenv or nil
local env = getgenvFn and getgenvFn() or _G
local BASE_URL = "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
local SOURCE_CACHE = env.__DEPHUB_SOURCE_CACHE or {}
env.__DEPHUB_SOURCE_CACHE = SOURCE_CACHE

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

local function httpGet(path)
    local url = BASE_URL .. path
    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and type(result) == "string" and #result > 0 then
        return true, result, url
    end
    if not ok then
        return false, tostring(result), url
    end
    return false, "Resposta HTTP vazia", url
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
    local cached = SOURCE_CACHE[path]
    local source
    local url = BASE_URL .. path

    if type(cached) == "string" and #cached > 0 then
        source = cached
    else
        local okHttp, downloaded, downloadedUrl = httpGet(path)
        if not okHttp then
            logWarn("Falha no download de " .. path .. ": " .. tostring(downloaded))
            return nil
        end
        source = downloaded
        url = downloadedUrl
        SOURCE_CACHE[path] = source
    end

    local okCompile, chunk = compile(source, url)
    if not okCompile then
        SOURCE_CACHE[path] = nil
        return nil
    end

    local okRun, result = pcall(chunk)
    if not okRun then
        logWarn("Erro executando " .. path .. ": " .. tostring(result))
        return nil
    end

    return result
end

local function beginPrefetch(path)
    local state = {
        done = false,
        ok = false,
        source = nil,
        url = BASE_URL .. path,
        error = nil
    }

    local cached = SOURCE_CACHE[path]
    if type(cached) == "string" and #cached > 0 then
        state.done = true
        state.ok = true
        state.source = cached
        return state
    end

    task.spawn(function()
        local ok, source, url = httpGet(path)
        state.ok = ok
        state.source = ok and source or nil
        state.url = url
        state.error = ok and nil or source
        if ok then
            SOURCE_CACHE[path] = source
        end
        state.done = true
    end)

    return state
end

local executorName, executorVersion = detectExecutor()
local gameId = tostring(game.GameId)
local placeId = tostring(game.PlaceId)

log("Loader iniciado")
log("Executor: " .. executorName .. (executorVersion and " " .. executorVersion or ""))
log("PlaceId: " .. placeId)
log("GameId: " .. gameId)
log(capability("loadstring", loadstring))
log(capability("getgenv", getgenvFn))

local previousState = env.__DEPHUB_LOADER_STATE
if type(previousState) == "table" and previousState.status == "running" then
    previousState.status = "failed"
end

if env.__DEPHUB_LOADER_EXECUTED and type(previousState) == "table" and previousState.status == "success" then
    logWarn("Loader ja foi executado com sucesso nesta sessao.")
    return
end

env.__DEPHUB_LOADER_EXECUTED = false
env.__DEPHUB_LOADER_STATE = {
    status = "running",
    executor = executorName,
    version = executorVersion,
    startedAt = os_clock()
}

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

env.__DEPHUB.Loader = env.__DEPHUB.Loader or {}
env.__DEPHUB.Loader.State = env.__DEPHUB_LOADER_STATE

env.__DEPHUB.Loader.MarkFailed = function(reason)
    local state = env.__DEPHUB_LOADER_STATE
    if type(state) == "table" then
        state.status = "failed"
        state.error = tostring(reason or "Falha desconhecida")
        env.__DEPHUB_LOADER_EXECUTED = false
    end
end

local GAME_SCRIPTS = {
    ["119048529960596"] = "src/games/rt3.lua",
    ["994732206"] = "src/games/bloxfruits.lua"
}

local path = GAME_SCRIPTS[gameId]
local prefetch = path and beginPrefetch(path) or nil

local Loading = loadModule("src/ui/loading.lua")
if type(Loading) == "table" and type(Loading.new) == "function" then
    env.__DEPHUB_UI_LOADING = Loading
    local okLoading, loadingInstance = pcall(function()
        return Loading.new({
            Title = "DEPHUB",
            Status = "Preparando inicialização...",
            LogoId = "rbxassetid://79507712997362",
            DisplayOrder = 10000
        })
    end)
    if okLoading and loadingInstance then
        env.__DEPHUB_LOADING_INSTANCE = loadingInstance
        pcall(loadingInstance.SetProgress, loadingInstance, 0.06, "Carregando núcleo...")
    end
end

local function finishLoading(message)
    local loading = env.__DEPHUB_LOADING_INSTANCE
    if not loading then
        return
    end

    local completed = false
    pcall(function()
        if type(loading.Complete) == "function" then
            loading:Complete(message or "Inicialização concluída")
            completed = true
        end
    end)

    if not completed then
        pcall(loading.Destroy, loading)
    end

    env.__DEPHUB_LOADING_INSTANCE = nil
end

local function abortLoading()
    local loading = env.__DEPHUB_LOADING_INSTANCE
    if loading then
        pcall(loading.Destroy, loading)
    end
    env.__DEPHUB_LOADING_INSTANCE = nil
end

local function executePayload()
    if not path then
        logWarn("Nenhum script especifico encontrado para este jogo.")
        abortLoading()
        return false
    end

    local loading = env.__DEPHUB_LOADING_INSTANCE
    if loading then
        pcall(loading.SetProgress, loading, 0.15, "Carregando script do jogo...")
    end

    local source
    local url = BASE_URL .. path

    if prefetch then
        while not prefetch.done do
            task.wait()
        end

        if not prefetch.ok then
            logWarn("Falha no download: " .. tostring(prefetch.error))
            abortLoading()
            return false
        end

        source = prefetch.source
        url = prefetch.url
    else
        local okHttp, downloaded, downloadedUrl = httpGet(path)
        if not okHttp then
            logWarn("Falha no download: " .. tostring(downloaded))
            abortLoading()
            return false
        end
        source = downloaded
        url = downloadedUrl
        SOURCE_CACHE[path] = source
    end

    if type(source) ~= "string" or #source == 0 then
        abortLoading()
        return false
    end

    log("Script selecionado: " .. url)
    log("Download concluido: " .. tostring(#source) .. " bytes")

    if loading then
        pcall(loading.SetProgress, loading, 0.28, "Compilando núcleo...")
    end

    local okCompile, chunk = compile(source, url)
    if not okCompile then
        abortLoading()
        return false
    end

    if loading then
        pcall(loading.SetProgress, loading, 0.55, "Inicializando módulos...")
    end

    local okRun, result = pcall(chunk)
    if not okRun then
        logWarn("Erro executando payload: " .. tostring(result))
        abortLoading()
        return false
    end

    if result ~= true and not (path == "src/games/bloxfruits.lua" and type(result) == "table") then
        logWarn("Payload nao confirmou inicializacao completa.")
        abortLoading()
        return false
    end

    if path == "src/games/bloxfruits.lua" then
        env.__DEPHUB.BloxFruits = result
    end

    log("Execucao concluida: " .. url)
    return true
end

local function startUpdater()
    local updater = loadModule("src/core/updater.lua")
    if type(updater) ~= "table" or type(updater.new) ~= "function" then
        logWarn("Updater indisponivel.")
        return false
    end

    local instance = updater.new({
        PlaceId = game.PlaceId,
        PollInterval = 15,
        Countdown = 12,
        Mode = "serverhop"
    })

    env.__DEPHUB.Updater = instance
    instance:Start()
    log("Monitor de atualizacao iniciado: 15s")
    return true
end

if not localPlayer then
    env.__DEPHUB.Loader.MarkFailed("LocalPlayer indisponivel")
    logWarn("LocalPlayer indisponivel. Abortando carregamento.")
    abortLoading()
    return
end

local ok, result = pcall(executePayload)
if not ok then
    env.__DEPHUB.Loader.MarkFailed(result)
    logWarn("Falha inesperada no loader: " .. tostring(result))
    abortLoading()
elseif result then
    env.__DEPHUB_LOADER_EXECUTED = true
    env.__DEPHUB_LOADER_STATE.status = "success"
    env.__DEPHUB_LOADER_STATE.finishedAt = os_clock()
    finishLoading(gameId == "994732206" and "Blox Fruits carregado" or "Inicialização concluída")
    log("========================================")
    log("DepHub carregado com sucesso")
    log("========================================")
    task.defer(startUpdater)
else
    env.__DEPHUB.Loader.MarkFailed("Payload nao inicializou corretamente")
    logWarn("DepHub nao foi carregado. Uma nova tentativa sera permitida.")
    abortLoading()
end
