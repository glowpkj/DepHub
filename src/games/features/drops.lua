local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local localPlayer = Players.LocalPlayer

local AutoDropModule = {}
AutoDropModule.Enabled = false

local dropThread = nil
local dropConnection = nil
local activeDrops = {}

local function processDrop(drop)
    if not AutoDropModule.Enabled or activeDrops[drop] then return end

    local character = localPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    activeDrops[drop] = true

    task.spawn(function()
        pcall(function()
            local touchInterest = drop:FindFirstChildOfClass("TouchInterest") or drop:FindFirstChild("TouchInterest")
            if touchInterest and firetouchinterest then
                firetouchinterest(hrp, drop, 0)
                task.wait(0.01)
                firetouchinterest(hrp, drop, 1)
            elseif drop:IsA("Model") then
                drop:PivotTo(hrp.CFrame)
            elseif drop:IsA("BasePart") then
                drop.CFrame = hrp.CFrame
            end
        end)

        task.wait(0.1)
        activeDrops[drop] = nil
    end)
end

function AutoDropModule.Start()
    if AutoDropModule.Enabled then return end
    AutoDropModule.Enabled = true

    dropThread = task.spawn(function()
        while AutoDropModule.Enabled do
            local dropFolder = Workspace:FindFirstChild("DropFolder")

            if dropFolder then
                if not dropConnection then
                    dropConnection = dropFolder.ChildAdded:Connect(function(child)
                        if AutoDropModule.Enabled then
                            processDrop(child)
                        end
                    end)
                end

                pcall(function()
                    for _, drop in ipairs(dropFolder:GetChildren()) do
                        if not AutoDropModule.Enabled then break end
                        processDrop(drop)
                    end
                end)
            end

            task.wait(0.15)
        end
    end)
end

function AutoDropModule.Stop()
    if not AutoDropModule.Enabled then return end
    AutoDropModule.Enabled = false
    table.clear(activeDrops)

    if dropConnection then
        pcall(function()
            dropConnection:Disconnect()
        end)
        dropConnection = nil
    end

    if dropThread then
        pcall(function()
            task.cancel(dropThread)
        end)
        dropThread = nil
    end
end

function AutoDropModule.Toggle(state)
    if state then
        AutoDropModule.Start()
    else
        AutoDropModule.Stop()
    end
end

AutoDropModule.Set = AutoDropModule.Toggle

return AutoDropModule
