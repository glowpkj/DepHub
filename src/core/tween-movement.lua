local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local RunService=game:GetService("RunService")

local LocalPlayer=Players.LocalPlayer

local Movement={}
Movement.__index=Movement

function Movement.new(config)
    config=config or {}

    return setmetatable({
        Speed=tonumber(config.Speed) or 45,
        MinDuration=tonumber(config.MinDuration) or 0.05,
        UsePhysics=config.UsePhysics~=false,
        Tween=nil,
        VelocityConnection=nil,
        ActiveHumanoid=nil,
        ActiveRoot=nil,
        CollisionState={},
        ControlState=nil,
        Moving=false,
        MoveToken=0,
        Destroyed=false
    },Movement)
end

function Movement:_character()
    local character=LocalPlayer and LocalPlayer.Character
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    local root=character and character:FindFirstChild("HumanoidRootPart")

    if not humanoid or humanoid.Health<=0 or not root then
        return nil
    end

    return humanoid,root
end

function Movement:_toCFrame(target)
    local targetType=typeof(target)

    if targetType=="CFrame" then
        return target
    end

    if targetType=="Vector3" then
        return CFrame.new(target)
    end

    if targetType=="Instance" and target:IsA("BasePart") then
        return target.CFrame
    end

    return nil
end

function Movement:_applyTravelState(humanoid,root)
    local character=root and root.Parent
    if not character then return end

    self.CollisionState={}
    for _,object in ipairs(character:GetDescendants()) do
        if object:IsA("BasePart") then
            self.CollisionState[object]=object.CanCollide
            object.CanCollide=false
        end
    end

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
end

function Movement:_restoreHumanoid(humanoid)
    if not humanoid or not humanoid.Parent or humanoid.Health<=0 then return end

    if self.UsePhysics and humanoid:GetState()==Enum.HumanoidStateType.Physics then
        pcall(humanoid.ChangeState,humanoid,Enum.HumanoidStateType.GettingUp)
    end
end

function Movement:Stop()
    self.MoveToken+=1

    local tween=self.Tween
    local connection=self.VelocityConnection
    local humanoid=self.ActiveHumanoid

    self.Tween=nil
    self.VelocityConnection=nil
    self.ActiveHumanoid=nil
    self.ActiveRoot=nil
    self.Moving=false

    if tween then
        pcall(tween.Cancel,tween)
    end

    if connection then
        pcall(connection.Disconnect,connection)
    end

    self:_restoreHumanoid(humanoid)
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

    local targetCFrame=self:_toCFrame(target)
    if not targetCFrame then
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

    local distance=(root.Position-targetCFrame.Position).Magnitude
    if distance<=0.05 then
        return true
    end

    local duration=math.max(distance/moveSpeed,self.MinDuration)

    self.Moving=true
    self.ActiveHumanoid=humanoid
    self.ActiveRoot=root
    self:_applyTravelState(humanoid,root)

    root.AssemblyLinearVelocity=Vector3.zero
    root.AssemblyAngularVelocity=Vector3.zero

    if self.UsePhysics then
        pcall(humanoid.ChangeState,humanoid,Enum.HumanoidStateType.Physics)
    end

    local connection
    connection=RunService.Stepped:Connect(function()
        if self.MoveToken~=token or not root.Parent then return end

        local character=root.Parent

        for _,object in ipairs(character:GetDescendants()) do
            if object:IsA("BasePart") then
                if self.CollisionState[object]==nil then
                    self.CollisionState[object]=object.CanCollide
                end
                object.CanCollide=false
            end
        end

        humanoid.WalkSpeed=0
        humanoid.JumpPower=0
        humanoid.JumpHeight=0
        humanoid.AutoRotate=false
        root.AssemblyLinearVelocity=Vector3.zero
        root.AssemblyAngularVelocity=Vector3.zero
    end)

    self.VelocityConnection=connection

    local tween=TweenService:Create(
        root,
        TweenInfo.new(duration,Enum.EasingStyle.Linear),
        {CFrame=targetCFrame}
    )

    self.Tween=tween
    tween:Play()

    local playbackState=tween.Completed:Wait()

    if self.MoveToken~=token then
        return false,"cancelled"
    end

    if self.VelocityConnection==connection then
        pcall(connection.Disconnect,connection)
        self.VelocityConnection=nil
    end

    if self.Tween==tween then
        self.Tween=nil
    end

    self.ActiveHumanoid=nil
    self.ActiveRoot=nil
    self.Moving=false
    self:_restoreHumanoid(humanoid)
    self:_restoreTravelState(humanoid)

    if playbackState==Enum.PlaybackState.Completed then
        return true
    end

    return false,"cancelled"
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
