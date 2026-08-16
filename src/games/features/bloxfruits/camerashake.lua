local Feature = {}
Feature.__index = Feature

function Feature.new(context)
    return setmetatable({Context = context, State = context.State, Enabled = false}, Feature)
end

local function inspect(instance, label)
    if not instance or type(instance.GetAttributes) ~= "function" then return end
    local attributes = instance:GetAttributes()
    for name, value in pairs(attributes) do
        local lowered = string.lower(tostring(name))
        if string.find(lowered, "camera") or string.find(lowered, "shake") or string.find(lowered, "effect") or string.find(lowered, "screen") then
            print("[DepHub][CameraShake] " .. label .. " attribute " .. tostring(name) .. " = " .. tostring(value))
        end
    end
end

function Feature:Debug()
    print("[DepHub][CameraShake] Debug ativo. Nenhum RemoteEvent sera enviado.")
    inspect(self.Context.LocalPlayer and self.Context.LocalPlayer.Character, "Character")
    inspect(workspace.CurrentCamera, "CurrentCamera")
    local playerGui = self.Context.LocalPlayer and self.Context.LocalPlayer:FindFirstChildOfClass("PlayerGui")
    inspect(playerGui, "PlayerGui")
end

function Feature:SetEnabled(enabled)
    if self.State.Destroyed then return false end
    self.Enabled = enabled == true
    self.State.CameraShakeDisabled = not self.Enabled
    self:Debug()
    return true
end

function Feature:Enable() return self:SetEnabled(true) end
function Feature:Disable() return self:SetEnabled(false) end
function Feature:IsEnabled() return self.Enabled end
function Feature:Destroy()
    if not self.Context then return end
    self.Enabled = false
    self.Context = nil
    self.State = nil
end

return Feature
