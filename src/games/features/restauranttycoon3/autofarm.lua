local cl_game = game
local cl_workspace = workspace
local cl_players = cl_game:GetService("Players")
local cl_localplayer = cl_players.LocalPlayer

local cl_findfirstchild = cl_game.FindFirstChild
local cl_getdescendants = cl_game.GetDescendants
local cl_getchildren = cl_game.GetChildren
local cl_isa = cl_game.IsA

local cl_task = task
local cl_spawn = cl_task.spawn
local cl_wait = cl_task.wait
local cl_cancel = cl_task.cancel

local cl_pcall = pcall
local cl_clear = table.clear
local cl_vector3 = Vector3.new

local cl_fireprompt = fireproximityprompt or nil
local cl_fireclick = fireclickdetector or nil
local cl_vu = cl_game:GetService("VirtualUser")

local AutoFarmModule = {}
AutoFarmModule.Enabled = false

local activeInteractions = {}
local farmThread = nil

local function getMyTycoon()
    local tycoonsFolder = cl_findfirstchild(cl_workspace, "Tycoons")
    if not tycoonsFolder then return nil end

    local children = cl_getchildren(tycoonsFolder)
    for i = 1, #children do
        local tycoon = children[i]
        local playerValue = cl_findfirstchild(tycoon, "Player")
        if playerValue then
            if cl_isa(playerValue, "ObjectValue") and playerValue.Value == cl_localplayer then
                return tycoon
            end

            if cl_isa(playerValue, "StringValue") and tostring(playerValue.Value) == cl_localplayer.Name then
                return tycoon
            end
        end
    end

    return nil
end

local function interactWithModel(model)
    if not AutoFarmModule.Enabled or activeInteractions[model] then return end
    activeInteractions[model] = true

    cl_spawn(function()
        cl_pcall(function()
            local character = cl_localplayer.Character
            local rootPart = character and cl_findfirstchild(character, "HumanoidRootPart")
            local targetPart = model.PrimaryPart or cl_findfirstchild(model, "Part", true) or cl_findfirstchild(model, "Base", true) or cl_findfirstchild(model, "MeshPart", true)

            if rootPart and targetPart and cl_isa(targetPart, "BasePart") then
                local originalCFrame = rootPart.CFrame
                rootPart.CFrame = targetPart.CFrame * CFrame.new(cl_vector3(0, 1.5, 0))
                cl_wait(0.012)

                local detector = cl_findfirstchild(model, "ClickDetector", true) or cl_findfirstchild(targetPart, "ClickDetector")
                if detector and cl_fireclick then
                    cl_fireclick(detector)
                else
                    cl_vu:ClickButton1(cl_vector3(0, 0, 0), cl_workspace.CurrentCamera.CFrame)
                end

                cl_wait(0.01)
                rootPart.CFrame = originalCFrame
            end
        end)
        cl_wait(0.04)
        activeInteractions[model] = nil
    end)
end

local function triggerPrompt(prompt)
    if not AutoFarmModule.Enabled or activeInteractions[prompt] then return end

    local name = prompt.Name
    local action = prompt.ActionText
    local object = prompt.ObjectText

    if action == "Cook" or object == "Cook" or name == "Cook" then return end

    activeInteractions[prompt] = true

    cl_spawn(function()
        cl_pcall(function()
            local character = cl_localplayer.Character
            local rootPart = character and cl_findfirstchild(character, "HumanoidRootPart")
            local parentPart = prompt.Parent

            local originalCFrame
            local targetPart = nil

            if parentPart then
                if cl_isa(parentPart, "BasePart") then
                    targetPart = parentPart
                elseif cl_isa(parentPart, "Model") then
                    targetPart = cl_findfirstchild(parentPart, "HumanoidRootPart") or parentPart.PrimaryPart or cl_findfirstchild(parentPart, "Part", true)
                end
            end

            if rootPart and targetPart then
                originalCFrame = rootPart.CFrame
                rootPart.CFrame = targetPart.CFrame * CFrame.new(cl_vector3(0, 1.5, 0))
                cl_wait(0.012)
            end

            if cl_fireprompt then
                cl_fireprompt(prompt)
            else
                prompt:InputHoldBegin()
                cl_wait(prompt.HoldDuration + 0.01)
                prompt:InputHoldEnd()
            end

            if rootPart and originalCFrame then
                rootPart.CFrame = originalCFrame
            end
        end)

        cl_wait(0.04)
        activeInteractions[prompt] = nil
    end)
end

function AutoFarmModule.Start()
    if AutoFarmModule.Enabled then return end
    AutoFarmModule.Enabled = true

    farmThread = cl_spawn(function()
        local myTycoon

        while AutoFarmModule.Enabled do
            if not myTycoon or not myTycoon.Parent then
                myTycoon = getMyTycoon()
            end

            if myTycoon then
                cl_pcall(function()
                    local items = cl_findfirstchild(myTycoon, "Items")
                    local surface = items and cl_findfirstchild(items, "Surface")

                    if surface then
                        local surfaceDescendants = cl_getdescendants(surface)
                        for i = 1, #surfaceDescendants do
                            local desc = surfaceDescendants[i]
                            if not AutoFarmModule.Enabled then break end

                            if cl_isa(desc, "Model") and (desc.Name == "Bill" or desc.Name == "Trash") then
                                interactWithModel(desc)
                            end
                        end
                    end

                    local tycoonDescendants = cl_getdescendants(myTycoon)
                    for i = 1, #tycoonDescendants do
                        local desc = tycoonDescendants[i]
                        if not AutoFarmModule.Enabled then break end

                        if cl_isa(desc, "ProximityPrompt") and desc.Name == "CustomerInteractPrompt" and desc.Enabled then
                            triggerPrompt(desc)
                        end
                    end
                end)
            end

            cl_wait(0.08)
        end
    end)
end

function AutoFarmModule.Stop()
    if not AutoFarmModule.Enabled then return end
    AutoFarmModule.Enabled = false
    cl_clear(activeInteractions)

    if farmThread then
        cl_pcall(function()
            cl_cancel(farmThread)
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
