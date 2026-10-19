local Feature = {}
Feature.__index = Feature

-- Humanised timing: vary each periodic wait to avoid a perfectly periodic loop.
local function jitter(base, spread)
    spread = spread or 0.2
    return task.wait(base * (1 + (math.random() * 2 - 1) * spread))
end

local function alive(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.Health > 0
end

local QuestData = nil
do
    -- The parent backend loads quests.lua once and hands it through State; this
    -- fallback only matters if a feature is instantiated standalone in tests.
    local ok, result = pcall(function()
        return (((type(getgenv) == "function" and getgenv() or _G).__DEPHUB or {}).BloxFruits or {}).QuestData
    end)
    QuestData = ok and result or nil
end

function Feature.new(context)
    local self = setmetatable({}, Feature)
    self.Context = context
    self.State = context.State
    self.Enabled = false
    self.Thread = nil
    self.QuestData = (context.State and context.State.QuestData) or QuestData
    self.Monster = nil
    self.KillCount = 0
    self.LastStatus = "idle"
    -- Movement/attack tuning. Auto-target-copy keeps the character glued to the
    -- mob (the standard BF farm trick); the offsets are deliberately small so
    -- the pivot does not clip inside the target.
    self.Equip = nil
    self.NotifyOnQuest = true
    self.cachedRemote = nil
    return self
end

function Feature:_commf()
    if self.cachedRemote and self.cachedRemote.Parent then return self.cachedRemote end
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local commf = remotes and remotes:FindFirstChild("CommF_")
    self.cachedRemote = commf
    return commf
end

function Feature:_level()
    local LocalPlayer = self.Context.LocalPlayer
    local data = LocalPlayer and LocalPlayer:FindFirstChild("Data")
    local level = data and data:FindFirstChild("Level")
    if level and level:IsA("IntValue") then return level.Value end
    if data and data:FindFirstChild("Level") then return data.Level.Value end
    return nil
end

function Feature:_enemyFolder()
    local Workspace = game:GetService("Workspace")
    return Workspace:FindFirstChild("Enemies")
end

-- Preferred target source: the live monster that matches the current quest name.
function Feature:_findLiveMonster(name)
    local folder = self:_enemyFolder()
    if not folder or not name then return nil end
    local LocalPlayer = self.Context.LocalPlayer
    local root = self.Context.GetRoot(LocalPlayer.Character)
    local best, bestDistance = nil, math.huge
    for _, enemy in ipairs(folder:GetChildren()) do
        local humanoid = enemy:FindFirstChildOfClass("Humanoid")
        local targetRoot = enemy:FindFirstChild("HumanoidRootPart")
        if humanoid and humanoid.Health > 0 and targetRoot and enemy.Name == name then
            local distance = root and (targetRoot.Position - root.Position).Magnitude or 0
            if distance < bestDistance then best, bestDistance = enemy, distance end
        end
    end
    return best
end

function Feature:_requestQuest(name, level, questName)
    local commf = self:_commf()
    if not commf then return false end
    local ok = pcall(function() commf:InvokeServer("StartQuest", questName or (name .. "Quest1"), level or 1) end)
    return ok
end

function Feature:_teleport(cf)
    local root = self.Context.GetRoot(self.Context.LocalPlayer.Character)
    if root and cf then pcall(function() root.CFrame = cf end) end
end

function Feature:_freeze(enemy)
    local humanoid = enemy and enemy:FindFirstChildOfClass("Humanoid")
    local root = enemy and enemy:FindFirstChild("HumanoidRootPart")
    local head = enemy and enemy:FindFirstChild("Head")
    if humanoid then pcall(function() humanoid.WalkSpeed = 0 end) end
    if root then pcall(function() root.CanCollide = false end) end
    if head then pcall(function() head.CanCollide = false end) end
end

function Feature:Enable()
    if self.Enabled or self.State.Destroyed then return true end
    self.Enabled = true
    self.LastStatus = "starting"
    self.Thread = task.spawn(function()
        while self.Enabled and not self.State.Destroyed do
            local stepOk, err = pcall(function() self:_step() end)
            if not stepOk then self.LastStatus = "error: " .. tostring(err) end
            jitter(0.2, 0.3)
        end
    end)
    return true
end

function Feature:_step()
    local LocalPlayer = self.Context.LocalPlayer
    if not alive(LocalPlayer.Character) then self.LastStatus = "respawning"; return end
    local level = self:_level()
    local placeId = game.PlaceId
    local monster, spawn, world = nil, nil, nil
    if self.QuestData then
        local ok, name, cf, w = pcall(function()
            local n, c, ww = self.QuestData.For(placeId, level or 1)
            return n, c, ww
        end)
        if ok then monster, spawn, world = name, cf, w end
    end
    if not monster then self.LastStatus = "no quest data for level " .. tostring(level); return end
    self.Monster = monster
    local owner = self.Context.LocalPlayer
    local ownerRoot = self.Context.GetRoot(owner.Character)
    local live = self:_findLiveMonster(monster)
    if live and ownerRoot then
        local targetRoot = live:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            self:_freeze(live)
            -- Stay just above/behind the monster; the offset keeps the pivot out
            -- of the target's collider while remaining in melee range.
            pcall(function()
                ownerRoot.CFrame = targetRoot.CFrame * CFrame.new(2, 25, 2)
            end)
            self.LastStatus = "farming " .. monster
            local blade = self.State.Features and self.State.Features.BladeHits
            if blade then
                -- Auto-farm is meaningless without fast attack, so enable the
                -- blade-hits backend if the user armed only the farm.
                if not blade.Enabled and type(blade.Enable) == "function" then pcall(blade.Enable, blade) end
                if blade.Enabled then blade:AttackNearest(self.BladeRange or blade.AttackRange) end
            end
            return
        end
    end
    -- No live monster: walk to the recorded spawn anchor so the server spawns one.
    if spawn then
        self:_teleport(CFrame.new(spawn[1], spawn[2], spawn[3]))
        self.LastStatus = "approaching " .. monster
    else
        self.LastStatus = "waiting for " .. monster
    end
end

function Feature:Disable()
    self.Enabled = false
    self.LastStatus = "idle"
    if self.Thread then pcall(task.cancel, self.Thread); self.Thread = nil end
    return true
end

function Feature:GetStatus()
    return {Monster = self.Monster, Status = self.LastStatus, Kills = self.KillCount}
end

function Feature:IsEnabled() return self.Enabled end

function Feature:Destroy()
    if not self.Context then return end
    self:Disable()
    self.Context = nil
    self.State = nil
    self.cachedRemote = nil
end

return Feature
