local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Visual = {}
Visual.__index = Visual

Visual.Id = "DepHub_JumpAnywhere"
Visual.MinPower = 50
Visual.MaxPower = 500
Visual.DefaultPower = 120
Visual.BypassStates = {
    Enum.HumanoidStateType.Jumping,
    Enum.HumanoidStateType.Climbing,
}

local function getHumanoid()
    local player = Players.LocalPlayer
    local character = player and player.Character
    return character and character:FindFirstChildOfClass("Humanoid") or nil
end

function Visual.new()
    return setmetatable({
        Active = false,
        Power = Visual.DefaultPower,
        Humanoid = nil,
        Original = nil,
        Connection = nil,
    }, Visual)
end

function Visual:_capture(humanoid)
    local original = {
        JumpPower = humanoid.JumpPower,
        UseJumpPower = humanoid.UseJumpPower,
        JumpHeight = humanoid.JumpHeight,
        States = {},
    }

    for _, state in ipairs(Visual.BypassStates) do
        local ok, enabled = pcall(humanoid.GetStateEnabled, humanoid, state)
        if ok then
            original.States[state] = enabled
        end
    end

    return original
end

function Visual:_restore()
    local humanoid = self.Humanoid
    local original = self.Original
    if not humanoid or not original then return end

    pcall(function()
        if original.JumpPower ~= nil then humanoid.JumpPower = original.JumpPower end
        if original.UseJumpPower ~= nil then humanoid.UseJumpPower = original.UseJumpPower end
        if original.JumpHeight ~= nil then humanoid.JumpHeight = original.JumpHeight end
    end)

    for state, enabled in pairs(original.States) do
        pcall(humanoid.SetStateEnabled, humanoid, state, enabled)
    end

    self.Humanoid = nil
    self.Original = nil
end

function Visual:_apply()
    if not self.Active then return end

    local humanoid = getHumanoid()
    if humanoid ~= self.Humanoid then
        self:_restore()
        if not humanoid then return end
        self.Humanoid = humanoid
        self.Original = self:_capture(humanoid)
    end

    if not humanoid then return end

    pcall(function()
        humanoid.UseJumpPower = true
        humanoid.JumpPower = self.Power
        humanoid.JumpHeight = math.max(tonumber(self.Original.JumpHeight) or 0, 7.2)
    end)

    for _, state in ipairs(Visual.BypassStates) do
        pcall(humanoid.SetStateEnabled, humanoid, state, true)
    end
end

function Visual:Start()
    if self.Active then return false end
    self.Active = true
    self:_apply()
    self.Connection = RunService.Heartbeat:Connect(function()
        self:_apply()
    end)
    return true
end

function Visual:Stop()
    if not self.Active and not self.Humanoid then return false end
    self.Active = false

    if self.Connection then
        pcall(self.Connection.Disconnect, self.Connection)
        self.Connection = nil
    end

    self:_restore()
    return true
end

function Visual:SetPower(value)
    local numeric = tonumber(value)
    if not numeric then return false end
    self.Power = math.clamp(math.floor(numeric + 0.5), Visual.MinPower, Visual.MaxPower)
    if self.Active then self:_apply() end
    return true
end

function Visual:Destroy()
    self:Stop()
    return true
end

return Visual
