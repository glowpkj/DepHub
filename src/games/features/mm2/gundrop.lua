local game=game
local type=type
local os_clock=os.clock

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
    local LocalPlayer=context.LocalPlayer or Players.LocalPlayer
    local RoleTracker=context.RoleTracker
    local RoundTracker=context.RoundTracker

    local self={
        Destroyed=false,
        ESPEnabled=false,
        AutoPickup=false,
        Connections={},
        Highlight=nil,
        Billboard=nil,
        CurrentDrop=nil,
        SafeDistance=tonumber(context.GunSafeDistance) or 22,
        PickupHold=tonumber(context.GunPickupHold) or 0.16,
        Cooldown=0.8,
        LastAttempt=0,
        Busy=false,
        Token=0,
        DebugInfo={GunDrop="missing",MurderDistance=-1,Safe=true,Attempts=0,Pickups=0,Returns=0,LastAction="idle",LastError="none"}
    }

    function self:_localRoot()
        local character=LocalPlayer and LocalPlayer.Character
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        local root=character and character:FindFirstChild("HumanoidRootPart")
        if not humanoid or humanoid.Health<=0 or not root then return nil end
        return root
    end

    function self:_part(drop)
        if not drop or not drop.Parent then return nil end
        if drop:IsA("BasePart") then return drop end
        return drop:FindFirstChildWhichIsA("BasePart",true)
    end

    function self:_hasLocalGun()
        if not RoleTracker then return false end
        if type(RoleTracker.HasTool)=="function" then return RoleTracker:HasTool(LocalPlayer,"Gun") end
        local character=LocalPlayer and LocalPlayer.Character
        local backpack=LocalPlayer and LocalPlayer:FindFirstChildOfClass("Backpack")
        return (character and character:FindFirstChild("Gun",true)~=nil) or (backpack and backpack:FindFirstChild("Gun",true)~=nil)
    end

    function self:_murderDistance(dropPart)
        local murder=RoleTracker and RoleTracker:GetMurder() or nil
        if not murder or murder==LocalPlayer then return math.huge end
        local character=murder.Character
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        local root=character and character:FindFirstChild("HumanoidRootPart")
        if not root or not humanoid or humanoid.Health<=0 then return math.huge end
        return (root.Position-dropPart.Position).Magnitude
    end

    function self:_destroyESP()
        if self.Highlight then pcall(self.Highlight.Destroy,self.Highlight) self.Highlight=nil end
        if self.Billboard then pcall(self.Billboard.Destroy,self.Billboard) self.Billboard=nil end
    end

    function self:_updateESP(drop)
        if not self.ESPEnabled or not drop or not drop.Parent then
            self:_destroyESP()
            return
        end
        if self.CurrentDrop==drop and self.Highlight and self.Highlight.Parent and self.Billboard and self.Billboard.Parent then return end
        self:_destroyESP()
        local part=self:_part(drop)
        if not part then return end

        local highlight=Instance.new("Highlight")
        highlight.Name="DepHubMM2GunDrop"
        highlight.Adornee=drop
        highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillColor=Color3.fromRGB(80,170,255)
        highlight.FillTransparency=.25
        highlight.OutlineColor=Color3.fromRGB(255,255,255)
        highlight.OutlineTransparency=.15
        highlight.Parent=drop
        self.Highlight=highlight

        local billboard=Instance.new("BillboardGui")
        billboard.Name="DepHubMM2GunDropLabel"
        billboard.Adornee=part
        billboard.AlwaysOnTop=true
        billboard.Size=UDim2.fromOffset(110,26)
        billboard.StudsOffset=Vector3.new(0,2.2,0)
        billboard.Parent=part
        local label=Instance.new("TextLabel")
        label.Size=UDim2.fromScale(1,1)
        label.BackgroundTransparency=1
        label.Text="GUN DROP"
        label.TextColor3=Color3.fromRGB(255,255,255)
        label.TextSize=11
        label.Font=Enum.Font.GothamBold
        label.TextStrokeTransparency=.45
        label.Parent=billboard
        self.Billboard=billboard
    end

    function self:_getDrop()
        local drop=RoleTracker and type(RoleTracker.GetGunDrop)=="function" and RoleTracker:GetGunDrop() or nil
        if drop and drop.Parent then
            self.CurrentDrop=drop
            self.DebugInfo.GunDrop=drop:GetFullName()
            return drop
        end
        self.CurrentDrop=nil
        self.DebugInfo.GunDrop="missing"
        return nil
    end

    function self:_tryPickup()
        if self.Destroyed or not self.AutoPickup or self.Busy then return end
        if os_clock()-self.LastAttempt<self.Cooldown then return end
        if RoundTracker and not RoundTracker:IsRoundActive() then
            self.DebugInfo.LastAction="waiting round"
            return
        end
        if RoleTracker and RoleTracker:GetMurder()==LocalPlayer then
            self.DebugInfo.LastAction="local murder"
            return
        end
        if self:_hasLocalGun() then
            self.DebugInfo.LastAction="already has gun"
            return
        end

        local drop=self:_getDrop()
        local part=self:_part(drop)
        local root=self:_localRoot()
        if not part or not root then return end

        local murderDistance=self:_murderDistance(part)
        self.DebugInfo.MurderDistance=murderDistance==math.huge and -1 or murderDistance
        self.DebugInfo.Safe=murderDistance>self.SafeDistance
        if murderDistance<=self.SafeDistance then
            self.DebugInfo.LastAction="murder near gun"
            return
        end

        self.LastAttempt=os_clock()
        self.Busy=true
        self.DebugInfo.Attempts=self.DebugInfo.Attempts+1
        self.DebugInfo.LastAction="picking gun"
        local token=self.Token
        local origin=root.CFrame

        task.spawn(function()
            local ok,err=pcall(function()
                if self.Destroyed or not self.AutoPickup or token~=self.Token or not part.Parent or not root.Parent then return end
                root.CFrame=part.CFrame*CFrame.new(0,1.4,0)
                if type(firetouchinterest)=="function" then
                    pcall(firetouchinterest,root,part,0)
                    task.wait(0.03)
                    pcall(firetouchinterest,root,part,1)
                end
                task.wait(self.PickupHold)
                if self:_hasLocalGun() or not drop.Parent then
                    self.DebugInfo.Pickups=self.DebugInfo.Pickups+1
                    self.DebugInfo.LastAction="gun collected"
                else
                    self.DebugInfo.LastAction="pickup retry"
                end
            end)
            if not ok then self.DebugInfo.LastError=tostring(err) end
            if root and root.Parent then
                pcall(function() root.CFrame=origin end)
                self.DebugInfo.Returns=self.DebugInfo.Returns+1
            end
            self.Busy=false
        end)
    end

    function self:SetESP(value)
        if self.Destroyed then return false end
        self.ESPEnabled=value==true
        if not self.ESPEnabled then self:_destroyESP() else self:_updateESP(self:_getDrop()) end
        return true
    end

    function self:SetAutoPickup(value)
        if self.Destroyed then return false end
        self.AutoPickup=value==true
        self.Token=self.Token+1
        if not self.AutoPickup then self.Busy=false end
        return true
    end

    function self:SetSafeDistance(value)
        value=tonumber(value)
        if not value then return false end
        self.SafeDistance=math.max(5,math.min(80,value))
        return true
    end

    function self:SetPickupHold(value)
        value=tonumber(value)
        if not value then return false end
        self.PickupHold=math.max(0.05,math.min(0.5,value))
        return true
    end

    function self:GetDebugInfo()
        local out={}
        for k,v in pairs(self.DebugInfo) do out[k]=v end
        out.SafeDistance=self.SafeDistance
        out.PickupHold=self.PickupHold
        out.Busy=self.Busy
        return out
    end

    self.Connections[#self.Connections+1]=RunService.Heartbeat:Connect(function()
        if self.Destroyed then return end
        local drop=self:_getDrop()
        self:_updateESP(drop)
        if self.AutoPickup then self:_tryPickup() end
    end)

    function self:Destroy()
        if self.Destroyed then return end
        self.Destroyed=true
        self.Token=self.Token+1
        self.AutoPickup=false
        self.ESPEnabled=false
        disconnectAll(self.Connections)
        self:_destroyESP()
        self.CurrentDrop=nil
    end

    return self
end

return Factory
