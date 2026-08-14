local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local localPlayer = Players.LocalPlayer

local AutoDropModule = {}
AutoDropModule.Enabled = false

local dropThread = nil
local activeDrops = {}

local function processDrop(drop)
    if not AutoDropModule.Enabled or activeDrops[drop] then return end
    
    local character = localPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    activeDrops[drop] = true

    task.spawn(function()
        pcall(function()
            local touchInterest = drop:FindFirstChildOfClass("TouchInterest") or drop:FindFirstChild("TouchInterest")
            
            if touchInterest and firetouchinterest then
                firetouchinterest(hrp, drop, 0)
                task.wait(0.01)
                firetouchinterest(hrp, drop, 1)
            else
                local targetCFrame = drop:IsA("Model") and drop:GetPivot() or drop.CFrame
                if targetCFrame then
                    drop:PivotTo(hrp.CFrame)
                end
            end
        end)

        print("[Drop] Coletado com sucesso.")
        task.wait(0.1)
        activeDrops[drop] = nil
    end)
end

function AutoDropModule.Start()
    if AutoDropModule.Enabled then return end
    AutoDropModule.Enabled = true

    dropThread = task.spawn(function()
        local dropFolder = Workspace:WaitForChild("DropFolder")

        local connection = dropFolder.ChildAdded:Connect(function(child)
            if AutoDropModule.Enabled then
                processDrop(child)
            end
        end)

        while AutoDropModule.Enabled do
            pcall(function()
                local drops = dropFolder:GetChildren()
                for i = 1, #drops do
                    if not AutoDropModule.Enabled then break end
                    processDrop(drops[i])
                end
            end)
            task.wait(0.1)
        end

        if connection then connection:Disconnect() end
    end)
end

function AutoDropModule.Stop()
    if not AutoDropModule.Enabled then return end
    AutoDropModule.Enabled = false
    table.clear(activeDrops)

    if dropThread then
        pcall(function()
            if task and task.cancel then
                task.cancel(dropThread)
            else
                coroutine.close(dropThread)
            end
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