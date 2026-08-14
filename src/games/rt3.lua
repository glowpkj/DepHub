local game = game
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
    log("Baixando modulo: " .. path)

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

local Library = loadModule("src/ui/lib.lua")
local AutoFarm = loadModule("src/games/features/autofarm.lua")
local InstantCook = loadModule("src/games/features/instant-cook.lua")
local AutoDrop = loadModule("src/games/features/drops.lua")
local AutoFarmFriends = loadModule("src/games/features/autofarm-friends.lua")

if not Library or type(Library.new) ~= "function" then
    logWarn("Biblioteca de UI invalida ou sem Library.new. Abortando inicializacao.")
    return false
end

local okWindow, Window = pcall(function()
    return Library.new("DepHub", "Restaurant Tycoon 3", "rbxassetid://79507712997362")
end)

if not okWindow or type(Window) ~= "table" then
    logWarn("Falha ao criar janela: " .. tostring(Window))
    return false
end

local okTab, MainTab = pcall(function()
    return Window:CreateTab("Automação", nil, "Gerenciamento de rotinas automatizadas e telemetria.")
end)

if not okTab or type(MainTab) ~= "table" then
    logWarn("Falha ao criar aba principal: " .. tostring(MainTab))
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
    log("Feature registrada: " .. title)
    return true
end

addToggle("Auto Farm Geral", "Ativa o atendimento e gerenciamento automático.", AutoFarm)
addToggle("Cozimento Instantâneo", "Automatiza o processamento das tarefas de cozinha.", InstantCook)
addToggle("Auto Drop", "Coleta automaticamente os drops disponíveis.", AutoDrop)
addToggle("Auto Farm Friends", "Automatiza interações permitidas nos tycoons de amigos.", AutoFarmFriends)

if RegisteredFeatures == 0 then
    logWarn("Nenhuma feature foi registrada.")
    pcall(Window.Destroy, Window)
    return false
end

log("Restaurant Tycoon 3 inicializado com sucesso")
return true
