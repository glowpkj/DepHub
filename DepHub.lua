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

local sourceRef = tostring((...) or env.__DEPHUB_SOURCE_REF or "main")
-- Source hosts in fallback order. raw.githubusercontent.com serves a branch ref
-- through an edge cache whose TTL can keep a whole revision behind, so a "bump
-- main" can go unseen by the loader (and by every module) for minutes. jsDelivr
-- re-resolves from git per request, and github.com/<ref>/raw/ is a third origin;
-- the first host that answers the version probe wins for the whole session, and
-- its base is published so every module fetches from the same live mirror.
local HOST_TEMPLATES = {
    "https://cdn.jsdelivr.net/gh/glowpkj/DepHub@" .. sourceRef .. "/",
    "https://github.com/glowpkj/DepHub/raw/" .. sourceRef .. "/",
    "https://raw.githubusercontent.com/glowpkj/DepHub/" .. sourceRef .. "/",
}
local BASE_URL = HOST_TEMPLATES[1]
local VERSION = "0.0.98"
local CACHE_KEY = "__DEPHUB_SOURCE_CACHE"
local EXECUTED_KEY = "__DEPHUB_LOADER_EXECUTED"
local STATE_KEY = "__DEPHUB_LOADER_STATE"

-- Executors cache game:HttpGet by exact URL, so a fixed source URL can keep
-- serving an older revision of a module even after main is updated. A token
-- that changes per session makes the module URLs unique, forcing a real fetch
-- of current source; GitHub's raw host ignores the query, so the file is the
-- same. The loader's own in-memory cache still keeps it to one fetch per module.
local CACHE_BUST = tostring(os.time()) .. "." .. tostring(math.floor((os.clock() % 1) * 1e6))

local placeId = tostring(game.PlaceId)
local gameId = tostring(game.GameId)

local function log(message)
    local text = tostring(message)
    pcall(print, text)
    local diag = env and env.__DEPHUB and env.__DEPHUB.Diagnostics
    if diag and type(diag.Log) == "function" then pcall(diag.Log, diag, "loader", text) end
end

local function detectExecutor()
    local ok, name = pcall(function()
        if type(identifyexecutor) == "function" then return identifyexecutor() end
        if type(getexecutorname) == "function" then return getexecutorname() end
        return "Desconhecido"
    end)
    return ok and tostring(name) or "Desconhecido"
end

local BACKEND_KEYS = {
    "AOTR", "TSB", "MM2", "NoobPiece", "BloxFruits", "Universal", "Runtime", "Volleyball42"
}

local HANDLE_KEYS = {
    "Updater", "Window", "UIGuard", "TempUI", "UI", "DemonUI", "Scheduler", "HealthMonitor", "Dashboard", "AntiAFK"
}

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

    -- Release the previous diagnostics console first so its log hooks (warn/
    -- print interception) are removed before the new session installs its own.
    local previousDiag = env.__DEPHUB and env.__DEPHUB.Diagnostics
    if previousDiag and type(previousDiag.Destroy) == "function" then pcall(previousDiag.Destroy, previousDiag) end
    if env.__DEPHUB then env.__DEPHUB.Diagnostics = nil end

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
        state.DemonUI = nil
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

-- The source-host resolver is defined once performRequest exists (below), but it
-- is referenced while publishing state, so it is forward-declared here.
local resolveBase

env[STATE_KEY] = {
    status = "running", startedAt = os.clock(), Version = VERSION,
    PlaceId = placeId, GameId = gameId, SourceRef = sourceRef
}

env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.Version = VERSION
-- Provisional: the first candidate host. httpGet refines this through
-- resolveBase() on the first module fetch and stores the winner back, so the
-- value a later module reads is the host that actually served the current build.
env.__DEPHUB.SourceBaseURL = env.__DEPHUB.SourceBaseURL or BASE_URL
-- Published so each backend can make its own module URLs unique per session and
-- avoid an executor serving a cached older revision (see CACHE_BUST above).
env.__DEPHUB.SourceCacheBust = CACHE_BUST
env.__DEPHUB.Log = log
local session = env[STATE_KEY]

-- The diagnostics collector is declared here so early failures can be recorded,
-- but it is only instantiated after the module loader exists (below).
local Diag

env.__DEPHUB.Debug = function()
    return {
        Executor = detectExecutor(),
        RemoteVersion = env.__DEPHUB.RemoteVersion,
        SourceBaseURL = env.__DEPHUB.SourceBaseURL,
        BaseVersion = env.__DEPHUB.BaseVersion,
        State = env[STATE_KEY],
        Cache = env[CACHE_KEY],
        Version = VERSION
    }
end

local function fail(reason)
    local message = tostring(reason or "Falha desconhecida")
    log("Falha: " .. message)
    if Diag then Diag:Note("FALHA DO LOADER: " .. message) end
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
    local requestFunctions = {}
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

-- Pick the source host that actually serves the current version. Probing with
-- src/version.txt is enough: a host may be reachable yet still hand back a stale
-- cached tree, so the probe reads the version and only accepts a host whose
-- content parses, preferring the one that reports the newest version seen. The
-- winner is stored in env so later sessions and every module reuse the same
-- mirror instead of each re-probing.
resolveBase = function()
    if type(env.__DEPHUB) == "table" and type(env.__DEPHUB.SourceBaseURL) == "string"
        and env.__DEPHUB.SourceBaseRef == sourceRef then
        return env.__DEPHUB.SourceBaseURL
    end

    local bestBase, bestVersion
    local function segments(v)
        local out = {}
        for part in tostring(v):gmatch("%d+") do out[#out + 1] = tonumber(part) or 0 end
        return out
    end
    local function newer(a, b)
        if not a then return false end
        if not b then return true end
        local sa, sb = segments(a), segments(b)
        for i = 1, math.max(#sa, #sb) do
            local x, y = sa[i] or 0, sb[i] or 0
            if x ~= y then return x > y end
        end
        return false
    end

    for _, base in ipairs(HOST_TEMPLATES) do
        local token = tostring(os.time()) .. "." .. tostring(math.floor((os.clock() % 1) * 1e6))
        local ok, body = performRequest(base .. "src/version.txt?cb=" .. token)
        if ok and type(body) == "string" then
            local version = tostring(body):match("[%d%.]+")
            if version and newer(version, bestVersion) then
                bestBase, bestVersion = base, version
            end
            -- A host serving the local version or newer is good enough: stop at
            -- the earliest one, so the preferred mirror wins as soon as it is
            -- current. Probing continues only while hosts come back older
            -- (stale cache) or unreachable.
            if version and not newer(VERSION, version) then break end
        end
    end

    local base = bestBase or BASE_URL
    env.__DEPHUB = env.__DEPHUB or {}
    env.__DEPHUB.SourceBaseURL = base
    env.__DEPHUB.SourceBaseRef = sourceRef
    env.__DEPHUB.BaseVersion = bestVersion
    return base
end

local function httpGet(path, useCache)
    local base = resolveBase()
    local cache = getCache()
    if useCache ~= false and type(cache[path]) == "string" and #cache[path] > 0 then return true, cache[path] end
    local separator = path:find("?", 1, true) and "&" or "?"
    local ok, result = performRequest(base .. path .. separator .. "cb=" .. CACHE_BUST)
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

-- Instantiate the diagnostics collector now that the loader can fetch modules.
-- A no-op stand-in keeps every later Diag call valid even if it fails to load.
do
    local okDiag, diagModule = loadModule("src/core/diagnostics.lua", false)
    if okDiag and type(diagModule) == "table" and type(diagModule.new) == "function" then
        local okNew, instance = pcall(diagModule.new)
        if okNew and type(instance) == "table" then Diag = instance end
    end
    if not Diag then
        Diag = {SetEnvironment=function() end, RegisterModule=function() end, Module=function() end,
            Probe=function() end, Feature=function() end, Watch=function() end, Command=function() end,
            SniffRemote=function() end, RunCommand=function() return "" end, Note=function() end, Log=function() end,
            Install=function() return false end, Report=function() return "diagnostico indisponivel" end,
            LogText=function() return "" end, MetricsLine=function() return "" end, Destroy=function() end,
            Copy=function() return false, "diagnostico indisponivel" end}
        Diag.__stub = true
    end
    env.__DEPHUB.Diagnostics = Diag
end
Diag:RegisterModule("src/core/diagnostics.lua")
Diag:Module("src/core/diagnostics.lua", not Diag.__stub, Diag.__stub and "nao carregou" or "carregado")
Diag:SetEnvironment({
    Executor = detectExecutor(),
    Version = VERSION,
    PlaceId = placeId,
    GameId = gameId,
    GameName = tostring(game.Name or "?"),
    SourceRef = sourceRef,
    HttpGet = type(game.HttpGet) == "function" and "game:HttpGet" or "ausente",
    request = type(request) == "function" and "presente" or "ausente",
    loadstring = type(loadstring) == "function" and "presente" or "ausente"
})

local executorName = detectExecutor()
log("Iniciando loader v" .. VERSION)
log("Executor detectado: " .. tostring(executorName))
log("PlaceId: " .. placeId)
log("GameId: " .. gameId)

local okVersion, remoteVersion = httpGet("src/version.txt", false)
if okVersion then env.__DEPHUB.RemoteVersion = tostring(remoteVersion):match("[%d%.]+") or VERSION end
log("Fonte: " .. tostring(env.__DEPHUB.SourceBaseURL) .. " (remoto " .. tostring(env.__DEPHUB.RemoteVersion or "?") .. ")")

-- Compare two dotted version strings numerically, segment by segment. Returns
-- true only when "a" is strictly newer than "b", so an older remote (a test
-- stub, a branch build, a stale mirror) never triggers a reload.
local function versionIsNewer(a, b)
    local function segments(v)
        local out = {}
        for part in tostring(v):gmatch("%d+") do out[#out + 1] = tonumber(part) or 0 end
        return out
    end
    local sa, sb = segments(a), segments(b)
    for i = 1, math.max(#sa, #sb) do
        local x, y = sa[i] or 0, sb[i] or 0
        if x ~= y then return x > y end
    end
    return false
end

-- Self-heal for the bootstrap cached by the executor. The loader's own module
-- fetches carry a per-session cache-bust token, but the bootstrap line a user
-- pastes (game:HttpGet(BASE_URL .. "DepHub.lua")) has a fixed URL, so an
-- executor can keep serving the old loader body even after main is bumped --
-- the running build then lags a whole version behind (old branch behaviour in
-- game). When the remote version is newer than this build, re-fetch the loader
-- itself with a fresh token and re-execute it. The guard records the version we
-- are switching to (in env, which survives the re-execution), so the freshly
-- loaded build sees the flag matching its own VERSION and does not loop.
local remV = env.__DEPHUB.RemoteVersion
if okVersion and type(remV) == "string" and versionIsNewer(remV, VERSION) and env.__DEPHUB_SELF_UPDATE_ATTEMPT ~= remV then
    env.__DEPHUB_SELF_UPDATE_ATTEMPT = remV
    log("Versao remota " .. remV .. " difere da local " .. VERSION .. "; recarregando loader.")
    local token = tostring(os.time()) .. "." .. tostring(math.floor((os.clock() % 1) * 1e6))
    local fetched, freshSource = performRequest(resolveBase() .. "DepHub.lua?cb=" .. token)
    if fetched and type(freshSource) == "string" and #freshSource > 0 then
        local okCompile, freshChunk = compile(freshSource)
        if okCompile then
            -- Retire this session before re-executing: the fresh build runs from
            -- the top and would otherwise see a "running" session and bail with
            -- "inicializacao em andamento". Clearing it lets the new build take
            -- over cleanly; this frame returns right after, so it never resumes.
            env[STATE_KEY] = nil
            local okRun, runError = pcall(freshChunk, sourceRef)
            if okRun then return true end
            log("Recarga do loader falhou ao executar: " .. tostring(runError))
        else
            log("Recarga do loader nao compilou: " .. tostring(freshChunk))
        end
    else
        log("Recarga do loader nao baixou: " .. tostring(freshSource))
    end
    -- Fall through: if the reload did not take, run the cached build as before
    -- rather than leaving the player with nothing. Restore the session that was
    -- cleared for the reload attempt so this frame can still finish cleanly.
    env[STATE_KEY] = session
end
-- This build is the one the guard was waiting for, so the attempt is complete.
if env.__DEPHUB_SELF_UPDATE_ATTEMPT == VERSION then env.__DEPHUB_SELF_UPDATE_ATTEMPT = nil end

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
    ["1316421563"] = {Core = "src/games/volleyball42.lua", Volleyball42 = true},
    ["114234929420007"] = {Core = "src/games/bloodstrike.lua", BloodStrike = true},
    ["107778070777162"] = {Core = "src/games/steal-a-egg.lua", StealAnEgg = true},
    ["93978595733734"] = {Core = "src/games/violence-district.lua", ViolenceDistrict = true},
    ["6739698191"] = {Core = "src/games/violence-district.lua", ViolenceDistrict = true}
}

local gameName = tostring(game.Name or ""):lower()
local isAOTRName = gameName:find("attack on titan") ~= nil and gameName:find("revolution") ~= nil
-- A known place/game id wins. The AOT:R name check is a documented fallback for
-- its newer universe. Any other game falls back to the universal backend, which
-- is built to run anywhere (movement, ESP, aim, chat, server hop) instead of
-- leaving the player with an empty window. Set env.__DEPHUB_DISABLE_UNIVERSAL
-- to true to opt out and get the plain "unsupported" state instead.
local knownTarget = targets[placeId] or targets[gameId] or (isAOTRName and {Core = "src/games/aotr.lua", AOTR = true}) or nil
if not knownTarget and env.__DEPHUB_DISABLE_UNIVERSAL ~= true then
    knownTarget = {Core = "src/games/universal.lua", Universal = true}
end
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait()

-- The shell is identical for every game, so the loader only hands it the name
-- and version. Categories and tabs are the backend's job: each game fills the
-- shared shell with its own interface.
local okDemon, demonModule = loadModule("src/core/demon-ui.lua", false)
Diag:RegisterModule("src/core/demon-ui.lua")
if not okDemon or type(demonModule) ~= "table" or type(demonModule.new) ~= "function" then
    Diag:Module("src/core/demon-ui.lua", false, tostring(demonModule))
    return fail("DemonOfDarknessUI nao carregou: " .. tostring(demonModule))
end
Diag:Module("src/core/demon-ui.lua", true, "carregado")

local okWindow, window = pcall(demonModule.new, {
    Name = "DepHub",
    Version = VERSION
})
if not okWindow or type(window) ~= "table" then
    Diag:Module("demon-ui window", false, tostring(window))
    return fail("Nao foi possivel iniciar DemonOfDarknessUI: " .. tostring(window))
end
Diag:Module("demon-ui window", true, "janela criada")

env.__DEPHUB.DemonUI = window
env.__DEPHUB.UI = window

-- Fixed Dashboard tab: every game gets the same home screen, created here by
-- the loader so it exists no matter which backend (or no backend) runs. It
-- reuses the library's own dashboard builders -- CreateDashboardBanner (the
-- player greeting/avatar card plus the game/server card) and
-- CreatePerformanceDashboard (live framerate/latency/players/session metrics) --
-- so there is no game-specific code and no new UI to keep in sync. The builders
-- take the tab name, which the adapter returns on the tab record. Failures are
-- non-fatal: a dashboard that cannot be built must never stop the hub loading.
local function buildDashboardTab()
    local lib = window.Library
    if type(lib) ~= "table" or type(lib.CreateStandaloneTab) ~= "function" then
        Diag:Note("Dashboard: CreateStandaloneTab indisponivel")
        return false
    end
    local ok, tab = pcall(function() return lib:CreateStandaloneTab("Dashboard", "house") end)
    if not ok or not tab then
        Diag:Note("Dashboard: aba independente falhou: " .. tostring(tab))
        return false
    end
    pcall(function() lib:SetActiveCategory("Dashboard") end)
    local okBanner, bannerErr = pcall(function() lib:CreateDashboardBanner("Dashboard") end)
    if not okBanner then Diag:Note("Dashboard: banner falhou: " .. tostring(bannerErr)) end
    local okPerf, perfErr = pcall(function() lib:CreatePerformanceDashboard("Dashboard", "Right") end)
    if not okPerf then Diag:Note("Dashboard: metricas falharam: " .. tostring(perfErr)) end
    return okBanner and okPerf
end
local dashboardBuilt = buildDashboardTab()
Diag:Module("dashboard tab", dashboardBuilt, dashboardBuilt and "aba Dashboard criada" or "nao foi possivel montar a aba Dashboard")

-- The Debug tab and the print/warn log hooks are opt-in. They are useful for
-- development but add a tab to every game and intercept every print, so by
-- default the hub runs clean. Set env.__DEPHUB_ENABLE_DEBUG = true before
-- loading to get the tab, or call the console command `debug on` live. The
-- collector itself is always created, so backends keep instrumenting it and the
-- data is ready the moment the tab is shown -- nothing is thrown away.
local function debugEnabled()
    return env.__DEPHUB_ENABLE_DEBUG == true
end
if debugEnabled() then Diag:Install(window) end

-- Live switch: installs or removes the Debug tab and the log hooks without a
-- reload. Registered as a built-in console command on the collector.
Diag:Command("debug", function(argument)
    argument = tostring(argument or ""):lower()
    if argument == "on" or argument == "true" or argument == "1" then
        env.__DEPHUB_ENABLE_DEBUG = true
        Diag:Install(window)
        return "debug ligado (aba Debug ativa)"
    elseif argument == "off" or argument == "false" or argument == "0" then
        env.__DEPHUB_ENABLE_DEBUG = false
        Diag:Uninstall()
        return "debug desligado (aba Debug removida; coleta continua ativa)"
    end
    return "uso: debug on|off (atual: " .. tostring(debugEnabled()) .. ")"
end)

-- When the Debug tab is hidden there is no console to reach the command above,
-- so expose one global the user can call straight from the executor console to
-- bring it back: __DEPHUB_DEBUG() and __DEPHUB_DEBUG_OFF().
env.__DEPHUB_DEBUG = function()
    env.__DEPHUB_ENABLE_DEBUG = true
    local ok = Diag:Install(window)
    return ok and "aba Debug ativa" or "nao foi possivel ativar a aba Debug"
end
env.__DEPHUB_DEBUG_OFF = function()
    env.__DEPHUB_ENABLE_DEBUG = false
    Diag:Uninstall()
    return "aba Debug removida"
end

-- Unknown game with universal disabled: keep the window, tell the player the
-- place is unsupported and stop. No incompatible backend is forced on them.
if not knownTarget then
    Diag:Note("Jogo nao reconhecido: nenhum backend carregado (universal desativado).")
    pcall(function()
        local tab = window:CreateTab("Incompativel")
        if tab then
            local section = tab:CreateSection("Estado", "Left")
            if section then
                section:CreateParagraph("Jogo nao reconhecido",
                    "O DepHub nao tem suporte especifico para este lugar e o backend universal foi desativado.\nPlaceId: " .. placeId ..
                    "\nGameId: " .. gameId .. "\nPara usar o backend universal, defina env.__DEPHUB_DISABLE_UNIVERSAL = false (ou nil) e recarregue.")
            end
        end
    end)
    env.__DEPHUB.Mode = "Unsupported"
    env.__DEPHUB.Backend = nil
    env[EXECUTED_KEY] = true
    env[STATE_KEY].status = "unsupported"
    env[STATE_KEY].finishedAt = os.clock()
    log("Jogo nao reconhecido - PlaceId " .. placeId .. " / GameId " .. gameId)
    return true
end

local target = knownTarget
Diag:RegisterModule(target.Core)
local okCore, coreResult = loadModule(target.Core, false)
if not okCore then
    Diag:Module(target.Core, false, tostring(coreResult))
    return fail("Core " .. tostring(target.Core) .. " falhou: " .. tostring(coreResult))
end
local isRT3 = target.Core == "src/games/rt3.lua"
local isTSB = target.TSB == true
local isMM2 = target.MM2 == true
local isAOTR = target.AOTR == true
local isNoobPiece = target.NoobPiece == true
local isVolleyball42 = target.Volleyball42 == true
local isBloodStrike = target.BloodStrike == true
local isStealAnEgg = target.StealAnEgg == true
local isViolenceDistrict = target.ViolenceDistrict == true

if isRT3 then
    if coreResult ~= true then
        Diag:Module(target.Core, false, "retornou " .. tostring(coreResult))
        return fail("Modulo RT3 nao inicializou")
    end
    Diag:Module(target.Core, true, "carregado")
elseif type(coreResult) ~= "table" then
    Diag:Module(target.Core, false, "retornou " .. typeof(coreResult) .. " (" .. tostring(coreResult) .. ")")
    return fail("Core " .. tostring(target.Core) .. " retornou " .. typeof(coreResult) .. " (" .. tostring(coreResult) .. ")")
else
    Diag:Module(target.Core, true, "carregado")
end

env.__DEPHUB.Universal = target.Universal and coreResult or nil
env.__DEPHUB.BloxFruits = not target.Universal and not isRT3 and not isTSB and not isMM2 and not isAOTR and not isNoobPiece and not isVolleyball42 and not isBloodStrike and not isStealAnEgg and not isViolenceDistrict and coreResult or nil
env.__DEPHUB.TSB = isTSB and coreResult or nil
env.__DEPHUB.MM2 = isMM2 and coreResult or nil
env.__DEPHUB.AOTR = isAOTR and coreResult or nil
env.__DEPHUB.NoobPiece = isNoobPiece and coreResult or nil
env.__DEPHUB.Volleyball42 = isVolleyball42 and coreResult or nil
env.__DEPHUB.BloodStrike = isBloodStrike and coreResult or nil
env.__DEPHUB.StealAnEgg = isStealAnEgg and coreResult or nil
env.__DEPHUB.ViolenceDistrict = isViolenceDistrict and coreResult or nil

local backend
if target.Universal then backend = coreResult
elseif isRT3 then backend = env.__DEPHUB.Runtime
elseif isTSB then backend = coreResult
elseif isMM2 then backend = coreResult
elseif isAOTR then backend = coreResult
elseif isNoobPiece then backend = coreResult
elseif isVolleyball42 then backend = coreResult
elseif isBloodStrike then backend = coreResult
elseif isStealAnEgg then backend = coreResult
elseif isViolenceDistrict then backend = coreResult
else backend = coreResult end

-- Informational only: the shell no longer changes per game, so this label
-- simply names which backend was loaded.
env.__DEPHUB.Mode = tostring(knownTarget.Core or "Game"):match("([^/]+)%.lua$") or "Game"
env.__DEPHUB.Backend = backend

if env[STATE_KEY] ~= session then return false end

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