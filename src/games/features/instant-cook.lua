local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer

local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
local cookFolder = eventsFolder and eventsFolder:FindFirstChild("Cook")
local cookInputRemote = cookFolder and cookFolder:FindFirstChild("CookInputRequested")
local cookUpdatedEvent = cookFolder and cookFolder:FindFirstChild("CookUpdated")

local CookModule = {
    Enabled = false,
    FixedPosition = nil
}

local connections = {}
local loopThreads = {}

local function instantProcess(equipment, stationType)
    if not CookModule.Enabled or not equipment or not stationType or not cookInputRemote then return end

    task.spawn(function()
        pcall(function()
            cookInputRemote:FireServer("Interact", equipment, stationType)
            task.wait(0.05)
            cookInputRemote:FireServer("CompleteTask", equipment, stationType, false)
        end)
    end)
end

function CookModule.Start()
    if CookModule.Enabled then return end
    CookModule.Enabled = true

    local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then CookModule.FixedPosition = hrp.CFrame end

    table.insert(connections, RunService.Heartbeat:Connect(function()
        if not CookModule.Enabled or not CookModule.FixedPosition then return end

        local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            if (root.Position - CookModule.FixedPosition.Position).Magnitude > 0.5 then
                root.CFrame = CookModule.FixedPosition
            end
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end))

    if cookUpdatedEvent then
        table.insert(connections, cookUpdatedEvent.OnClientEvent:Connect(function(actionType, p1, p2, p3, p4)
            if not CookModule.Enabled then return end
            if actionType == "DirectToEquipment" and typeof(p1) == "Instance" then
                instantProcess(p1, p2)
            elseif actionType == "UpdateInteraction" and typeof(p2) == "Instance" and p4 == true then
                instantProcess(p2, p3)
            end
        end))
    end

    loopThreads[#loopThreads + 1] = task.spawn(function()
        while CookModule.Enabled do
            local tempFolder = workspace:FindFirstChild("Temp")
            if tempFolder then
                pcall(function()
                    for _, desc in ipairs(tempFolder:GetDescendants()) do
                        if not CookModule.Enabled then break end
                        if desc:IsA("ProximityPrompt") and desc.Enabled and (desc.ActionText == "Cook" or desc.ObjectText == "Cook") then
                            pcall(function()
                                if fireproximityprompt then
                                    fireproximityprompt(desc)
                                else
                                    desc:InputHoldBegin()
                                    task.wait(desc.HoldDuration)
                                    desc:InputHoldEnd()
                                end
                            end)
                            task.wait(0.1)
                        end
                    end
                end)
            end
            task.wait(0.5)
        end
    end)
end

function CookModule.Stop()
    if not CookModule.Enabled then return end
    CookModule.Enabled = false

    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    for _, thread in ipairs(loopThreads) do
        pcall(function()
            task.cancel(thread)
        end)
    end

    connections = {}
    loopThreads = {}
    CookModule.FixedPosition = nil
end

function CookModule.Toggle(state)
    if state then
        CookModule.Start()
    else
        CookModule.Stop()
    end
end

CookModule.Set = CookModule.Toggle

return CookModule
