local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")

local AutoAttack={}
AutoAttack.__index=AutoAttack

function AutoAttack.new()
    local self=setmetatable({
        Player=Players.LocalPlayer,
        Remote=ReplicatedStorage:WaitForChild("Events"):WaitForChild("PlayerAttack"),
        Enabled=false,
        RangeCheck=true,
        Interval=0.05,
        FallbackRange=8,
        Token=0,
        Enemies={},
        Connections={}
    },AutoAttack)

    self:_bindEnemies()
    return self
end

function AutoAttack:_enemyFolder()
    local quests=Workspace:FindFirstChild("Quests")
    return quests and quests:FindFirstChild("Enemies")
end

function AutoAttack:_register(object)
    local model

    if object:IsA("Model") then
        model=object
    elseif object:IsA("Humanoid") or object.Name=="HumanoidRootPart" then
        model=object.Parent
    end

    if model and model:IsA("Model") then
        self.Enemies[model]=true
    end
end

function AutoAttack:_bindEnemies()
    local folder=self:_enemyFolder()
    if not folder then
        local quests=Workspace:FindFirstChild("Quests")
        if quests then
            self.Connections[#self.Connections+1]=quests.ChildAdded:Connect(function(child)
                if child.Name=="Enemies" then
                    self:_bindEnemies()
                end
            end)
        end
        return
    end

    for _,object in ipairs(folder:GetDescendants()) do
        self:_register(object)
    end

    self.Connections[#self.Connections+1]=folder.DescendantAdded:Connect(function(object)
        self:_register(object)
    end)

    self.Connections[#self.Connections+1]=folder.DescendantRemoving:Connect(function(object)
        if object:IsA("Model") then
            self.Enemies[object]=nil
        end
    end)
end

function AutoAttack:_character()
    local character=self.Player.Character
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    local root=character and character:FindFirstChild("HumanoidRootPart")

    if not character or not humanoid or humanoid.Health<=0 or not root then
        return nil
    end

    return character,root
end

function AutoAttack:_range(character)
    local tool=character:FindFirstChildOfClass("Tool")
    local range=tool and tool:GetAttribute("Range")

    if typeof(range)=="number" then
        return range
    end

    return self.FallbackRange
end

function AutoAttack:_enemyInRange(root,range)
    local folder=self:_enemyFolder()
    if not folder then return false end

    for model in pairs(self.Enemies) do
        if not model.Parent or not model:IsDescendantOf(folder) then
            self.Enemies[model]=nil
        else
            local humanoid=model:FindFirstChildOfClass("Humanoid")
            local enemyRoot=model:FindFirstChild("HumanoidRootPart")

            if humanoid and humanoid.Health>0 and enemyRoot then
                if (root.Position-enemyRoot.Position).Magnitude<=range then
                    return true
                end
            end
        end
    end

    return false
end

function AutoAttack:_run(token)
    while self.Enabled and token==self.Token do
        local character,root=self:_character()

        if character and root then
            local canAttack=true

            if self.RangeCheck then
                canAttack=self:_enemyInRange(root,self:_range(character))
            end

            if canAttack then
                self.Remote:FireServer(1)
            end
        end

        task.wait(self.Interval)
    end
end

function AutoAttack:SetEnabled(enabled)
    enabled=enabled==true
    if self.Enabled==enabled then return end

    self.Enabled=enabled
    self.Token+=1

    if enabled then
        local token=self.Token
        task.spawn(function()
            self:_run(token)
        end)
    end
end

function AutoAttack:SetRangeCheck(enabled)
    self.RangeCheck=enabled==true
end

function AutoAttack:Destroy()
    self:SetEnabled(false)

    for _,connection in ipairs(self.Connections) do
        pcall(connection.Disconnect,connection)
    end

    table.clear(self.Connections)
    table.clear(self.Enemies)
end

return AutoAttack
