local Feature = {}
Feature.__index = Feature

function Feature.new(context)
    return setmetatable({Context = context, State = context.State, Enabled = false, Thread = nil}, Feature)
end

function Feature:_setVisionRadius(value)
    local player = self.Context.LocalPlayer
    if not player then return false end
    local ok = pcall(function()
        if player.VisionRadius ~= value then player.VisionRadius = value end
    end)
    if ok and player.VisionRadius == value then return true end
    local valueObject = player:FindFirstChild("VisionRadius")
    if valueObject and valueObject:IsA("NumberValue") and valueObject.Value ~= value then pcall(function() valueObject.Value = value end) end
    return valueObject and valueObject:IsA("NumberValue") and valueObject.Value == value or false
end

function Feature:Enable()
    if self.Enabled or self.State.Destroyed then return true end
    self.Enabled = true
    self.Thread = task.spawn(function()
        while self.Enabled and not self.State.Destroyed do
            pcall(function()
                if self.Context.LocalPlayer.VisionRadius ~= 5000 then self:_setVisionRadius(5000) end
            end)
            task.wait(0.5)
        end
    end)
    return true
end

function Feature:Disable()
    self.Enabled = false
    if self.Thread then pcall(task.cancel, self.Thread); self.Thread = nil end
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
