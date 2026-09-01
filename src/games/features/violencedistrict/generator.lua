local game=game
local task=task
local type=type
local tonumber=tonumber
local tostring=tostring
local pairs=pairs
local ipairs=ipairs
local os_clock=os.clock

local Factory={}

local function disconnectAll(list)
    if not list then return end
    for i=#list,1,-1 do
        local connection=list[i]
        list[i]=nil
        if connection then pcall(connection.Disconnect,connection) end
    end
end

function Factory.new(context)
    context=context or {}

    local Players=context.Players or game:GetService("Players")
    local RunService=context.RunService or game:GetService("RunService")
    local ReplicatedStorage=context.ReplicatedStorage or game:GetService("ReplicatedStorage")
    local Workspace=context.Workspace or game:GetService("Workspace")
    local LocalPlayer=context.LocalPlayer or Players.LocalPlayer

    local self={
        Enabled=false,
        Destroyed=false,
        Connections={},
        CharacterConnections={},
        Character=nil,
        AutoRepair=context.AutoRepair==true,
        AutoSkillCheck=context.AutoSkillCheck==true,
        Debug=context.Debug==true,
        RepairRange=tonumber(context.RepairRange) or 14,
        CurrentPoint=nil,
        CurrentGenerator=nil,
        LastRepairAt=0,
        LastSkillAt=0,
        StepAccumulator=0,
        DebugInfo={
            Runtime="idle",
            RepairRemote="missing",
            SkillRemote="missing",
            Generators="missing",
            NearestPoint="none",
            NearestDistance=0,
            CurrentGenerator="none",
            CurrentPoint="none",
            RepairCalls=0,
            SkillChecks=0,
            LastAction="none",
            LastSkillIndex=0,
            LastError="none"
        }
    }

    function self:_debug(message)
        self.DebugInfo.LastAction=tostring(message)
        if self.Debug then
            print("[DepHub VD Generator] "..tostring(message))
        end
    end

    function self:_getGeneratorFolder()
        local map=Workspace:FindFirstChild("Map")
        local folder=map and map:FindFirstChild("Generators")
        self.DebugInfo.Generators=folder and "ready" or "missing"
        return folder
    end

    function self:_getRemotes()
        local remotes=ReplicatedStorage:FindFirstChild("Remotes")
        local generator=remotes and remotes:FindFirstChild("Generator")
        local repair=generator and generator:FindFirstChild("RepairEvent")
        local skill=generator and generator:FindFirstChild("SkillCheckResultEvent")
        self.DebugInfo.RepairRemote=repair and repair:IsA("RemoteEvent") and "ready" or "missing"
        self.DebugInfo.SkillRemote=skill and skill:IsA("RemoteEvent") and "ready" or "missing"
        return repair,skill
    end

    function self:_root()
        local character=LocalPlayer and LocalPlayer.Character
        return character and character:FindFirstChild("HumanoidRootPart")
    end

    function self:_worldPosition(instance)
        if not instance then return nil end
        if instance:IsA("BasePart") then return instance.Position end
        if instance:IsA("Model") then
            local ok,pivot=pcall(instance.GetPivot,instance)
            if ok then return pivot.Position end
        end
        local part=instance:FindFirstChildWhichIsA("BasePart",true)
        return part and part.Position or nil
    end

    function self:_generatorFromPoint(point,folder)
        local current=point
        while current and current.Parent do
            if current.Parent==folder then return current end
            current=current.Parent
        end
        return nil
    end

    function self:_findNearestRepairPoint(maxRange)
        local root=self:_root()
        local folder=self:_getGeneratorFolder()
        if not root or not folder then return nil,nil,math.huge end
        local bestPoint,bestGenerator,bestDistance=nil,nil,math.huge
        for _,generator in ipairs(folder:GetChildren()) do
            for _,descendant in ipairs(generator:GetDescendants()) do
                if string.match(descendant.Name,"^GeneratorPoint%d+$") then
                    local position=self:_worldPosition(descendant)
                    if position then
                        local distance=(position-root.Position).Magnitude
                        if distance<bestDistance and (not maxRange or distance<=maxRange) then
                            bestPoint=descendant
                            bestGenerator=generator
                            bestDistance=distance
                        end
                    end
                end
            end
        end
        self.DebugInfo.NearestPoint=bestPoint and bestPoint.Name or "none"
        self.DebugInfo.NearestDistance=bestDistance<math.huge and bestDistance or 0
        return bestPoint,bestGenerator,bestDistance
    end

    function self:_fireRepair(point,generator)
        if not point then return false end
        local repair=self:_getRemotes()
        if not repair or not repair:IsA("RemoteEvent") then return false end
        local ok,err=pcall(repair.FireServer,repair,point,true)
        if not ok then
            self.DebugInfo.LastError=tostring(err)
            self:_debug("RepairEvent error: "..tostring(err))
            return false
        end
        self.CurrentPoint=point
        self.CurrentGenerator=generator
        self.LastRepairAt=os_clock()
        self.DebugInfo.RepairCalls=self.DebugInfo.RepairCalls+1
        self.DebugInfo.CurrentPoint=point.Name
        self.DebugInfo.CurrentGenerator=generator and generator.Name or "none"
        self:_debug("repair start: "..self.DebugInfo.CurrentGenerator.." / "..point.Name)
        return true
    end

    function self:_resolveSkillIndex(skillObject)
        if skillObject then
            for _,name in ipairs({"Index","SkillCheckIndex","SkillcheckIndex","Check","Number","Stage"}) do
                local value=skillObject:GetAttribute(name)
                value=tonumber(value)
                if value then return value end
            end
            for _,descendant in ipairs(skillObject:GetDescendants()) do
                if descendant:IsA("IntValue") or descendant:IsA("NumberValue") then
                    local lowered=string.lower(descendant.Name)
                    if string.find(lowered,"index",1,true) or string.find(lowered,"check",1,true) or string.find(lowered,"stage",1,true) then
                        local value=tonumber(descendant.Value)
                        if value then return value end
                    end
                end
            end
        end
        return 1
    end

    function self:_submitSkillCheck(skillObject)
        if self.Destroyed or not self.Enabled or not self.AutoSkillCheck then return false end
        if os_clock()-self.LastSkillAt<0.12 then return false end

        local _,skillRemote=self:_getRemotes()
        if not skillRemote or not skillRemote:IsA("RemoteEvent") then return false end

        local point,generator=self:_findNearestRepairPoint(math.max(self.RepairRange,24))
        if not point then
            point=self.CurrentPoint
            generator=self.CurrentGenerator
        end
        if not point or not generator then
            self:_debug("skillcheck sem generator/point")
            return false
        end

        local index=self:_resolveSkillIndex(skillObject)
        local ok,err=pcall(skillRemote.FireServer,skillRemote,"success",index,generator,point)
        if not ok then
            self.DebugInfo.LastError=tostring(err)
            self:_debug("SkillCheckResultEvent error: "..tostring(err))
            return false
        end

        self.LastSkillAt=os_clock()
        self.DebugInfo.SkillChecks=self.DebugInfo.SkillChecks+1
        self.DebugInfo.LastSkillIndex=index
        self.DebugInfo.CurrentGenerator=generator.Name
        self.DebugInfo.CurrentPoint=point.Name
        self:_debug("skillcheck success: index="..tostring(index).." | "..generator.Name.." / "..point.Name)
        return true
    end

    function self:_onCharacterDescendant(instance)
        if not self.AutoSkillCheck or not instance then return end
        if string.lower(instance.Name)=="skillcheck-gen" then
            task.defer(function()
                if not self.Destroyed and self.Enabled and instance.Parent then
                    self:_submitSkillCheck(instance)
                end
            end)
        end
    end

    function self:_bindCharacter(character)
        disconnectAll(self.CharacterConnections)
        self.Character=character
        self.CurrentPoint=nil
        self.CurrentGenerator=nil
        if not character then return end
        self.CharacterConnections[#self.CharacterConnections+1]=character.ChildAdded:Connect(function(instance)
            self:_onCharacterDescendant(instance)
        end)
        self.CharacterConnections[#self.CharacterConnections+1]=character.DescendantAdded:Connect(function(instance)
            if instance.Parent~=character then
                self:_onCharacterDescendant(instance)
            end
        end)
        for _,instance in ipairs(character:GetDescendants()) do
            if string.lower(instance.Name)=="skillcheck-gen" then
                self:_onCharacterDescendant(instance)
                break
            end
        end
    end

    function self:_step(dt)
        if self.Destroyed or not self.Enabled then return end
        self.StepAccumulator=self.StepAccumulator+dt
        if self.StepAccumulator<0.25 then return end
        self.StepAccumulator=0

        self:_getRemotes()
        if not self.AutoRepair then return end

        local point,generator,distance=self:_findNearestRepairPoint(self.RepairRange)
        if not point then
            self.CurrentPoint=nil
            self.CurrentGenerator=nil
            self.DebugInfo.CurrentPoint="none"
            self.DebugInfo.CurrentGenerator="none"
            return
        end

        local changed=point~=self.CurrentPoint or generator~=self.CurrentGenerator
        local stale=os_clock()-self.LastRepairAt>=1.5
        if changed or stale then
            self:_fireRepair(point,generator)
        else
            self.DebugInfo.NearestDistance=distance
        end
    end

    function self:SetAutoRepair(value)
        self.AutoRepair=value==true
        self:_debug(self.AutoRepair and "auto repair ligado" or "auto repair desligado")
        return true
    end

    function self:SetAutoSkillCheck(value)
        self.AutoSkillCheck=value==true
        self:_debug(self.AutoSkillCheck and "auto skillcheck ligado" or "auto skillcheck desligado")
        return true
    end

    function self:SetRepairRange(value)
        value=tonumber(value)
        if not value then return false end
        self.RepairRange=math.max(2,math.min(50,value))
        return true
    end

    function self:SetDebug(value)
        self.Debug=value==true
        self:_debug(self.Debug and "debug ligado" or "debug desligado")
        return true
    end

    function self:GetDebugInfo()
        local result={}
        for key,value in pairs(self.DebugInfo) do result[key]=value end
        result.Runtime=self.Enabled and "running" or "idle"
        result.AutoRepair=self.AutoRepair
        result.AutoSkillCheck=self.AutoSkillCheck
        result.RepairRange=self.RepairRange
        return result
    end

    function self:Enable()
        if self.Destroyed or self.Enabled then return false end
        self.Enabled=true
        self.DebugInfo.Runtime="running"
        self:_bindCharacter(LocalPlayer.Character)
        self.Connections[#self.Connections+1]=LocalPlayer.CharacterAdded:Connect(function(character)
            task.defer(function()
                if self.Destroyed or not self.Enabled then return end
                self:_bindCharacter(character)
                self:_debug("respawn detectado")
            end)
        end)
        self.Connections[#self.Connections+1]=LocalPlayer.CharacterRemoving:Connect(function()
            disconnectAll(self.CharacterConnections)
            self.Character=nil
            self.CurrentPoint=nil
            self.CurrentGenerator=nil
            self:_debug("character removido")
        end)
        self.Connections[#self.Connections+1]=RunService.Heartbeat:Connect(function(dt)
            local ok,err=pcall(self._step,self,dt)
            if not ok then
                self.DebugInfo.LastError=tostring(err)
                if self.Debug then warn("[DepHub VD Generator] "..tostring(err)) end
            end
        end)
        return true
    end

    function self:Disable()
        if self.Destroyed then return false end
        self.Enabled=false
        self.DebugInfo.Runtime="idle"
        disconnectAll(self.Connections)
        disconnectAll(self.CharacterConnections)
        self.Character=nil
        self.CurrentPoint=nil
        self.CurrentGenerator=nil
        self.StepAccumulator=0
        return true
    end

    function self:Destroy()
        if self.Destroyed then return end
        self:Disable()
        self.Destroyed=true
    end

    return self
end

return Factory
