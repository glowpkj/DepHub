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
local BASE_URL = "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
local previous = type(env[STATE_KEY]) == "table" and env[STATE_KEY] or nil
if previous and type(previous.Destroy) == "function" then pcall(previous.Destroy, previous) end

local State = {
    Started = false,
    Destroyed = false,
    Toggles = {
        ObservationHaki = true,
        PlayerESP = false,
        FruitESP = false,
        UnbreakableAll = false,
        DashCustomizer = false,
        FlashstepNoCooldown = false,
        WaterWalking = false
    },
    Values = {
        DashLength = 1
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
    if not signal then return nil end
    local ok, connection = pcall(signal.Connect, signal, callback)
    if ok and connection then list[#list + 1] = connection; return connection end
end

local function disconnectAll(list)
    if not list then return end
    for index = #list, 1, -1 do
        local connection = list[index]
        list[index] = nil
        if connection then pcall(connection.Disconnect, connection) end
    end
end

local function destroy(instance)
    if instance then pcall(instance.Destroy, instance) end
end

local function getRoot(character)
    if not character then return nil end
    local root = character:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then return root end
    local head = character:FindFirstChild("Head")
    if head and head:IsA("BasePart") then return head end
    return character:FindFirstChildWhichIsA("BasePart", true)
end

local function getPlayer(character)
    if not character then return nil end
    return Players:GetPlayerFromCharacter(character) or Players:FindFirstChild(character.Name)
end

local function getHumanoid(character)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function healthText(humanoid)
    if not humanoid then return "Vida: --/--" end
    local health = tonumber(humanoid.Health)
    local maxHealth = tonumber(humanoid.MaxHealth)
    if not health or not maxHealth then return "Vida: --/--" end
    return "Vida: " .. tostring(math_floor(health + 0.5)) .. "/" .. tostring(math_floor(maxHealth + 0.5))
end

local function isProtectionName(name)
    if type(name) ~= "string" then return false end
    local lowered = string_lower(name)
    return lowered == "pvpdisabled" or lowered == "pvpdisabledvalue" or lowered == "pvpprotection" or lowered == "protection" or lowered == "protected" or lowered == "safezone" or lowered == "nopvp" or string_sub(lowered, 1, 8) == "protect_"
end

local function hasProtection(character)
    if not character then return false end
    if character:FindFirstChildOfClass("ForceField") then return true end
    for _, name in ipairs({"PvPDisabled", "PVPDisabled", "PvPProtection", "Protection", "Protected", "SafeZone", "NoPvP"}) do
        if character:GetAttribute(name) == true then return true end
    end
    for _, object in ipairs(character:GetDescendants()) do
        if isProtectionName(object.Name) then
            if object:IsA("BoolValue") and object.Value then return true end
            if (object:IsA("IntValue") or object:IsA("NumberValue")) and object.Value ~= 0 then return true end
            if object:IsA("ObjectValue") and object.Value ~= nil then return true end
        end
    end
    return false
end

local function teamColor(player)
    if player and player.Team == Pirates then return BrickColor.new("Persimmon").Color end
    if player and player.Team == Marines then return BrickColor.new("Pastel light blue").Color end
    return BrickColor.new("Institutional white").Color
end

local function compile(source)
    if type(loadstring) ~= "function" then return false, "loadstring indisponivel" end
    local ok, chunk, compileError = pcall(loadstring, source)
    if not ok or type(chunk) ~= "function" then return false, tostring(compileError or chunk) end
    return true, chunk
end

local function loadFeature(path, context)
    local okGet, source = pcall(function() return game:HttpGet(BASE_URL .. path) end)
    if not okGet or type(source) ~= "string" or #source == 0 then return false, tostring(source) end
    local okCompile, chunk = compile(source)
    if not okCompile then return false, chunk end
    local okRun, factory = pcall(chunk)
    if not okRun or type(factory) ~= "table" or type(factory.new) ~= "function" then return false, tostring(factory) end
    local okNew, feature = pcall(factory.new, context)
    if not okNew or type(feature) ~= "table" then return false, tostring(feature) end
    return true, feature
end

local context = {
    State = State,
    LocalPlayer = LocalPlayer,
    Players = Players,
    Workspace = Workspace,
    ChangeSetting = ChangeSetting,
    Connect = connect,
    DisconnectAll = disconnectAll,
    Destroy = destroy,
    GetRoot = getRoot,
    GetPlayer = getPlayer,
    GetHumanoid = getHumanoid,
    HealthText = healthText,
    IsProtectionName = isProtectionName,
    HasProtection = hasProtection,
    TeamColor = teamColor
}

local featurePaths = {
    PlayerESP = "src/games/features/bloxfruits/playeresp.lua",
    FruitESP = "src/games/features/bloxfruits/fruit.lua",
    ObservationHaki = "src/games/features/bloxfruits/observation.lua",
    UnbreakableAll = "src/games/features/bloxfruits/unbreakable.lua",
    CameraShake = "src/games/features/bloxfruits/camerashake.lua",
    DashCustomizer = "src/games/features/bloxfruits/dash.lua",
    FlashstepNoCooldown = "src/games/features/bloxfruits/flashstep.lua",
    WaterWalking = "src/games/features/bloxfruits/waterwalking.lua"
}

local features = {}
for name, path in pairs(featurePaths) do
    local ok, feature = loadFeature(path, context)
    if not ok then
        for _, loaded in pairs(features) do pcall(loaded.Destroy, loaded) end
        if env[STATE_KEY] == State then env[STATE_KEY] = nil end
        if env.__DEPHUB and env.__DEPHUB.BloxFruits == State then env.__DEPHUB.BloxFruits = nil end
        return false
    end
    features[name] = feature
end

State.Features = features
State.PlayerESP = features.PlayerESP.Records
State.FruitESP = features.FruitESP.Records

function State:RemovePlayerESP(character)
    local feature = self.Features and self.Features.PlayerESP
    if feature and type(feature._remove) == "function" then feature:_remove(character) end
end

function State:RemoveFruitESP(tool)
    local feature = self.Features and self.Features.FruitESP
    if feature and type(feature._remove) == "function" then feature:_remove(tool) end
end

function State:SetCameraShake(enabled)
    if self.Destroyed then return false end
    return self.Features.CameraShake:SetEnabled(enabled == true)
end

function State:SetDashLength(value)
    if self.Destroyed or not self.Features or not self.Features.DashCustomizer then return false end
    return self.Features.DashCustomizer:SetValue(value)
end

function State:GetDashLength()
    return self.Values.DashLength
end

function State:SetToggle(name, enabled)
    if self.Destroyed or type(name) ~= "string" then return false end
    enabled = enabled == true
    if self.Toggles[name] == enabled then return true end
    local feature = self.Features[name]
    if not feature then return false end
    local ok = enabled and feature:Enable() or feature:Disable()
    if ok == false then return false end
    self.Toggles[name] = enabled
    if name == "UnbreakableAll" then
        self.UnbreakableCaptured = feature.Captured == true
        self.OriginalUnbreakableAll = feature.Original
    end
    return true
end

function State:GetToggle(name) return self.Toggles[name] == true end
function State:GetPaths() return self.Paths end

function State:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    for name in pairs(self.Toggles) do self.Toggles[name] = false end
    for _, feature in pairs(self.Features or {}) do pcall(feature.Destroy, feature) end
    disconnectAll(self.Connections)
    self.Features = nil
    if env[STATE_KEY] == self then env[STATE_KEY] = nil end
    if env.__DEPHUB and env.__DEPHUB.BloxFruits == self then env.__DEPHUB.BloxFruits = nil end
end

function State:Start()
    if self.Destroyed or self.Started then return false end
    self.Started = true
    if self.Toggles.ObservationHaki then self.Features.ObservationHaki:Enable() end
    return true
end

if not LocalPlayer then return false end
local ok, started = pcall(State.Start, State)
if not ok or not started then pcall(State.Destroy, State); return false end
return State
