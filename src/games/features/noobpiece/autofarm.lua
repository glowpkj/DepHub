local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")

local AutoFarm={}
AutoFarm.__index=AutoFarm

function AutoFarm.new(movement,autoAttack)
    return setmetatable({
        Player=Players.LocalPlayer,
        Movement=movement,
        AutoAttack=autoAttack,
        Enabled=false,
        Token=0,
        Target=nil,
        RangeMargin=1,
        Tolerance=0.75,
        FallbackRange=8,
        WeaponCategory="Fists"
    },AutoFarm)
end

function AutoFarm:_character()
    local character=self.Player.Character
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    local root=character and character:FindFirstChild("HumanoidRootPart")

    if not character or not humanoid or humanoid.Health<=0 or not root then
        return nil
    end

    return root
end

function AutoFarm:_weapon()
    local character=self.Player.Character
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    if not character or not humanoid then return nil end

    local equipped=character:FindFirstChildOfClass("Tool")
    if equipped and equipped:GetAttribute("StatCategory")==self.WeaponCategory then
        return equipped
    end

    local backpack=self.Player:FindFirstChildOfClass("Backpack")
    if not backpack then return nil end

    for _,tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and tool:GetAttribute("StatCategory")==self.WeaponCategory then
            pcall(humanoid.EquipTool,humanoid,tool)
            return tool
        end
    end

    return nil
end

function AutoFarm:_range()
    local tool=self:_weapon()
    local range=tool and tool:GetAttribute("Range")

    if typeof(range)=="number" then
        return range
    end

    return self.FallbackRange
end

function AutoFarm:SetWeaponCategory(category)
    if category~="Fists" and category~="Sword" then
        return false
    end

    self.WeaponCategory=category
    return true
end

function AutoFarm:GetWeaponCategory()
    return self.WeaponCategory
end

function AutoFarm:_folder()
    local quests=Workspace:FindFirstChild("Quests")
    return quests and quests:FindFirstChild("Enemies")
end

function AutoFarm:_valid(model)
    if not model or model.Name~="Noob" then return false end

    local folder=self:_folder()
    if not folder or not model:IsDescendantOf(folder) then return false end

    local humanoid=model:FindFirstChildOfClass("Humanoid")
    local root=model:FindFirstChild("HumanoidRootPart")

    return humanoid~=nil and humanoid.Health>0 and root~=nil
end

function AutoFarm:_nearest(root)
    local folder=self:_folder()
    if not folder then return nil end

    local nearest
    local nearestDistance=math.huge

    for _,object in ipairs(folder:GetDescendants()) do
        if object:IsA("Model") and object.Name=="Noob" and self:_valid(object) then
            local enemyRoot=object:FindFirstChild("HumanoidRootPart")
            local distance=(root.Position-enemyRoot.Position).Magnitude

            if distance<nearestDistance then
                nearest=object
                nearestDistance=distance
            end
        end
    end

    return nearest
end

function AutoFarm:_face(root,enemyRoot)
    local target=Vector3.new(enemyRoot.Position.X,root.Position.Y,enemyRoot.Position.Z)

    if (target-root.Position).Magnitude>0.01 then
        root.CFrame=CFrame.lookAt(root.Position,target)
    end
end

function AutoFarm:_goal(root,enemyRoot,range)
    local desired=math.max(0.5,range-self.RangeMargin)
    local position=enemyRoot.Position-enemyRoot.CFrame.LookVector*desired
    position=Vector3.new(position.X,enemyRoot.Position.Y,position.Z)

    return CFrame.lookAt(
        position,
        Vector3.new(enemyRoot.Position.X,position.Y,enemyRoot.Position.Z)
    ),desired
end

function AutoFarm:_run(token)
    self.AutoAttack:SetFarmEnabled(true)

    while self.Enabled and token==self.Token do
        local root=self:_character()

        if not root then
            self.Target=nil
            task.wait(0.25)
            continue
        end

        if not self:_valid(self.Target) then
            self.Target=self:_nearest(root)
        end

        local target=self.Target

        if not target then
            task.wait(0.15)
            continue
        end

        local enemyRoot=target:FindFirstChild("HumanoidRootPart")

        if not enemyRoot then
            self.Target=nil
            continue
        end

        local range=self:_range()
        local goal=self:_goal(root,enemyRoot,range)
        local goalDistance=(root.Position-goal.Position).Magnitude

        if goalDistance>self.Tolerance then
            self.Movement:FlyTo(goal)
        else
            self:_face(root,enemyRoot)
            task.wait(0.03)
        end
    end

    if token==self.Token then
        self.Target=nil
        self.AutoAttack:SetFarmEnabled(false)
    end
end

function AutoFarm:SetEnabled(enabled)
    enabled=enabled==true
    if self.Enabled==enabled then return end

    self.Enabled=enabled
    self.Token+=1

    if enabled then
        local token=self.Token
        task.spawn(function()
            self:_run(token)
        end)
    else
        self.Target=nil
        self.AutoAttack:SetFarmEnabled(false)

        if self.Movement then
            self.Movement:Stop()
        end
    end
end

function AutoFarm:Destroy()
    self:SetEnabled(false)
end

return AutoFarm
