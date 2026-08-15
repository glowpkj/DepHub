local game = game
local task = task
local pcall = pcall
local tostring = tostring
local type = type
local print = print
local warn = warn
local os_clock = os.clock

local function log(message)
    pcall(print, "[DEPHUB RT3] " .. tostring(message))
end

local function logWarn(message)
    pcall(warn, "[DEPHUB RT3] " .. tostring(message))
end

local compiler = loadstring
if type(compiler) ~= "function" then
    logWarn("loadstring indisponivel.")
    return false
end

local BASE_URL = "https://raw.githubusercontent.com/glowpkj/DepHub/main/"

local function fetch(path)
    local url = BASE_URL .. path
    local cacheBust = "?dephub=" .. tostring(math.floor(os_clock() * 1000000))
    local ok, result = pcall(function()
        return game:HttpGet(url .. cacheBust)
    end)

    if ok and type(result) == "string" and #result > 0 then
        return true, result, url
    end

    if not ok then
        return false, tostring(result), url
    end

    return false, "Resposta vazia", url
end

local function loadModule(path)
    local okFetch, raw, url = fetch(path)
    if not okFetch then
        logWarn("Falha no modulo " .. path .. ": " .. tostring(raw))
        return nil
    end

    local okCompile, chunk, compileError = pcall(compiler, raw)
    if not okCompile then
        logWarn("Erro compilando " .. path .. ": " .. tostring(chunk))
        return nil
    end

    if type(chunk) ~= "function" then
        logWarn("Codigo invalido em " .. path .. ": " .. tostring(compileError))
        return nil
    end

    local okRun, result = pcall(chunk)
    if not okRun then
        logWarn("Erro executando " .. path .. ": " .. tostring(result))
        return nil
    end

    return result
end

local function loadModules(paths)
    local results = {}
    local remaining = #paths

    for _, path in ipairs(paths) do
        task.spawn(function()
            results[path] = loadModule(path)
            remaining = remaining - 1
        end)
    end

    while remaining > 0 do
        task.wait()
    end

    return results
end

log("Inicializando Restaurant Tycoon 3")

local Loading = loadModule("src/ui/loading.lua")
local loading
if Loading and type(Loading.new) == "function" then
    loading = Loading.new({
        Title = "DEPHUB",
        Status = "Preparando inicialização...",
        LogoId = "rbxassetid://79507712997362"
    })
    loading:SetProgress(0.06, "Preparando inicialização...")
end

local core = loadModules({
    "src/core/scheduler.lua",
    "src/core/health-monitor.lua",
    "src/core/dashboard.lua",
    "src/core/runtime.lua",
    "src/core/anti-afk.lua"
})

local Scheduler = core["src/core/scheduler.lua"]
local HealthMonitor = core["src/core/health-monitor.lua"]
local Dashboard = core["src/core/dashboard.lua"]
local Runtime = core["src/core/runtime.lua"]
local AntiAFK = core["src/core/anti-afk.lua"]

if loading then
    loading:SetProgress(0.28, "Núcleo carregado...")
end

if not Scheduler or type(Scheduler.new) ~= "function" then
    logWarn("Scheduler indisponivel. Abortando inicializacao.")
    if loading then loading:Destroy() end
    return false
end

if not HealthMonitor or type(HealthMonitor.new) ~= "function" then
    logWarn("Health Monitor indisponivel. Abortando inicializacao.")
    if loading then loading:Destroy() end
    return false
end

if not Dashboard or type(Dashboard.new) ~= "function" then
    logWarn("Dashboard provider indisponivel. Abortando inicializacao.")
    if loading then loading:Destroy() end
    return false
end

if not Runtime or type(Runtime.new) ~= "function" then
    logWarn("Runtime indisponivel. Abortando inicializacao.")
    if loading then loading:Destroy() end
    return false
end

if not AntiAFK or type(AntiAFK.Start) ~= "function" then
    logWarn("Anti-AFK indisponivel. Abortando inicializacao.")
    if loading then loading:Destroy() end
    return false
end

local env = type(getgenv) == "function" and getgenv() or _G
local previousRuntime = env.__DEPHUB and env.__DEPHUB.Runtime
if type(previousRuntime) == "table" and type(previousRuntime.Destroy) == "function" then
    pcall(previousRuntime.Destroy, previousRuntime)
end

local runtime = Runtime.new({
    Scheduler = Scheduler,
    HealthMonitor = HealthMonitor,
    Dashboard = Dashboard,
    SchedulerOptions = {
        DefaultInterval = 0.1,
        MaxErrors = 5
    },
    HealthOptions = {
        Interval = 2,
        MaxErrors = 5
    },
    DashboardOptions = {
        Interval = 1,
        ManifestInterval = 30
    }
})

env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.Runtime = runtime
env.__DEPHUB.Scheduler = runtime.Scheduler
env.__DEPHUB.HealthMonitor = runtime.HealthMonitor
env.__DEPHUB.Dashboard = runtime.Dashboard
env.__DEPHUB.AntiAFK = AntiAFK

env.__DEPHUB_DASHBOARD = runtime.Dashboard

runtime.HealthMonitor:Register("Dashboard", function()
    local data = runtime.Dashboard and runtime.Dashboard:Get()
    return type(data) == "table" and data.GameId ~= nil
end)

runtime.HealthMonitor:Register("Runtime", function()
    return not runtime.Destroyed
end)

runtime:Start()
AntiAFK.Start()

if loading then
    loading:SetProgress(0.42, "Runtime e dashboard iniciados...")
end

local modules = loadModules({
    "src/ui/init.lua",
    "src/games/features/autofarm.lua",
    "src/games/features/instant-cook.lua",
    "src/games/features/drops.lua",
    "src/games/features/autofarm-friends.lua"
})

local Library = modules["src/ui/init.lua"]
local AutoFarm = modules["src/games/features/autofarm.lua"]
local InstantCook = modules["src/games/features/instant-cook.lua"]
local AutoDrop = modules["src/games/features/drops.lua"]
local AutoFarmFriends = modules["src/games/features/autofarm-friends.lua"]

if loading then
    loading:SetProgress(0.68, "Interface e automações carregadas...")
end

if not Library or type(Library.new) ~= "function" then
    logWarn("Biblioteca de UI invalida ou sem Library.new. Abortando inicializacao.")
    AntiAFK.Stop()
    runtime:Destroy()
    if loading then loading:Destroy() end
    return false
end

local okWindow, Window = pcall(function()
    return Library.new("DepHub", "Restaurant Tycoon 3", "rbxassetid://79507712997362")
end)

if not okWindow or type(Window) ~= "table" then
    logWarn("Falha ao criar janela: " .. tostring(Window))
    AntiAFK.Stop()
    runtime:Destroy()
    if loading then loading:Destroy() end
    return false
end

local okTab, MainTab = pcall(function()
    return Window:CreateTab("Automação", nil, "Gerenciamento de rotinas automatizadas e telemetria.")
end)

if not okTab or type(MainTab) ~= "table" then
    logWarn("Falha ao criar aba principal: " .. tostring(MainTab))
    pcall(Window.Destroy, Window)
    AntiAFK.Stop()
    runtime:Destroy()
    if loading then loading:Destroy() end
    return false
end

local RegisteredFeatures = 0

local function addToggle(title, description, module)
    if not module then
        logWarn("Feature indisponivel: " .. title)
        return false
    end

    local handler = module.Toggle or module.Set
    if type(handler) ~= "function" then
        logWarn("Feature sem Toggle/Set: " .. title)
        return false
    end

    local ok, err = pcall(function()
        MainTab:CreateToggle(title, description, false, function(state)
            local success, executionError = pcall(handler, state)
            if not success then
                logWarn("Erro em " .. title .. ": " .. tostring(executionError))
            end
        end)
    end)

    if not ok then
        logWarn("Falha ao registrar " .. title .. ": " .. tostring(err))
        return false
    end

    RegisteredFeatures = RegisteredFeatures + 1
    return true
end

addToggle("Auto Farm Geral", "Ativa o atendimento e gerenciamento automático.", AutoFarm)
addToggle("Cozimento Instantâneo", "Automatiza o processamento das tarefas de cozinha.", InstantCook)
addToggle("Auto Drop", "Coleta automaticamente os drops disponíveis.", AutoDrop)
addToggle("Auto Farm Friends", "Automatiza interações permitidas nos tycoons de amigos.", AutoFarmFriends)

if RegisteredFeatures == 0 then
    logWarn("Nenhuma feature foi registrada.")
    pcall(Window.Destroy, Window)
    AntiAFK.Stop()
    runtime:Destroy()
    if loading then loading:Destroy() end
    return false
end

local dashboardData = runtime.Dashboard:Get()
if Window.DashboardStats then
    Window.DashboardStats.Ping:SetValue(dashboardData and dashboardData.Ping and tostring(dashboardData.Ping) .. " ms" or "--")
end

local lastReleaseVersion = dashboardData and dashboardData.ScriptVersion or nil
runtime.Dashboard.OnUpdate = function(data)
    if not Window or Window.Destroyed then
        return
    end

    if Window.DashboardStats then
        Window.DashboardStats.Ping:SetValue(data.Ping and tostring(data.Ping) .. " ms" or "--")
        if data.ScriptVersion then
            Window.DashboardStats.Version:SetValue(data.ScriptVersion)
        end
    end

    if data.ScriptVersion and data.ScriptVersion ~= lastReleaseVersion then
        lastReleaseVersion = data.ScriptVersion
        if data.RecentUpdates then
            Window:SetReleases(data.RecentUpdates)
        end
    end
end

if dashboardData and dashboardData.RecentUpdates then
    Window:SetReleases(dashboardData.RecentUpdates)
end

local snapshot = runtime:GetSnapshot()
dashboardData = snapshot.Dashboard or dashboardData or {}

log("Dashboard: " .. tostring(dashboardData.GameName or "Unknown") .. " | Ping: " .. tostring(dashboardData.Ping or "Unknown") .. " ms | FPS: " .. tostring(dashboardData.FPS or "Unknown") .. " | Script: " .. tostring(dashboardData.ScriptVersion or "Unknown") .. " | Executor: " .. tostring(dashboardData.Executor or "Unknown"))
log("Runtime health: " .. tostring(snapshot.Health))
log("Restaurant Tycoon 3 inicializado com sucesso")

if loading then
    loading:Complete("Inicialização concluída")
end

return true
