local Feature = {}
Feature.__index = Feature

function Feature.new(context)
    return setmetatable({
        Context = context,
        State = context.State,
        Enabled = false,
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
    pcall(function()
        if character:GetAttribute("FlashstepCooldown") ~= 1 then
            character:SetAttribute("FlashstepCooldown", 1)
        end
    end)
end

function Feature:_bind(character)
    self:_disconnectCharacter()
    self.Character = character
    if not character then return end
    self:_apply(character)
    self.Context.Connect(self.CharacterConnections, character:GetAttributeChangedSignal("FlashstepCooldown"), function()
        self:_apply(character)
    end)
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
    local character = self.Character
    self:_disconnectCharacter()
    if self.RespawnConnection then
        pcall(self.RespawnConnection.Disconnect, self.RespawnConnection)
        self.RespawnConnection = nil
    end
    if character and character.Parent then
        pcall(function()
            character:SetAttribute("FlashstepCooldown", 0)
        end)
    end
    return true
end

function Feature:IsEnabled() return self.Enabled end

function Feature:Destroy()
    if not self.Context then return end
    self:Disable()
    self.Context = nil
    self.State = nil
end

return Feature
