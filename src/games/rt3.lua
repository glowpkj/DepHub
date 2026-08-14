-- restauranty tycoon 3

local game = game
local pcall = pcall
local task = task
local getgenv = getgenv or function() return _G end

local GetService = game.GetService
local HttpService = GetService(game, "HttpService")

local function fetch(url)
    local success, content = pcall(function()
        return game:HttpGet(url)
    end)
    if success and content and #content > 0 then
        return content
    end
    return nil
end

local function loadModule(url)
    local raw = fetch(url)
    if not raw then return nil end
    local loadstring = loadstring or (getgenv and getgenv().loadstring)
    if not loadstring then return nil end
    local executable, err = loadstring(raw)
    if executable then
        return executable()
    end
    return nil
end

local Library = loadModule("https://githubusercontent.com")
local AutoFarm = loadModule("https://githubusercontent.com")
local InstantCook = loadModule("https://githubusercontent.com")

if Library then
    local Window = Library.new("DepHub", "Restaurant Tycoon 3", "rbxassetid://79507712997362")
    
    local MainTab = Window:CreateTab("Automação", nil, "Gerenciamento de rotinas automatizadas e telemetria.")

    if AutoFarm then
        MainTab:CreateToggle(
            "Auto Farm Geral", 
            "Ativa o recolhimento automático de pedidos, atendimento e limpeza do Tycoon.", 
            false, 
            function(state)
                if AutoFarm.Toggle then
                    AutoFarm.Toggle(state)
                elseif AutoFarm.Set then
                    AutoFarm.Set(state)
                end
            end
        )
    end

    if InstantCook then
        MainTab:CreateToggle(
            "Cozimento Instantâneo", 
            "Intercepta eventos remotos e finaliza o preparo de refeições instantaneamente.", 
            false, 
            function(state)
                if InstantCook.Toggle then
                    InstantCook.Toggle(state)
                elseif InstantCook.Set then
                    InstantCook.Set(state)
                end
            end
        )
    end
end
