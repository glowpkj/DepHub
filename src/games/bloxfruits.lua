local game = game
local task = task
local pcall = pcall
local type = type
local tostring = tostring
local tonumber = tonumber
local ipairs = ipairs
local pairs = pairs
local string_sub = string.sub
local string_lower = string.lower
local math_floor = math.floor
local os_clock = os.clock
local warn = warn
local print = print

local GetService = game.GetService
local FindFirstChild = game.FindFirstChild
local Players = GetService(game, "Players")
local ReplicatedStorage = GetService(game, "ReplicatedStorage")
local Teams = GetService(game, "Teams")
local Workspace = GetService(game, "Workspace")
local LocalPlayer = Players.LocalPlayer

local Characters = Workspace:FindFirstChild("Characters")
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local ChangeSetting = Remotes and Remotes:FindFirstChild("ChangeSetting")
local Effect = ReplicatedStorage:FindFirstChild("Effect")
local EffectContainer = Effect and Effect:FindFirstChild("Container")
local Ice1 = EffectContainer and EffectContainer:FindFirstChild("Ice1")
local Waterwalk = Ice1 and Ice1:FindFirstChild("Waterwalk")
local IceEffect = Waterwalk and Waterwalk:FindFirstChild("ice")
local NPCs = ReplicatedStorage:FindFirstChild("NPCs")
local LegendarySwordDealer = NPCs and NPCs:FindFirstChild("Legendary Sword Dealer")
local Pirates = Teams:FindFirstChild("Pirates")
local Marines = Teams:FindFirstChild("Marines")

local STATE_KEY = "__DEPHUB_BLOXFRUITS"
local env = type(getgenv) == "function" and getgenv() or _G
local previous = type(env[STATE_KEY]) == "table" and env[STATE_KEY] or nil

if previous and type(previous.Destroy) == "function" then
    pcall(previous.Destroy, previous)
end

local State = {
    Destroyed = false,
    Toggles = {
        CameraShake = true,
        ObservationHaki = true,
        PlayerESP = false,
        UnbreakableAll = false,
        FruitESP = false
    },
    Connections = {},
    PlayerESP = {},
    FruitESP = {},
    OriginalUnbreakableAll = nil,
    UnbreakableCaptured = false
}

env[STATE_KEY] = State

env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.BloxFruits = State

env.__DEPHUB.BloxFruitsPaths = {
    IceEffect = "game:GetService(\"ReplicatedStorage\").Effect.Container.Ice1.Waterwalk.ice",
    LegendarySwordDealer = "game:GetService(\"ReplicatedStorage\").NPCs[\"Legendary Sword Dealer\"]"
}

local function log(message)
    pcall(print, "[DEPHUB BLOX FRUITS] " .. tostring(message))
end

local function logWarn(message)
    pcall(warn, "[DEPHUB BLOX FRUITS] " .. tostring(message))
end

local function connect(connectionList, signal, callback)
    if not signal then
        return nil
    end

    local ok, connection = pcall(function()
        return signal:Connect(callback)
    end)

    if ok and connection then
        connectionList[#connectionList + 1] = connection
        return connection
    end

    return nil
end

local function disconnectList(connectionList)
    for index = #connectionList, 1, -1 do
        local connection = connectionList[index]
        connectionList[index] = nil
        if connection then
            pcall(connection.Disconnect, connection)
        end
    end
end

local function safeDestroy(instance)
    if instance then
        pcall(instance.Destroy, instance)
    end
end

local function getCharacterRoot(character)
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

    if character:IsA("BasePart") then
        return character
    end

    return character:FindFirstChildWhichIsA("BasePart", true)
end

local function getPlayerFromCharacter(character)
    if not character then
        return nil
    end

    local player = Players:GetPlayerFromCharacter(character)
    if player then
        return player
    end

    local name = character.Name
    if type(name) ~= "string" then
        return nil
    end

    return Players:FindFirstChild(name)
end

local function getHealthController(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        return humanoid
    end

    local health = character and character:FindFirstChild("Health")
    if health and health:IsA("NumberValue") then
        return health
    end

    return nil
end

local function getHealthText(character)
    local humanoid = getHealthController(character)
    if not humanoid then
        return "Vida: --/--"
    end

    local current = tonumber(humanoid.Health)
    local maximum = tonumber(humanoid.MaxHealth)
    if not current or not maximum then
        return "Vida: --/--"
    end

    return "Vida: " .. tostring(math_floor(current + 0.5)) .. "/" .. tostring(math_floor(maximum + 0.5))
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

local function hasActiveProtection(character)
    if not character then
        return false
    end

    if character:FindFirstChildOfClass("ForceField") then
        return true
    end

    local attributes = {
        "PvPDisabled",
        "PVPDisabled",
        "PvPProtection",
        "Protection",
        "Protected",
        "SafeZone",
        "NoPvP"
    }

    for _, attributeName in ipairs(attributes) do
        local value = character:GetAttribute(attributeName)
        if value == true then
            return true
        end
    end

    for _, descendant in ipairs(character:GetDescendants()) do
        if isProtectionName(descendant.Name) then
            if descendant:IsA("BoolValue") and descendant.Value then
                return true
            end
            if descendant:IsA("IntValue") or descendant:IsA("NumberValue") then
                if descendant.Value ~= 0 then
                    return true
                end
            end
            if descendant:IsA("ObjectValue") and descendant.Value ~= nil then
                return true
            end
        end
    end

    return false
end

local function getTeamColor(player)
    if player and player.Team == Pirates then
        return BrickColor.new("Persimmon").Color
    end

    if player and player.Team == Marines then
        return BrickColor.new("Pastel light blue").Color
    end

    return BrickColor.new("Institutional white").Color
end

local function createPlayerESP(character)
    if State.Destroyed or not character or character == LocalPlayer.Character then
        return
    end

    local player = getPlayerFromCharacter(character)
    if not player or player == LocalPlayer then
        return
    end

    local existing = State.PlayerESP[character]
    if existing then
        return
    end

    local head = character:FindFirstChild("Head")
    if not head or not head:IsA("BasePart") then
        return
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "DepHubPlayerESP"
    highlight.Adornee = character
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = 0.55
    highlight.OutlineTransparency = 0
    highlight.FillColor = getTeamColor(player)
    highlight.OutlineColor = getTeamColor(player)
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
    label.Name = "Info"
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextStrokeTransparency = 0.35
    label.TextColor3 = getTeamColor(player)
    label.Text = player.Name .. "\n" .. getHealthText(character) .. "\nPvP: " .. (hasActiveProtection(character) and "Desativado" or "Ativado")
    label.Parent = billboard

    local record = {
        Character = character,
        Player = player,
        Highlight = highlight,
        Billboard = billboard,
        Label = label,
        Connections = {}
    }

    State.PlayerESP[character] = record

    local function update()
        if State.Destroyed or not record.Label or not record.Label.Parent then
            return
        end

        local color = getTeamColor(player)
        record.Highlight.FillColor = color
        record.Highlight.OutlineColor = color
        record.Label.TextColor3 = color
        record.Label.Text = player.Name .. "\n" .. getHealthText(character) .. "\nPvP: " .. (hasActiveProtection(character) and "Desativado" or "Ativado")
    end

    local humanoid = getHealthController(character)
    if humanoid then
        connect(record.Connections, humanoid:GetPropertyChangedSignal("Health"), update)
        pcall(function()
            connect(record.Connections, humanoid:GetPropertyChangedSignal("MaxHealth"), update)
        end)
    end

    connect(record.Connections, character.ChildAdded, update)
    connect(record.Connections, character.ChildRemoved, update)
    connect(record.Connections, character.DescendantAdded, function(descendant)
        if descendant:IsA("ForceField") or isProtectionName(descendant.Name) then
            update()
        end
    end)
    connect(record.Connections, character.DescendantRemoving, function(descendant)
        if descendant:IsA("ForceField") or isProtectionName(descendant.Name) then
            task.defer(update)
        end
    end)

    for _, attributeName in ipairs({"PvPDisabled", "PVPDisabled", "PvPProtection", "Protection", "Protected", "SafeZone", "NoPvP"}) do
        connect(record.Connections, character:GetAttributeChangedSignal(attributeName), update)
    end

    connect(record.Connections, player:GetPropertyChangedSignal("Team"), update)
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
    disconnectList(record.Connections)
    safeDestroy(record.Highlight)
    safeDestroy(record.Billboard)
end

local function clearPlayerESP()
    for character in pairs(State.PlayerESP) do
        State:RemovePlayerESP(character)
    end
end

local function scanPlayerESP()
    if not Characters then
        Characters = Workspace:FindFirstChild("Characters")
    end

    if not Characters then
        return
    end

    for _, character in ipairs(Characters:GetChildren()) do
        if character:IsA("Model") then
            createPlayerESP(character)
        end
    end
end

local function startPlayerESP()
    if not Characters then
        Characters = Workspace:FindFirstChild("Characters")
    end

    if not Characters then
        logWarn("workspace.Characters indisponivel para Player ESP.")
        return
    end

    clearPlayerESP()
    scanPlayerESP()

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

    task.spawn(function()
        while not State.Destroyed and State.Toggles.PlayerESP do
            scanPlayerESP()
            task.wait(1.5)
        end
    end)
end

local function getFruitAdornee(instance)
    if instance:IsA("BasePart") then
        return instance
    end

    if instance:IsA("Model") then
        if instance.PrimaryPart then
            return instance.PrimaryPart
        end
        return instance:FindFirstChildWhichIsA("BasePart", true)
    end

    if instance:IsA("Attachment") then
        return instance
    end

    return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function getFruitPosition(instance, adornee)
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
    if State.Destroyed or not State.Toggles.FruitESP or not instance then
        return
    end

    if State.FruitESP[instance] then
        return
    end

    local name = instance.Name
    if type(name) ~= "string" or string_sub(name, 1, 6) ~= "Fruit " then
        return
    end

    local adornee = getFruitAdornee(instance)
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
    label.Name = "Info"
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextStrokeTransparency = 0.35
    label.TextColor3 = Color3.fromRGB(255, 220, 80)
    label.Text = name .. "\nDistância: --"
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
    disconnectList(record.Connections)
    safeDestroy(record.Billboard)
end

local function clearFruitESP()
    for instance in pairs(State.FruitESP) do
        State:RemoveFruitESP(instance)
    end
end

local function scanFruitESP()
    for _, instance in ipairs(Workspace:GetChildren()) do
        if string_sub(instance.Name, 1, 6) == "Fruit " then
            createFruitESP(instance)
        end
    end
end

local function startFruitESP()
    clearFruitESP()
    scanFruitESP()

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

    task.spawn(function()
        while not State.Destroyed and State.Toggles.FruitESP do
            local character = LocalPlayer.Character
            local root = getCharacterRoot(character)
            if root then
                for instance, record in pairs(State.FruitESP) do
                    if instance.Parent and record.Label and record.Label.Parent then
                        local adornee = getFruitAdornee(instance)
                        local position = adornee and getFruitPosition(instance, adornee)
                        if position then
                            local distance = (root.Position - position).Magnitude
                            record.Label.Text = instance.Name .. "\nDistância: " .. tostring(math_floor(distance + 0.5)) .. " studs"
                        end
                    else
                        State:RemoveFruitESP(instance)
                    end
                end
            end
            task.wait(0.25)
        end
    end)
end

local function setVisionRadius(value)
    if not LocalPlayer then
        return false
    end

    local ok, changed = pcall(function()
        if LocalPlayer.VisionRadius ~= value then
            LocalPlayer.VisionRadius = value
            return true
        end
        return false
    end)

    if ok and changed then
        return true
    end

    local valueObject = LocalPlayer:FindFirstChild("VisionRadius")
    if valueObject and valueObject:IsA("NumberValue") and valueObject.Value ~= value then
        local success = pcall(function()
            valueObject.Value = value
        end)
        if success then
            return true
        end
    end

    local attribute = LocalPlayer:GetAttribute("VisionRadius")
    if attribute ~= value then
        local success = pcall(function()
            LocalPlayer:SetAttribute("VisionRadius", value)
        end)
        if success then
            return true
        end
    end

    return false
end

local function startObservationHaki()
    task.spawn(function()
        while not State.Destroyed and State.Toggles.ObservationHaki do
            pcall(function()
                local current = LocalPlayer.VisionRadius
                if current ~= 5000 then
                    setVisionRadius(5000)
                end
            end)

            local valueObject = LocalPlayer:FindFirstChild("VisionRadius")
            if valueObject and valueObject:IsA("NumberValue") and valueObject.Value ~= 5000 then
                pcall(function()
                    valueObject.Value = 5000
                end)
            end

            if LocalPlayer:GetAttribute("VisionRadius") ~= 5000 then
                pcall(function()
                    LocalPlayer:SetAttribute("VisionRadius", 5000)
                end)
            end

            task.wait(0.5)
        end
    end)
end

local function setCameraShake(enabled)
    if not ChangeSetting or not ChangeSetting:IsA("RemoteEvent") then
        logWarn("Remotes.ChangeSetting indisponivel.")
        return false
    end

    local ok, result = pcall(function()
        return ChangeSetting:FireServer("CameraShake", enabled)
    end)

    return ok and result ~= false
end

local function startCameraShake()
    setCameraShake(false)
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
        if original == nil then
            LocalPlayer:SetAttribute("UnbreakableAll", nil)
        else
            LocalPlayer:SetAttribute("UnbreakableAll", original)
        end
    end)
end

local function stopPlayerESP()
    disconnectList(State.Connections.PlayerESP or {})
    State.Connections.PlayerESP = nil
    clearPlayerESP()
end

local function stopFruitESP()
    disconnectList(State.Connections.FruitESP or {})
    State.Connections.FruitESP = nil
    clearFruitESP()
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

    if name == "CameraShake" then
        setCameraShake(not enabled)
    elseif name == "ObservationHaki" then
        if enabled then
            startObservationHaki()
        end
    elseif name == "PlayerESP" then
        if enabled then
            startPlayerESP()
        else
            stopPlayerESP()
        end
    elseif name == "UnbreakableAll" then
        if enabled then
            startUnbreakableAll()
        else
            stopUnbreakableAll()
        end
    elseif name == "FruitESP" then
        if enabled then
            startFruitESP()
        else
            stopFruitESP()
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
    return {
        IceEffect = IceEffect,
        LegendarySwordDealer = LegendarySwordDealer
    }
end

function State:Destroy()
    if self.Destroyed then
        return
    end

    self.Destroyed = true
    self.Toggles.CameraShake = false
    self.Toggles.ObservationHaki = false
    self.Toggles.PlayerESP = false
    self.Toggles.UnbreakableAll = false
    self.Toggles.FruitESP = false

    stopPlayerESP()
    stopFruitESP()
    stopUnbreakableAll()
    disconnectList(self.Connections)

    if env[STATE_KEY] == self then
        env[STATE_KEY] = nil
    end

    if env.__DEPHUB and env.__DEPHUB.BloxFruits == self then
        env.__DEPHUB.BloxFruits = nil
    end
end

function State:Start()
    if self.Destroyed then
        return false
    end

    startCameraShake()
    startObservationHaki()

    log("Blox Fruits core inicializado sem frontend.")
    log("Player ESP, Fruit ESP e Unbreakable All permanecem desligados ate o frontend chamar SetToggle().")
    return true
end

if not LocalPlayer then
    logWarn("LocalPlayer indisponivel. Inicializacao abortada.")
    return false
end

local ok, started = pcall(State.Start, State)
if not ok or not started then
    logWarn("Falha inicializando Blox Fruits: " .. tostring(started))
    pcall(State.Destroy, State)
    return false
end

return State
