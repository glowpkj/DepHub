local game = game
local pcall = pcall
local task = task
local tostring = tostring
local getgenv = getgenv or function() return _G end

local GetService = game.GetService
local Players = GetService(game, "Players")
local localPlayer = Players.LocalPlayer

if getgenv().__DEPHUB_LOADER_EXECUTED then 
    return 
end
getgenv().__DEPHUB_LOADER_EXECUTED = true

local GAME_SCRIPTS = {
    ["119048529960596"] = "https://raw.githubusercontent.com/glowpkj/DepHub/refs/heads/main/src/games/rt3.lua"
}

local UNIVERSAL_URL = "https://githubusercontent.com"

local function fetchScript(targetUrl)
    local success, content = pcall(function()
        return game:HttpGet(targetUrl)
    end)
    if success and content and #content > 0 then
        return content
    end
    return nil
end

local function executePayload()
    local loadstring = loadstring or (getgenv and getgenv().loadstring)
    if not loadstring then return end

    local currentGameId = tostring(game.GameId)
    local targetUrl = GAME_SCRIPTS[currentGameId] or UNIVERSAL_URL
    local scriptRaw = fetchScript(targetUrl)

    if not scriptRaw and targetUrl ~= UNIVERSAL_URL then
        scriptRaw = fetchScript(UNIVERSAL_URL)
    end

    if scriptRaw then
        local executable, err = loadstring(scriptRaw)
        if executable then
            task.spawn(executable)
        end
    end
end

pcall(function()
    if localPlayer.Character then
        executePayload()
    else
        local connection
        connection = localPlayer.CharacterAdded:Connect(function()
            connection:Disconnect()
            executePayload()
        end)
    end
end)
