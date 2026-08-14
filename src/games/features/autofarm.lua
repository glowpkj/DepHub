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

local function triggerPrompt(prompt)
    if not AutoFarmModule.Enabled or activeInteractions[prompt] then return end
    if prompt.ActionText == "Cook" or prompt.ObjectText == "Cook" or prompt.Name == "Cook" then return end

    activeInteractions[prompt] = true

    task.spawn(function()
        pcall(function()
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

function AutoFarmModule.Start()
    if AutoFarmModule.Enabled then return end
    AutoFarmModule.Enabled = true

    farmThread = task.spawn(function()
        local myTycoon
        local tempFolder

        while AutoFarmModule.Enabled do
            if not myTycoon or not myTycoon.Parent then
                myTycoon = getMyTycoon()
            end

            if not tempFolder or not tempFolder.Parent then
                tempFolder = workspace:FindFirstChild("Temp")
            end

            if myTycoon then
                pcall(function()
                    for _, desc in ipairs(myTycoon:GetDescendants()) do
                        if not AutoFarmModule.Enabled then break end
                        if desc:IsA("ProximityPrompt") and desc.Name == "CustomerInteractPrompt" and desc.Enabled then
                            triggerPrompt(desc)
                        end
                    end
                end)
            end

            if tempFolder then
                pcall(function()
                    for _, desc in ipairs(tempFolder:GetDescendants()) do
                        if not AutoFarmModule.Enabled then break end
                        if desc:IsA("ProximityPrompt") and desc.Enabled then
                            triggerPrompt(desc)
                        end
                    end
                end)
            end

            task.wait(0.15)
        end
    end)
end

function AutoFarmModule.Stop()
    if not AutoFarmModule.Enabled then return end
    AutoFarmModule.Enabled = false
    table.clear(activeInteractions)

    if farmThread then
        pcall(function()
            task.cancel(farmThread)
        end)
        farmThread = nil
    end
end

function AutoFarmModule.Toggle(state)
    if state then
        AutoFarmModule.Start()
    else
        AutoFarmModule.Stop()
    end
end

AutoFarmModule.Set = AutoFarmModule.Toggle

return AutoFarmModule
