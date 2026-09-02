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
    local PlayerGui=LocalPlayer and (LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui",10))

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
        RepairActive=false,
        LastSkillAt=0,
        StepAccumulator=0,
        MapCache=nil,
        ExitLeverCache=nil,
        ExitGateCache=nil,
        DebugInfo={
            Runtime="idle",
            Map="missing",
            RepairRemote="missing",
            SkillRemote="missing",
            Generators="missing",
            NearestPoint="none",
            NearestDistance=0,
            CurrentGenerator="none",
            CurrentPoint="none",
            RepairActive=false,
            RepairCalls=0,
            RepairStops=0,
            SkillChecks=0,
            LastSkillIndex=0,
            ExitLever="missing",
            LastAction="none",
            LastError="none"
        }
    }

    function self:_debug(message)
        self.DebugInfo.LastAction=tostring(message)
        if self.Debug then
            print("[DepHub VD Generator] "..tostring(message))
        end
    end

    function self:_root()
        local character=LocalPlayer and LocalPlayer.Character
        return character and character:FindFirstChild("HumanoidRootPart")
    end

    function self:_worldPart(instance)
        if not instance then return nil end
        if instance:IsA("BasePart") then return instance end
        return instance:FindFirstChildWhichIsA("BasePart",true)
    end

    function self:_worldPosition(instance)
        if not instance then return nil end
        if instance:IsA("BasePart") then return instance.Position end
        if instance:IsA("Model") then
            local ok,pivot=pcall(instance.GetPivot,instance)
            if ok then return pivot.Position end
        end
        local part=self:_worldPart(instance)
        return part and part.Position or nil
    end

    function self:_looksLikeMap(instance)
        if not instance or not instance.Parent then return false end
        if instance.Name=="Map" then return true end
        local hasGate=false
        local hasGenerator=false
        for _,descendant in ipairs(instance:GetDescendants()) do
            if descendant.Name=="Gate" then hasGate=true end
            if string.match(descendant.Name,"^GeneratorPoint%d+$") then hasGenerator=true end
            if hasGate and hasGenerator then return true end
        end
        return false
    end

    function self:_getMapRoot()
        if self.MapCache and self.MapCache.Parent then
            self.DebugInfo.Map=self.MapCache:GetFullName()
            return self.MapCache
        end

        self.MapCache=nil
        local direct=Workspace:FindFirstChild("Map")
        if direct then
            self.MapCache=direct
            self.DebugInfo.Map=direct:GetFullName()
            return direct
        end

        for _,child in ipairs(Workspace:GetChildren()) do
            if (child:IsA("Folder") or child:IsA("Model")) and self:_looksLikeMap(child) then
                self.MapCache=child
                self.DebugInfo.Map=child:GetFullName()
                return child
            end
        end

        self.DebugInfo.Map="missing"
        return nil
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

    function self:_generatorForPoint(point,map)
        if not point then return nil end
        local current=point.Parent
        local fallback=nil
        while current and current~=map do
            if current:IsA("Model") then
                fallback=fallback or current
                if string.find(string.lower(current.Name),"generator",1,true) then
                    return current
                end
            end
            current=current.Parent
        end
        return fallback
    end

    function self:_findNearestRepairPoint(maxRange)
        local root=self:_root()
        local map=self:_getMapRoot()
        if not root or not map then
            self.DebugInfo.Generators="missing"
            return nil,nil,math.huge
        end

        local bestPoint,bestGenerator,bestDistance=nil,nil,math.huge
        local count=0

        for _,descendant in ipairs(map:GetDescendants()) do
            if string.match(descendant.Name,"^GeneratorPoint%d+$") then
                count=count+1
                local position=self:_worldPosition(descendant)
                if position then
                    local distance=(position-root.Position).Magnitude
                    if distance<bestDistance and (not maxRange or distance<=maxRange) then
                        bestPoint=descendant
                        bestGenerator=self:_generatorForPoint(descendant,map)
                        bestDistance=distance
                    end
                end
            end
        end

        self.DebugInfo.Generators=count>0 and ("ready:"..tostring(count)) or "missing"
        self.DebugInfo.NearestPoint=bestPoint and bestPoint.Name or "none"
        self.DebugInfo.NearestDistance=bestDistance<math.huge and bestDistance or 0
        return bestPoint,bestGenerator,bestDistance
    end

    function self:_findExitLever()
        if self.ExitLeverCache and self.ExitLeverCache.Parent and self.ExitGateCache and self.ExitGateCache.Parent then
            self.DebugInfo.ExitLever=self.ExitLeverCache:GetFullName()
            return self.ExitLeverCache,self.ExitGateCache
        end

        self.ExitLeverCache=nil
        self.ExitGateCache=nil
        local map=self:_getMapRoot()
        if not map then
            self.DebugInfo.ExitLever="missing"
            return nil,nil
        end

        local root=self:_root()
        local bestLever,bestGate,bestDistance=nil,nil,math.huge

        for _,descendant in ipairs(map:GetDescendants()) do
            if descendant.Name=="ExitLever" then
                local current=descendant.Parent
                local gate=nil
                while current and current~=map do
                    if current.Name=="Gate" and current:IsA("Model") then
                        gate=current
                        break
                    end
                    current=current.Parent
                end

                if gate then
                    local position=self:_worldPosition(descendant)
                    local distance=position and root and (position-root.Position).Magnitude or 0
                    if not bestLever or distance<bestDistance then
                        bestLever=descendant
                        bestGate=gate
                        bestDistance=distance
                    end
                end
            end
        end

        self.ExitLeverCache=bestLever
        self.ExitGateCache=bestGate
        self.DebugInfo.ExitLever=bestLever and bestLever:GetFullName() or "missing"
        return bestLever,bestGate
    end

    function self:HasExitLever()
        local lever=self:_findExitLever()
        return lever~=nil
    end

    function self:GetExitLeverInfo()
        local lever,gate=self:_findExitLever()
        return {
            Available=lever~=nil,
            Lever=lever,
            Gate=gate,
            Path=lever and lever:GetFullName() or "none"
        }
    end

    function self:TeleportToExitLever()
        local root=self:_root()
        local lever=self:_findExitLever()
        if not root or not lever then
            self:_debug("ExitLever nao encontrado")
            return false
        end

        local targetPart=self:_worldPart(lever)
        local targetCFrame=nil

        if targetPart then
            targetCFrame=targetPart.CFrame
        elseif lever:IsA("Model") then
            local ok,pivot=pcall(lever.GetPivot,lever)
            if ok then targetCFrame=pivot end
        end

        if not targetCFrame then
            self:_debug("ExitLever sem posicao")
            return false
        end

        root.CFrame=targetCFrame*CFrame.new(0,3,3)
        self:_debug("teleport ExitLever")
        return true
    end

    function self:_fireRepair(point,generator)
        if not point or self.RepairActive then return false end
        local repair=self:_getRemotes()
        if not repair or not repair:IsA("RemoteEvent") then return false end

        local ok,err=pcall(repair.FireServer,repair,point,true)
        if not ok then
            self.DebugInfo.LastError=tostring(err)
            self:_debug("RepairEvent start error: "..tostring(err))
            return false
        end

        self.CurrentPoint=point
        self.CurrentGenerator=generator
        self.RepairActive=true
        self.DebugInfo.RepairActive=true
        self.DebugInfo.RepairCalls=self.DebugInfo.RepairCalls+1
        self.DebugInfo.CurrentPoint=point.Name
        self.DebugInfo.CurrentGenerator=generator and generator.Name or "none"
        self:_debug("repair start: "..self.DebugInfo.CurrentGenerator.." / "..point.Name)
        return true
    end

    function self:_stopRepair(reason)
        local point=self.CurrentPoint
        local wasActive=self.RepairActive

        if wasActive and point and point.Parent then
            local repair=self:_getRemotes()
            if repair and repair:IsA("RemoteEvent") then
                local ok,err=pcall(repair.FireServer,repair,point,false)
                if not ok then
                    self.DebugInfo.LastError=tostring(err)
                    self:_debug("RepairEvent stop error: "..tostring(err))
                else
                    self.DebugInfo.RepairStops=self.DebugInfo.RepairStops+1
                end
            end
        end

        self.RepairActive=false
        self.CurrentPoint=nil
        self.CurrentGenerator=nil
        self.DebugInfo.RepairActive=false
        self.DebugInfo.CurrentPoint="none"
        self.DebugInfo.CurrentGenerator="none"

        if wasActive and reason then
            self:_debug("repair stop: "..tostring(reason))
        end
    end

    function self:_resolveSkillIndex(skillObject)
        if skillObject then
            for _,name in ipairs({"Index","SkillCheckIndex","SkillcheckIndex","Check","Number","Stage"}) do
                local value=tonumber(skillObject:GetAttribute(name))
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

    function self:_debugSkillGui()
        if not self.Debug or not PlayerGui then return end
        local found=0
        for _,object in ipairs(PlayerGui:GetDescendants()) do
            if object:IsA("GuiObject") and object.Visible then
                local lowered=string.lower(object.Name)
                if string.find(lowered,"skill",1,true) or string.find(lowered,"check",1,true) or string.find(lowered,"gen",1,true) then
                    found=found+1
                    print("[DepHub VD SkillUI] "..object:GetFullName().." pos="..tostring(object.AbsolutePosition).." size="..tostring(object.AbsoluteSize))
                    if found>=20 then break end
                end
            end
        end
        if found==0 then
            print("[DepHub VD SkillUI] nenhum GuiObject nomeado como skill/check/gen")
        end
    end

    function self:_submitSkillCheck(skillObject)
        if self.Destroyed or not self.Enabled or not self.AutoSkillCheck then return false end
        if os_clock()-self.LastSkillAt<0.18 then return false end

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
        self:_debugSkillGui()

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
        self:_debug("skillcheck success enviado: index="..tostring(index).." | "..generator.Name.." / "..point.Name)
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
        self:_stopRepair("character mudou")
        if not character then return end

        self.CharacterConnections[#self.CharacterConnections+1]=character.DescendantAdded:Connect(function(instance)
            self:_onCharacterDescendant(instance)
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
        if self.StepAccumulator<0.2 then return end
        self.StepAccumulator=0

        self:_getRemotes()
        self:_findExitLever()

        if not self.AutoRepair then
            if self.RepairActive then self:_stopRepair("Auto Repair desligado") end
            return
        end

        if self.RepairActive then
            local root=self:_root()
            local position=self.CurrentPoint and self.CurrentPoint.Parent and self:_worldPosition(self.CurrentPoint) or nil
            if not root or not position then
                self:_stopRepair("point sumiu")
                return
            end

            local distance=(position-root.Position).Magnitude
            self.DebugInfo.NearestDistance=distance
            if distance>self.RepairRange+2 then
                self:_stopRepair("saiu do range")
            end
            return
        end

        local point,generator=self:_findNearestRepairPoint(self.RepairRange)
        if point then
            self:_fireRepair(point,generator)
        end
    end

    function self:SetAutoRepair(value)
        self.AutoRepair=value==true
        if not self.AutoRepair then
            self:_stopRepair("toggle")
        end
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
            self:_stopRepair("character removido")
            disconnectAll(self.CharacterConnections)
            self.Character=nil
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
        self:_stopRepair("feature desligada")
        self.Enabled=false
        self.DebugInfo.Runtime="idle"
        disconnectAll(self.Connections)
        disconnectAll(self.CharacterConnections)
        self.Character=nil
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
