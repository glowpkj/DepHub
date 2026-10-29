local game = game
local task = task
local pcall = pcall
local tostring = tostring
local type = type
local print = print
local warn = warn

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

local BASE_URL = ((type(getgenv)=="function" and getgenv() or _G).__DEPHUB or {}).SourceBaseURL or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"

local function fetch(path)
    local cb = tostring((type(getgenv)=="function" and getgenv() or _G).__DEPHUB and ((type(getgenv)=="function" and getgenv() or _G).__DEPHUB or {}).SourceCacheBust or "")
    local url = BASE_URL .. path .. (cb ~= "" and ("?cb=" .. cb) or "")
    local ok, result = pcall(function()
        return game:HttpGet(url)
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
    log("Carregando modulo: " .. path)
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

    log("Modulo carregado: " .. path)
    return result
end

log("Inicializando Restaurant Tycoon 3")

local corePaths = {
    "src/core/scheduler.lua",
    "src/core/health-monitor.lua",
    "src/core/dashboard.lua",
    "src/core/runtime.lua",
    "src/core/anti-afk.lua"
}
local core = {}
for _, path in ipairs(corePaths) do
    core[path] = loadModule(path)
end

local Scheduler = core["src/core/scheduler.lua"]
local HealthMonitor = core["src/core/health-monitor.lua"]
local Dashboard = core["src/core/dashboard.lua"]
local Runtime = core["src/core/runtime.lua"]
local AntiAFK = core["src/core/anti-afk.lua"]

if not Scheduler or type(Scheduler.new) ~= "function" then
    logWarn("Scheduler indisponivel. Abortando inicializacao.")
    return false
end

if not HealthMonitor or type(HealthMonitor.new) ~= "function" then
    logWarn("Health Monitor indisponivel. Abortando inicializacao.")
    return false
end

if not Dashboard or type(Dashboard.new) ~= "function" then
    logWarn("Dashboard provider indisponivel. Abortando inicializacao.")
    return false
end

if not Runtime or type(Runtime.new) ~= "function" then
    logWarn("Runtime indisponivel. Abortando inicializacao.")
    return false
end

if not AntiAFK or type(AntiAFK.Start) ~= "function" then
    logWarn("Anti-AFK indisponivel. Abortando inicializacao.")
    return false
end

local env = type(getgenv) == "function" and getgenv() or _G
local previousRuntime = env.__DEPHUB and env.__DEPHUB.Runtime
if type(previousRuntime) == "table" and type(previousRuntime.Destroy) == "function" then
    pcall(previousRuntime.Destroy, previousRuntime)
end

local okRuntime, runtime = pcall(function()
    return Runtime.new({
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
end)

if not okRuntime or type(runtime) ~= "table" then
    logWarn("Falha criando Runtime: " .. tostring(runtime))
    return false
end

env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.Runtime = runtime
runtime.Features = {}
local destroyRuntime = runtime.Destroy
function runtime:Destroy()
    if self.Destroyed then return end
    for _, feature in pairs(self.Features) do
        local handler = feature.Toggle or feature.Set
        if type(handler) == "function" then pcall(handler, false) end
    end
    self.Features = {}
    pcall(AntiAFK.Stop)
    local handles={Scheduler=self.Scheduler,HealthMonitor=self.HealthMonitor,Dashboard=self.Dashboard,AntiAFK=AntiAFK}
    destroyRuntime(self)
    if env.__DEPHUB then
        if env.__DEPHUB.Runtime==self then env.__DEPHUB.Runtime=nil end
        for name,handle in pairs(handles) do if env.__DEPHUB[name]==handle then env.__DEPHUB[name]=nil end end
    end
    if env.__DEPHUB_DASHBOARD==handles.Dashboard then env.__DEPHUB_DASHBOARD=nil end
end
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

local okStart, startError = pcall(runtime.Start, runtime)
if not okStart then
    logWarn("Falha iniciando Runtime: " .. tostring(startError))
    AntiAFK.Stop()
    runtime:Destroy()
    return false
end

local okAntiAFK, antiAFKError = pcall(AntiAFK.Start)
if not okAntiAFK then
    logWarn("Falha iniciando Anti-AFK: " .. tostring(antiAFKError))
end

local featurePaths = {
    "src/games/features/restauranttycoon3/autofarm.lua",
    "src/games/features/restauranttycoon3/instant-cook.lua",
    "src/games/features/restauranttycoon3/drops.lua",
    "src/games/features/restauranttycoon3/autofarm-friends.lua"
}
local modules = {}
for _, path in ipairs(featurePaths) do
    modules[path] = loadModule(path)
end

local AutoFarm = modules["src/games/features/restauranttycoon3/autofarm.lua"]
local InstantCook = modules["src/games/features/restauranttycoon3/instant-cook.lua"]
local AutoDrop = modules["src/games/features/restauranttycoon3/drops.lua"]
local AutoFarmFriends = modules["src/games/features/restauranttycoon3/autofarm-friends.lua"]

local RegisteredFeatures = 0

local function registerFeature(name, module)
    if not module then
        logWarn("Feature indisponivel: " .. name)
        return false
    end

    local handler = module.Toggle or module.Set
    if type(handler) ~= "function" then
        logWarn("Feature sem Toggle/Set: " .. name)
        return false
    end

    runtime.Features[name] = module
    RegisteredFeatures = RegisteredFeatures + 1
    
local UI=(env.__DEPHUB or {}).UI
if type(UI)=="table" and type(UI.CreateTab)=="function" then
    local tabs={}
    local function dephubSection(ui, tabs, tabName, sectionName, column)
    local tab=tabs[tabName]
    if not tab then
        tab=ui:CreateTab(tabName,"All")
        tabs[tabName]=tab
    end
    if not tab then return nil end
    return tab:CreateSection(sectionName,column or "Left")
end
local function dephubNotify(ui,title,message)
    if ui and type(ui.Notify)=="function" then ui:Notify(title,message) end
end

    local farm=dephubSection(UI,tabs,"Restaurant Farm","Farm","Left")
    if farm then
        farm:CreateToggle("Auto farm",runtime.Features.AutoFarm and runtime.Features.AutoFarm.Enabled==true,function(v)
            if runtime.Features.AutoFarm then runtime.Features.AutoFarm.Toggle(v) end
        end)
        farm:CreateToggle("Farm de amigos",runtime.Features.AutoFarmFriends and runtime.Features.AutoFarmFriends.Enabled==true,function(v)
            if runtime.Features.AutoFarmFriends then runtime.Features.AutoFarmFriends.Toggle(v) end
        end)
    end
    local kitchen=dephubSection(UI,tabs,"Kitchen","Cozinha","Left")
    if kitchen then
        kitchen:CreateToggle("Cozinhar instantaneamente",runtime.Features.InstantCook and runtime.Features.InstantCook.Enabled==true,function(v)
            if runtime.Features.InstantCook then runtime.Features.InstantCook.Toggle(v) end
        end)
        kitchen:CreateToggle("Coletar drops",runtime.Features.AutoDrop and runtime.Features.AutoDrop.Enabled==true,function(v)
            if runtime.Features.AutoDrop then runtime.Features.AutoDrop.Toggle(v) end
        end)
    end
    local status=dephubSection(UI,tabs,"Status","Runtime","Left")
    if status then status:CreateParagraph("DepHub","Restaurant Tycoon 3 carregado. Os controles acionam as funções registradas no runtime.") end
end
return true
end

registerFeature("AutoFarm", AutoFarm)
registerFeature("InstantCook", InstantCook)
registerFeature("AutoDrop", AutoDrop)
registerFeature("AutoFarmFriends", AutoFarmFriends)

if RegisteredFeatures == 0 then
    logWarn("Nenhuma feature foi registrada.")
    AntiAFK.Stop()
    runtime:Destroy()
    return false
end

local snapshot = runtime:GetSnapshot()
local dashboardData = snapshot.Dashboard or {}

log("Dashboard: " .. tostring(dashboardData.GameName or "Unknown") .. " | Ping: " .. tostring(dashboardData.Ping or "Unknown") .. " ms | FPS: " .. tostring(dashboardData.FPS or "Unknown") .. " | Script: " .. tostring(dashboardData.ScriptVersion or "Unknown") .. " | Executor: " .. tostring(dashboardData.Executor or "Unknown"))
log("Runtime health: " .. tostring(snapshot.Health))
log("Restaurant Tycoon 3 inicializado com sucesso")

-- Report the RT3 runtime into the shared Debug tab. This backend has no direct
-- game-structure dependency (every module is fetched over HTTP), so its real
-- failure surface is the loader and runtime: a module that failed to fetch, a
-- feature missing its Toggle/Set contract, or a health check that went stale.
do
    local Diag=env.__DEPHUB and env.__DEPHUB.Diagnostics
    if Diag and type(Diag.Probe)=="function" then
        Diag:SetEnvironment({["RT3 features"]=tostring(RegisteredFeatures)})
        for _,path in ipairs(featurePaths) do
            Diag:RegisterModule(path)
            local loaded=modules[path]
            local hasHandler=type(loaded)=="table" and type(loaded.Toggle or loaded.Set)=="function"
            Diag:Module(path,loaded~=nil,loaded and (hasHandler and "carregado" or "sem Toggle/Set") or "ausente")
        end
        Diag:Probe("runtime.Start",runtime~=nil,runtime and "ok" or "ausente")
        Diag:Probe("Runtime.Dashboard",runtime.Dashboard~=nil,runtime.Dashboard and "ligado" or "ausente")
        Diag:Probe("Runtime.HealthMonitor",runtime.HealthMonitor~=nil,runtime.HealthMonitor and "ligado" or "ausente")
        Diag:Probe("Runtime.Scheduler",runtime.Scheduler~=nil,runtime.Scheduler and "ligado" or "ausente")
        Diag:Probe("AntiAFK",env.__DEPHUB and env.__DEPHUB.AntiAFK~=nil,env.__DEPHUB and env.__DEPHUB.AntiAFK and "ligado" or "ausente")
        Diag:Probe("Features registradas",RegisteredFeatures>0,RegisteredFeatures.." de "..#featurePaths)
        Diag:Feature("RT3.AutoFarm",function() return runtime.Features.AutoFarm and tostring(runtime.Features.AutoFarm.Enabled) or "ausente" end)
        Diag:Feature("RT3.AutoFarmFriends",function() return runtime.Features.AutoFarmFriends and tostring(runtime.Features.AutoFarmFriends.Enabled) or "ausente" end)
        Diag:Feature("RT3.InstantCook",function() return runtime.Features.InstantCook and tostring(runtime.Features.InstantCook.Enabled) or "ausente" end)
        Diag:Feature("RT3.AutoDrop",function() return runtime.Features.AutoDrop and tostring(runtime.Features.AutoDrop.Enabled) or "ausente" end)
        Diag:Feature("RT3.Health",function()
            local snap=runtime:GetSnapshot()
            return snap and tostring(snap.Health) or "sem snapshot"
        end)
        if type(Diag.Watch)=="function" then
            Diag:Watch("RT3 health",function() local snap=runtime:GetSnapshot() return snap and tostring(snap.Health) or "?" end)
            Diag:Watch("RT3 features",function()
                local n=0
                for _ in pairs(runtime.Features) do n=n+1 end
                return n
            end)
            Diag:Watch("RT3 destruido",function() return tostring(runtime.Destroyed) end)
        end
        if type(Diag.Command)=="function" then
            Diag:Command("rt3",function()
                local snap=runtime:GetSnapshot() or {}
                local data=snap.Dashboard or {}
                local names={}
                for name in pairs(runtime.Features) do names[#names+1]=name end
                table.sort(names)
                return "features="..table.concat(names,",")
                    .." health="..tostring(snap.Health)
                    .." executor="..tostring(data.Executor)
                    .." destruido="..tostring(runtime.Destroyed)
            end)
        end
    end
end

return true

