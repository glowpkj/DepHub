local cl_game = game
local cl_workspace = workspace
local cl_players = cl_game:GetService("Players")
local cl_localplayer = cl_players.LocalPlayer

local cl_findfirstchild = cl_game.FindFirstChild
local cl_getdescendants = cl_game.GetDescendants
local cl_isa = cl_game.IsA

local cl_task = task
local cl_spawn = cl_task.spawn
local cl_wait = cl_task.wait
local cl_cancel = cl_task.cancel

local cl_pcall = pcall
local cl_ipairs = ipairs
local cl_clear = table.clear
local cl_vector3 = Vector3.new

local cl_fireprompt = fireproximityprompt or nil

local cl_replicatedstorage = cl_game:GetService("ReplicatedStorage")
local cl_runservice = cl_game:GetService("RunService")

local eventsFolder = cl_findfirstchild(cl_replicatedstorage, "Events")
local cookFolder = eventsFolder and cl_findfirstchild(eventsFolder, "Cook")
local cookInputRemote = cookFolder and cl_findfirstchild(cookFolder, "CookInputRequested")
local cookUpdatedEvent = cookFolder and cl_findfirstchild(cookFolder, "CookUpdated")

local CookModule = {
    Enabled = false,
    FixedPosition = nil,
    IsCooking = false
}

local connections = {}
local loopThreads = {}

local function unanchorCharacter()
    local character = cl_localplayer.Character
    if not character then return end
    
    local descendants = cl_getdescendants(character)
    for i = 1, #descendants do
        local part = descendants[i]
        if cl_isa(part, "BasePart") and part.Anchored then
            part.Anchored = false
        end
    end
end

local function instantProcess(equipment, stationType)
    if not CookModule.Enabled or not equipment or not stationType or not cookInputRemote then return end

    CookModule.IsCooking = true
    unanchorCharacter()
    
    local character = cl_localplayer.Character
    local hrp = character and cl_findfirstchild(character, "HumanoidRootPart")
    if hrp then 
        CookModule.FixedPosition = hrp.CFrame 
    end

    cl_spawn(function()
        cl_pcall(function()
            cookInputRemote:FireServer("Interact", equipment, stationType)
            cl_wait(0.02)
            cookInputRemote:FireServer("CompleteTask", equipment, stationType, false)
        end)
        cl_wait(0.03)
        unanchorCharacter()
        CookModule.IsCooking = false
        CookModule.FixedPosition = nil
    end)
end

function CookModule.Start()
    if CookModule.Enabled then return end
    CookModule.Enabled = true

    connections[#connections + 1] = cl_runservice.Heartbeat:Connect(function()
        if not CookModule.Enabled then return end
        
        unanchorCharacter()

        if not CookModule.IsCooking or not CookModule.FixedPosition then return end

        local character = cl_localplayer.Character
        if not character then return end

        local root = cl_findfirstchild(character, "HumanoidRootPart")
        if root then
            if (root.Position - CookModule.FixedPosition.Position).Magnitude > 0.05 then
                root.CFrame = CookModule.FixedPosition
            end
            root.AssemblyLinearVelocity = cl_vector3(0, 0, 0)
            root.AssemblyAngularVelocity = cl_vector3(0, 0, 0)
        end

        local humanoid = cl_findfirstchild(character, "Humanoid")
        if humanoid and humanoid.PlatformStand then
            humanoid.PlatformStand = false
        end
    end)

    if cookUpdatedEvent then
        connections[#connections + 1] = cookUpdatedEvent.OnClientEvent:Connect(function(actionType, p1, p2, p3, p4)
            if not CookModule.Enabled then return end
            if actionType == "DirectToEquipment" and typeof(p1) == "Instance" then
                instantProcess(p1, p2)
            elseif actionType == "UpdateInteraction" and typeof(p2) == "Instance" and p4 == true then
                instantProcess(p2, p3)
            end
        end)
    end

    loopThreads[#loopThreads + 1] = cl_spawn(function()
        while CookModule.Enabled do
            local tempFolder = cl_findfirstchild(cl_workspace, "Temp")
            if tempFolder and not CookModule.IsCooking then
                cl_pcall(function()
                    local descendants = cl_getdescendants(tempFolder)
                    for i = 1, #descendants do
                        if not CookModule.Enabled or CookModule.IsCooking then break end
                        local desc = descendants[i]
                        if cl_isa(desc, "ProximityPrompt") and desc.Enabled and (desc.ActionText == "Cook" or desc.ObjectText == "Cook" or desc.Name == "Cook") then
                            
                            unanchorCharacter()
                            local character = cl_localplayer.Character
                            local hrp = character and cl_findfirstchild(character, "HumanoidRootPart")
                            if hrp then 
                                CookModule.FixedPosition = hrp.CFrame 
                            end
                            
                            CookModule.IsCooking = true

                            cl_pcall(function()
                                if cl_fireprompt then
                                    cl_fireprompt(desc)
                                else
                                    desc:InputHoldBegin()
                                    cl_wait(desc.HoldDuration + 0.005)
                                    desc:InputHoldEnd()
                                end
                            end)
                            
                            cl_wait(0.05)
                            unanchorCharacter()
                            CookModule.IsCooking = false
                            CookModule.FixedPosition = nil
                        end
                    end
                end)
            end
            cl_wait(0.1)
        end
    end)
end

function CookModule.Stop()
    if not CookModule.Enabled then return end
    CookModule.Enabled = false
    CookModule.IsCooking = false

    for i = 1, #connections do
        local connection = connections[i]
        if connection then
            connection:Disconnect()
        end
    end

    for i = 1, #loopThreads do
        local thread = loopThreads[i]
        if thread then
            cl_cancel(thread)
        end
    end

    cl_clear(connections)
    cl_clear(loopThreads)
    CookModule.FixedPosition = nil
    unanchorCharacter()
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
