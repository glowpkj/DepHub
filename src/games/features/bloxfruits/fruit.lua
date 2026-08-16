local Feature = {}
Feature.__index = Feature

local UserInputService = game:GetService("UserInputService")

local GENERIC_NAMES = {
    Fruit = true,
    Handle = true,
    Weld = true,
    Welded = true,
    Keep = true,
    Script = true,
    LocalScript = true,
    ClientEatScript = true,
    FruitAnimator = true,
    EatRemote = true,
}

local function safeText(value)
    if value == nil then return nil end
    local text = tostring(value)
    if text == "" then return nil end
    return text
end

function Feature.new(context)
    local self = setmetatable({}, Feature)
    self.Context = context
    self.State = context.State
    self.Connections = {}
    self.Records = {}
    self.Enabled = false
    self.Thread = nil
    self.Camera = workspace.CurrentCamera
    self.CameraConnection = nil
    return self
end

function Feature:_isDroppedTool(instance)
    return instance and instance:IsA("Tool") and instance.Parent == self.Context.Workspace and instance:FindFirstChild("Fruit") ~= nil
end

function Feature:_isSpawnedFruit(instance)
    if not instance or not instance:IsA("Model") or instance.Name ~= "Fruit" then return false end
    return instance:IsDescendantOf(self.Context.Workspace) and instance ~= self.Context.Workspace:FindFirstChild("Map")
end

function Feature:_isFruitSpawnEntry(instance)
    if not instance then return false end
    local fruitSpawns = self.Context.Workspace:FindFirstChild("_WorldOrigin")
    fruitSpawns = fruitSpawns and fruitSpawns:FindFirstChild("FruitSpawns")
    if not fruitSpawns or not instance:IsDescendantOf(fruitSpawns) then return false end
    if instance:IsA("Tool") then return instance:FindFirstChild("Fruit") ~= nil end
    return instance:IsA("Model") and instance.Name == "Fruit"
end

function Feature:_isFruit(instance)
    return self:_isDroppedTool(instance) or self:_isSpawnedFruit(instance) or self:_isFruitSpawnEntry(instance)
end

function Feature:_fruitModel(instance)
    return instance and instance:IsA("Tool") and instance:FindFirstChild("Fruit") or (instance and instance:IsA("Model") and instance or nil)
end

function Feature:_adornee(instance)
    local fruit = self:_fruitModel(instance)
    if fruit then
        if fruit:IsA("Model") then
            return fruit.PrimaryPart or fruit:FindFirstChildWhichIsA("BasePart", true)
        end
        if fruit:IsA("BasePart") or fruit:IsA("Attachment") then return fruit end
    end
    if instance:IsA("Tool") then
        local handle = instance:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then return handle end
        return instance:FindFirstChildWhichIsA("BasePart", true)
    end
end

function Feature:_position(instance, adornee)
    local fruit = self:_fruitModel(instance)
    if fruit and fruit:IsA("Model") then
        local ok, pivot = pcall(fruit.GetPivot, fruit)
        if ok then return pivot.Position end
    end
    if adornee and adornee:IsA("BasePart") then return adornee.Position end
    if adornee and adornee:IsA("Attachment") then return adornee.WorldPosition end
    if instance:IsA("Tool") then
        local handle = instance:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then return handle.Position end
    end
end

function Feature:_stringValue(instance, names)
    for _, descendant in ipairs(instance:GetDescendants()) do
        if descendant:IsA("StringValue") and names[string.lower(descendant.Name)] then
            local text = safeText(descendant.Value)
            if text and not GENERIC_NAMES[text] then return text end
        end
    end
end

function Feature:_attributeValue(instance, names)
    local current = instance
    while current and current ~= self.Context.Workspace do
        for name in pairs(names) do
            local ok, value = pcall(function() return current:GetAttribute(name) end)
            if ok then
                local text = safeText(value)
                if text and not GENERIC_NAMES[text] then return text end
            end
        end
        current = current.Parent
    end
end

function Feature:_modelNameCandidate(instance)
    local fruit = self:_fruitModel(instance)
    if fruit and fruit:IsA("Model") then
        local name = safeText(fruit.Name)
        if name and not GENERIC_NAMES[name] then return name end
        for _, child in ipairs(fruit:GetChildren()) do
            if (child:IsA("Model") or child:IsA("Folder")) and not GENERIC_NAMES[child.Name] then
                return child.Name
            end
        end
    end
end

function Feature:_fruitName(instance)
    if instance:IsA("Tool") then
        local name = safeText(instance.Name)
        if name and not GENERIC_NAMES[name] then return name end
    end

    local names = {
        fruitname = true,
        fruit_name = true,
        fruittype = true,
        fruit_type = true,
        displayname = true,
        display_name = true,
        fruit = true,
    }

    local attr = self:_attributeValue(instance, names)
    if attr then return attr end

    local stringValue = self:_stringValue(instance, names)
    if stringValue then return stringValue end

    local candidate = self:_modelNameCandidate(instance)
    if candidate then return candidate end

    return "Fruit"
end

function Feature:_getMap()
    return self.Context.Workspace:FindFirstChild("Map")
end

function Feature:_directMapModel(instance)
    local map = self:_getMap()
    if not map or not instance then return nil end
    local current = instance
    while current and current.Parent and current.Parent ~= map do
        current = current.Parent
    end
    if current and current.Parent == map and current:IsA("Model") then return current end
end

function Feature:_nearestIsland(position)
    local map = self:_getMap()
    if not map or not position then return nil end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Include
    rayParams.FilterDescendantsInstances = {map}
    local hit = self.Context.Workspace:Raycast(position + Vector3.new(0, 40, 0), Vector3.new(0, -160, 0), rayParams)
    if hit and hit.Instance then
        local island = self:_directMapModel(hit.Instance)
        if island then return island end
    end

    local bestIsland
    local bestDistance = math.huge
    for _, island in ipairs(map:GetChildren()) do
        if island:IsA("Model") then
            local ok, boxCFrame, boxSize = pcall(island.GetBoundingBox, island)
            if ok and boxCFrame and boxSize then
                local localPoint = boxCFrame:PointToObjectSpace(position)
                local half = boxSize * 0.5
                local clamped = Vector3.new(
                    math.clamp(localPoint.X, -half.X, half.X),
                    math.clamp(localPoint.Y, -half.Y, half.Y),
                    math.clamp(localPoint.Z, -half.Z, half.Z)
                )
                local closest = boxCFrame:PointToWorldSpace(clamped)
                local distance = (closest - position).Magnitude
                if distance < bestDistance then
                    bestDistance = distance
                    bestIsland = island
                end
            end
        end
    end
    return bestIsland
end

function Feature:_islandName(instance, position)
    local direct = self:_directMapModel(instance)
    if direct then return direct.Name end
    local nearest = self:_nearestIsland(position)
    return nearest and nearest.Name or "Desconhecida"
end

function Feature:_lineFor(record, position)
    local root = self.Context.GetRoot(self.Context.LocalPlayer.Character)
    if not root or not position or not record.Beam then return end
    if not record.RootAttachment or record.RootAttachment.Parent ~= root then
        self.Context.Destroy(record.RootAttachment)
        local attachment = Instance.new("Attachment")
        attachment.Name = "DepHubFruitLineRoot"
        attachment.Parent = root
        record.RootAttachment = attachment
    end
    if not record.FruitAttachment or record.FruitAttachment.Parent ~= record.Adornee then
        self.Context.Destroy(record.FruitAttachment)
        if record.Adornee and record.Adornee.Parent then
            local attachment = Instance.new("Attachment")
            attachment.Name = "DepHubFruitLineTarget"
            attachment.Parent = record.Adornee
            record.FruitAttachment = attachment
        end
    end
    if record.RootAttachment and record.FruitAttachment then
        record.Beam.Attachment0 = record.RootAttachment
        record.Beam.Attachment1 = record.FruitAttachment
    end
end

function Feature:_stopSpectate(record)
    if not record or not record.Spectating then return end
    record.Spectating = false
    if record.SpectateThread then
        pcall(task.cancel, record.SpectateThread)
        record.SpectateThread = nil
    end
    local camera = workspace.CurrentCamera
    if record.PreviousCamera then
        pcall(function()
            camera.CameraType = record.PreviousCamera.Type
            camera.CameraSubject = record.PreviousCamera.Subject
            if record.PreviousCamera.Type == Enum.CameraType.Scriptable and record.PreviousCamera.CFrame then
                camera.CFrame = record.PreviousCamera.CFrame
            end
        end)
    end
    record.PreviousCamera = nil
end

function Feature:_startSpectate(record)
    if not record or record.Spectating or self.State.Destroyed then return end
    local camera = workspace.CurrentCamera
    if not camera or not record.Instance or not record.Instance.Parent then return end
    self:_stopSpectate(record)
    record.Spectating = true
    record.PreviousCamera = {
        Type = camera.CameraType,
        Subject = camera.CameraSubject,
        CFrame = camera.CFrame
    }
    camera.CameraType = Enum.CameraType.Scriptable
    record.SpectateThread = task.spawn(function()
        while record.Spectating and self.Enabled and not self.State.Destroyed do
            local position = self:_position(record.Instance, self:_adornee(record.Instance))
            if not position then break end
            local target = position + Vector3.new(0, 2.5, 0)
            local current = camera.CFrame.Position
            local direction = (target - current)
            local distance = direction.Magnitude
            local offset = distance > 6 and direction.Unit * math.min(distance - 4, 2) or Vector3.zero
            camera.CFrame = CFrame.lookAt(current + offset, target)
            task.wait()
        end
        if record.Spectating then self:_stopSpectate(record) end
    end)
end

function Feature:_spectateButton(record)
    local button = Instance.new("TextButton")
    button.Name = "ViewFruitButton"
    button.Size = UDim2.new(1, -12, 0, 24)
    button.Position = UDim2.new(0, 6, 1, -28)
    button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    button.BorderSizePixel = 0
    button.Text = "SEGURE PARA VER"
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 10
    button.Parent = record.Billboard

    local function begin()
        self:_startSpectate(record)
    end

    local function finish()
        self:_stopSpectate(record)
    end

    self.Context.Connect(record.Connections, button.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then begin() end
    end)
    self.Context.Connect(record.Connections, button.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then finish() end
    end)
    self.Context.Connect(record.Connections, UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then finish() end
    end)

    return button
end

function Feature:_update(record)
    if self.State.Destroyed or not record.Label or not record.Label.Parent then return end
    local adornee = self:_adornee(record.Instance)
    local position = self:_position(record.Instance, adornee)
    local root = self.Context.GetRoot(self.Context.LocalPlayer.Character)
    if not position or not root then return end
    local distance = (root.Position - position).Magnitude
    local fruitName = self:_fruitName(record.Instance)
    local island = self:_islandName(record.Instance, position)
    record.Adornee = adornee
    record.Label.Text = fruitName .. "\nIlha: " .. island .. "\nDistância: " .. tostring(math.floor(distance + 0.5)) .. " studs"
    if record.Billboard.Adornee ~= adornee then record.Billboard.Adornee = adornee end
    self:_lineFor(record, position)
end

function Feature:_remove(instance)
    local record = self.Records[instance]
    if not record then return end
    self.Records[instance] = nil
    self:_stopSpectate(record)
    self.Context.DisconnectAll(record.Connections)
    self.Context.Destroy(record.Billboard)
    self.Context.Destroy(record.Beam)
    self.Context.Destroy(record.FruitAttachment)
    self.Context.Destroy(record.RootAttachment)
end

function Feature:_create(instance)
    if self.State.Destroyed or not self.Enabled or self.Records[instance] or not self:_isFruit(instance) then return end
    local adornee = self:_adornee(instance)
    if not adornee then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "DepHubFruitESP"
    billboard.Adornee = adornee
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 10000
    billboard.Size = UDim2.fromOffset(280, 84)
    billboard.StudsOffset = Vector3.new(0, 2.8, 0)
    billboard.Parent = adornee

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0, 54)
    label.Position = UDim2.fromOffset(0, 0)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0
    label.TextColor3 = Color3.fromRGB(255, 235, 90)
    label.TextWrapped = true
    label.Parent = billboard

    local beam = Instance.new("Beam")
    beam.Name = "DepHubFruitESPLine"
    beam.FaceCamera = true
    beam.Width0 = 0.055
    beam.Width1 = 0.055
    beam.LightEmission = 1
    beam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
    beam.Transparency = NumberSequence.new(0.12)
    beam.Parent = self.Context.LocalPlayer.Character or self.Context.Workspace

    local record = {
        Instance = instance,
        Billboard = billboard,
        Label = label,
        Beam = beam,
        Adornee = adornee,
        FruitAttachment = nil,
        RootAttachment = nil,
        Spectating = false,
        SpectateThread = nil,
        PreviousCamera = nil,
        Connections = {}
    }
    self.Records[instance] = record
    self:_spectateButton(record)
    self:_update(record)

    self.Context.Connect(record.Connections, instance.AncestryChanged, function(_, parent)
        if not parent or not self:_isFruit(instance) then self:_remove(instance) end
    end)

    if instance:IsA("Tool") then
        self.Context.Connect(record.Connections, instance.ChildAdded, function(child)
            if child.Name == "Fruit" then
                task.defer(function()
                    if self.Records[instance] then self:_update(record) end
                end)
            end
        end)
        self.Context.Connect(record.Connections, instance.ChildRemoved, function(child)
            if child.Name == "Fruit" then
                task.defer(function()
                    if self.Records[instance] and not self:_isDroppedTool(instance) then self:_remove(instance) end
                end)
            end
        end)
        self.Context.Connect(record.Connections, instance:GetPropertyChangedSignal("Name"), function() self:_update(record) end)
    end
end

function Feature:_scanRoot(root)
    if not root then return end
    local objects = root == self.Context.Workspace and root:GetDescendants() or root:GetDescendants()
    for _, instance in ipairs(objects) do
        if self:_isFruit(instance) then self:_create(instance) end
    end
end

function Feature:Enable()
    if self.Enabled or self.State.Destroyed then return true end
    self.Enabled = true
    self:_scanRoot(self.Context.Workspace)

    local fruitSpawns = self.Context.Workspace:FindFirstChild("_WorldOrigin")
    fruitSpawns = fruitSpawns and fruitSpawns:FindFirstChild("FruitSpawns")
    if fruitSpawns then self:_scanRoot(fruitSpawns) end

    self.Context.Connect(self.Connections, self.Context.Workspace.DescendantAdded, function(instance)
        if self.Enabled and self:_isFruit(instance) then task.defer(function() self:_create(instance) end) end
    end)
    self.Context.Connect(self.Connections, self.Context.Workspace.DescendantRemoving, function(instance)
        self:_remove(instance)
    end)

    self.Thread = task.spawn(function()
        while self.Enabled and not self.State.Destroyed do
            for instance, record in pairs(self.Records) do
                if not self:_isFruit(instance) or not record.Label or not record.Label.Parent then
                    self:_remove(instance)
                else
                    self:_update(record)
                end
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
    for instance in pairs(self.Records) do self:_remove(instance) end
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
