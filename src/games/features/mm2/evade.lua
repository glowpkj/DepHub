local game=game
local task=task
local type=type
local pairs=pairs
local ipairs=ipairs
local os_clock=os.clock

local Factory={}
local ATTACK_ID=115592970007001

local function disconnectAll(list)
    for i=#list,1,-1 do
        local c=list[i]
        list[i]=nil
        if c then pcall(c.Disconnect,c) end
    end
end

local function animationId(track)
    if not track then return nil end
    local animation=track.Animation
    local id=animation and animation.AnimationId
    return type(id)=="string" and tonumber(id:match("%d+")) or nil
end

function Factory.new(context)
    context=context or {}
    local Players=context.Players or game:GetService("Players")
    local RunService=context.RunService or game:GetService("RunService")
    local LocalPlayer=context.LocalPlayer or Players.LocalPlayer
    local RoleTracker=context.RoleTracker
    local RoundTracker=context.RoundTracker

    local self={
        Enabled=false,
        Destroyed=false,
        Connections={},
        MurderConnections={},
        MurderPlayer=nil,
        MurderCharacter=nil,
        DangerPart=nil,
        DangerCharacter=nil,
        DangerSize=tonumber(context.DangerSize) or 18,
        EscapeHeight=tonumber(context.EscapeHeight) or 32,
        ReturnDelay=tonumber(context.ReturnDelay) or 0.05,
        ShowBox=context.ShowBox==true,
        Evading=false,
        SavedCFrame=nil,
        SavedRoot=nil,
        EvadeToken=0,
        LastEvade=0,
        DebugInfo={Runtime="idle",Murder="none",Animator="missing",Attacks=0,Evades=0,Inside=false,Evading=false,LastDistance=0,LastError="none"}
    }

    function self:_localRoot()
        local character=LocalPlayer and LocalPlayer.Character
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        local root=character and character:FindFirstChild("HumanoidRootPart")
        if not humanoid or humanoid.Health<=0 then return nil end
        return root
    end

    function self:_destroyBox()
        if self.DangerPart then pcall(self.DangerPart.Destroy,self.DangerPart) end
        self.DangerPart=nil
        self.DangerCharacter=nil
    end

    function self:_ensureBox()
        local character=LocalPlayer and LocalPlayer.Character
        local root=self:_localRoot()
        if not character or not root then self:_destroyBox() return nil end
        if self.DangerPart and self.DangerPart.Parent and self.DangerCharacter==character then
            self.DangerPart.Size=Vector3.new(self.DangerSize,self.DangerSize,self.DangerSize)
            self.DangerPart.Transparency=self.ShowBox and 0.78 or 1
            return self.DangerPart
        end
        self:_destroyBox()
        local part=Instance.new("Part")
        part.Name="DepHubMM2DangerBox"
        part.Size=Vector3.new(self.DangerSize,self.DangerSize,self.DangerSize)
        part.CFrame=root.CFrame
        part.Color=Color3.fromRGB(255,76,76)
        part.Material=Enum.Material.ForceField
        part.Transparency=self.ShowBox and 0.78 or 1
        part.CanCollide=false
        part.CanTouch=false
        part.CanQuery=false
        part.CastShadow=false
        part.Massless=true
        part.Anchored=false
        part.Parent=character
        local weld=Instance.new("WeldConstraint")
        weld.Part0=root
        weld.Part1=part
        weld.Parent=part
        self.DangerPart=part
        self.DangerCharacter=character
        return part
    end

    function self:_inside(murderRoot,myRoot)
        if not murderRoot or not myRoot then return false end
        local p=myRoot.CFrame:PointToObjectSpace(murderRoot.Position)
        local half=self.DangerSize*0.5
        local inside=math.abs(p.X)<=half and math.abs(p.Y)<=half and math.abs(p.Z)<=half
        self.DebugInfo.Inside=inside
        self.DebugInfo.LastDistance=(murderRoot.Position-myRoot.Position).Magnitude
        return inside
    end

    function self:_restore(token)
        if token~=self.EvadeToken or not self.Evading then return end
        local root=self.SavedRoot
        local saved=self.SavedCFrame
        self.Evading=false
        self.DebugInfo.Evading=false
        self.SavedRoot=nil
        self.SavedCFrame=nil
        if root and root.Parent and saved then
            task.delay(self.ReturnDelay,function()
                if self.Destroyed or token~=self.EvadeToken or not root.Parent then return end
                pcall(function() root.CFrame=saved end)
            end)
        end
    end

    function self:_evade(track,murderRoot)
        if self.Destroyed or not self.Enabled or self.Evading then return false end
        if RoundTracker and not RoundTracker:IsRoundActive() then return false end
        if os_clock()-self.LastEvade<0.15 then return false end
        local myRoot=self:_localRoot()
        if not myRoot or not self:_inside(murderRoot,myRoot) then return false end

        self.LastEvade=os_clock()
        self.EvadeToken=self.EvadeToken+1
        local token=self.EvadeToken
        self.Evading=true
        self.DebugInfo.Evading=true
        self.DebugInfo.Evades=self.DebugInfo.Evades+1
        self.SavedRoot=myRoot
        self.SavedCFrame=myRoot.CFrame

        local ok,err=pcall(function()
            myRoot.CFrame=self.SavedCFrame*CFrame.new(0,self.EscapeHeight,0)
        end)
        if not ok then
            self.DebugInfo.LastError=tostring(err)
            self.Evading=false
            self.DebugInfo.Evading=false
            return false
        end

        local stoppedConnection
        local okConnect,connection=pcall(function()
            return track.Stopped:Connect(function()
                if stoppedConnection then pcall(stoppedConnection.Disconnect,stoppedConnection) end
                self:_restore(token)
            end)
        end)
        if okConnect then stoppedConnection=connection end

        task.delay(1.35,function()
            if stoppedConnection then pcall(stoppedConnection.Disconnect,stoppedConnection) end
            self:_restore(token)
        end)
        return true
    end

    function self:_attachCharacter(character)
        disconnectAll(self.MurderConnections)
        self.MurderCharacter=character
        self.DebugInfo.Animator="missing"
        if not character then return end
        task.spawn(function()
            local humanoid=character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid",8)
            if self.Destroyed or not self.Enabled or self.MurderCharacter~=character or not humanoid then return end
            local animator=humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator",8)
            if self.Destroyed or not self.Enabled or self.MurderCharacter~=character or not animator then return end
            self.DebugInfo.Animator="ready"
            self.MurderConnections[#self.MurderConnections+1]=animator.AnimationPlayed:Connect(function(track)
                if animationId(track)~=ATTACK_ID then return end
                self.DebugInfo.Attacks=self.DebugInfo.Attacks+1
                local root=character:FindFirstChild("HumanoidRootPart")
                if root then self:_evade(track,root) end
            end)
        end)
    end

    function self:_bindMurder(player)
        if self.MurderPlayer==player then return end
        disconnectAll(self.MurderConnections)
        self.MurderPlayer=player
        self.MurderCharacter=nil
        self.DebugInfo.Murder=player and player.Name or "none"
        if not player then return end
        self.MurderConnections[#self.MurderConnections+1]=player.CharacterAdded:Connect(function(character)
            self:_attachCharacter(character)
        end)
        self.MurderConnections[#self.MurderConnections+1]=player.CharacterRemoving:Connect(function(character)
            if self.MurderCharacter==character then self:_attachCharacter(nil) end
        end)
        self:_attachCharacter(player.Character)
    end

    function self:SetDangerSize(value)
        value=tonumber(value)
        if not value then return false end
        self.DangerSize=math.max(4,math.min(60,value))
        self:_ensureBox()
        return true
    end

    function self:SetEscapeHeight(value)
        value=tonumber(value)
        if not value then return false end
        self.EscapeHeight=math.max(8,math.min(100,value))
        return true
    end

    function self:SetShowBox(value)
        self.ShowBox=value==true
        self:_ensureBox()
        return true
    end

    function self:GetDebugInfo()
        local out={}
        for k,v in pairs(self.DebugInfo) do out[k]=v end
        return out
    end

    function self:Enable()
        if self.Destroyed then return false end
        if self.Enabled then return true end
        self.Enabled=true
        self.DebugInfo.Runtime="running"
        if RoleTracker then
            local roleConnection=RoleTracker:OnChanged(function(role,player)
                if role=="Murder" then self:_bindMurder(player) end
            end)
            if roleConnection then self.Connections[#self.Connections+1]=roleConnection end
            self:_bindMurder(RoleTracker:GetMurder())
        end
        self.Connections[#self.Connections+1]=RunService.Heartbeat:Connect(function()
            if self.Enabled then self:_ensureBox() end
        end)
        return true
    end

    function self:Disable()
        if not self.Enabled then return true end
        self.Enabled=false
        self.DebugInfo.Runtime="idle"
        self.EvadeToken=self.EvadeToken+1
        if self.Evading and self.SavedRoot and self.SavedRoot.Parent and self.SavedCFrame then
            pcall(function() self.SavedRoot.CFrame=self.SavedCFrame end)
        end
        self.Evading=false
        self.DebugInfo.Evading=false
        self.SavedRoot=nil
        self.SavedCFrame=nil
        disconnectAll(self.Connections)
        disconnectAll(self.MurderConnections)
        self.MurderPlayer=nil
        self.MurderCharacter=nil
        self:_destroyBox()
        return true
    end

    function self:Destroy()
        if self.Destroyed then return end
        self:Disable()
        self.Destroyed=true
        self.DebugInfo.Runtime="destroyed"
    end

    return self
end

return Factory
