local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer

-- Verificação de segurança para os Remotes
local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
local cookFolder = eventsFolder and eventsFolder:FindFirstChild("Cook")

local cookInputRemote = cookFolder and cookFolder:WaitForChild("CookInputRequested")
local cookUpdatedEvent = cookFolder and cookFolder:WaitForChild("CookUpdated")
local tempFolder = workspace:WaitForChild("Temp")

local CookModule = {
    Enabled = false,
    FixedPosition = nil
}

local connections = {}
local loopThreads = {}

-- Função de processamento com pcall melhorado
local function instantProcess(equipment, stationType)
    if not CookModule.Enabled or not equipment or not stationType or not cookInputRemote then return end
    
    task.spawn(function()
        local success, err = pcall(function()
            cookInputRemote:FireServer("Interact", equipment, stationType)
            task.wait(0.05) -- Um delay levemente maior evita que o servidor ignore o comando
            cookInputRemote:FireServer("CompleteTask", equipment, stationType, false)
        end)
        if not success then print("[Instant Cook] Erro no Processo: " .. tostring(err)) end
    end)
end

function CookModule.Start()
    if CookModule.Enabled then return end
    CookModule.Enabled = true

    -- Trava de Posição mais suave
    local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then CookModule.FixedPosition = hrp.CFrame end

    local lockPos = RunService.Heartbeat:Connect(function()
        if CookModule.Enabled and CookModule.FixedPosition then
            local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then
                -- Em vez de forçar o CFrame toda hora, só reseta se afastar muito
                if (root.Position - CookModule.FixedPosition.Position).Magnitude > 0.5 then
                    root.CFrame = CookModule.FixedPosition
                end
                root.AssemblyLinearVelocity = Vector3.zero -- Zera a velocidade para não escorregar
            end
        end
    end)
    table.insert(connections, lockPos)

    -- Evento de Culinária
    if cookUpdatedEvent then
        local cookConn = cookUpdatedEvent.OnClientEvent:Connect(function(actionType, p1, p2, p3, p4)
            if not CookModule.Enabled then return end
            if actionType == "DirectToEquipment" and typeof(p1) == "Instance" then
                instantProcess(p1, p2)
            elseif actionType == "UpdateInteraction" and typeof(p2) == "Instance" and p4 == true then
                instantProcess(p2, p3)
            end
        end)
        table.insert(connections, cookConn)
    end

    -- Scanner de ProximityPrompt otimizado
    local scanThread = task.spawn(function()
        while CookModule.Enabled do
            pcall(function()
                for _, desc in ipairs(tempFolder:GetDescendants()) do
                    if not CookModule.Enabled then break end
                    if desc:IsA("ProximityPrompt") and desc.Enabled then
                        if desc.ActionText == "Cook" or desc.ObjectText == "Cook" then
                            -- Usa a função do executor se disponível
                            if fireproximityprompt then
                                fireproximityprompt(desc)
                            else
                                -- Fallback manual
                                desc:InputHoldBegin()
                                task.wait(desc.HoldDuration)
                                desc:InputHoldEnd()
                            end
                            task.wait(0.1)
                        end
                    end
                end
            end)
            task.wait(0.5) -- Aumentei o tempo para poupar CPU
        end
    end)
    table.insert(loopThreads, scanThread)
    
    print("[Instant Cook] Ativado com Otimizações!")
end

function CookModule.Stop()
    if not CookModule.Enabled then return end
    CookModule.Enabled = false
    for _, c in ipairs(connections) do if c then c:Disconnect() end end
    for _, t in ipairs(loopThreads) do pcall(task.cancel, t) end
    connections = {}
    loopThreads = {}
    print("[Instant Cook] Desativado.")
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
