-- Owned tween/hold and character-only noclip. No map edits or game mover writes.
local Module={}
function Module.new(context)
    context=context or {}
    local self={Root=nil,Character=nil,Speed=1000,Noclip=true,Collisions={},Destroyed=false}
    local function cancelTween()
        if self.Completed then self.Completed:Disconnect();self.Completed=nil end
        local tween=self.Tween;self.Tween=nil
        if tween then tween:Cancel() end
        self.Arrived=false
    end
    local function restoreCollisions()
        for part,value in pairs(self.Collisions) do
            if part.Parent then pcall(function() part.CanCollide=value end) end
        end
        self.Collisions={}
    end
    local function noclip()
        if not self.Noclip or not self.Character then return end
        for part,value in pairs(self.Collisions) do
            if not part:IsDescendantOf(self.Character) then
                if part.Parent then pcall(function() part.CanCollide=value end) end
                self.Collisions[part]=nil
            end
        end
        for _,part in ipairs(self.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                if self.Collisions[part]==nil then self.Collisions[part]=part.CanCollide end
                part.CanCollide=false
            end
        end
    end
    function self:Stop()
        cancelTween()
        if self.Step then self.Step:Disconnect();self.Step=nil end
        if self.Hold then self.Hold:Destroy();self.Hold=nil end
        restoreCollisions()
        if self.Root and self.Root.Parent then
            if self.Rotation then pcall(function() self.Root.CFrame=CFrame.new(self.Root.Position)*self.Rotation end) end
            pcall(function() self.Root.AssemblyLinearVelocity=self.Velocity end)
            pcall(function() self.Root.AssemblyAngularVelocity=self.AngularVelocity end)
        end
        if self.Humanoid and self.Humanoid.Parent then pcall(function() self.Humanoid.AutoRotate=self.AutoRotate end) end
        self.Humanoid=nil;self.Rotation=nil
        self.Root=nil;self.Character=nil;self.Target=nil;self.TargetModel=nil;self.Goal=nil
    end
    function self:SetSpeed(value)
        value=tonumber(value)
        if self.Destroyed or not value or value~=value or value<50 or value>2000 then return false end
        if self.Speed~=value then self.Speed=value;cancelTween();self.Goal=nil end
        return true
    end
    function self:SetNoclip(value)
        if self.Destroyed then return false end
        self.Noclip=value==true
        if self.Noclip then noclip() else restoreCollisions() end
        return true
    end
    function self:Move(root,target,height,targetModel)
        if self.Destroyed then return false end
        if not root.Parent or not target.Parent then self:Stop();return false end
        if self.Root~=root then
            self:Stop();self.Root=root;self.Character=root.Parent
            self.Velocity=root.AssemblyLinearVelocity;self.AngularVelocity=root.AssemblyAngularVelocity
            self.Rotation=root.CFrame.Rotation
            self.Humanoid=self.Character:FindFirstChildOfClass("Humanoid")
            if self.Humanoid then self.AutoRotate=self.Humanoid.AutoRotate;self.Humanoid.AutoRotate=false end
            self.Hold=Instance.new("BodyVelocity")
            self.Hold.Name="DepHub_AOTR_FarmHold"
            self.Hold.MaxForce=Vector3.new(1000000,1000000,1000000)
            self.Hold.Velocity=Vector3.new(0,0,0);self.Hold.Parent=root
            noclip()
            local run=context.RunService or game:GetService("RunService")
            self.Step=run.Stepped:Connect(function()
                local ok,err=pcall(function()
                    local humanoid=self.Character and self.Character:FindFirstChildOfClass("Humanoid")
                    local targetHumanoid=self.TargetModel and self.TargetModel:FindFirstChildOfClass("Humanoid")
                    if not self.Root or not self.Root.Parent or self.Root.Anchored or not humanoid or humanoid.Health<=0
                        or (self.Target and not self.Target.Parent)
                        or (self.TargetModel and (not self.TargetModel.Parent or not targetHumanoid or targetHumanoid.Health<=0))
                        or (context.Player and context.Player.Character~=self.Character) then self:Stop();return end
                    noclip()
                    self.Root.AssemblyAngularVelocity=Vector3.new(0,0,0)
                end)
                if not ok then self:Stop();if context.Warn then context.Warn("movement: "..tostring(err)) end end
            end)
        end
        noclip()
        self.TargetModel=targetModel
        local goal=target.Position+Vector3.new(0,height,0)
        local distance=(goal-root.Position).Magnitude
        if distance~=distance or distance>10000000 then self:Stop();error("Invalid movement distance") end
        if self.Target==target and self.Goal and (goal-self.Goal.Position).Magnitude<8 then
            if self.Tween or (self.Arrived and distance<4) then return true end
        end
        cancelTween();self.Target=target
        -- The target is directly below the hover point; use a nonparallel up axis.
        self.Goal=CFrame.lookAt(goal,target.Position,Vector3.new(0,0,1))
        if distance<0.5 then root.CFrame=self.Goal;self.Arrived=true;return true end
        local service=context.TweenService or game:GetService("TweenService")
        local tween=service:Create(root,TweenInfo.new(math.max(0.03,distance/self.Speed),Enum.EasingStyle.Linear),{CFrame=self.Goal})
        self.Tween=tween
        self.Completed=tween.Completed:Connect(function(state)
            if self.Tween~=tween then return end
            self.Tween=nil;self.Arrived=state==Enum.PlaybackState.Completed
            if self.Completed then self.Completed:Disconnect();self.Completed=nil end
        end)
        tween:Play()
        return true
    end
    function self:Destroy() if not self.Destroyed then self:Stop();self.Destroyed=true end end
    return self
end
return Module
