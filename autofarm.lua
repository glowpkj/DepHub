local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local AutoFarmModule = {}
AutoFarmModule.Enabled = false

local activeInteractions = {}
local farmThread = nil

local function getMyTycoon()
    local tycoonsFolder = workspace:FindFirstChild("Tycoons")
    if not tycoonsFolder then return nil end

    for _, tycoon in ipairs(tycoonsFolder:GetChildren()) do
        local playerValue = tycoon:FindFirstChild("Player")
        if playerValue then
            if playerValue:IsA("ObjectValue") and playerValue.Value == localPlayer then
                return tycoon
            elseif playerValue:IsA("StringValue") and playerValue.Value == localPlayer.Name then
                return tycoon
            end
        end
    end
    return nil
end

local function instantRemoteTrigger(prompt, sourceName)
    if not AutoFarmModule.Enabled then return end
    if activeInteractions[prompt] then return end
    
    if prompt.ActionText == "Cook" or prompt.ObjectText == "Cook" or prompt.Name == "Cook" then
        return
    end

    activeInteractions[prompt] = true
    print(string.format("[DEBUG ATIVANDO] Prompt Remoto via %s! ID: '%s' | Action: '%s'", sourceName, prompt.Name, prompt.ActionText))

    task.spawn(function()
        local success, err = pcall(function()
            if fireproximityprompt then
                fireproximityprompt(prompt)
            else
                prompt:InputHoldBegin()
                task.wait(prompt.HoldDuration + 0.01)
                prompt:InputHoldEnd()
            end
        end)
        
        if success then
            print("npc que pediu comida")
        else
            warn("[DEBUG ERRO] Falha ao disparar remotamente: " .. tostring(err))
        end
        
        task.wait(0.05)
        activeInteractions[prompt] = nil
    end)
end

function AutoFarmModule.Start()
    if AutoFarmModule.Enabled then return end
    AutoFarmModule.Enabled = true
    
    print("====================================")
    print("[SISTEMA] Monitor Remoto Ultra Forte Iniciado")
    print("====================================")

    farmThread = task.spawn(function()
        local myTycoon = nil
        while not myTycoon and AutoFarmModule.Enabled do
            myTycoon = getMyTycoon()
            if not myTycoon then
                task.wait(0.5)
            end
        end
        
        if not AutoFarmModule.Enabled or not myTycoon then return end
        
        print("[DEBUG SUCESSO] Vinculado ao Tycoon de forma remota: " .. myTycoon.Name)
        local tempFolder = workspace:WaitForChild("Temp")

        while AutoFarmModule.Enabled do
            pcall(function()
                local tempDescendants = tempFolder:GetDescendants()
                for i = 1, #tempDescendants do
                    if not AutoFarmModule.Enabled then break end
                    local desc = tempDescendants[i]
                    if desc:IsA("ProximityPrompt") and desc.Enabled then
                        instantRemoteTrigger(desc, "Pasta_Temp")
                    end
                end
            end)

            pcall(function()
                local tycoonDescendants = myTycoon:GetDescendants()
                for i = 1, #tycoonDescendants do
                    if not AutoFarmModule.Enabled then break end
                    local desc = tycoonDescendants[i]
                    if desc:IsA("ProximityPrompt") and desc.Name == "CustomerInteractPrompt" and desc.Enabled then
                        instantRemoteTrigger(desc, "Seu_Tycoon")
                    end
                end
            end)

            task.wait(0.1)
        end
    end)
end

function AutoFarmModule.Stop()
    if not AutoFarmModule.Enabled then return end
    AutoFarmModule.Enabled = false
    table.clear(activeInteractions)
    
    if farmThread then
        pcall(function()
            if task and task.cancel then
                task.cancel(farmThread)
            else
                coroutine.close(farmThread)
            end
        end)
        farmThread = nil
    end
    
    print("[SISTEMA] AutoFarm Desativado!")
end

function AutoFarmModule.ToggleAutoGive(state)
    if state then
        AutoFarmModule.Start()
    else
        AutoFarmModule.Stop()
    end
end

AutoFarmModule.Toggle = AutoFarmModule.ToggleAutoGive
AutoFarmModule.Set = AutoFarmModule.ToggleAutoGive

return AutoFarmModule