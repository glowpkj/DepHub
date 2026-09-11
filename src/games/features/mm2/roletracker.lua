local game=game
local task=task
local type=type
local pairs=pairs
local ipairs=ipairs

local Factory={}

local function disconnectAll(list)
    if not list then return end
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
    local LocalPlayer=context.LocalPlayer or Players.LocalPlayer

    local self={
        Enabled=false,
        Destroyed=false,
        Connections={},
        PlayerConnections={},
        Listeners={},
        Murder=nil,
        Sheriff=nil,
        LastSheriff=nil,
        GunDrop=nil,
        Accumulator=0,
        Debug=context.Debug==true,
        DebugInfo={Murder="none",Sheriff="none",LastSheriff="none",GunDrop="missing",Scans=0,LastChange="none"}
    }

    function self:_emit(role,newPlayer,oldPlayer)
        self.DebugInfo.LastChange=role..":"..(newPlayer and newPlayer.Name or "none")
        for callback in pairs(self.Listeners) do
            task.spawn(function()
                pcall(callback,role,newPlayer,oldPlayer)
            end)
        end
    end

    function self:OnChanged(callback)
        if type(callback)~="function" then return nil end
        self.Listeners[callback]=true
        local connection={Connected=true}
        function connection:Disconnect()
            if not self.Connected then return end
            self.Connected=false
            self._owner.Listeners[self._callback]=nil
        end
        connection._owner=self
        connection._callback=callback
        return connection
    end

    function self:_hasTool(player,name)
        if not player then return false end
        local character=player.Character
        local backpack=player:FindFirstChildOfClass("Backpack")
        if character and character:FindFirstChild(name,true) then return true end
        if backpack and backpack:FindFirstChild(name,true) then return true end
        return false
    end

    function self:_findGunDrop()
        if self.GunDrop and self.GunDrop.Parent then
            self.DebugInfo.GunDrop=self.GunDrop:GetFullName()
            return self.GunDrop
        end
        self.GunDrop=nil
        for _,object in ipairs(Workspace:GetDescendants()) do
            if object.Name=="GunDrop" then
                self.GunDrop=object
                break
            end
        end
        self.DebugInfo.GunDrop=self.GunDrop and self.GunDrop:GetFullName() or "missing"
        return self.GunDrop
    end

    function self:_setMurder(player)
        if self.Murder==player then return end
        local old=self.Murder
        self.Murder=player
        self.DebugInfo.Murder=player and player.Name or "none"
        self:_emit("Murder",player,old)
    end

    function self:_setSheriff(player)
        if self.Sheriff==player then return end
        local old=self.Sheriff
        if player then
            self.LastSheriff=self.Sheriff or self.LastSheriff
            self.Sheriff=player
        else
            self.LastSheriff=self.Sheriff or self.LastSheriff
            self.Sheriff=nil
        end
        self.DebugInfo.Sheriff=self.Sheriff and self.Sheriff.Name or "none"
        self.DebugInfo.LastSheriff=self.LastSheriff and self.LastSheriff.Name or "none"
        self:_emit("Sheriff",self.Sheriff,old)
    end

    function self:Scan()
        if self.Destroyed then return end
        self.DebugInfo.Scans=self.DebugInfo.Scans+1
        local murder=nil
        local sheriff=nil

        for _,player in ipairs(Players:GetPlayers()) do
            if self:_hasTool(player,"Knife") then murder=player end
            if self:_hasTool(player,"Gun") then sheriff=player end
        end

        if murder then
            self:_setMurder(murder)
        elseif self.Murder and (not self.Murder.Parent or not self.Murder.Character) then
            self:_setMurder(nil)
        end

        if sheriff then
            if sheriff~=self.Sheriff then self:_setSheriff(sheriff) end
        elseif self.Sheriff and not self.Sheriff.Parent then
            self:_setSheriff(nil)
        end

        self:_findGunDrop()
    end

    function self:GetRole(player)
        if not player then return "Unknown" end
        if player==self.Murder then return "Murder" end
        if player==self.Sheriff then return "Sheriff" end
        return "Innocent"
    end

    function self:GetMurder() return self.Murder end
    function self:GetSheriff() return self.Sheriff end
    function self:GetLastSheriff() return self.LastSheriff end
    function self:GetGunDrop() return self:_findGunDrop() end
    function self:HasTool(player,name) return self:_hasTool(player,name) end

    function self:ResetRound()
        self.GunDrop=nil
        self:_setMurder(nil)
        self:_setSheriff(nil)
        self.LastSheriff=nil
        self.DebugInfo.LastSheriff="none"
        self.DebugInfo.GunDrop="missing"
    end

    function self:_watchPlayer(player)
        if self.PlayerConnections[player] then return end
        local list={}
        self.PlayerConnections[player]=list

        local function rescan()
            task.defer(function()
                if self.Enabled and not self.Destroyed then self:Scan() end
            end)
        end

        list[#list+1]=player.CharacterAdded:Connect(function(character)
            rescan()
            list[#list+1]=character.ChildAdded:Connect(rescan)
            list[#list+1]=character.ChildRemoved:Connect(rescan)
        end)
        list[#list+1]=player.CharacterRemoving:Connect(rescan)

        local backpack=player:FindFirstChildOfClass("Backpack")
        if backpack then
            list[#list+1]=backpack.ChildAdded:Connect(rescan)
            list[#list+1]=backpack.ChildRemoved:Connect(rescan)
        end

        if player.Character then
            list[#list+1]=player.Character.ChildAdded:Connect(rescan)
            list[#list+1]=player.Character.ChildRemoved:Connect(rescan)
        end
    end

    function self:_unwatchPlayer(player)
        local list=self.PlayerConnections[player]
        self.PlayerConnections[player]=nil
        disconnectAll(list)
        if self.Murder==player then self:_setMurder(nil) end
        if self.Sheriff==player then self:_setSheriff(nil) end
        if self.LastSheriff==player then
            self.LastSheriff=nil
            self.DebugInfo.LastSheriff="none"
        end
    end

    function self:Enable()
        if self.Destroyed then return false end
        if self.Enabled then return true end
        self.Enabled=true
        for _,player in ipairs(Players:GetPlayers()) do self:_watchPlayer(player) end
        self.Connections[#self.Connections+1]=Players.PlayerAdded:Connect(function(player)
            self:_watchPlayer(player)
            self:Scan()
        end)
        self.Connections[#self.Connections+1]=Players.PlayerRemoving:Connect(function(player)
            self:_unwatchPlayer(player)
        end)
        self.Connections[#self.Connections+1]=Workspace.DescendantAdded:Connect(function(object)
            if object.Name=="GunDrop" then
                self.GunDrop=object
                self.DebugInfo.GunDrop=object:GetFullName()
            end
        end)
        self.Connections[#self.Connections+1]=Workspace.DescendantRemoving:Connect(function(object)
            if object==self.GunDrop then
                self.GunDrop=nil
                self.DebugInfo.GunDrop="missing"
            end
        end)
        self.Connections[#self.Connections+1]=RunService.Heartbeat:Connect(function(dt)
            self.Accumulator=self.Accumulator+dt
            if self.Accumulator>=0.45 then
                self.Accumulator=0
                self:Scan()
            end
        end)
        self:Scan()
        return true
    end

    function self:GetDebugInfo()
        local out={}
        for k,v in pairs(self.DebugInfo) do out[k]=v end
        return out
    end

    function self:Disable()
        if not self.Enabled then return true end
        self.Enabled=false
        disconnectAll(self.Connections)
        for player in pairs(self.PlayerConnections) do self:_unwatchPlayer(player) end
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
