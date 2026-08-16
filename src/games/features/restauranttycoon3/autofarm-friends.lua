local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local AutoFarmFriendsModule = {}
AutoFarmFriendsModule.Enabled = false

local activeInteractions = {}
local farmThread = nil

local friendList = {}
local lastFriendUpdate = 0

local function updateFriendsList()
    local currentTime = tick()
    if currentTime - lastFriendUpdate < 30 then return end
    
    table.clear(friendList)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            pcall(function()
                if localPlayer:IsFriendsWith(player.UserId) then
                    friendList[player.Name] = true
                end
            end)
        end
    end
    lastFriendUpdate = currentTime
end

local function getFriendTycoons()
    local tycoonsFolder = workspace:FindFirstChild("Tycoons")
    if not tycoonsFolder then return {} end

    local friendTycoons = {}

    for _, tycoon in ipairs(tycoonsFolder:GetChildren()) do
        local playerValue = tycoon:FindFirstChild("Player")
        if playerValue then
            local ownerName = nil
            if playerValue:IsA("ObjectValue") and playerValue.Value then
                ownerName = playerValue.Value.Name
            elseif playerValue:IsA("StringValue") and playerValue.Value ~= "" then
                ownerName = playerValue.Value
            end

            if ownerName and friendList[ownerName] then
                table.insert(friendTycoons, tycoon)
            end
        end
    end

    return friendTycoons
end

local function instantRemoteTrigger(prompt, sourceName)
    if not AutoFarmFriendsModule.Enabled then return end
    if activeInteractions[prompt] then return end
    
    if prompt.ActionText == "Cook" or prompt.ObjectText == "Cook" or prompt.Name == "Cook" then
        return
    end

    activeInteractions[prompt] = true

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
        
        task.wait(0.05)
        activeInteractions[prompt] = nil
    end)
end

function AutoFarmFriendsModule.Start()
    if AutoFarmFriendsModule.Enabled then return end
    AutoFarmFriendsModule.Enabled = true

    updateFriendsList()

    farmThread = task.spawn(function()
        local tempFolder = workspace:WaitForChild("Temp")

        while AutoFarmFriendsModule.Enabled do
            updateFriendsList()

            -- 1. Varredura nos Tycoons de Amigos (Apenas CustomerInteractPrompt)
            pcall(function()
                local friendTycoons = getFriendTycoons()
                for _, tycoon in ipairs(friendTycoons) do
                    if not AutoFarmFriendsModule.Enabled then break end
                    local tycoonDescendants = tycoon:GetDescendants()
                    for i = 1, #tycoonDescendants do
                        if not AutoFarmFriendsModule.Enabled then break end
                        local desc = tycoonDescendants[i]
                        if desc:IsA("ProximityPrompt") and desc.Name == "CustomerInteractPrompt" and desc.Enabled then
                            instantRemoteTrigger(desc, "Tycoon_Amigo")
                        end
                    end
                end
            end)

            -- 2. Varredura Remota na pasta Temp (Prompts Globais)
            pcall(function()
                local tempDescendants = tempFolder:GetDescendants()
                for i = 1, #tempDescendants do
                    if not AutoFarmFriendsModule.Enabled then break end
                    local desc = tempDescendants[i]
                    if desc:IsA("ProximityPrompt") and desc.Enabled then
                        instantRemoteTrigger(desc, "Pasta_Temp")
                    end
                end
            end)

            task.wait(0.1)
        end
    end)
    print("[Auto Farm Friends] Ativado com Sucesso!")
end

function AutoFarmFriendsModule.Stop()
    if not AutoFarmFriendsModule.Enabled then return end
    AutoFarmFriendsModule.Enabled = false
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

    print("[Auto Farm Friends] Desativado!")
end

function AutoFarmFriendsModule.Toggle(state)
    if state then
        AutoFarmFriendsModule.Start()
    else
        AutoFarmFriendsModule.Stop()
    end
end

AutoFarmFriendsModule.Set = AutoFarmFriendsModule.Toggle

return AutoFarmFriendsModule