local game = game
local task = task
local type = type
local tonumber = tonumber
local tostring = tostring
local pcall = pcall
local pairs = pairs
local ipairs = ipairs
local string_sub = string.sub
local string_lower = string.lower
local string_find = string.find
local string_gsub = string.gsub
local math_floor = math.floor

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local Characters = Workspace:FindFirstChild("Characters")
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local ChangeSetting = Remotes and Remotes:FindFirstChild("ChangeSetting")
local Pirates = Teams:FindFirstChild("Pirates")
local Marines = Teams:FindFirstChild("Marines")

local Effect = ReplicatedStorage:FindFirstChild("Effect")
local EffectContainer = Effect and Effect:FindFirstChild("Container")
local Ice1 = EffectContainer and EffectContainer:FindFirstChild("Ice1")
local Waterwalk = Ice1 and Ice1:FindFirstChild("Waterwalk")
local IceEffect = Waterwalk and Waterwalk:FindFirstChild("ice")
local NPCs = ReplicatedStorage:FindFirstChild("NPCs")
local LegendarySwordDealer = NPCs and NPCs:FindFirstChild("Legendary Sword Dealer")

local env = type(getgenv) == "function" and getgenv() or _G
local STATE_KEY = "__DEPHUB_BLOXFRUITS"
local previous = type(env[STATE_KEY]) == "table" and env[STATE_KEY] or nil
if previous and type(previous.Destroy) == "function" then
    pcall(previous.Destroy, previous)
end

local State = {
    Started = false,
    Destroyed = false,
    Toggles = {
        ObservationHaki = true,
        PlayerESP = false,
        FruitESP = false,
        UnbreakableAll = false
    },
    Connections = {},
    PlayerESP = {},
    FruitESP = {},
    OriginalUnbreakableAll = nil,
    UnbreakableCaptured = false,
    CameraShakeDisabled = false,
    Paths = {
        IceEffect = IceEffect,
        LegendarySwordDealer = LegendarySwordDealer,
        IceEffectPath = "game:GetService(\"ReplicatedStorage\").Effect.Container.Ice1.Waterwalk.ice",
        LegendarySwordDealerPath = "game:GetService(\"ReplicatedStorage\").NPCs[\"Legendary Sword Dealer\"]"
    }
}

env[STATE_KEY] = State
env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.BloxFruits = State
env.__DEPHUB.BloxFruitsPaths = State.Paths

local function connect(list, signal, callback)
    if not signal then
        return nil
    end

    local ok, connection = pcall(signal.Connect, signal, callback)
    if ok and connection then
        list[#list + 1] = connection
        return connection
    end

    return nil
end

local function disconnectAll(list)
    if not list then
        return
    end

    for index = #list, 1, -1 do
        local connection = list[index]
        list[index] = nil
        if connection then
            pcall(connection.Disconnect, connection)
        end
    end
end

local function destroy(instance)
    if instance then
        pcall(instance.Destroy, instance)
    end
end

local function getRoot(character)
    if not character then
        return nil
    end

    local root = character:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        return root
    end

    local head = character:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        return head
    end

    return character:FindFirstChildWhichIsA("BasePart", true)
end

local function getPlayer(character)
    if not character then
        return nil
    end

    return Players:GetPlayerFromCharacter(character) or Players:FindFirstChild(character.Name)
end

local function getHumanoid(character)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function healthText(humanoid)
    if not humanoid then
        return "Vida: --/--"
    end

    local health = tonumber(humanoid.Health)
    local maxHealth = tonumber(humanoid.MaxHealth)
    if not health or not maxHealth then
        return "Vida: --/--"
    end

    return "Vida: " .. tostring(math_floor(health + 0.5)) .. "/" .. tostring(math_floor(maxHealth + 0.5))
end

local function isProtectionName(name)
    if type(name) ~= "string" then
        return false
    end

    local lowered = string_lower(name)
    return lowered == "pvpdisabled"
        or lowered == "pvpdisabledvalue"
        or lowered == "pvpprotection"
        or lowered == "protection"
        or lowered == "protected"
        or lowered == "safezone"
        or lowered == "nopvp"
        or string_sub(lowered, 1, 8) == "protect_"
end

local function hasProtection(character)
    if not character then
        return false
    end

    if character:FindFirstChildOfClass("ForceField") then
        return true
    end

    local attributeNames = {
        "PvPDisabled",
        "PVPDisabled",
        "PvPProtection",
        "Protection",
        "Protected",
        "SafeZone",
        "NoPvP"
    }

    for _, name in ipairs(attributeNames) do
        if character:GetAttribute(name) == true then
            return true
        end
    end

    for _, object in ipairs(character:GetDescendants()) do
        if isProtectionName(object.Name) then
            if object:IsA("BoolValue") and object.Value then
                return true
            end
            if (object:IsA("IntValue") or object:IsA("NumberValue")) and object.Value ~= 0 then
                return true
            end
            if object:IsA("ObjectValue") and object.Value ~= nil then
                return true
            end
        end
    end

    return false
end

local function teamColor(player)
    if player and player.Team == Pirates then
        return BrickColor.new("Persimmon").Color
    end

    if player and player.Team == Marines then
        return BrickColor.new("Pastel light blue").Color
    end

    return BrickColor.new("Institutional white").Color
end

local function updatePlayerText(record)
    if not record.Label or not record.Label.Parent then
        return
    end

    local lines = {
        record.Player.Name,
        healthText(record.Humanoid)
    }

    if not record.Protected then
        lines[#lines + 1] = "PvP: Ativado"
    end

    record.Label.Text = table.concat(lines, "\n")
end

local function updatePlayerAppearance(record)
    if State.Destroyed or not record.Highlight or not record.Label then
        return
    end

    local color = teamColor(record.Player)
    record.Highlight.FillColor = color
    record.Highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    record.Label.TextColor3 = Color3.fromRGB(255, 255, 255)
    updatePlayerText(record)
end

local function updatePlayerHealth(record)
    if State.Destroyed then
        return
    end
    updatePlayerText(record)
end

local function updatePlayerProtection(record)
    if State.Destroyed or not record.Character or not record.Character.Parent then
        return
    end

    record.Protected = hasProtection(record.Character)
    updatePlayerText(record)
end

local function createPlayerESP(character)
    if State.Destroyed or not State.Toggles.PlayerESP or not character then
        return
    end

    if character == LocalPlayer.Character or State.PlayerESP[character] then
        return
    end

    local player = getPlayer(character)
    if not player or player == LocalPlayer then
        return
    end

    local head = character:FindFirstChild("Head")
    local humanoid = getHumanoid(character)
    if not head or not humanoid then
        return
    end

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

    local record = {
        Character = character,
        Player = player,
        Humanoid = humanoid,
        Highlight = highlight,
        Billboard = billboard,
        Label = label,
        Protected = hasProtection(character),
        Connections = {}
    }

    State.PlayerESP[character] = record
    updatePlayerAppearance(record)

    connect(record.Connections, humanoid:GetPropertyChangedSignal("Health"), function()
        updatePlayerHealth(record)
    end)

    connect(record.Connections, humanoid:GetPropertyChangedSignal("MaxHealth"), function()
        updatePlayerHealth(record)
    end)

    connect(record.Connections, player:GetPropertyChangedSignal("Team"), function()
        updatePlayerAppearance(record)
    end)

    connect(record.Connections, character.ChildAdded, function(child)
        if child:IsA("ForceField") or isProtectionName(child.Name) then
            updatePlayerProtection(record)
        end
    end)

    connect(record.Connections, character.ChildRemoved, function(child)
        if child:IsA("ForceField") or isProtectionName(child.Name) then
            task.defer(updatePlayerProtection, record)
        end
    end)

    connect(record.Connections, character.DescendantAdded, function(descendant)
        if isProtectionName(descendant.Name) or descendant:IsA("ForceField") then
            updatePlayerProtection(record)
        end
    end)

    connect(record.Connections, character.DescendantRemoving, function(descendant)
        if isProtectionName(descendant.Name) or descendant:IsA("ForceField") then
            task.defer(updatePlayerProtection, record)
        end
    end)

    local attributeNames = {
        "PvPDisabled",
        "PVPDisabled",
        "PvPProtection",
        "Protection",
        "Protected",
        "SafeZone",
        "NoPvP"
    }

    for _, attributeName in ipairs(attributeNames) do
        connect(record.Connections, character:GetAttributeChangedSignal(attributeName), function()
            updatePlayerProtection(record)
        end)
    end

    connect(record.Connections, character.AncestryChanged, function(_, parent)
        if not parent then
            State:RemovePlayerESP(character)
        end
    end)
end

function State:RemovePlayerESP(character)
    local record = self.PlayerESP[character]
    if not record then
        return
    end

    self.PlayerESP[character] = nil
    disconnectAll(record.Connections)
    destroy(record.Highlight)
    destroy(record.Billboard)
end

local function clearPlayerESP()
    for character in pairs(State.PlayerESP) do
        State:RemovePlayerESP(character)
    end
end

local function startPlayerESP()
    Characters = Characters or Workspace:FindFirstChild("Characters")
    if not Characters then
        return false
    end

    clearPlayerESP()

    for _, character in ipairs(Characters:GetChildren()) do
        if character:IsA("Model") then
            createPlayerESP(character)
        end
    end

    local connections = State.Connections.PlayerESP or {}
    State.Connections.PlayerESP = connections

    connect(connections, Characters.ChildAdded, function(character)
        if State.Toggles.PlayerESP and character:IsA("Model") then
            task.defer(createPlayerESP, character)
        end
    end)

    connect(connections, Characters.ChildRemoved, function(character)
        State:RemovePlayerESP(character)
    end)

    return true
end

local function fruitRootFromInstance(instance)
    if not instance then
        return nil
    end

    local current = instance
    while current and current ~= Workspace do
        if current:IsA("Tool") then
            return current
        end
        current = current.Parent
    end

    return nil
end

local function fruitModel(tool)
    if not tool or not tool:IsA("Tool") then
        return nil
    end

    return tool:FindFirstChild("Fruit")
end

local function fruitAdornee(tool, fruit)
    if fruit then
        if fruit:IsA("Model") then
            return fruit.PrimaryPart or fruit:FindFirstChildWhichIsA("BasePart", true)
        end

        if fruit:IsA("BasePart") then
            return fruit
        end

        if fruit:IsA("Attachment") then
            return fruit
        end
    end

    if tool then
        local handle = tool:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then
            return handle
        end
        return tool:FindFirstChildWhichIsA("BasePart", true)
    end

    return nil
end

local function fruitPosition(tool, fruit, adornee)
    if fruit and fruit:IsA("Model") then
        local ok, pivot = pcall(fruit.GetPivot, fruit)
        if ok then
            return pivot.Position
        end
    end

    if adornee and adornee:IsA("BasePart") then
        return adornee.Position
    end

    if adornee and adornee:IsA("Attachment") then
        return adornee.WorldPosition
    end

    if tool then
        local handle = tool:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then
            return handle.Position
        end
    end

    return nil
end

local function fruitName(tool)
    if not tool then
        return "Fruit"
    end

    local name = tostring(tool.Name)
    local lower = string_lower(name)

    if string_sub(lower, -6) == " fruit" then
        return name
    end

    local spaced = string_gsub(name, "([Ff][Rr][Uu][Ii][Tt])", "Fruit")
    if string_find(string_lower(spaced), "fruit", 1, true) then
        return spaced
    end

    return name
end

local function isDroppedFruitTool(tool)
    if not tool or not tool:IsA("Tool") or tool.Parent ~= Workspace then
        return false
    end

    return fruitModel(tool) ~= nil
end

local function updateFruitRecord(record)
    if State.Destroyed or not record.Label or not record.Label.Parent then
        return
    end

    local fruit = fruitModel(record.Tool)
    local adornee = fruitAdornee(record.Tool, fruit)
    local position = fruitPosition(record.Tool, fruit, adornee)
    local root = getRoot(LocalPlayer.Character)

    if not position or not root then
        return
    end

    local distance = (root.Position - position).Magnitude
    record.Label.Text = fruitName(record.Tool) .. "\nDistância: " .. tostring(math_floor(distance + 0.5)) .. " studs"

    if record.Billboard.Adornee ~= adornee then
        record.Billboard.Adornee = adornee
    end
end

local function createFruitESP(tool)
    if State.Destroyed or not State.Toggles.FruitESP or State.FruitESP[tool] then
        return
    end

    if not isDroppedFruitTool(tool) then
        return
    end

    local fruit = fruitModel(tool)
    local adornee = fruitAdornee(tool, fruit)
    if not adornee then
        return
    end

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

    local record = {
        Tool = tool,
        Fruit = fruit,
        Billboard = billboard,
        Label = label,
        Connections = {}
    }

    State.FruitESP[tool] = record
    updateFruitRecord(record)

    connect(record.Connections, tool.AncestryChanged, function(_, parent)
        if not parent or not isDroppedFruitTool(tool) then
            State:RemoveFruitESP(tool)
        end
    end)

    connect(record.Connections, tool.ChildAdded, function(child)
        if child.Name == "Fruit" then
            record.Fruit = child
            updateFruitRecord(record)
        end
    end)

    connect(record.Connections, tool.ChildRemoved, function(child)
        if child == record.Fruit then
            task.defer(function()
                if State.FruitESP[tool] then
                    record.Fruit = fruitModel(tool)
                    if not record.Fruit then
                        State:RemoveFruitESP(tool)
                    else
                        updateFruitRecord(record)
                    end
                end
            end)
        end
    end)

    connect(record.Connections, tool:GetPropertyChangedSignal("Name"), function()
        updateFruitRecord(record)
    end)
end

function State:RemoveFruitESP(tool)
    local record = self.FruitESP[tool]
    if not record then
        return
    end

    self.FruitESP[tool] = nil
    disconnectAll(record.Connections)
    destroy(record.Billboard)
end

local function clearFruitESP()
    for tool in pairs(State.FruitESP) do
        State:RemoveFruitESP(tool)
    end
end

local function scanDroppedFruits()
    for _, instance in ipairs(Workspace:GetChildren()) do
        if instance:IsA("Tool") and isDroppedFruitTool(instance) then
            createFruitESP(instance)
        end
    end
end

local function startFruitESP()
    clearFruitESP()
    scanDroppedFruits()

    local connections = State.Connections.FruitESP or {}
    State.Connections.FruitESP = connections

    connect(connections, Workspace.ChildAdded, function(instance)
        if State.Toggles.FruitESP and instance:IsA("Tool") then
            task.defer(createFruitESP, instance)
        end
    end)

    connect(connections, Workspace.ChildRemoved, function(instance)
        if instance:IsA("Tool") then
            State:RemoveFruitESP(instance)
        end
    end)

    task.spawn(function()
        while not State.Destroyed and State.Toggles.FruitESP do
            for tool, record in pairs(State.FruitESP) do
                if not isDroppedFruitTool(tool) or not record.Label or not record.Label.Parent then
                    State:RemoveFruitESP(tool)
                else
                    updateFruitRecord(record)
                end
            end
            task.wait(0.2)
        end
    end)

    return true
end

local function setVisionRadius(value)
    if not LocalPlayer then
        return false
    end

    local ok = pcall(function()
        if LocalPlayer.VisionRadius ~= value then
            LocalPlayer.VisionRadius = value
        end
    end)

    if ok and LocalPlayer.VisionRadius == value then
        return true
    end

    local valueObject = LocalPlayer:FindFirstChild("VisionRadius")
    if valueObject and valueObject:IsA("NumberValue") and valueObject.Value ~= value then
        pcall(function()
            valueObject.Value = value
        end)
    end

    return valueObject and valueObject:IsA("NumberValue") and valueObject.Value == value or false
end

local function startObservationHaki()
    task.spawn(function()
        while not State.Destroyed and State.Toggles.ObservationHaki do
            pcall(function()
                if LocalPlayer.VisionRadius ~= 5000 then
                    setVisionRadius(5000)
                end
            end)
            task.wait(0.5)
        end
    end)
end

local function setCameraShake(enabled)
    if not ChangeSetting or not ChangeSetting:IsA("RemoteEvent") then
        return false
    end

    local ok = pcall(function()
        ChangeSetting:FireServer("CameraShake", enabled)
    end)

    if ok then
        State.CameraShakeDisabled = not enabled
    end

    return ok
end

local function startUnbreakableAll()
    if not State.UnbreakableCaptured then
        State.OriginalUnbreakableAll = LocalPlayer:GetAttribute("UnbreakableAll")
        State.UnbreakableCaptured = true
    end

    task.spawn(function()
        while not State.Destroyed and State.Toggles.UnbreakableAll do
            pcall(function()
                if LocalPlayer:GetAttribute("UnbreakableAll") ~= true then
                    LocalPlayer:SetAttribute("UnbreakableAll", true)
                end
            end)
            task.wait(0.75)
        end
    end)
end

local function stopUnbreakableAll()
    if not State.UnbreakableCaptured then
        return
    end

    local original = State.OriginalUnbreakableAll
    State.UnbreakableCaptured = false
    State.OriginalUnbreakableAll = nil

    pcall(function()
        LocalPlayer:SetAttribute("UnbreakableAll", original)
    end)
end

local function stopPlayerESP()
    disconnectAll(State.Connections.PlayerESP or {})
    State.Connections.PlayerESP = nil
    clearPlayerESP()
end

local function stopFruitESP()
    disconnectAll(State.Connections.FruitESP or {})
    State.Connections.FruitESP = nil
    clearFruitESP()
end

function State:SetCameraShake(enabled)
    if self.Destroyed then
        return false
    end

    return setCameraShake(enabled == true)
end

function State:SetToggle(name, enabled)
    if self.Destroyed or type(name) ~= "string" then
        return false
    end

    enabled = enabled == true
    if self.Toggles[name] == enabled then
        return true
    end

    self.Toggles[name] = enabled

    if name == "ObservationHaki" then
        if enabled then
            startObservationHaki()
        end
    elseif name == "PlayerESP" then
        if enabled then
            return startPlayerESP()
        end
        stopPlayerESP()
    elseif name == "FruitESP" then
        if enabled then
            return startFruitESP()
        end
        stopFruitESP()
    elseif name == "UnbreakableAll" then
        if enabled then
            startUnbreakableAll()
        else
            stopUnbreakableAll()
        end
    else
        return false
    end

    return true
end

function State:GetToggle(name)
    return self.Toggles[name] == true
end

function State:GetPaths()
    return self.Paths
end

function State:Destroy()
    if self.Destroyed then
        return
    end

    self.Destroyed = true
    self.Toggles.ObservationHaki = false
    self.Toggles.PlayerESP = false
    self.Toggles.FruitESP = false
    self.Toggles.UnbreakableAll = false

    stopPlayerESP()
    stopFruitESP()
    stopUnbreakableAll()
    disconnectAll(self.Connections)

    if env[STATE_KEY] == self then
        env[STATE_KEY] = nil
    end

    if env.__DEPHUB and env.__DEPHUB.BloxFruits == self then
        env.__DEPHUB.BloxFruits = nil
    end
end

function State:Start()
    if self.Destroyed or self.Started then
        return false
    end

    self.Started = true
    setCameraShake(false)
    startObservationHaki()
    return true
end

if not LocalPlayer then
    return false
end

local ok, started = pcall(State.Start, State)
if not ok or not started then
    pcall(State.Destroy, State)
    return false
end

return State
