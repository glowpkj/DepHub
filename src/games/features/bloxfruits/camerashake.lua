local Feature = {}
Feature.__index = Feature

function Feature.new(context)
    return setmetatable({Context = context, State = context.State, Enabled = false}, Feature)
end

function Feature:SetEnabled(enabled)
    if self.State.Destroyed then return false end
    local remote = self.Context.ChangeSetting
    if not remote or not remote:IsA("RemoteEvent") then return false end
    local ok = pcall(function() remote:FireServer("CameraShake", enabled == true) end)
    if ok then
        self.Enabled = enabled == true
        self.State.CameraShakeDisabled = not self.Enabled
    end
    return ok
end

function Feature:Enable() return self:SetEnabled(true) end
function Feature:Disable() return self:SetEnabled(false) end
function Feature:IsEnabled() return self.Enabled end
function Feature:Destroy()
    if not self.Context then return end
    self:Disable()
    self.Context = nil
    self.State = nil
end

return Feature
