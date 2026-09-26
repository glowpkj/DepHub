local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")

local Movement={}
Movement.__index=Movement

function Movement.new(config)
    config=config or {}

    return setmetatable({
        Player=Players.LocalPlayer,
        Speed=tonumber(config.Speed) or 45,
        MinDuration=tonumber(config.MinDuration) or 0.05,
        MaxSegmentDuration=tonumber(config.MaxSegmentDuration) or 1.1,
        SegmentPause=tonumber(config.SegmentPause) or 0.08,
        UsePhysics=config.UsePhysics~=false,
        Tween=nil,
        SteppedConnection=nil,
        HeartbeatConnection=nil,
        ActiveHumanoid=nil,
        ActiveRoot=nil,
        CollisionState={},
        ControlState=nil,
        LastClearCFrame=nil,
        Moving=false,
        MoveToken=0,
        Destroyed=false
    },Movement)
end

function Movement:_character()
    local character=self.Player and self.Player.Character
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    local root=character and character:FindFirstChild("HumanoidRootPart")

    if not humanoid or humanoid.Health<=0 or not root then
        return nil
    end

    return humanoid,root
end

function Movement:_toCFrame(target)
    local kind=typeof(target)

    if kind=="CFrame" then
        return target
    elseif kind=="Vector3" then
        return CFrame.new(target)
    elseif kind=="Instance" and target:IsA("BasePart") then
        return target.CFrame
    end

    return nil
end

function Movement:_isRootClear(cframe,character)
    local params=OverlapParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={character}

    local ok,parts=pcall(
        Workspace.GetPartBoundsInBox,
        Workspace,
        cframe,
        Vector3.new(1.8,2,1.8),
        params
    )

    if not ok then
        return true
    end

    for _,part in ipairs(parts) do
        if part:IsA("BasePart") and part.CanCollide then
            return false
        end
    end

    return true
end

function Movement:_noclip(character)
    for _,part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            if self.CollisionState[part]==nil then
                self.CollisionState[part]=part.CanCollide
            end
            part.CanCollide=false
        end
    end
end

function Movement:_applyTravelState(humanoid,root)
    self.CollisionState={}
    self.ControlState={
        WalkSpeed=humanoid.WalkSpeed,
        JumpPower=humanoid.JumpPower,
        JumpHeight=humanoid.JumpHeight,
        AutoRotate=humanoid.AutoRotate
    }

    humanoid.WalkSpeed=0
    humanoid.JumpPower=0
    humanoid.JumpHeight=0
    humanoid.AutoRotate=false
    self:_noclip(root.Parent)
end

function Movement:_restoreTravelState(humanoid)
    for part,canCollide in pairs(self.CollisionState) do
        if part and part.Parent then
            part.CanCollide=canCollide
        end
    end
    table.clear(self.CollisionState)

    local state=self.ControlState
    self.ControlState=nil

    if humanoid and humanoid.Parent and state then
        humanoid.WalkSpeed=state.WalkSpeed
        humanoid.JumpPower=state.JumpPower
        humanoid.JumpHeight=state.JumpHeight
        humanoid.AutoRotate=state.AutoRotate
    end

    if humanoid and humanoid.Parent and humanoid.Health>0 and self.UsePhysics and humanoid:GetState()==Enum.HumanoidStateType.Physics then
        pcall(humanoid.ChangeState,humanoid,Enum.HumanoidStateType.GettingUp)
    end
end

function Movement:Stop()
    self.MoveToken+=1

    local tween=self.Tween
    local stepped=self.SteppedConnection
    local heartbeat=self.HeartbeatConnection
    local humanoid=self.ActiveHumanoid
    local root=self.ActiveRoot
    local lastClear=self.LastClearCFrame

    self.Tween=nil
    self.SteppedConnection=nil
    self.HeartbeatConnection=nil
    self.ActiveHumanoid=nil
    self.ActiveRoot=nil
    self.LastClearCFrame=nil
    self.Moving=false

    if tween then pcall(tween.Cancel,tween) end
    if stepped then pcall(stepped.Disconnect,stepped) end
    if heartbeat then pcall(heartbeat.Disconnect,heartbeat) end

    if root and root.Parent then
        if not self:_isRootClear(root.CFrame,root.Parent) and lastClear then
            root.CFrame=lastClear
        end

        root.AssemblyLinearVelocity=Vector3.zero
        root.AssemblyAngularVelocity=Vector3.zero
    end

    self:_restoreTravelState(humanoid)
    return true
end

function Movement:IsMoving()
    return self.Moving==true
end

function Movement:FlyTo(target,speed)
    if self.Destroyed then
        return false,"destroyed"
    end

    local goal=self:_toCFrame(target)
    if not goal then
        return false,"invalid target"
    end

    local humanoid,root=self:_character()
    if not humanoid or not root then
        return false,"character unavailable"
    end

    local moveSpeed=tonumber(speed) or self.Speed
    if moveSpeed<=0 then
        return false,"invalid speed"
    end

    self:Stop()
    local token=self.MoveToken
    local distance=(root.Position-goal.Position).Magnitude

    if distance<=0.05 then
        return true
    end

    self.Moving=true
    self.ActiveHumanoid=humanoid
    self.ActiveRoot=root
    self:_applyTravelState(humanoid,root)

    if self:_isRootClear(root.CFrame,root.Parent) then
        self.LastClearCFrame=root.CFrame
    end

    root.AssemblyLinearVelocity=Vector3.zero
    root.AssemblyAngularVelocity=Vector3.zero

    if self.UsePhysics then
        pcall(humanoid.ChangeState,humanoid,Enum.HumanoidStateType.Physics)
    end

    self.SteppedConnection=RunService.Stepped:Connect(function()
        if token~=self.MoveToken or not root.Parent then return end

        self:_noclip(root.Parent)
        humanoid.WalkSpeed=0
        humanoid.JumpPower=0
        humanoid.JumpHeight=0
        humanoid.AutoRotate=false
    end)

    local lastClearCheck=0

    self.HeartbeatConnection=RunService.Heartbeat:Connect(function()
        if token~=self.MoveToken then return end

        if not root.Parent or humanoid.Health<=0 then
            self:Stop()
            return
        end

        root.AssemblyLinearVelocity=Vector3.zero
        root.AssemblyAngularVelocity=Vector3.zero

        local now=os.clock()
        if now-lastClearCheck>=0.15 then
            lastClearCheck=now

            if self:_isRootClear(root.CFrame,root.Parent) then
                self.LastClearCFrame=root.CFrame
            end
        end
    end)

    local completed=true

    while token==self.MoveToken do
        local delta=goal.Position-root.Position
        local remaining=delta.Magnitude

        if remaining<=0.05 then
            root.CFrame=goal
            break
        end

        local segmentDuration=math.min(remaining/moveSpeed,self.MaxSegmentDuration)
        local segmentDistance=math.min(remaining,moveSpeed*self.MaxSegmentDuration)
        local nextPosition=root.Position+delta.Unit*segmentDistance
        local segmentGoal=CFrame.new(nextPosition)*goal.Rotation

        local ok,tween=pcall(function()
            return TweenService:Create(
                root,
                TweenInfo.new(math.max(segmentDuration,self.MinDuration),Enum.EasingStyle.Linear),
                {CFrame=segmentGoal}
            )
        end)

        if not ok then
            self:Stop()
            return false,tostring(tween)
        end

        self.Tween=tween
        tween:Play()

        local playbackState=tween.Completed:Wait()

        if token~=self.MoveToken then
            return false,"cancelled"
        end

        if playbackState~=Enum.PlaybackState.Completed then
            completed=false
            break
        end

        self.Tween=nil
        root.AssemblyLinearVelocity=Vector3.zero
        root.AssemblyAngularVelocity=Vector3.zero

        if remaining>segmentDistance+0.05 and self.SegmentPause>0 then
            task.wait(self.SegmentPause)
        end
    end

    if token~=self.MoveToken then
        return false,"cancelled"
    end

    self:Stop()
    return completed
end

function Movement:SetSpeed(value)
    value=tonumber(value)
    if not value or value<=0 then
        return false
    end

    self.Speed=value
    return true
end

function Movement:Destroy()
    if self.Destroyed then return end
    self:Stop()
    self.Destroyed=true
end

return Movement
