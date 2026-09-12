local game=game
local type=type
local tonumber=tonumber
local typeof=typeof

local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local RunService=game:GetService("RunService")

local LocalPlayer=Players.LocalPlayer

local Movement={}
Movement.__index=Movement

function Movement.new(config)
    config=config or {}

    return setmetatable({
        Speed=tonumber(config.Speed) or 120,
        MinDuration=tonumber(config.MinDuration) or 0.05,
        Tween=nil,
        VelocityConnection=nil,
        Moving=false,
        Destroyed=false
    },Movement)
end

function Movement:_root()
    local character=LocalPlayer and LocalPlayer.Character
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    local root=character and character:FindFirstChild("HumanoidRootPart")

    if not humanoid or humanoid.Health<=0 or not root then
        return nil
    end

    return root
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

function Movement:Stop()
    if self.Tween then
        pcall(self.Tween.Cancel,self.Tween)
        self.Tween=nil
    end

    if self.VelocityConnection then
        pcall(self.VelocityConnection.Disconnect,self.VelocityConnection)
        self.VelocityConnection=nil
    end

    self.Moving=false
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

    local root=self:_root()
    if not root then
        return false,"character unavailable"
    end

    self:Stop()

    local moveSpeed=tonumber(speed) or self.Speed
    if moveSpeed<=0 then
        return false,"invalid speed"
    end

    local distance=(root.Position-targetCFrame.Position).Magnitude
    local duration=math.max(distance/moveSpeed,self.MinDuration)

    self.Moving=true
    self.VelocityConnection=RunService.Heartbeat:Connect(function()
        if not self.Moving or not root.Parent then return end
        root.AssemblyLinearVelocity=Vector3.zero
        root.AssemblyAngularVelocity=Vector3.zero
    end)

    local tween=TweenService:Create(
        root,
        TweenInfo.new(duration,Enum.EasingStyle.Linear,Enum.EasingDirection.Out),
        {CFrame=targetCFrame}
    )

    self.Tween=tween
    tween:Play()

    local playbackState=tween.Completed:Wait()

    if self.Tween==tween then
        self.Tween=nil
    end

    if self.VelocityConnection then
        pcall(self.VelocityConnection.Disconnect,self.VelocityConnection)
        self.VelocityConnection=nil
    end

    self.Moving=false

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
