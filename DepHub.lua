local game = game
local pcall = pcall
local task = task
local tostring = tostring
local string = string
local getgenv = getgenv or function() return _G end

local GetService = game.GetService
local Players = GetService(game, "Players")
local localPlayer = Players.LocalPlayer

local rprint = rconsoleprint or print

local function debugLog(message)
    pcall(function()
        rprint("[DEPHUB DEBUG] " .. tostring(message) .. "\n")
    end)
end

if getgenv().__DEPHUB_LOADER_EXECUTED then 
    debugLog("Abortado: Loader ja foi executado nesta sessao.")
    return 
end
getgenv().__DEPHUB_LOADER_EXECUTED = true

local GAME_SCRIPTS = {
    ["119048529960596"] = "https://raw.githubusercontent.com/glowpkj/DepHub/refs/heads/main/src/games/rt3.lua"
}

local UNIVERSAL_URL = "https://githubusercontent.com"

local function fetchScript(targetUrl)
    debugLog("Requisitando URL: " .. tostring(targetUrl))
    local success, content = pcall(function()
        return game:HttpGet(targetUrl)
    end)
    if success and content and #content > 0 then
        debugLog("Download concluido com sucesso (" .. #content .. " bytes).")
        return content
    end
    debugLog("Falha no download da URL informada.")
    return nil
end

local function executePayload()
    local loadstring = loadstring or (getgenv and getgenv().loadstring)
    if not loadstring then 
        debugLog("Erro Fatal: Executor nao suporta 'loadstring'.")
        return 
    end

    local currentPlaceId = tostring(game.PlaceId)
    local currentGameId = tostring(game.GameId)
    
    debugLog("Identificadores locais - PlaceId: " .. currentPlaceId .. " | GameId: " .. currentGameId)

    local targetUrl = GAME_SCRIPTS[currentPlaceId] or GAME_SCRIPTS[currentGameId] or UNIVERSAL_URL
    debugLog("Rota selecionada para o ambiente atual: " .. (GAME_SCRIPTS[currentPlaceId] and "Especifica por PlaceId" or GAME_SCRIPTS[currentGameId] and "Especifica por GameId" or "Failsafe Universal"))

    local scriptRaw = fetchScript(targetUrl)

    if not scriptRaw and targetUrl ~= UNIVERSAL_URL then
        debugLog("Iniciando desvio de emergencia para o Script Universal.")
        scriptRaw = fetchScript(UNIVERSAL_URL)
    end

    if scriptRaw then
        debugLog("Compilando bytecode via loadstring...")
        local executable, err = loadstring(scriptRaw)
        if executable then
            debugLog("Injetando thread principal de execucao...")
            task.spawn(function()
                local executionSuccess, executionError = pcall(executable)
                if not executionSuccess then
                    debugLog("Erro em tempo de execucao do script principal: " .. tostring(executionError))
                end
            end)
        else
            debugLog("Erro de compilacao no script: " .. tostring(err))
        end
    else
        debugLog("Erro Fatal: Nenhum codigo fonte valido foi recuperado.")
    end
end

pcall(function()
    debugLog("Loader inicializado. Monitorando carregamento do Character...")
    if localPlayer.Character then
        debugLog("Character detectado imediatamente.")
        executePayload()
    else
        debugLog("Aguardando evento CharacterAdded...")
        local connection
        connection = localPlayer.CharacterAdded:Connect(function()
            connection:Disconnect()
            debugLog("CharacterAdded disparado.")
            executePayload()
        end)
    end
end)
