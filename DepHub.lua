local game = game
local task = task
local type = type
local tostring = tostring
local ipairs = ipairs
local pcall = pcall

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local env = type(getgenv) == "function" and getgenv() or _G
local BASE_URL = "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
local VERSION = "0.0.5"
local CACHE_KEY = "__DEPHUB_SOURCE_CACHE"
local EXECUTED_KEY = "__DEPHUB_LOADER_EXECUTED"
local STATE_KEY = "__DEPHUB_LOADER_STATE"

local function allowedLog(message)
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

local function cleanupRuntime()
    local oldLoading = env.__DEPHUB_LOADING_INSTANCE
    if oldLoading then
        pcall(oldLoading.Destroy, oldLoading)
        env.__DEPHUB_LOADING_INSTANCE = nil
    end

    env.__DEPHUB_UI_MODULES = nil
    env.__DEPHUB_UI_LOADING = nil

    local state = env.__DEPHUB
    if type(state) ~= "table" then return end

    for _, key in ipairs({
        "Frontend",
        "BloxFruits",
        "BloxFruitsUI",
        "TSB",
        "TSBUI",
        "ViolenceDistrict",
        "ViolenceDistrictUI",
        "Universal",
        "Updater",
        "Runtime",
        "Window"
    }) do
        local target = state[key]
        if type(target) == "table" and type(target.Destroy) == "function" then
            pcall(target.Destroy, target)
        end
    end

    state.BloxFruits = nil
    state.BloxFruitsUI = nil
    state.TSB = nil
    state.TSBUI = nil
    state.ViolenceDistrict = nil
    state.ViolenceDistrictUI = nil
    state.Universal = nil
    state.Updater = nil
    state.Runtime = nil
    state.Window = nil
    state.Frontend = nil

    env.__DEPHUB_TSB = nil
    env.__DEPHUB_TSB_FRONTEND = nil
    env.__DEPHUB_VD = nil
    env.__DEPHUB_VD_FRONTEND = nil
end

local previousState = env[STATE_KEY]
if env[EXECUTED_KEY]
    and type(previousState) == "table"
    and previousState.status == "success"
    and previousState.Frontend == "library-1" then

    allowedLog("Status: Loader ja executado com sucesso nesta sessao")
    return
end

cleanupRuntime()
env[EXECUTED_KEY] = false
env[STATE_KEY] = {
    status = "running",
    startedAt = os.clock(),
    Version = VERSION,
    Frontend = "library-1"
}

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

local function fail(reason)
    allowedLog("Falha: " .. tostring(reason))
    cleanupRuntime()
    env.__DEPHUB.Loader.MarkFailed(reason)
    return false
end

local function performRequest(url)
    local requestFunctions = {
        type(request) == "function" and request or nil,
        type(http_request) == "function" and http_request or nil,
        type(syn) == "table" and type(syn.request) == "function" and syn.request or nil
    }

    for _, requestFunction in ipairs(requestFunctions) do
        if requestFunction then
            local ok, response = pcall(requestFunction, {
                Url = url,
                Method = "GET"
            })

            if ok and type(response) == "table" then
                local body = response.Body or response.body
                local status = tonumber(response.StatusCode or response.status_code or 200) or 200

                if status >= 200
                    and status < 400
                    and type(body) == "string"
                    and #body > 0 then

                    return true, body
                end
            end
        end
    end

    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)

    if ok and type(result) == "string" and #result > 0 then
        return true, result
    end

    return false, ok and "Resposta HTTP vazia" or tostring(result)
end

local function httpGet(path, useCache)
    local cache = env[CACHE_KEY]
    if type(cache) ~= "table" then
        cache = {}
        env[CACHE_KEY] = cache
    end

    if useCache ~= false
        and type(cache[path]) == "string"
        and #cache[path] > 0 then

        return true, cache[path]
    end

    local ok, result = performRequest(BASE_URL .. path)
    if not ok then
        return false, result
    end

    if useCache ~= false then
        cache[path] = result
    end

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
    if type(loadstring) ~= "function" then
        return false, "loadstring indisponivel"
    end

    local ok, chunk, compileError = pcall(loadstring, source)
    if not ok or type(chunk) ~= "function" then
        return false, tostring(compileError or chunk)
    end

    return true, chunk
end

local function loadModule(path, useCache)
    local okSource, source = httpGet(path, useCache)
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

allowedLog("Iniciando loader v" .. VERSION)
allowedLog("Executor detectado: " .. tostring(env.__DEPHUB.Executor))

local gameId = tostring(game.GameId)
local placeId = tostring(game.PlaceId)

allowedLog("PlaceId: " .. placeId)
allowedLog("GameId: " .. gameId)

local okVersion, remoteVersion = httpGet("src/version.txt", false)
if okVersion then
    remoteVersion = tostring(remoteVersion):match("[%d%.]+") or VERSION
    env.__DEPHUB.RemoteVersion = remoteVersion
end

local targets = {
    ["994732206"] = {
        Core = "src/games/bloxfruits.lua"
    },
    ["85211729168715"] = {
        Core = "src/games/bloxfruits.lua"
    },
    ["119048529960596"] = {
        Core = "src/games/rt3.lua"
    },
    ["10449761463"] = {
        Core = "src/games/tsb.lua",
        Frontend = "src/games/features/tsb/frontend.lua",
        TSB = true
    },
    ["3808081382"] = {
        Core = "src/games/tsb.lua",
        Frontend = "src/games/features/tsb/frontend.lua",
        TSB = true
    },
    ["93978595733734"] = {
        Core = "src/games/violencedistrict.lua",
        Frontend = "src/games/features/violencedistrict/frontend.lua",
        ViolenceDistrict = true
    },
    ["6739698191"] = {
        Core = "src/games/violencedistrict.lua",
        Frontend = "src/games/features/violencedistrict/frontend.lua",
        ViolenceDistrict = true
    }
}

local target = targets[placeId]
    or targets[gameId]
    or {
        Core = "src/games/universal.lua",
        Universal = true
    }

if not game:IsLoaded() then
    game.Loaded:Wait()
end

task.wait()

local okCore, coreResult = loadModule(target.Core, false)
if not okCore then
    return fail(coreResult)
end

local isRT3 = target.Core == "src/games/rt3.lua"
local isTSB = target.TSB == true
local isVD = target.ViolenceDistrict == true

if isRT3 then
    if coreResult ~= true then
        return fail("Modulo RT3 nao inicializou")
    end
elseif type(coreResult) ~= "table" then
    return fail(coreResult)
end

env.__DEPHUB.Universal = target.Universal and coreResult or nil
env.__DEPHUB.BloxFruits = not target.Universal and not isRT3 and not isTSB and not isVD and coreResult or nil
env.__DEPHUB.TSB = isTSB and coreResult or nil
env.__DEPHUB.ViolenceDistrict = isVD and coreResult or nil

local mode
local backend

if target.Universal then
    mode = "Universal"
    backend = coreResult
elseif isRT3 then
    mode = "RT3"
    backend = env.__DEPHUB.Runtime
elseif isTSB then
    mode = "TSB"
    backend = coreResult
elseif isVD then
    mode = "ViolenceDistrict"
    backend = coreResult
else
    mode = "BloxFruits"
    backend = coreResult
end

if isTSB then
    env[STATE_KEY].Frontend = "tsb-compact-1"

    local okFrontend, frontend = loadModule(target.Frontend, false)
    if not okFrontend or type(frontend) ~= "table" then
        return fail(okFrontend and "Frontend TSB invalido" or frontend)
    end

    env.__DEPHUB.TSBUI = frontend
    env.__DEPHUB.Frontend = frontend
elseif isVD then
    env[STATE_KEY].Frontend = "vd-compact-1"

    local okFrontend, frontend = loadModule(target.Frontend, false)
    if not okFrontend or type(frontend) ~= "table" then
        return fail(okFrontend and "Frontend Violence District invalido" or frontend)
    end

    env.__DEPHUB.ViolenceDistrictUI = frontend
    env.__DEPHUB.Frontend = frontend
else
    local subtitles = {
        Universal = "UNIVERSAL",
        BloxFruits = "BLOX FRUITS",
        RT3 = "RESTAURANT TYCOON 3"
    }

    local okLibrary, Library = loadModule("library/init.lua", false)
    if not okLibrary
        or type(Library) ~= "table"
        or type(Library.new) ~= "function" then

        return fail(okLibrary and "Library inválida" or Library)
    end

    local okFrontend, frontend = pcall(Library.new, {
        Mode = mode,
        Backend = backend,
        Title = "DEPHUB",
        Subtitle = subtitles[mode]
    })

    if not okFrontend or type(frontend) ~= "table" then
        return fail(frontend)
    end

    env.__DEPHUB.Frontend = frontend
end

env[EXECUTED_KEY] = true
env[STATE_KEY].status = "success"
env[STATE_KEY].finishedAt = os.clock()

allowedLog(
    target.Universal
        and "Status: Script universal carregado com sucesso"
        or "Status: Jogo compativel carregado com sucesso"
)

task.defer(function()
    local ok, updaterModule = loadModule("src/core/updater.lua", false)
    if not ok
        or type(updaterModule) ~= "table"
        or type(updaterModule.new) ~= "function" then

        return
    end

    local okNew, updater = pcall(function()
        return updaterModule.new({
            PlaceId = game.PlaceId,
            GameId = game.GameId,
            PollInterval = 15,
            Mode = "serverhop"
        })
    end)

    if okNew and updater then
        env.__DEPHUB.Updater = updater
        pcall(updater.Start, updater)
    end
end)

return true
