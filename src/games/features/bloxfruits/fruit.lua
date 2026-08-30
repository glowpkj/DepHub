local game = game
local task = task
local pcall = pcall
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local string_lower = string.lower
local math_floor = math.floor

local GENERIC_NAMES = {Fruit = true, Handle = true, Weld = true, Welded = true, Keep = true, Script = true, LocalScript = true, ToolScript = true, FruitAnimator = true, EatRemote = true}
local WORLD_NON_ISLANDS = {Camera = true, Characters = true, _WorldOrigin = true, Map = true, Effects = true, Effect = true, Debris = true, Ignore = true, Temp = true, Temporary = true, SpawnLocation = true, Fruit = true}

local function safeText(value)
    if value == nil then return nil end
    local text = tostring(value)
    return text ~= "" and text or nil
end

local Feature = {}
Feature.__index = Feature

function Feature.new(context)
    return setmetatable({Context = context, State = context.State, Connections = {}, Records = {}, Enabled = false, Thread = nil}, Feature)
end

function Feature:_isDroppedTool(instance)
    return instance and instance:IsA("Tool") and instance.Parent == self.Context.Workspace and instance:FindFirstChild("Fruit") ~= nil
end

function Feature:_isSpawnedFruit(instance)
    return instance and instance:IsA("Model") and instance.Name == "Fruit" and not instance:FindFirstAncestorOfClass("Tool") and instance:IsDescendantOf(self.Context.Workspace)
end

function Feature:_isFruitSpawnEntry(instance)
    local worldOrigin = self.Context.Workspace:FindFirstChild("_WorldOrigin")
    local fruitSpawns = worldOrigin and worldOrigin:FindFirstChild("FruitSpawns")
    if not fruitSpawns or not instance or not instance:IsDescendantOf(fruitSpawns) then return false end
    if instance:IsA("Tool") then return instance:FindFirstChild("Fruit") ~= nil end
    return instance:IsA("Model") and instance.Name == "Fruit" and not instance:FindFirstAncestorOfClass("Tool")
end

function Feature:_isFruit(instance)
    return self:_isDroppedTool(instance) or self:_isSpawnedFruit(instance) or self:_isFruitSpawnEntry(instance)
end

function Feature:_fruitModel(instance)
    if not instance then return nil end
    if instance:IsA("Tool") then return instance:FindFirstChild("Fruit") end
    if instance:IsA("Model") then return instance end
end

function Feature:_adornee(instance)
    local fruit = self:_fruitModel(instance)
    if fruit and fruit:IsA("Model") then return fruit.PrimaryPart or fruit:FindFirstChildWhichIsA("BasePart", true) end
    if instance:IsA("Tool") then return instance:FindFirstChild("Handle") or instance:FindFirstChildWhichIsA("BasePart", true) end
    return fruit
end

function Feature:_position(instance, adornee)
    local fruit = self:_fruitModel(instance)
    if fruit and fruit:IsA("Model") then
        local ok, pivot = pcall(fruit.GetPivot, fruit)
        if ok and pivot then return pivot.Position end
    end
    if adornee and adornee:IsA("BasePart") then return adornee.Position end
    if adornee and adornee:IsA("Attachment") then return adornee.WorldPosition end
end

function Feature:_attribute(instance, name)
    local current = instance
    while current and current ~= self.Context.Workspace do
        local ok, value = pcall(current.GetAttribute, current, name)
        if ok and value ~= nil then return safeText(value) end
        current = current.Parent
    end
end

function Feature:_signature(adornee)
    local signatures = self.State and self.State.FruitSignatures
    if type(signatures) ~= "table" or not adornee then return nil end
    local meshId = nil
    local textureId = nil
    local mesh = adornee:FindFirstChildWhichIsA("SpecialMesh")
    if mesh then
        meshId = safeText(mesh.MeshId)
        textureId = safeText(mesh.TextureId)
    end
    if adornee:IsA("MeshPart") then
        meshId = meshId or safeText(adornee.MeshId)
        textureId = textureId or safeText(adornee.TextureID)
    end
    for fruitName, signature in pairs(signatures) do
        if type(signature) == "table" then
            local wantedMesh = safeText(signature.MeshId)
            local wantedTexture = safeText(signature.TextureId)
            if (wantedMesh and meshId == wantedMesh) or (wantedTexture and textureId == wantedTexture) then return safeText(fruitName) end
        elseif type(signature) == "string" and (signature == meshId or signature == textureId) then
            return safeText(fruitName)
        end
    end
end

function Feature:_fruitName(instance, adornee)
    local original = self:_attribute(instance, "OriginalName")
    if original and not GENERIC_NAMES[original] then return original end
    local fruit = self:_fruitModel(instance)
    if fruit then
        local value = self:_attribute(fruit, "OriginalName")
        if value and not GENERIC_NAMES[value] then return value end
    end
    local signature = self:_signature(adornee)
    if signature then return signature end
    if instance:IsA("Tool") then
        local name = safeText(instance.Name)
        if name and not GENERIC_NAMES[name] then return name end
    end
    if fruit and fruit:IsA("Model") then
        local name = safeText(fruit.Name)
        if name and not GENERIC_NAMES[name] then return name end
    end
    return "Fruit"
end

function Feature:_droppedBy(instance)
    local value = self:_attribute(instance, "DroppedBy")
    if value then return value end
    local fruit = self:_fruitModel(instance)
    return fruit and self:_attribute(fruit, "DroppedBy") or nil
end

function Feature:_getMap()
    return self.Context.Workspace:FindFirstChild("Map")
end

function Feature:_directMapModel(instance)
    local map = self:_getMap()
    local current = instance
    while map and current and current.Parent and current.Parent ~= map do current = current.Parent end
    if map and current and current.Parent == map and current:IsA("Model") then return current end
end

function Feature:_directWorldModel(instance)
    local map = self:_getMap()
    local current = instance
    while current and current.Parent do
        if current.Parent == self.Context.Workspace then
            return current:IsA("Model") and not WORLD_NON_ISLANDS[current.Name] and current or nil
        end
        if map and current.Parent == map then return nil end
        current = current.Parent
    end
end

function Feature:_nearestIsland(position)
    if not position then return nil end
    local candidates = {}
    local map = self:_getMap()
    if map then
        for _, island in ipairs(map:GetChildren()) do if island:IsA("Model") then candidates[#candidates + 1] = island end end
    end
    for _, object in ipairs(self.Context.Workspace:GetChildren()) do
        if object:IsA("Model") and not WORLD_NON_ISLANDS[object.Name] then candidates[#candidates + 1] = object end
    end
    local best, bestDistance = nil, math.huge
    for _, island in ipairs(candidates) do
        local ok, cf, size = pcall(island.GetBoundingBox, island)
        if ok and cf and size then
            local point = cf:PointToObjectSpace(position)
            local half = size * 0.5
            local clamped = Vector3.new(math.clamp(point.X, -half.X, half.X), math.clamp(point.Y, -half.Y, half.Y), math.clamp(point.Z, -half.Z, half.Z))
            local distance = (cf:PointToWorldSpace(clamped) - position).Magnitude
            if distance < bestDistance then bestDistance, best = distance, island end
        end
    end
    return best
end

function Feature:_islandName(instance, position)
    local direct = self:_directMapModel(instance) or self:_directWorldModel(instance) or self:_nearestIsland(position)
    return direct and direct.Name or "Desconhecida"
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
    if not record then return end
    record.Spectating = false
    if record.SpectateThread then pcall(task.cancel, record.SpectateThread); record.SpectateThread = nil end
    local camera = workspace.CurrentCamera
    if record.PreviousCamera and camera then
        pcall(function()
            camera.CameraType = record.PreviousCamera.Type
            camera.CameraSubject = record.PreviousCamera.Subject
            if record.PreviousCamera.Type == Enum.CameraType.Scriptable then camera.CFrame = record.PreviousCamera.CFrame end
        end)
    end
    record.PreviousCamera = nil
end

function Feature:_startSpectate(record)
    if not record or record.Spectating or self.State.Destroyed then return end
    local camera = workspace.CurrentCamera
    if not camera or not record.Instance or not record.Instance.Parent then return end
    local adornee = self:_adornee(record.Instance)
    local position = self:_position(record.Instance, adornee)
    if not position then return end
    record.Spectating = true
    record.PreviousCamera = {Type = camera.CameraType, Subject = camera.CameraSubject, CFrame = camera.CFrame}
    task.defer(function()
        if not record.Spectating or not self.Enabled or self.State.Destroyed then return end
        local ok = pcall(function() self.Context.LocalPlayer:RequestStreamAroundAsync(position) end)
        if not ok then return end
        if not record.Spectating or not self.Enabled or self.State.Destroyed then return end
        camera.CameraType = Enum.CameraType.Scriptable
        record.SpectateThread = task.spawn(function()
            while record.Spectating and self.Enabled and not self.State.Destroyed do
                local currentAdornee = self:_adornee(record.Instance)
                local currentPosition = self:_position(record.Instance, currentAdornee)
                if not currentPosition then break end
                local target = currentPosition + Vector3.new(0, 2.5, 0)
                camera.CFrame = CFrame.lookAt(target + Vector3.new(0, 5, 12), target)
                task.wait()
            end
            if record.Spectating then self:_stopSpectate(record) end
        end)
    end)
end

function Feature:_update(record)
    if self.State.Destroyed or not record.Label or not record.Label.Parent then return end
    local adornee = self:_adornee(record.Instance)
    local position = self:_position(record.Instance, adornee)
    local root = self.Context.GetRoot(self.Context.LocalPlayer.Character)
    if not position or not root then return end
    local distance = (root.Position - position).Magnitude
    local fruitName = self:_fruitName(record.Instance, adornee)
    local droppedBy = self:_droppedBy(record.Instance) or "Desconhecido"
    local island = self:_islandName(record.Instance, position)
    record.Adornee = adornee
    record.Label.Text = fruitName .. " - Dropado por: " .. droppedBy .. "\nIlha: " .. island .. "\nDistância: " .. tostring(math_floor(distance + 0.5)) .. " studs"
    record.Billboard.Adornee = adornee
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
    billboard.Size = UDim2.fromOffset(300, 70)
    billboard.StudsOffset = Vector3.new(0, 2.8, 0)
    billboard.Parent = adornee
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0, 70)
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
    beam.Parent = self.Context.Workspace
    local record = {Instance = instance, Billboard = billboard, Label = label, Beam = beam, Adornee = adornee, FruitAttachment = nil, RootAttachment = nil, Spectating = false, SpectateThread = nil, PreviousCamera = nil, Connections = {}}
    self.Records[instance] = record
    self:_update(record)
    self.Context.Connect(record.Connections, instance.AncestryChanged, function(_, parent)
        if not parent or not self:_isFruit(instance) then self:_remove(instance) end
    end)
    if instance:IsA("Tool") then
        self.Context.Connect(record.Connections, instance.ChildAdded, function(child)
            if child.Name == "Fruit" then task.defer(function() if self.Records[instance] then self:_update(record) end end) end
        end)
        self.Context.Connect(record.Connections, instance.ChildRemoved, function(child)
            if child.Name == "Fruit" then task.defer(function() if self.Records[instance] and not self:_isDroppedTool(instance) then self:_remove(instance) end end) end
        end)
        self.Context.Connect(record.Connections, instance:GetPropertyChangedSignal("Name"), function() self:_update(record) end)
    end
end

function Feature:_scanRoot(root)
    if not root then return end
    for _, instance in ipairs(root:GetDescendants()) do if self:_isFruit(instance) then self:_create(instance) end end
end

function Feature:Enable()
    if self.Enabled or self.State.Destroyed then return true end
    self.Enabled = true
    self:_scanRoot(self.Context.Workspace)
    local worldOrigin = self.Context.Workspace:FindFirstChild("_WorldOrigin")
    local fruitSpawns = worldOrigin and worldOrigin:FindFirstChild("FruitSpawns")
    if fruitSpawns then self:_scanRoot(fruitSpawns) end
    self.Context.Connect(self.Connections, self.Context.Workspace.DescendantAdded, function(instance)
        if self.Enabled and self:_isFruit(instance) then task.defer(function() self:_create(instance) end) end
    end)
    self.Context.Connect(self.Connections, self.Context.Workspace.DescendantRemoving, function(instance) self:_remove(instance) end)
    self.Thread = task.spawn(function()
        while self.Enabled and not self.State.Destroyed do
            for instance, record in pairs(self.Records) do
                if not self:_isFruit(instance) or not record.Label or not record.Label.Parent then self:_remove(instance) else self:_update(record) end
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
