local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")

local AutoFarm={}
AutoFarm.__index=AutoFarm

function AutoFarm.new(movement,autoAttack,islandData)
    return setmetatable({
        Player=Players.LocalPlayer,
        Movement=movement,
        AutoAttack=autoAttack,
        IslandData=islandData,
        Enabled=false,
        Token=0,
        Target=nil,
        RangeMargin=1,
        Tolerance=0.75,
        FallbackRange=8,
        WeaponCategory="Fists",
        SelectedEnemy="Noob",
        SelectedIsland="HomeIsland",
        EnemyCatalog={},
        OptionLookup={}
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

    if not character or not humanoid then
        return nil
    end

    local equipped=character:FindFirstChildOfClass("Tool")

    if equipped and equipped:GetAttribute("StatCategory")==self.WeaponCategory then
        return equipped
    end

    local backpack=self.Player:FindFirstChildOfClass("Backpack")

    if not backpack then
        return nil
    end

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

    if typeof(range)=="number" and range>0 then
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

function AutoFarm:_npcId(model)
    local id=model:GetAttribute("NpcId")

    if type(id)=="string" and id~="" then
        return id
    end

    return model.Name
end

function AutoFarm:_modelIsland(model)
    local folder=self:_folder()

    if not folder or not model then
        return nil
    end

    local current=model

    while current and current.Parent~=folder do
        current=current.Parent
    end

    if current and current.Parent==folder then
        return current.Name
    end

    return nil
end

function AutoFarm:_catalogKey(island,id)
    return tostring(island or "Unknown").."\0"..tostring(id)
end

function AutoFarm:_buildCatalog()
    local catalog={}
    local byKey={}

    local function add(meta)
        if type(meta.Id)~="string" or meta.Id=="" then
            return
        end

        local key=self:_catalogKey(meta.Island,meta.Id)
        local current=byKey[key]

        if not current then
            current={
                Id=meta.Id,
                Island=meta.Island or "Unknown",
                IslandOrder=meta.IslandOrder or math.huge,
                EnemyOrder=meta.EnemyOrder or math.huge,
                Boss=meta.Boss==true,
                Level=meta.Level,
                DisplayName=meta.DisplayName
            }
            byKey[key]=current
            catalog[#catalog+1]=current
            return
        end

        if typeof(meta.Level)=="number" then
            current.Level=meta.Level
        end

        if meta.Boss~=nil then
            current.Boss=meta.Boss==true
        end

        if type(meta.DisplayName)=="string" and meta.DisplayName~="" then
            current.DisplayName=meta.DisplayName
        end

        if meta.EnemyOrder and meta.EnemyOrder<current.EnemyOrder then
            current.EnemyOrder=meta.EnemyOrder
        end
    end

    if self.IslandData then
        for _,island in ipairs(self.IslandData.GetAll()) do
            for _,enemy in ipairs(island.Enemies or {}) do
                add({
                    Id=enemy.Id,
                    Island=island.Name,
                    IslandOrder=island.Order,
                    EnemyOrder=enemy.Order,
                    Boss=enemy.Boss
                })
            end
        end
    end

    local folder=self:_folder()

    if folder then
        for _,islandFolder in ipairs(folder:GetChildren()) do
            local islandData=self.IslandData and self.IslandData.Get(islandFolder.Name)

            for _,object in ipairs(islandFolder:GetDescendants()) do
                if object:IsA("Model") then
                    local id=object:GetAttribute("NpcId")
                    local hasInfo=type(id)=="string"
                        or object:GetAttribute("DisplayName")~=nil
                        or object:GetAttribute("Level")~=nil
                        or object:GetAttribute("Damage")~=nil
                        or object:GetAttribute("Boss")~=nil

                    if hasInfo then
                        add({
                            Id=self:_npcId(object),
                            Island=islandFolder.Name,
                            IslandOrder=islandData and islandData.Order or math.huge,
                            Boss=object:GetAttribute("Boss"),
                            Level=object:GetAttribute("Level"),
                            DisplayName=object:GetAttribute("DisplayName")
                        })
                    end
                end
            end
        end
    end

    table.sort(catalog,function(left,right)
        if typeof(left.Level)=="number" and typeof(right.Level)=="number" and left.Level~=right.Level then
            return left.Level<right.Level
        end

        if left.IslandOrder~=right.IslandOrder then
            return left.IslandOrder<right.IslandOrder
        end

        if left.EnemyOrder~=right.EnemyOrder then
            return left.EnemyOrder<right.EnemyOrder
        end

        return string.lower(left.Id)<string.lower(right.Id)
    end)

    self.EnemyCatalog=catalog
    return catalog
end

function AutoFarm:_option(meta)
    local value=meta.Id.." | "..meta.Island

    if meta.Boss then
        value=value.." | BOSS"
    end

    if typeof(meta.Level)=="number" then
        value=value.." | LV "..tostring(math.floor(meta.Level))
    end

    return value
end

function AutoFarm:GetEnemyTypes()
    local catalog=self:_buildCatalog()
    local values={}
    self.OptionLookup={}

    for _,meta in ipairs(catalog) do
        local option=self:_option(meta)
        values[#values+1]=option
        self.OptionLookup[option]=meta
    end

    if #values==0 then
        values[1]=self.SelectedEnemy
    end

    return values
end

function AutoFarm:_findMeta(id,island)
    for _,meta in ipairs(self.EnemyCatalog) do
        if meta.Id==id and (not island or meta.Island==island) then
            return meta
        end
    end

    return nil
end

function AutoFarm:SetSelectedEnemy(value)
    if type(value)~="string" or value=="" then
        return false
    end

    if #self.EnemyCatalog==0 then
        self:GetEnemyTypes()
    end

    local meta=self.OptionLookup[value]

    if not meta then
        meta=self:_findMeta(value)

        if not meta and self.IslandData then
            local island,enemy=self.IslandData.FindEnemy(value)

            if island and enemy then
                meta={
                    Id=enemy.Id,
                    Island=island.Name,
                    IslandOrder=island.Order,
                    EnemyOrder=enemy.Order,
                    Boss=enemy.Boss==true
                }
            end
        end
    end

    if meta then
        self.SelectedEnemy=meta.Id
        self.SelectedIsland=meta.Island
    else
        self.SelectedEnemy=value
        self.SelectedIsland=nil
    end

    self.Target=nil
    return true
end

function AutoFarm:GetSelectedEnemy()
    return self.SelectedEnemy
end

function AutoFarm:GetSelectedEnemyOption()
    self:GetEnemyTypes()
    local meta=self:_findMeta(self.SelectedEnemy,self.SelectedIsland)

    if meta then
        return self:_option(meta)
    end

    return self.SelectedEnemy
end

function AutoFarm:_valid(model)
    if not model then
        return false
    end

    local folder=self:_folder()

    if not folder or not model:IsDescendantOf(folder) then
        return false
    end

    if self:_npcId(model)~=self.SelectedEnemy then
        return false
    end

    if self.SelectedIsland and self:_modelIsland(model)~=self.SelectedIsland then
        return false
    end

    local humanoid=model:FindFirstChildOfClass("Humanoid")
    local root=model:FindFirstChild("HumanoidRootPart")

    return humanoid~=nil and humanoid.Health>0 and root~=nil
end

function AutoFarm:_nearest(root)
    local folder=self:_folder()

    if not folder then
        return nil
    end

    local nearest
    local nearestDistance=math.huge

    for _,object in ipairs(folder:GetDescendants()) do
        if object:IsA("Model") and self:_valid(object) then
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

function AutoFarm:_goal(enemyRoot,range)
    local desired=math.max(1,range-self.RangeMargin)
    local position=enemyRoot.Position-enemyRoot.CFrame.LookVector*desired
    position=Vector3.new(position.X,enemyRoot.Position.Y,position.Z)

    return CFrame.lookAt(
        position,
        Vector3.new(enemyRoot.Position.X,position.Y,enemyRoot.Position.Z)
    ),desired
end

function AutoFarm:_approachIsland(root)
    if not self.SelectedIsland or not self.IslandData then
        return false
    end

    local island=self.IslandData.Get(self.SelectedIsland)

    if not island or not island.CFrame then
        return false
    end

    local destination=island.CFrame*CFrame.new(0,3,0)

    if (root.Position-destination.Position).Magnitude<=80 then
        return false
    end

    self.AutoAttack:SetFarmReady(false)
    local moved=self.Movement:FlyTo(destination)
    task.wait(0.75)
    return moved
end

function AutoFarm:_run(token)
    self.AutoAttack:SetFarmEnabled(true)
    self.AutoAttack:SetFarmReady(false)

    while self.Enabled and token==self.Token do
        local root=self:_character()

        if not root then
            self.Target=nil
            self.AutoAttack:SetFarmReady(false)
            task.wait(0.25)
            continue
        end

        if not self:_valid(self.Target) then
            self.Target=self:_nearest(root)
        end

        local target=self.Target

        if not target then
            self.AutoAttack:SetFarmReady(false)

            if self:_approachIsland(root) then
                continue
            end

            task.wait(0.4)
            continue
        end

        local enemyRoot=target:FindFirstChild("HumanoidRootPart")

        if not enemyRoot then
            self.Target=nil
            self.AutoAttack:SetFarmReady(false)
            task.wait(0.1)
            continue
        end

        local range=self:_range()
        local goal,desired=self:_goal(enemyRoot,range)
        local goalDistance=(root.Position-goal.Position).Magnitude
        local targetDistance=(root.Position-enemyRoot.Position).Magnitude

        if goalDistance>self.Tolerance or targetDistance>range then
            self.AutoAttack:SetFarmReady(false)
            self.Movement:FlyTo(goal)
        else
            self:_face(root,enemyRoot)
            self.AutoAttack:SetFarmReady(
                targetDistance<=range
                and targetDistance>=math.max(0.5,desired-1.5)
            )
            task.wait(0.05)
        end
    end

    if token==self.Token then
        self.Target=nil
        self.AutoAttack:SetFarmReady(false)
        self.AutoAttack:SetFarmEnabled(false)
    end
end

function AutoFarm:SetEnabled(enabled)
    enabled=enabled==true

    if self.Enabled==enabled then
        return
    end

    self.Enabled=enabled
    self.Token+=1

    if enabled then
        local token=self.Token

        task.spawn(function()
            self:_run(token)
        end)
    else
        self.Target=nil
        self.AutoAttack:SetFarmReady(false)
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
