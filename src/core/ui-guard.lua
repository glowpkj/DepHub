local game=game
local type=type
local pcall=pcall
local ipairs=ipairs

local Factory={}

function Factory.new()
    local Players=game:GetService("Players")
    local RunService=game:GetService("RunService")
    local LocalPlayer=Players.LocalPlayer or Players.PlayerAdded:Wait()
    local PlayerGui=LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui",15)

    local self={
        Destroyed=false,
        Started=false,
        Connections={},
        Tracked=setmetatable({},{__mode="k"}),
        Accumulator=0,
        PlayerGui=PlayerGui,
        Target=nil
    }

    local function disconnectAll(list)
        for i=#list,1,-1 do
            local connection=list[i]
            list[i]=nil
            if connection then pcall(connection.Disconnect,connection) end
        end
    end

    function self:_resolveTarget()
        if type(gethui)=="function" then
            local ok,result=pcall(gethui)
            if ok and typeof(result)=="Instance" then
                return result
            end
        end
        return self.PlayerGui
    end

    function self:_isDepHub(gui)
        return gui
            and gui:IsA("ScreenGui")
            and string.find(string.lower(gui.Name),"dephub",1,true)~=nil
    end

    function self:_enforce(gui)
        if self.Destroyed or not self:_isDepHub(gui) or not gui.Parent then return end

        pcall(function()
            gui.Enabled=true
        end)

        pcall(function()
            gui.ResetOnSpawn=false
        end)

        pcall(function()
            gui.DisplayOrder=2147483647
        end)

        pcall(function()
            gui.ZIndexBehavior=Enum.ZIndexBehavior.Global
        end)

        pcall(function()
            gui.OnTopOfCoreBlur=true
        end)

        local target=self.Target or self:_resolveTarget()
        self.Target=target

        if target and target~=self.PlayerGui and gui.Parent~=target then
            pcall(function()
                gui.Parent=target
            end)
        end
    end

    function self:_track(gui)
        if not self:_isDepHub(gui) then return end

        self:_enforce(gui)

        if self.Tracked[gui] then return end
        self.Tracked[gui]=true

        self.Connections[#self.Connections+1]=gui:GetPropertyChangedSignal("Enabled"):Connect(function()
            if not self.Destroyed and gui.Parent and not gui.Enabled then
                self:_enforce(gui)
            end
        end)

        self.Connections[#self.Connections+1]=gui:GetPropertyChangedSignal("DisplayOrder"):Connect(function()
            if not self.Destroyed and gui.Parent and gui.DisplayOrder~=2147483647 then
                self:_enforce(gui)
            end
        end)
    end

    function self:_scan()
        if self.PlayerGui then
            for _,child in ipairs(self.PlayerGui:GetChildren()) do
                self:_track(child)
            end
        end

        local target=self.Target or self:_resolveTarget()
        self.Target=target

        if target and target~=self.PlayerGui then
            for _,child in ipairs(target:GetChildren()) do
                self:_track(child)
            end
        end

        for gui in pairs(self.Tracked) do
            if gui and gui.Parent then
                self:_enforce(gui)
            end
        end
    end

    function self:Start()
        if self.Destroyed or self.Started then return false end

        self.Started=true
        self.Target=self:_resolveTarget()
        self:_scan()

        if self.PlayerGui then
            self.Connections[#self.Connections+1]=self.PlayerGui.ChildAdded:Connect(function(child)
                task.defer(function()
                    if not self.Destroyed then self:_track(child) end
                end)
            end)
        end

        if self.Target and self.Target~=self.PlayerGui then
            self.Connections[#self.Connections+1]=self.Target.ChildAdded:Connect(function(child)
                task.defer(function()
                    if not self.Destroyed then self:_track(child) end
                end)
            end)
        end

        self.Connections[#self.Connections+1]=RunService.Heartbeat:Connect(function(dt)
            if self.Destroyed then return end
            self.Accumulator=self.Accumulator+dt
            if self.Accumulator<0.5 then return end
            self.Accumulator=0
            self:_scan()
        end)

        return true
    end

    function self:Destroy()
        if self.Destroyed then return end

        self.Destroyed=true
        self.Started=false
        disconnectAll(self.Connections)
        self.Tracked=setmetatable({},{__mode="k"})
    end

    return self
end

return Factory
