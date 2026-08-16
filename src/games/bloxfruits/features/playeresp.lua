local Feature = {}
Feature.__index = Feature

function Feature.new(context)
    local self = setmetatable({}, Feature)
    self.Context = context
    self.State = context.State
    self.Connections = {}
    self.Records = {}
    self.Enabled = false
    return self
end

function Feature:_updateText(record)
    if not record.Label or not record.Label.Parent then return end
    local lines = {record.Player.Name, self.Context.HealthText(record.Humanoid)}
    if not record.Protected then lines[#lines + 1] = "PvP: Ativado" end
    record.Label.Text = table.concat(lines, "\n")
end

function Feature:_updateProtection(record)
    if self.State.Destroyed or not record.Character or not record.Character.Parent then return end
    record.Protected = self.Context.HasProtection(record.Character)
    self:_updateText(record)
end

function Feature:_updateAppearance(record)
    if self.State.Destroyed or not record.Highlight or not record.Label then return end
    local color = self.Context.TeamColor(record.Player)
    record.Highlight.FillColor = color
    record.Highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    record.Label.TextColor3 = Color3.fromRGB(255, 255, 255)
    self:_updateText(record)
end

function Feature:_remove(character)
    local record = self.Records[character]
    if not record then return end
    self.Records[character] = nil
    self.Context.DisconnectAll(record.Connections)
    self.Context.Destroy(record.Highlight)
    self.Context.Destroy(record.Billboard)
end

function Feature:_create(character)
    if self.State.Destroyed or not self.Enabled or not character then return end
    if character == self.Context.LocalPlayer.Character or self.Records[character] then return end
    local player = self.Context.GetPlayer(character)
    if not player or player == self.Context.LocalPlayer then return end
    local head = character:FindFirstChild("Head")
    local humanoid = self.Context.GetHumanoid(character)
    if not head or not humanoid then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "DepHubPlayerESP"
    highlight.Adornee = character
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = 0
    highlight.OutlineTransparency = 0
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.Parent = character

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "DepHubPlayerESPText"
    billboard.Adornee = head
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 10000
    billboard.Size = UDim2.fromOffset(250, 76)
    billboard.StudsOffset = Vector3.new(0, 3.25, 0)
    billboard.Parent = head

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0
    label.Parent = billboard

    local record = {Character = character, Player = player, Humanoid = humanoid, Highlight = highlight, Billboard = billboard, Label = label, Protected = self.Context.HasProtection(character), Connections = {}}
    self.Records[character] = record
    self:_updateAppearance(record)

    self.Context.Connect(record.Connections, humanoid:GetPropertyChangedSignal("Health"), function() self:_updateText(record) end)
    self.Context.Connect(record.Connections, humanoid:GetPropertyChangedSignal("MaxHealth"), function() self:_updateText(record) end)
    self.Context.Connect(record.Connections, player:GetPropertyChangedSignal("Team"), function() self:_updateAppearance(record) end)
    self.Context.Connect(record.Connections, character.ChildAdded, function(child)
        if child:IsA("ForceField") or self.Context.IsProtectionName(child.Name) then self:_updateProtection(record) end
    end)
    self.Context.Connect(record.Connections, character.ChildRemoved, function(child)
        if child:IsA("ForceField") or self.Context.IsProtectionName(child.Name) then task.defer(function() self:_updateProtection(record) end) end
    end)
    self.Context.Connect(record.Connections, character.DescendantAdded, function(descendant)
        if self.Context.IsProtectionName(descendant.Name) or descendant:IsA("ForceField") then self:_updateProtection(record) end
    end)
    self.Context.Connect(record.Connections, character.DescendantRemoving, function(descendant)
        if self.Context.IsProtectionName(descendant.Name) or descendant:IsA("ForceField") then task.defer(function() self:_updateProtection(record) end) end
    end)
    for _, attributeName in ipairs({"PvPDisabled", "PVPDisabled", "PvPProtection", "Protection", "Protected", "SafeZone", "NoPvP"}) do
        self.Context.Connect(record.Connections, character:GetAttributeChangedSignal(attributeName), function() self:_updateProtection(record) end)
    end
    self.Context.Connect(record.Connections, character.AncestryChanged, function(_, parent)
        if not parent then self:_remove(character) end
    end)
end

function Feature:Enable()
    if self.Enabled or self.State.Destroyed then return true end
    local characters = self.Context.Workspace:FindFirstChild("Characters") or self.Context.Workspace:WaitForChild("Characters", 5)
    if not characters then return false end
    self.Enabled = true
    self.Characters = characters
    for _, character in ipairs(characters:GetChildren()) do
        if character:IsA("Model") then self:_create(character) end
    end
    self.Context.Connect(self.Connections, characters.ChildAdded, function(character)
        if self.Enabled and character:IsA("Model") then task.defer(function() self:_create(character) end) end
    end)
    self.Context.Connect(self.Connections, characters.ChildRemoved, function(character) self:_remove(character) end)
    return true
end

function Feature:Disable()
    if not self.Enabled then return true end
    self.Enabled = false
    self.Context.DisconnectAll(self.Connections)
    for character in pairs(self.Records) do self:_remove(character) end
    self.Characters = nil
    return true
end

function Feature:IsEnabled() return self.Enabled end
function Feature:Destroy()
    if not self.Context then return end
    self:Disable()
    self.Context = nil
    self.State = nil
    self.Records = nil
end

return Feature
