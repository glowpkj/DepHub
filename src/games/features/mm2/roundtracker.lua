local game=game
local type=type
local pairs=pairs
local ipairs=ipairs

local Factory={}

local function disconnectAll(list)
    for i=#list,1,-1 do
        local c=list[i]
        list[i]=nil
        if c then pcall(c.Disconnect,c) end
    end
end

function Factory.new(context)
    context=context or {}
    local Players=context.Players or game:GetService("Players")
    local RunService=context.RunService or game:GetService("RunService")
    local Workspace=context.Workspace or game:GetService("Workspace")

    local self={
        Enabled=false,
        Destroyed=false,
        Connections={},
        Listeners={},
        RoundActive=false,
        Accumulator=0,
        LobbyStable=0,
        OutsideStable=0,
        DebugInfo={Lobby="missing",PlayersChecked=0,PlayersInLobby=0,RoundActive=false,LastChange="none"}
    }

    function self:OnChanged(callback)
        if type(callback)~="function" then return nil end
        self.Listeners[callback]=true
        local connection={Connected=true,_owner=self,_callback=callback}
        function connection:Disconnect()
            if not self.Connected then return end
            self.Connected=false
            self._owner.Listeners[self._callback]=nil
        end
        return connection
    end

    function self:_emit(active)
        for callback in pairs(self.Listeners) do
            task.spawn(function() pcall(callback,active) end)
        end
    end

    function self:_setRoundActive(active,reason)
        active=active==true
        if self.RoundActive==active then return end
        self.RoundActive=active
        self.DebugInfo.RoundActive=active
        self.DebugInfo.LastChange=reason or (active and "started" or "ended")
        self:_emit(active)
    end

    function self:_getLobbyBounds()
        local lobby=Workspace:FindFirstChild("RegularLobby")
        if not lobby then
            self.DebugInfo.Lobby="missing"
            return nil,nil
        end
        self.DebugInfo.Lobby=lobby:GetFullName()
        if lobby:IsA("BasePart") then return lobby.CFrame,lobby.Size end
        if lobby:IsA("Model") then
            local ok,cf,size=pcall(lobby.GetBoundingBox,lobby)
            if ok then return cf,size end
        end
        local parts={}
        for _,object in ipairs(lobby:GetDescendants()) do
            if object:IsA("BasePart") then parts[#parts+1]=object end
        end
        if #parts==0 then return nil,nil end
        local minX,minY,minZ=math.huge,math.huge,math.huge
        local maxX,maxY,maxZ=-math.huge,-math.huge,-math.huge
        for _,part in ipairs(parts) do
            local p=part.Position
            local s=part.Size*0.5
            minX=math.min(minX,p.X-s.X); minY=math.min(minY,p.Y-s.Y); minZ=math.min(minZ,p.Z-s.Z)
            maxX=math.max(maxX,p.X+s.X); maxY=math.max(maxY,p.Y+s.Y); maxZ=math.max(maxZ,p.Z+s.Z)
        end
        local center=Vector3.new((minX+maxX)/2,(minY+maxY)/2,(minZ+maxZ)/2)
        return CFrame.new(center),Vector3.new(maxX-minX,maxY-minY,maxZ-minZ)
    end

    function self:_inside(cf,size,position)
        local localPos=cf:PointToObjectSpace(position)
        local half=size*0.5
        return math.abs(localPos.X)<=half.X+8
            and math.abs(localPos.Y)<=half.Y+12
            and math.abs(localPos.Z)<=half.Z+8
    end

    function self:_sample(dt)
        local cf,size=self:_getLobbyBounds()
        if not cf then return end

        local checked=0
        local inside=0
        for _,player in ipairs(Players:GetPlayers()) do
            local character=player.Character
            local root=character and character:FindFirstChild("HumanoidRootPart")
            local humanoid=character and character:FindFirstChildOfClass("Humanoid")
            if root and humanoid and humanoid.Health>0 then
                checked=checked+1
                if self:_inside(cf,size,root.Position) then inside=inside+1 end
            end
        end

        self.DebugInfo.PlayersChecked=checked
        self.DebugInfo.PlayersInLobby=inside
        local allInLobby=checked>0 and inside==checked

        if allInLobby then
            self.LobbyStable=self.LobbyStable+dt
            self.OutsideStable=0
            if self.LobbyStable>=1.25 then
                self:_setRoundActive(false,"all players in lobby")
            end
        else
            self.OutsideStable=self.OutsideStable+dt
            self.LobbyStable=0
            if checked>0 and self.OutsideStable>=0.75 then
                self:_setRoundActive(true,"players left lobby")
            end
        end
    end

    function self:IsRoundActive() return self.RoundActive end

    function self:GetDebugInfo()
        local out={}
        for k,v in pairs(self.DebugInfo) do out[k]=v end
        return out
    end

    function self:Enable()
        if self.Destroyed then return false end
        if self.Enabled then return true end
        self.Enabled=true
        self.Connections[#self.Connections+1]=RunService.Heartbeat:Connect(function(dt)
            self.Accumulator=self.Accumulator+dt
            if self.Accumulator>=0.25 then
                local elapsed=self.Accumulator
                self.Accumulator=0
                self:_sample(elapsed)
            end
        end)
        return true
    end

    function self:Disable()
        if not self.Enabled then return true end
        self.Enabled=false
        disconnectAll(self.Connections)
        self.LobbyStable=0
        self.OutsideStable=0
        return true
    end

    function self:Destroy()
        if self.Destroyed then return end
        self:Disable()
        self.Destroyed=true
        self.Listeners={}
    end

    return self
end

return Factory
