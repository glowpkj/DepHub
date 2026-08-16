local Feature = {}
Feature.__index = Feature

function Feature.new(context)
    local self = setmetatable({}, Feature)
    self.Context = context
    self.State = context.State
    self.Connections = {}
    self.Records = {}
    self.Enabled = false
    self.Thread = nil
    return self
end

function Feature:_fruitModel(tool)
    return tool and tool:FindFirstChild("Fruit") or nil
end

function Feature:_adornee(tool, fruit)
    if fruit then
        if fruit:IsA("Model") then return fruit.PrimaryPart or fruit:FindFirstChildWhichIsA("BasePart", true) end
        if fruit:IsA("BasePart") or fruit:IsA("Attachment") then return fruit end
    end
    if tool then
        local handle = tool:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then return handle end
        return tool:FindFirstChildWhichIsA("BasePart", true)
    end
end

function Feature:_position(tool, fruit, adornee)
    if fruit and fruit:IsA("Model") then
        local ok, pivot = pcall(fruit.GetPivot, fruit)
        if ok then return pivot.Position end
    end
    if adornee and adornee:IsA("BasePart") then return adornee.Position end
    if adornee and adornee:IsA("Attachment") then return adornee.WorldPosition end
    local handle = tool and tool:FindFirstChild("Handle")
    if handle and handle:IsA("BasePart") then return handle.Position end
end

function Feature:_name(tool)
    if not tool then return "Fruit" end
    local name = tostring(tool.Name)
    local lower = string.lower(name)
    if string.sub(lower, -6) == " fruit" then return name end
    local spaced = string.gsub(name, "([Ff][Rr][Uu][Ii][Tt])", "Fruit")
    if string.find(string.lower(spaced), "fruit", 1, true) then return spaced end
    return name
end

function Feature:_isDropped(tool)
    return tool and tool:IsA("Tool") and tool.Parent == self.Context.Workspace and self:_fruitModel(tool) ~= nil
end

function Feature:_update(record)
    if self.State.Destroyed or not record.Label or not record.Label.Parent then return end
    local fruit = self:_fruitModel(record.Tool)
    local adornee = self:_adornee(record.Tool, fruit)
    local position = self:_position(record.Tool, fruit, adornee)
    local root = self.Context.GetRoot(self.Context.LocalPlayer.Character)
    if not position or not root then return end
    local distance = (root.Position - position).Magnitude
    record.Label.Text = self:_name(record.Tool) .. "\nDistância: " .. tostring(math.floor(distance + 0.5)) .. " studs"
    if record.Billboard.Adornee ~= adornee then record.Billboard.Adornee = adornee end
end

function Feature:_remove(tool)
    local record = self.Records[tool]
    if not record then return end
    self.Records[tool] = nil
    self.Context.DisconnectAll(record.Connections)
    self.Context.Destroy(record.Billboard)
end

function Feature:_create(tool)
    if self.State.Destroyed or not self.Enabled or self.Records[tool] or not self:_isDropped(tool) then return end
    local fruit = self:_fruitModel(tool)
    local adornee = self:_adornee(tool, fruit)
    if not adornee then return end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "DepHubFruitESP"
    billboard.Adornee = adornee
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 10000
    billboard.Size = UDim2.fromOffset(270, 48)
    billboard.StudsOffset = Vector3.new(0, 2.6, 0)
    billboard.Parent = adornee
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0
    label.TextColor3 = Color3.fromRGB(255, 235, 90)
    label.Parent = billboard
    local record = {Tool = tool, Fruit = fruit, Billboard = billboard, Label = label, Connections = {}}
    self.Records[tool] = record
    self:_update(record)
    self.Context.Connect(record.Connections, tool.AncestryChanged, function(_, parent)
        if not parent or not self:_isDropped(tool) then self:_remove(tool) end
    end)
    self.Context.Connect(record.Connections, tool.ChildAdded, function(child)
        if child.Name == "Fruit" then record.Fruit = child; self:_update(record) end
    end)
    self.Context.Connect(record.Connections, tool.ChildRemoved, function(child)
        if child == record.Fruit then
            task.defer(function()
                if not self.Records[tool] then return end
                record.Fruit = self:_fruitModel(tool)
                if record.Fruit then self:_update(record) else self:_remove(tool) end
            end)
        end
    end)
    self.Context.Connect(record.Connections, tool:GetPropertyChangedSignal("Name"), function() self:_update(record) end)
end

function Feature:Enable()
    if self.Enabled or self.State.Destroyed then return true end
    self.Enabled = true
    for _, instance in ipairs(self.Context.Workspace:GetChildren()) do
        if instance:IsA("Tool") then self:_create(instance) end
    end
    self.Context.Connect(self.Connections, self.Context.Workspace.ChildAdded, function(instance)
        if self.Enabled and instance:IsA("Tool") then task.defer(function() self:_create(instance) end) end
    end)
    self.Context.Connect(self.Connections, self.Context.Workspace.ChildRemoved, function(instance)
        if instance:IsA("Tool") then self:_remove(instance) end
    end)
    self.Thread = task.spawn(function()
        while self.Enabled and not self.State.Destroyed do
            for tool, record in pairs(self.Records) do
                if not self:_isDropped(tool) or not record.Label or not record.Label.Parent then self:_remove(tool) else self:_update(record) end
            end
            task.wait(0.2)
        end
    end)
    return true
end

function Feature:Disable()
    if not self.Enabled then return true end
    self.Enabled = false
    self.Context.DisconnectAll(self.Connections)
    if self.Thread then pcall(task.cancel, self.Thread); self.Thread = nil end
    for tool in pairs(self.Records) do self:_remove(tool) end
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
