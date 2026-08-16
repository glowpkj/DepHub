local Feature = {}
Feature.__index = Feature

local function clamp(value)
    value = tonumber(value) or 1
    if value < 1 then return 1 end
    if value > 100 then return 100 end
    return math.floor(value + 0.5)
end

function Feature.new(context)
    return setmetatable({
        Context = context,
        State = context.State,
        Enabled = false,
        Value = clamp(context.State.Values.DashLength),
        Character = nil,
        CharacterConnections = {},
        RespawnConnection = nil
    }, Feature)
end

function Feature:_disconnectCharacter()
    self.Context.DisconnectAll(self.CharacterConnections)
    self.Character = nil
end

function Feature:_apply(character)
    if not self.Enabled or not character or not character.Parent then return end
    local value = clamp(self.Value)
    pcall(function()
        if character:GetAttribute("DashLength") ~= value then character:SetAttribute("DashLength", value) end
        if character:GetAttribute("DashLengthAir") ~= value then character:SetAttribute("DashLengthAir", value) end
        if character:GetAttribute("DashLengthGround") ~= value then character:SetAttribute("DashLengthGround", value) end
    end)
end

function Feature:_bind(character)
    self:_disconnectCharacter()
    self.Character = character
    if not character then return end
    self:_apply(character)
    for _, name in ipairs({"DashLength", "DashLengthAir", "DashLengthGround"}) do
        self.Context.Connect(self.CharacterConnections, character:GetAttributeChangedSignal(name), function()
            self:_apply(character)
        end)
    end
end

function Feature:SetValue(value)
    self.Value = clamp(value)
    self.State.Values.DashLength = self.Value
    if self.Enabled then self:_apply(self.Character or self.Context.LocalPlayer.Character) end
    return true
end

function Feature:Enable()
    if self.Enabled or self.State.Destroyed then return true end
    self.Enabled = true
    self:_bind(self.Context.LocalPlayer.Character)
    self.RespawnConnection = self.Context.Connect({}, self.Context.LocalPlayer.CharacterAdded, function(character)
        if self.Enabled then self:_bind(character) end
    end)
    return true
end

function Feature:Disable()
    if not self.Enabled then return true end
    self.Enabled = false
    self:_disconnectCharacter()
    if self.RespawnConnection then
        pcall(self.RespawnConnection.Disconnect, self.RespawnConnection)
        self.RespawnConnection = nil
    end
    return true
end

function Feature:IsEnabled() return self.Enabled end
function Feature:GetValue() return self.Value end

function Feature:Destroy()
    if not self.Context then return end
    self:Disable()
    self.Context = nil
    self.State = nil
end

return Feature
