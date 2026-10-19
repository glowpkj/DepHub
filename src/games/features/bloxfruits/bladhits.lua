local Feature = {}
Feature.__index = Feature

-- Humanised timing: vary each periodic wait to avoid a perfectly periodic loop.
local function jitter(base, spread)
    spread = spread or 0.15
    return task.wait(base * (1 + (math.random() * 2 - 1) * spread))
end

local function alive(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.Health > 0
end

function Feature.new(context)
    local self = setmetatable({}, Feature)
    self.Context = context
    self.State = context.State
    self.Enabled = false
    self.Thread = nil
    self.Net = nil
    self.RegisterAttack = nil
    self.RegisterHit = nil
    -- Rate limiting: the single most detectable part of a remote-hit farm. The
    -- original open-source scripts fire in a `while wait(0.1)` with no cap; we
    -- keep a measured floor and a jittered cadence instead.
    self.MinInterval = 0.1
    self.AttackRange = 100
    self.hits = 0
    return self
end

function Feature:_resolveRemotes()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    local net = (modules and modules:FindFirstChild("Net")) or ReplicatedStorage:FindFirstChild("Net")
    if not net then return false end
    local attack = net:FindFirstChild("RE/RegisterAttack")
    local hit = net:FindFirstChild("RE/RegisterHit")
    if not attack or not hit then return false end
    self.Net = net
    self.RegisterAttack = attack
    self.RegisterHit = hit
    return true
end

function Feature:_collectEnemies(range)
    local LocalPlayer = self.Context.LocalPlayer
    local root = self.Context.GetRoot(LocalPlayer.Character)
    if not root then return {} end
    local others = {}
    local nearest = nil
    local function scan(folder)
        if not folder then return end
        for _, enemy in ipairs(folder:GetChildren()) do
            if enemy ~= LocalPlayer.Character then
                local humanoid = enemy:FindFirstChildOfClass("Humanoid")
                local head = enemy:FindFirstChild("Head") or enemy:FindFirstChild("HumanoidRootPart")
                if humanoid and humanoid.Health > 0 and head then
                    local distance = (head.Position - root.Position).Magnitude
                    if distance <= (range or self.AttackRange) then
                        others[#others + 1] = enemy
                        if not nearest or distance < nearest.distance then
                            nearest = {part = head, distance = distance, enemy = enemy}
                        end
                    end
                end
            end
        end
    end
    scan(game:GetService("Workspace"):FindFirstChild("Enemies"))
    scan(game:GetService("Workspace"):FindFirstChild("Characters"))
    return others, nearest
end

-- Fire the server-side attack/hit remotes directly. Faster than tool:Activate()
-- and the reason auto-farm mastery loops work at all.
function Feature:AttackNearest(range)
    local others, nearest = self:_collectEnemies(range or self.AttackRange)
    if not nearest or #others == 0 then return false end
    local targets = {}
    for _, enemy in ipairs(others) do
        local head = enemy:FindFirstChild("Head") or enemy:FindFirstChild("HumanoidRootPart")
        if head then targets[#targets + 1] = {enemy, head} end
    end
    pcall(function() self.RegisterAttack:FireServer(self.Context.ClickDelay or 0) end)
    pcall(function() self.RegisterHit:FireServer(nearest.part, targets) end)
    self.hits = self.hits + 1
    return true
end

function Feature:Enable()
    if self.Enabled or self.State.Destroyed then return true end
    if not self:_resolveRemotes() then return false end
    self.Enabled = true
    self.Thread = task.spawn(function()
        while self.Enabled and not self.State.Destroyed do
            pcall(function()
                if alive(self.Context.LocalPlayer.Character) then self:AttackNearest() end
            end)
            jitter(self.MinInterval, 0.25)
        end
    end)
    return true
end

function Feature:Disable()
    self.Enabled = false
    if self.Thread then pcall(task.cancel, self.Thread); self.Thread = nil end
    return true
end

function Feature:SetRange(value)
    value = tonumber(value)
    if not value or value <= 0 then return false end
    self.AttackRange = value
    return true
end

function Feature:IsEnabled() return self.Enabled end

function Feature:Destroy()
    if not self.Context then return end
    self:Disable()
    self.Context = nil
    self.State = nil
    self.Net = nil
    self.RegisterAttack = nil
    self.RegisterHit = nil
end

return Feature
