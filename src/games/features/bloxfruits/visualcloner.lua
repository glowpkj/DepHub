local Players = game:GetService("Players")

local Feature = {}
Feature.__index = Feature

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function fruitName(name)
    local text = tostring(name or "")
    local normalized = lower(text)
    local separator = string.find(text, "-", 1, true)
    if not separator then return false end
    local left = string.sub(normalized, 1, separator - 1)
    local right = string.sub(normalized, separator + 1)
    if left == "" or right == "" or left ~= right then return false end
    return true
end

local function hasVisualContent(instance)
    return instance:FindFirstChildWhichIsA("BasePart", true)
        or instance:FindFirstChildWhichIsA("ParticleEmitter", true)
        or instance:FindFirstChildWhichIsA("Beam", true)
        or instance:FindFirstChildWhichIsA("Trail", true)
        or instance:FindFirstChildWhichIsA("Animation", true)
        or instance:FindFirstChildWhichIsA("AnimationController", true)
        or instance:FindFirstChildWhichIsA("GuiObject", true)
        or instance:IsA("GuiObject")
end

local function looksLikeVisual(instance)
    if not instance:IsA("Model") and not instance:IsA("Folder") and not instance:IsA("Tool") and not instance:IsA("ScreenGui") then return false end
    local name = lower(instance.Name)
    if fruitName(instance.Name) then return hasVisualContent(instance) or instance:IsA("Tool") end
    if string.find(name, "fruit", 1, true) or string.find(name, "effect", 1, true) or string.find(name, "transform", 1, true) or string.find(name, "aura", 1, true) or string.find(name, "skill", 1, true) or string.find(name, "attack", 1, true) or string.find(name, "vfx", 1, true) then
        return hasVisualContent(instance)
    end
    for _, child in ipairs(instance:GetChildren()) do
        local childName = lower(child.Name)
        if childName == "fruit" or string.find(childName, "fruit", 1, true) or string.find(childName, "effect", 1, true) or string.find(childName, "skill", 1, true) or string.find(childName, "attack", 1, true) or string.find(childName, "vfx", 1, true) then
            if hasVisualContent(instance) then return true end
        end
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

function Feature:_add(instance, player, source, kind)
    if not instance then return end
    if source == "PlayerGui" and instance:IsA("GuiObject") then
        instance = instance:FindFirstAncestorOfClass("ScreenGui")
    end
    if not instance or self.Options[instance] or instance.Archivable == false then return end
    self.NextId += 1
    local record = {
        Id = tostring(self.NextId),
        Instance = instance,
        Player = player,
        Name = instance.Name,
        Source = source,
        Kind = kind or instance.ClassName,
        Connections = {}
    }
    self.Options[instance] = record
    self.Records[record.Id] = record
    self.Context.Connect(record.Connections, instance.AncestryChanged, function(_, parent)
        if not parent then self:_remove(instance) end
    end)
end

function Feature:_remove(instance)
    local record = self.Options[instance]
    if not record then return end
    self.Options[instance] = nil
    self.Records[record.Id] = nil
    self.Context.DisconnectAll(record.Connections)
end

function Feature:_scanContainer(container, player, source)
    if not container then return end
    for _, instance in ipairs(container:GetChildren()) do
        if instance:IsA("Tool") and fruitName(instance.Name) then
            self:_add(instance, player, source, "FruitTool")
        elseif looksLikeVisual(instance) then
            self:_add(instance, player, source, instance.ClassName)
        end
        for _, descendant in ipairs(instance:GetDescendants()) do
            if looksLikeVisual(descendant) then
                self:_add(descendant, player, source, descendant.ClassName)
            elseif source == "PlayerGui" and descendant:IsA("GuiObject") then
                local screenGui = descendant:FindFirstAncestorOfClass("ScreenGui")
                local screenName = screenGui and lower(screenGui.Name) or ""
                local descendantName = lower(descendant.Name)
                if screenGui and (fruitName(descendant.Name) or string.find(descendantName, "fruit", 1, true) or string.find(descendantName, "effect", 1, true) or string.find(descendantName, "attack", 1, true) or string.find(descendantName, "skill", 1, true) or string.find(descendantName, "vfx", 1, true) or string.find(screenName, "fruit", 1, true) or string.find(screenName, "effect", 1, true) or string.find(screenName, "vfx", 1, true)) then
                    self:_add(screenGui, player, source, "ScreenGui")
                end
            end
        end
    end
end

function Feature:_scanPlayer(player, seen)
    if player == self.LocalPlayer then return end

    local containers = {
        {player:FindFirstChildOfClass("Backpack"), "Backpack"},
        {player:FindFirstChildOfClass("PlayerGui"), "PlayerGui"},
        {player.Character, "Character"}
    }

    for _, entry in ipairs(containers) do
        local container, source = entry[1], entry[2]
        if container then
            self:_scanContainer(container, player, source)
            for instance, record in pairs(self.Options) do
                if record.Player == player and record.Source == source and instance:IsDescendantOf(container) then
                    seen[instance] = true
                end
            end
        end
    end
end

function Feature:GetOptions()
    local list = {}
    for _, record in pairs(self.Records) do
        if record.Instance and record.Instance.Parent then
            list[#list + 1] = {
                Id = record.Id,
                Name = record.Name,
                Player = record.Player and record.Player.Name or "Unknown",
                Source = record.Source or "Unknown",
                Kind = record.Kind or "Unknown"
            }
        end
    end
    table.sort(list, function(a, b)
        if a.Name == b.Name then
            if a.Player == b.Player then return a.Source < b.Source end
            return a.Player < b.Player
        end
        return a.Name < b.Name
    end)
    return list
end

local function cloneDestination(localPlayer, record)
    if record.Source == "PlayerGui" then
        local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui") or localPlayer:FindFirstChild("PlayerGui")
        if not playerGui then return nil end
        if record.Instance:IsA("ScreenGui") then return playerGui end
        return localPlayer.Character
    end
    return localPlayer.Character
end

function Feature:CloneOption(id)
    local record = self.Records[tostring(id)]
    if self.State.Destroyed or not record or not record.Instance or not record.Instance.Parent then return false end
    if record.Instance.Archivable == false then return false end
    local destination = cloneDestination(self.LocalPlayer, record)
    if not destination then return false end
    local ok, clone = pcall(record.Instance.Clone, record.Instance)
    if not ok or not clone then return false end
    clone.Parent = destination
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

function Feature:_scan()
    local seen = {}
    for _, player in ipairs(Players:GetPlayers()) do
        self:_scanPlayer(player, seen)
    end
    for instance in pairs(self.Options) do
        if not seen[instance] then
            local stillValid = false
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= self.LocalPlayer and instance.Parent then
                    local backpack = player:FindFirstChildOfClass("Backpack")
                    local playerGui = player:FindFirstChildOfClass("PlayerGui")
                    local character = player.Character
                    if (backpack and instance:IsDescendantOf(backpack)) or (playerGui and instance:IsDescendantOf(playerGui)) or (character and instance:IsDescendantOf(character)) then
                        stillValid = true
                        break
                    end
                end
            end
            if not stillValid then self:_remove(instance) end
        end
    end
    if self.RefreshCallback then self.RefreshCallback(self:GetOptions()) end
end

function Feature:Enable()
    if self.Enabled or self.State.Destroyed then return true end
    self.Enabled = true
    self.Context.Connect(self.Connections, Players.PlayerAdded, function()
        if self.Enabled then task.defer(function() self:_scan() end) end
    end)
    self.Context.Connect(self.Connections, Players.PlayerRemoving, function(player)
        for instance, record in pairs(self.Options) do
            if record.Player == player then self:_remove(instance) end
        end
    end)
    self.Thread = task.spawn(function()
        while self.Enabled and not self.State.Destroyed do
            self:_scan()
            task.wait(0.5)
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
    for instance in pairs(self.Options) do self:_remove(instance) end
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
