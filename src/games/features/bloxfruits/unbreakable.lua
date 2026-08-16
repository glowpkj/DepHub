local Feature = {}
Feature.__index = Feature

function Feature.new(context)
    return setmetatable({Context = context, State = context.State, Enabled = false, Thread = nil, Captured = false, Original = nil}, Feature)
end

function Feature:Enable()
    if self.Enabled or self.State.Destroyed then return true end
    if not self.Captured then
        self.Original = self.Context.LocalPlayer:GetAttribute("UnbreakableAll")
        self.Captured = true
    end
    self.Enabled = true
    self.Thread = task.spawn(function()
        while self.Enabled and not self.State.Destroyed do
            pcall(function()
                if self.Context.LocalPlayer:GetAttribute("UnbreakableAll") ~= true then self.Context.LocalPlayer:SetAttribute("UnbreakableAll", true) end
            end)
            task.wait(0.75)
        end
    end)
    return true
end

function Feature:Disable()
    if not self.Enabled and not self.Captured then return true end
    self.Enabled = false
    if self.Thread then pcall(task.cancel, self.Thread); self.Thread = nil end
    if self.Captured then
        local original = self.Original
        self.Captured = false
        self.Original = nil
        pcall(function() self.Context.LocalPlayer:SetAttribute("UnbreakableAll", original) end)
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
