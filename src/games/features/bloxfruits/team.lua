local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Feature = {}
Feature.__index = Feature

function Feature.new(context)
    return setmetatable({
        Context = context,
        State = context.State,
        LocalPlayer = context.LocalPlayer,
        Pirates = Teams:FindFirstChild("Pirates"),
        Marines = Teams:FindFirstChild("Marines"),
        CommF = nil,
        Enabled = false,
        PreferredTeam = "Pirates",
        Thread = nil,
        RespawnConnection = nil
    }, Feature)
end

function Feature:_normalize(team)
    return team == "Marines" and "Marines" or "Pirates"
end

function Feature:SetTeam(team)
    self.PreferredTeam = self:_normalize(team)
    if self.State.Config then self.State.Config:Set("PreferredTeam", self.PreferredTeam) end
    if self.Enabled then self:_ensure() end
    return true
end

function Feature:_ensure()
    if not self.Enabled or self.State.Destroyed or not self.LocalPlayer then return end
    local target = self.PreferredTeam == "Marines" and self.Marines or self.Pirates
    if target and self.LocalPlayer.Team == target and self.LocalPlayer.Character and self.LocalPlayer.Character.Parent then return end
    if not self.CommF then
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        self.CommF = remotes and remotes:FindFirstChild("CommF_")
    end
    if not self.CommF then return end
    pcall(function() self.CommF:InvokeServer("SetTeam", self.PreferredTeam) end)
end

function Feature:Enable()
    if self.Enabled or self.State.Destroyed then return true end
    self.Enabled = true
    self.PreferredTeam = self:_normalize(self.State.Config and self.State.Config:Get("PreferredTeam", "Pirates") or "Pirates")
    if not game:IsLoaded() then game.Loaded:Wait() end
    self:_ensure()
    self.Thread = task.spawn(function()
        while self.Enabled and not self.State.Destroyed do
            self:_ensure()
            task.wait(0.5)
        end
    end)
    self.RespawnConnection = self.Context.Connect(self.State.Connections, self.LocalPlayer.CharacterAdded, function()
        if self.Enabled then task.defer(function() self:_ensure() end) end
    end)
    return true
end

function Feature:Disable()
    if not self.Enabled then return true end
    self.Enabled = false
    if self.Thread then pcall(task.cancel, self.Thread); self.Thread = nil end
    if self.RespawnConnection then pcall(self.RespawnConnection.Disconnect, self.RespawnConnection); self.RespawnConnection = nil end
    return true
end

function Feature:IsEnabled() return self.Enabled end
function Feature:Destroy()
    self:Disable()
    self.Context = nil
    self.State = nil
end

return Feature
