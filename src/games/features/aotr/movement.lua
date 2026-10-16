-- Own movers only. No map deletion, noclip, or writes to the game's BV/BG.
local Module={}
function Module.new()
    local self={Root=nil,Position=nil,Gyro=nil}
    function self:Stop()
        for _,key in ipairs({"Position","Gyro"}) do
            local instance=self[key];self[key]=nil
            if instance then pcall(function() instance:Destroy() end) end
        end
        if self.Root and self.Root.Parent then
            pcall(function() self.Root.AssemblyLinearVelocity=self.Velocity end)
            pcall(function() self.Root.AssemblyAngularVelocity=self.AngularVelocity end)
        end
        self.Root=nil
    end
    function self:Move(root,target,height)
        if self.Root~=root then
            self:Stop()
            self.Root=root
            self.Velocity=root.AssemblyLinearVelocity
            self.AngularVelocity=root.AssemblyAngularVelocity
            self.Position=Instance.new("BodyPosition")
            self.Position.Name="DepHub_AOTR_FarmPosition"
            self.Position.MaxForce=Vector3.new(5500,5500,5500)
            self.Position.P=1000;self.Position.D=1000
            self.Position.Parent=root
            self.Gyro=Instance.new("BodyGyro")
            self.Gyro.Name="DepHub_AOTR_FarmGyro"
            self.Gyro.MaxTorque=Vector3.new(5500,5500,5500)
            self.Gyro.Parent=root
        end
        local goal=target.Position+Vector3.new(0,height,0)
        local delta=goal-root.Position
        -- Limit each commanded destination to avoid unbounded mover acceleration.
        self.Position.Position=root.Position+(delta.Magnitude>30 and delta.Unit*30 or delta)
        if (target.Position-root.Position).Magnitude>0.01 then self.Gyro.CFrame=CFrame.new(root.Position,target.Position) end
    end
    function self:Destroy() self:Stop() end
    return self
end
return Module
