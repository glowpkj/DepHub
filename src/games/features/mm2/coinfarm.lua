local game=game
local type=type
local pairs=pairs
local ipairs=ipairs
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
    local Workspace=context.Workspace or game:GetService("Workspace")
    local LocalPlayer=context.LocalPlayer or Players.LocalPlayer
    local RoundTracker=context.RoundTracker
    local RoleTracker=context.RoleTracker

    local self={
        Enabled=false,
        Destroyed=false,
        Connections={},
        Interval=tonumber(context.CoinInterval) or 0.14,
        SafeDistance=tonumber(context.CoinSafeDistance) or 18,
        LastMove=0,
        LastCoin=nil,
        DebugInfo={Runtime="idle",Containers=0,Coins=0,Teleports=0,Paused="none",LastCoin="none",LastError="none"}
    }

    function self:_root()
        local character=LocalPlayer and LocalPlayer.Character
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        local root=character and character:FindFirstChild("HumanoidRootPart")
        if not humanoid or humanoid.Health<=0 then return nil end
        return root
    end

    function self:_murderTooClose(root)
        if not RoleTracker then return false end
        local murder=RoleTracker:GetMurder()
        if not murder or murder==LocalPlayer then return false end
        local character=murder.Character
        local murderRoot=character and character:FindFirstChild("HumanoidRootPart")
        if not murderRoot then return false end
        return (murderRoot.Position-root.Position).Magnitude<=self.SafeDistance
    end

    function self:_coins(root)
        local coins={}
        local containers=0
        for _,object in ipairs(Workspace:GetDescendants()) do
            if object.Name=="CoinContainer" then
                containers=containers+1
                for _,descendant in ipairs(object:GetDescendants()) do
                    if descendant:IsA("BasePart") and descendant.Parent then
                        coins[#coins+1]=descendant
                    end
                end
            end
        end
        self.DebugInfo.Containers=containers
        self.DebugInfo.Coins=#coins
        table.sort(coins,function(a,b)
            if not a.Parent then return false end
            if not b.Parent then return true end
            return (a.Position-root.Position).Magnitude<(b.Position-root.Position).Magnitude
        end)
        return coins
    end

    function self:_step()
        if self.Destroyed or not self.Enabled then return end
        if os_clock()-self.LastMove<self.Interval then return end

        if RoundTracker and not RoundTracker:IsRoundActive() then
            self.DebugInfo.Paused="lobby"
            return
        end

        local root=self:_root()
        if not root then
            self.DebugInfo.Paused="dead"
            return
        end

        if self:_murderTooClose(root) then
            self.DebugInfo.Paused="murder nearby"
            return
        end

        local coins=self:_coins(root)
        local coin=coins[1]
        if not coin or not coin.Parent then
            self.DebugInfo.Paused="no coins"
            return
        end

        self.DebugInfo.Paused="none"
        self.LastMove=os_clock()
        self.LastCoin=coin
        self.DebugInfo.LastCoin=coin:GetFullName()

        local ok,err=pcall(function()
            root.CFrame=coin.CFrame*CFrame.new(0,2.2,0)
        end)
        if ok then
            self.DebugInfo.Teleports=self.DebugInfo.Teleports+1
            self.DebugInfo.LastError="none"
        else
            self.DebugInfo.LastError=tostring(err)
        end
    end

    function self:SetSafeDistance(value)
        value=tonumber(value)
        if not value then return false end
        self.SafeDistance=math.max(0,math.min(80,value))
        return true
    end

    function self:SetInterval(value)
        value=tonumber(value)
        if not value then return false end
        self.Interval=math.max(0.05,math.min(1,value))
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
        self.Connections[#self.Connections+1]=RunService.Heartbeat:Connect(function()
            local ok,err=pcall(self._step,self)
            if not ok then self.DebugInfo.LastError=tostring(err) end
        end)
        return true
    end

    function self:Disable()
        if not self.Enabled then return true end
        self.Enabled=false
        self.DebugInfo.Runtime="idle"
        disconnectAll(self.Connections)
        self.LastCoin=nil
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
