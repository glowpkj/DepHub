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

    local names = {
        "PvPDisabled",
        "PVPDisabled",
        "PvPProtection",
        "Protection",
        "Protected",
        "SafeZone",
        "NoPvP"
    }

    for _, name in ipairs(names) do
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

local function updatePlayerHealth(record)
    if not record.Label or not record.Label.Parent then
        return
    end

    record.Label.Text = record.Player.Name .. "\n" .. healthText(record.Humanoid) .. "\nPvP: " .. (record.Protected and "Desativado" or "Ativado")
end

local function updatePlayerAppearance(record)
    if State.Destroyed or not record.Highlight or not record.Label then
        return
    end

    local color = teamColor(record.Player)
    record.Highlight.FillColor = color
    record.Highlight.OutlineColor = color
    record.Label.TextColor3 = color
    updatePlayerHealth(record)
end

local function updatePlayerProtection(record)
    if State.Destroyed or not record.Character or not record.Character.Parent then
        return
    end

    record.Protected = hasProtection(record.Character)
    updatePlayerHealth(record)
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
    highlight.FillTransparency = 0.55
    highlight.OutlineTransparency = 0
    highlight.Parent = character

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "DepHubPlayerESPText"
    billboard.Adornee = head
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 10000
    billboard.Size = UDim2.fromOffset(230, 70)
    billboard.StudsOffset = Vector3.new(0, 3.2, 0)
    billboard.Parent = head

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextStrokeTransparency = 0.35
    label.Parent = billboard

    local record = {
        Character = character,
        Player = player,
        Humanoid = humanoid,
        Highlight = highlight,
        Billboard = billboard,
        Label = label,
        Protected = false,
        Connections = {}
    }

    State.PlayerESP[character] = record
    record.Protected = hasProtection(character)
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

local function fruitAdornee(instance)
    if instance:IsA("BasePart") then
        return instance
    end

    if instance:IsA("Model") then
        return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
    end

    if instance:IsA("Attachment") then
        return instance
    end

    return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function fruitPosition(instance, adornee)
    if instance:IsA("Model") then
        local ok, pivot = pcall(instance.GetPivot, instance)
        if ok then
            return pivot.Position
        end
    end

    if adornee:IsA("BasePart") then
        return adornee.Position
    end

    if adornee:IsA("Attachment") then
        return adornee.WorldPosition
    end

    return nil
end

local function createFruitESP(instance)
    if State.Destroyed or not State.Toggles.FruitESP or State.FruitESP[instance] then
        return
    end

    if string_sub(instance.Name, 1, 6) ~= "Fruit " then
        return
    end

    local adornee = fruitAdornee(instance)
    if not adornee then
        return
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "DepHubFruitESP"
    billboard.Adornee = adornee
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 10000
    billboard.Size = UDim2.fromOffset(260, 46)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.Parent = adornee

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextStrokeTransparency = 0.35
    label.TextColor3 = Color3.fromRGB(255, 220, 80)
    label.Text = instance.Name .. "\nDistância: --"
    label.Parent = billboard

    local record = {
        Instance = instance,
        Billboard = billboard,
        Label = label,
        Connections = {}
    }

    State.FruitESP[instance] = record

    connect(record.Connections, instance.AncestryChanged, function(_, parent)
        if not parent then
            State:RemoveFruitESP(instance)
        end
    end)
end

function State:RemoveFruitESP(instance)
    local record = self.FruitESP[instance]
    if not record then
        return
    end

    self.FruitESP[instance] = nil
    disconnectAll(record.Connections)
    destroy(record.Billboard)
end

local function clearFruitESP()
    for instance in pairs(State.FruitESP) do
        State:RemoveFruitESP(instance)
    end
end

local function startFruitESP()
    clearFruitESP()

    for _, instance in ipairs(Workspace:GetChildren()) do
        if string_sub(instance.Name, 1, 6) == "Fruit " then
            createFruitESP(instance)
        end
    end

    local connections = State.Connections.FruitESP or {}
    State.Connections.FruitESP = connections

    connect(connections, Workspace.ChildAdded, function(instance)
        if State.Toggles.FruitESP and string_sub(instance.Name, 1, 6) == "Fruit " then
            task.defer(createFruitESP, instance)
        end
    end)

    connect(connections, Workspace.ChildRemoved, function(instance)
        State:RemoveFruitESP(instance)
    end)

    return true
end

local function startFruitDistanceLoop()
    task.spawn(function()
        while not State.Destroyed and State.Toggles.FruitESP do
            local root = getRoot(LocalPlayer.Character)
            if root then
                for instance, record in pairs(State.FruitESP) do
                    if not instance.Parent or not record.Label.Parent then
                        State:RemoveFruitESP(instance)
                    else
                        local adornee = fruitAdornee(instance)
                        local position = adornee and fruitPosition(instance, adornee)
                        if position then
                            local distance = (root.Position - position).Magnitude
                            record.Label.Text = instance.Name .. "\nDistância: " .. tostring(math_floor(distance + 0.5)) .. " studs"
                        end
                    end
                end
            end
            task.wait(0.25)
        end
    end)
end

local function applyCameraShake(enabled)
    if not ChangeSetting or not ChangeSetting:IsA("RemoteEvent") then
        return false
    end

    return pcall(ChangeSetting.FireServer, ChangeSetting, "CameraShake", enabled)
end

function State:SetCameraShake(enabled)
    if self.Destroyed then
        return false
    end

    return applyCameraShake(enabled == true)
end

local function setVisionRadius()
    if not LocalPlayer then
        return
    end

    local ok = pcall(function()
        if LocalPlayer.VisionRadius ~= 5000 then
            LocalPlayer.VisionRadius = 5000
        end
    end)

    if not ok then
        local valueObject = LocalPlayer:FindFirstChild("VisionRadius")
        if valueObject and valueObject:IsA("NumberValue") and valueObject.Value ~= 5000 then
            pcall(function()
                valueObject.Value = 5000
            end)
        end
    end
end

local function startObservationHaki()
    task.spawn(function()
        while not State.Destroyed and State.Toggles.ObservationHaki do
            setVisionRadius()
            task.wait(0.5)
        end
    end)
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
    State.OriginalUnbreakableAll = nil
    State.UnbreakableCaptured = false

    pcall(function()
        LocalPlayer:SetAttribute("UnbreakableAll", original)
    end)
end

local function stopPlayerESP()
    disconnectAll(State.Connections.PlayerESP)
    State.Connections.PlayerESP = nil
    clearPlayerESP()
end

local function stopFruitESP()
    disconnectAll(State.Connections.FruitESP)
    State.Connections.FruitESP = nil
    clearFruitESP()
end

function State:SetToggle(name, enabled)
    if self.Destroyed or type(name) ~= "string" then
        return false
    end

    enabled = enabled == true

    if name == "PlayerESP" then
        self.Toggles.PlayerESP = enabled
        if enabled then
            return startPlayerESP()
        end
        stopPlayerESP()
        return true
    end

    if name == "FruitESP" then
        self.Toggles.FruitESP = enabled
        if enabled then
            local ok = startFruitESP()
            if ok then
                startFruitDistanceLoop()
            end
            return ok
        end
        stopFruitESP()
        return true
    end

    if name == "UnbreakableAll" then
        self.Toggles.UnbreakableAll = enabled
        if enabled then
            startUnbreakableAll()
        else
            stopUnbreakableAll()
        end
        return true
    end

    if name == "ObservationHaki" then
        self.Toggles.ObservationHaki = enabled
        if enabled then
            startObservationHaki()
        end
        return true
    end

    return false
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
    self.Started = false
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
        return self.Started
    end

    if not LocalPlayer then
        return false
    end

    applyCameraShake(false)
    startObservationHaki()
    self.Started = true
    return true
end

if not LocalPlayer then
    return false
end

local ok, started = pcall(State.Start, State)
if not ok or started ~= true then
    pcall(State.Destroy, State)
    return false
end

return State
