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
    local Workspace=context.Workspace or game:GetService("Workspace")
    local LocalPlayer=context.LocalPlayer or Players.LocalPlayer
    local RoundTracker=context.RoundTracker
    local RoleTracker=context.RoleTracker

    local self={
        Enabled=false,
        Destroyed=false,
        Connections={},
        Containers=setmetatable({},{__mode="k"}),
        Coins=setmetatable({},{__mode="k"}),
        IgnoreUntil=setmetatable({},{__mode="k"}),
        Delay=tonumber(context.CoinDelay) or 0.05,
        SafeDistance=tonumber(context.CoinSafeDistance) or 18,
        Token=0,
        LastCoin=nil,
        DebugInfo={Runtime="idle",Containers=0,Coins=0,Teleports=0,Paused="none",LastCoin="none",LastTargetDistance=0,LastError="none"}
    }

    function self:_root()
        local character=LocalPlayer and LocalPlayer.Character
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        local root=character and character:FindFirstChild("HumanoidRootPart")
        if not humanoid or humanoid.Health<=0 or not root then return nil end
        return root
    end

    function self:_murderTooClose(root)
        if not RoleTracker then return false end
        local murder=RoleTracker:GetMurder()
        if not murder or murder==LocalPlayer then return false end
        local character=murder.Character
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        local murderRoot=character and character:FindFirstChild("HumanoidRootPart")
        if not murderRoot or not humanoid or humanoid.Health<=0 then return false end
        return (murderRoot.Position-root.Position).Magnitude<=self.SafeDistance
    end

    function self:_addCoin(object)
        if not object or not object.Parent or not object:IsA("BasePart") then return end
        local parent=object.Parent
        local insideContainer=false
        while parent and parent~=Workspace do
            if parent.Name=="CoinContainer" then insideContainer=true break end
            parent=parent.Parent
        end
        if insideContainer then self.Coins[object]=true end
    end

    function self:_registerContainer(container)
        if not container or self.Containers[container] then return end
        self.Containers[container]=true
        for _,object in ipairs(container:GetDescendants()) do self:_addCoin(object) end
    end

    function self:_initialScan()
        self.Containers=setmetatable({},{__mode="k"})
        self.Coins=setmetatable({},{__mode="k"})
        for _,object in ipairs(Workspace:GetDescendants()) do
            if object.Name=="CoinContainer" then self:_registerContainer(object) end
        end
    end

    function self:_refreshCounts()
        local containers=0
        for container in pairs(self.Containers) do
            if container and container.Parent then containers=containers+1 else self.Containers[container]=nil end
        end
        local coins=0
        for coin in pairs(self.Coins) do
            if coin and coin.Parent then coins=coins+1 else self.Coins[coin]=nil self.IgnoreUntil[coin]=nil end
        end
        self.DebugInfo.Containers=containers
        self.DebugInfo.Coins=coins
    end

    function self:_nearest(root)
        local now=os_clock()
        local best=nil
        local bestDistance=math.huge
        for coin in pairs(self.Coins) do
            if coin and coin.Parent then
                local ignored=self.IgnoreUntil[coin]
                if not ignored or now>=ignored then
                    local distance=(coin.Position-root.Position).Magnitude
                    if distance<bestDistance then
                        best=coin
                        bestDistance=distance
                    end
                end
            end
        end
        return best,bestDistance
    end

    function self:_teleportCoin(root,coin,distance)
        if not root or not root.Parent or not coin or not coin.Parent then return false end
        self.LastCoin=coin
        self.DebugInfo.LastCoin=coin:GetFullName()
        self.DebugInfo.LastTargetDistance=distance or 0
        self.IgnoreUntil[coin]=os_clock()+0.18
        local ok,err=pcall(function()
            root.CFrame=coin.CFrame*CFrame.new(0,1.8,0)
        end)
        if ok then
            self.DebugInfo.Teleports=self.DebugInfo.Teleports+1
            self.DebugInfo.LastError="none"
            return true
        end
        self.DebugInfo.LastError=tostring(err)
        return false
    end

    function self:_run(token)
        while self.Enabled and not self.Destroyed and token==self.Token do
            if RoundTracker and not RoundTracker:IsRoundActive() then
                self.DebugInfo.Paused="lobby"
                task.wait(0.08)
            else
                local root=self:_root()
                if not root then
                    self.DebugInfo.Paused="dead"
                    task.wait(0.08)
                elseif self:_murderTooClose(root) then
                    self.DebugInfo.Paused="murder nearby"
                    task.wait(0.06)
                else
                    self:_refreshCounts()
                    local coin,distance=self:_nearest(root)
                    if not coin then
                        self.DebugInfo.Paused="no coins"
                        task.wait(0.06)
                    else
                        self.DebugInfo.Paused="none"
                        self:_teleportCoin(root,coin,distance)
                        task.wait(self.Delay)
                    end
                end
            end
        end
    end

    function self:SetSafeDistance(value)
        value=tonumber(value)
        if not value then return false end
        self.SafeDistance=math.max(0,math.min(80,value))
        return true
    end

    function self:SetDelay(value)
        value=tonumber(value)
        if not value then return false end
        self.Delay=math.max(0.02,math.min(0.3,value))
        return true
    end

    function self:GetDebugInfo()
        self:_refreshCounts()
        local out={}
        for k,v in pairs(self.DebugInfo) do out[k]=v end
        out.Delay=self.Delay
        out.SafeDistance=self.SafeDistance
        return out
    end

    function self:Enable()
        if self.Destroyed then return false end
        if self.Enabled then return true end
        self.Enabled=true
        self.DebugInfo.Runtime="running"
        self:_initialScan()
        self.Connections[#self.Connections+1]=Workspace.DescendantAdded:Connect(function(object)
            if object.Name=="CoinContainer" then self:_registerContainer(object) else self:_addCoin(object) end
        end)
        self.Connections[#self.Connections+1]=Workspace.DescendantRemoving:Connect(function(object)
            if self.Containers[object] then self.Containers[object]=nil end
            if self.Coins[object] then self.Coins[object]=nil self.IgnoreUntil[object]=nil end
        end)
        self.Token=self.Token+1
        local token=self.Token
        task.spawn(function()
            local ok,err=pcall(self._run,self,token)
            if not ok then self.DebugInfo.LastError=tostring(err) end
        end)
        return true
    end

    function self:Disable()
        if not self.Enabled then return true end
        self.Enabled=false
        self.Token=self.Token+1
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
        self.Containers={}
        self.Coins={}
        self.IgnoreUntil={}
    end

    return self
end

return Factory
