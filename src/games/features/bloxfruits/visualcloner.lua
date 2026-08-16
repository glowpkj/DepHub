local Players = game:GetService("Players")

local Feature = {}
Feature.__index = Feature

local IGNORE = {
    Humanoid = true,
    HumanoidRootPart = true,
    Head = true,
    Torso = true,
    UpperTorso = true,
    LowerTorso = true,
    LeftHand = true,
    RightHand = true,
    LeftFoot = true,
    RightFoot = true,
    LeftLowerArm = true,
    RightLowerArm = true,
    LeftLowerLeg = true,
    RightLowerLeg = true,
    LeftUpperArm = true,
    RightUpperArm = true,
    LeftUpperLeg = true,
    RightUpperLeg = true,
    Root = true,
    Handle = true
}

local function visualContent(model)
    return model:FindFirstChildWhichIsA("BasePart", true)
        or model:FindFirstChildWhichIsA("ParticleEmitter", true)
        or model:FindFirstChildWhichIsA("Beam", true)
        or model:FindFirstChildWhichIsA("Trail", true)
end

local function looksLikeVisual(model)
    if not model:IsA("Model") or IGNORE[model.Name] or not visualContent(model) then return false end
    local name = string.lower(model.Name)
    if string.find(name, "fruit", 1, true) or string.find(name, "effect", 1, true) or string.find(name, "transform", 1, true) or string.find(name, "aura", 1, true) then return true end
    for _, child in ipairs(model:GetChildren()) do
        local childName = string.lower(child.Name)
        if childName == "fruit" or string.find(childName, "fruit", 1, true) or string.find(childName, "effect", 1, true) then return true end
    end
    return false
end

function Feature.new(context)
    return setmetatable({
        Context = context,
        State = context.State,
        LocalPlayer = context.LocalPlayer,
        Workspace = context.Workspace,
        Enabled = false,
        Records = {},
        Options = {},
        Connections = {},
        Thread = nil,
        RefreshCallback = nil,
        NextId = 0,
        LocalClones = {}
    }, Feature)
end

function Feature:SetRefreshCallback(callback)
    self.RefreshCallback = type(callback) == "function" and callback or nil
    if self.RefreshCallback then self.RefreshCallback(self:GetOptions()) end
end

function Feature:_add(model, player)
    if self.Options[model] then return end
    self.NextId += 1
    local record = {Id = tostring(self.NextId), Model = model, Player = player, Name = model.Name, Connections = {}}
    self.Options[model] = record
    self.Records[record.Id] = record
    self.Context.Connect(record.Connections, model.AncestryChanged, function(_, parent)
        if not parent then self:_remove(model) end
    end)
end

function Feature:_remove(model)
    local record = self.Options[model]
    if not record then return end
    self.Options[model] = nil
    self.Records[record.Id] = nil
    self.Context.DisconnectAll(record.Connections)
end

function Feature:_scan()
    local characters = self.Workspace:FindFirstChild("Characters")
    if not characters then return end
    local seen = {}
    for _, character in ipairs(characters:GetChildren()) do
        local player = Players:GetPlayerFromCharacter(character)
        if player and player ~= self.LocalPlayer then
            for _, descendant in ipairs(character:GetDescendants()) do
                if looksLikeVisual(descendant) then
                    seen[descendant] = true
                    self:_add(descendant, player)
                end
            end
        end
    end
    for model in pairs(self.Options) do
        if not seen[model] then self:_remove(model) end
    end
    if self.RefreshCallback then self.RefreshCallback(self:GetOptions()) end
end

function Feature:GetOptions()
    local list = {}
    for _, record in pairs(self.Records) do
        if record.Model and record.Model.Parent then
            list[#list + 1] = {Id = record.Id, Name = record.Name, Player = record.Player and record.Player.Name or "Unknown"}
        end
    end
    table.sort(list, function(a, b)
        if a.Name == b.Name then return a.Player < b.Player end
        return a.Name < b.Name
    end)
    return list
end

function Feature:_prepareClone(clone)
    for _, descendant in ipairs(clone:GetDescendants()) do
        if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
            descendant:Destroy()
        elseif descendant:IsA("BasePart") then
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = false
            descendant.Massless = true
            descendant.Anchored = false
        end
    end
end

function Feature:CloneOption(id)
    local record = self.Records[tostring(id)]
    local character = self.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if self.State.Destroyed or not record or not record.Model or not record.Model.Parent or not root then return false end
    local ok, clone = pcall(record.Model.Clone, record.Model)
    if not ok or not clone then return false end
    self:_prepareClone(clone)
    clone.Name = "DepHubVisualClone_" .. tostring(record.Name)
    clone.Parent = character
    pcall(function() clone:PivotTo(root.CFrame) end)
    for _, part in ipairs(clone:GetDescendants()) do
        if part:IsA("BasePart") then
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = root
            weld.Part1 = part
            weld.Parent = part
        end
    end
    self.LocalClones[clone] = true
    return true
end

function Feature:ClearClones()
    for clone in pairs(self.LocalClones) do
        pcall(clone.Destroy, clone)
        self.LocalClones[clone] = nil
    end
    return true
end

function Feature:Enable()
    if self.Enabled or self.State.Destroyed then return true end
    local characters = self.Workspace:FindFirstChild("Characters") or self.Workspace:WaitForChild("Characters", 5)
    if not characters then return false end
    self.Enabled = true
    self.Context.Connect(self.Connections, characters.ChildAdded, function(character)
        if self.Enabled and character:IsA("Model") then task.defer(function() self:_scan() end) end
    end)
    self.Context.Connect(self.Connections, characters.ChildRemoved, function() self:_scan() end)
    self.Thread = task.spawn(function()
        while self.Enabled and not self.State.Destroyed do
            self:_scan()
            task.wait(1)
        end
    end)
    self:_scan()
    return true
end

function Feature:Disable()
    if not self.Enabled then return true end
    self.Enabled = false
    self.Context.DisconnectAll(self.Connections)
    if self.Thread then pcall(task.cancel, self.Thread); self.Thread = nil end
    for model in pairs(self.Options) do self:_remove(model) end
    return true
end

function Feature:IsEnabled() return self.Enabled end
function Feature:Destroy()
    self:Disable()
    self:ClearClones()
    self.Context = nil
    self.State = nil
end

return Feature
