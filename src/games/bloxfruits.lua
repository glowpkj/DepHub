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
local Stats = game:GetService("Stats")
local RunService = game:GetService("RunService")
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
local VERSION = "0.0.2"
local previous = type(env[STATE_KEY]) == "table" and env[STATE_KEY] or nil
if previous and type(previous.Destroy) == "function" then pcall(previous.Destroy, previous) end

local function connect(list, signal, callback)
    if not signal then return nil end
    local ok, connection = pcall(signal.Connect, signal, callback)
    if ok and connection then
        list[#list + 1] = connection
        return connection
    end
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

local function loadModule(path, context)
    local okGet, source = pcall(function() return game:HttpGet(BASE_URL .. path) end)
    if not okGet or type(source) ~= "string" or #source == 0 then return false, tostring(source) end
    local okCompile, chunk = compile(source)
    if not okCompile then return false, chunk end
    local okRun, factory = pcall(chunk)
    if not okRun or type(factory) ~= "table" or type(factory.new) ~= "function" then return false, tostring(factory) end
    local okNew, module = pcall(factory.new, context)
    if not okNew or type(module) ~= "table" then return false, tostring(module) end
    return true, module
end

local function loadUILibrary()
    local okGet, source = pcall(function() return game:HttpGet(BASE_URL .. "src/ui/init.lua?dephubui=" .. tostring(math_floor(os.clock() * 1000000))) end)
    if not okGet or type(source) ~= "string" or #source == 0 then return false, tostring(source) end
    local okCompile, chunk = compile(source)
    if not okCompile then return false, chunk end
    local okRun, library = pcall(chunk)
    if not okRun or type(library) ~= "table" or type(library.new) ~= "function" then return false, tostring(library) end
    return true, library
end

local function getPing()
    local ok, value = pcall(function()
        local network = Stats:FindFirstChild("Network")
        local serverStats = network and network:FindFirstChild("ServerStatsItem")
        local ping = serverStats and (serverStats:FindFirstChild("Data Ping") or serverStats:FindFirstChild("Ping"))
        if not ping then return nil end
        local raw = ping:GetValueString()
        local number = tonumber(string.match(raw, "[%d%.]+"))
        return number and math_floor(number + 0.5) or nil
    end)
    return ok and value or nil
end

local baseContext = {LocalPlayer = LocalPlayer, Players = Players, Workspace = Workspace, Connect = connect, DisconnectAll = disconnectAll, Destroy = destroy, GetRoot = getRoot, GetPlayer = getPlayer, GetHumanoid = getHumanoid, HealthText = healthText, IsProtectionName = isProtectionName, HasProtection = hasProtection, TeamColor = teamColor, ChangeSetting = ChangeSetting}
local configOk, config = loadModule("src/games/features/bloxfruits/config.lua", baseContext)
if not configOk then return false end
config:Load({PlayerESP = false, FruitESP = false, UnbreakableAll = false, DashCustomizer = false, FlashstepNoCooldown = false, WaterWalking = false, AutoJoinTeam = true, DashLength = 1, PreferredTeam = "Pirates"})

local State = {
    Started = false,
    Destroyed = false,
    Config = config,
    Version = VERSION,
    Toggles = {
        ObservationHaki = true,
        PlayerESP = config:Get("PlayerESP", false),
        FruitESP = config:Get("FruitESP", false),
        UnbreakableAll = config:Get("UnbreakableAll", false),
        DashCustomizer = config:Get("DashCustomizer", false),
        FlashstepNoCooldown = config:Get("FlashstepNoCooldown", false),
        WaterWalking = config:Get("WaterWalking", false),
        AutoJoinTeam = config:Get("AutoJoinTeam", true)
    },
    Values = {DashLength = tonumber(config:Get("DashLength", 1)) or 1},
    Connections = {},
    PlayerESP = {},
    FruitESP = {},
    OriginalUnbreakableAll = nil,
    UnbreakableCaptured = false,
    CameraShakeDisabled = false,
    UI = nil,
    PingThread = nil,
    PingStat = nil,
    Paths = {IceEffect = IceEffect, LegendarySwordDealer = LegendarySwordDealer, IceEffectPath = "game:GetService(\"ReplicatedStorage\").Effect.Container.Ice1.Waterwalk.ice", LegendarySwordDealerPath = "game:GetService(\"ReplicatedStorage\").NPCs[\"Legendary Sword Dealer\"]"}
}

baseContext.State = State
env[STATE_KEY] = State
env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.BloxFruits = State
env.__DEPHUB.BloxFruitsPaths = State.Paths

local featurePaths = {PlayerESP = "src/games/features/bloxfruits/playeresp.lua", FruitESP = "src/games/features/bloxfruits/fruit.lua", ObservationHaki = "src/games/features/bloxfruits/observation.lua", UnbreakableAll = "src/games/features/bloxfruits/unbreakable.lua", CameraShake = "src/games/features/bloxfruits/camerashake.lua", DashCustomizer = "src/games/features/bloxfruits/dash.lua", FlashstepNoCooldown = "src/games/features/bloxfruits/flashstep.lua", WaterWalking = "src/games/features/bloxfruits/waterwalking.lua", AutoJoinTeam = "src/games/features/bloxfruits/team.lua"}
local features = {}
for name, path in pairs(featurePaths) do
    local ok, feature = loadModule(path, baseContext)
    if not ok then
        for _, loaded in pairs(features) do pcall(loaded.Destroy, loaded) end
        pcall(config.Destroy, config)
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
    local ok = self.Features.DashCustomizer:SetValue(value)
    if ok then self.Values.DashLength = self.Features.DashCustomizer:GetValue() end
    return ok
end

function State:GetDashLength()
    return self.Values.DashLength
end

function State:SetPreferredTeam(team)
    if self.Destroyed or not self.Features or not self.Features.AutoJoinTeam then return false end
    return self.Features.AutoJoinTeam:SetTeam(team)
end

function State:GetPreferredTeam()
    return self.Features and self.Features.AutoJoinTeam and self.Features.AutoJoinTeam.PreferredTeam or self.Config:Get("PreferredTeam", "Pirates")
end

function State:SaveConfig()
    if self.Destroyed then return false end
    return self.Config:Update({PlayerESP = self.Toggles.PlayerESP, FruitESP = self.Toggles.FruitESP, UnbreakableAll = self.Toggles.UnbreakableAll, DashCustomizer = self.Toggles.DashCustomizer, FlashstepNoCooldown = self.Toggles.FlashstepNoCooldown, WaterWalking = self.Toggles.WaterWalking, AutoJoinTeam = self.Toggles.AutoJoinTeam, DashLength = self.Values.DashLength, PreferredTeam = self:GetPreferredTeam()})
end

function State:SetToggle(name, enabled)
    if self.Destroyed or type(name) ~= "string" then return false end
    enabled = enabled == true
    if self.Toggles[name] == enabled then
        self:SaveConfig()
        return true
    end
    local feature = self.Features[name]
    if not feature then return false end
    local ok = enabled and feature:Enable() or feature:Disable()
    if ok == false then return false end
    self.Toggles[name] = enabled
    if name == "UnbreakableAll" then
        self.UnbreakableCaptured = feature.Captured == true
        self.OriginalUnbreakableAll = feature.Original
    end
    self:SaveConfig()
    return true
end

function State:GetToggle(name)
    return self.Toggles[name] == true
end

function State:GetPaths()
    return self.Paths
end

function State:_reapplyCharacter(character)
    if self.Destroyed or not character then return end
    task.defer(function()
        if self.Destroyed then return end
        for _, feature in pairs(self.Features or {}) do
            if feature.Enabled and type(feature._bind) == "function" then
                pcall(feature._bind, feature, character)
            end
        end
    end)
end

function State:_stopPingMonitor()
    local thread = self.PingThread
    self.PingThread = nil
    if thread then pcall(task.cancel, thread) end
end

function State:_startPingMonitor(stat)
    self:_stopPingMonitor()
    self.PingStat = stat
    self.PingThread = task.spawn(function()
        while not self.Destroyed and self.UI and self.PingStat == stat do
            local value = getPing()
            if value then
                pcall(stat.SetValue, stat, tostring(value) .. " ms")
            else
                pcall(stat.SetValue, stat, "--")
            end
            task.wait(1)
        end
    end)
end

function State:CreateUI()
    if self.Destroyed then return false end
    if self.UI and not self.UI.Destroyed then return true end
    local okLibrary, Library = loadUILibrary()
    if not okLibrary or type(Library) ~= "table" or type(Library.new) ~= "function" then return false end
    local okWindow, Window = pcall(Library.new, "DepHub", "Blox Fruits", "rbxassetid://79507712997362")
    if not okWindow or type(Window) ~= "table" then return false end
    self.UI = Window
    env.__DEPHUB.Window = Window

    local okCombat, Combat = pcall(Window.CreateTab, Window, "Combat/PvP", nil, "Combate, movimentação e modificadores de confronto.")
    local okVisual, Visual = pcall(Window.CreateTab, Window, "Visual/ESP", nil, "Informações visuais, ESP e renderização.")
    local okUtility, Utility = pcall(Window.CreateTab, Window, "Utility/Misc", nil, "Utilidades, rede e automação de time.")
    local okSettings, Settings = pcall(Window.CreateTab, Window, "Settings", nil, "Configuração, persistência e versão do DepHub.")
    if not okCombat or not okVisual or not okUtility or not okSettings then
        pcall(Window.Destroy, Window)
        self.UI = nil
        env.__DEPHUB.Window = nil
        return false
    end

    local function addToggle(tab, title, description, name)
        tab:CreateToggle(title, description, self:GetToggle(name), function(enabled)
            local ok = self:SetToggle(name, enabled)
            if not ok then
                task.defer(function()
                    if self.UI and self.UI.Notify then self.UI:Notify("DepHub", "Falha ao alterar " .. title, 3, "Error") end
                end)
            end
        end)
    end

    local Information = Combat:CreateSection("Informações")
    Information:CreateLabel("SILENT AIM")
    Information:CreateLabel("Interceptações de metamethod e alteração de remotes de jogos de terceiros não são habilitadas neste framework.")
    Combat = Combat:CreateSection("Movimento")
    Visual = Visual:CreateSection("Destaques e ESP")
    Utility = Utility:CreateSection("Utilidades e equipe")
    Settings = Settings:CreateSection("Preferências da biblioteca")
    addToggle(Combat, "Unbreakable All", "Aplica o atributo de durabilidade enquanto ativo.", "UnbreakableAll")
    Combat:CreateSlider("Dash Length", "Define o comprimento do dash.", 1, 100, self.Values.DashLength, function(value)
        self:SetDashLength(value)
    end)
    addToggle(Combat, "Dash Customizer", "Ativa o controle personalizado do dash.", "DashCustomizer")
    addToggle(Combat, "Flashstep No Cooldown", "Remove o cooldown do Flashstep quando suportado.", "FlashstepNoCooldown")

    addToggle(Visual, "Player ESP", "Exibe informações visuais dos jogadores.", "PlayerESP")
    addToggle(Visual, "Fruit ESP", "Exibe frutas detectadas no mapa.", "FruitESP")

    local UtilityGrid = Utility:CreateStatGrid()
    self:_startPingMonitor(UtilityGrid:CreateStat("PING", "--"))
    addToggle(Utility, "Water Walking", "Permite caminhar sobre a água enquanto ativo.", "WaterWalking")
    addToggle(Utility, "Auto Join Team", "Entra automaticamente no time configurado.", "AutoJoinTeam")
    Utility:CreateDivider("PREFERRED TEAM")
    Utility:CreateButton("Pirates", function() self:SetPreferredTeam("Pirates") end)
    Utility:CreateButton("Marines", function() self:SetPreferredTeam("Marines") end)

    Settings:CreateLabel("DEPHUB v" .. self.Version)
    Settings:CreateLabel("Estado: configuração persistente ativa.")
    Settings:CreateButton("Salvar Configuração", function()
        local ok = self:SaveConfig()
        Window:Notify("DepHub", ok and "Configuração salva." or "Falha ao salvar configuração.", 3, ok and "Success" or "Error")
    end)
    Settings:CreateButton("Reconstruir Interface", function()
        local current = self.UI
        if current then pcall(current.Destroy, current) end
        self.UI = nil
        task.defer(function() self:CreateUI() end)
    end)

    return true
end

function State:Destroy()
    if self.Destroyed then return end
    self:SaveConfig()
    self.Destroyed = true
    self:_stopPingMonitor()
    if self.UI then pcall(self.UI.Destroy, self.UI) end
    self.UI = nil
    if env.__DEPHUB and env.__DEPHUB.Window then env.__DEPHUB.Window = nil end
    for name in pairs(self.Toggles) do self.Toggles[name] = false end
    for _, feature in pairs(self.Features or {}) do pcall(feature.Destroy, feature) end
    pcall(config.Destroy, config)
    disconnectAll(self.Connections)
    self.Features = nil
    if env[STATE_KEY] == self then env[STATE_KEY] = nil end
    if env.__DEPHUB and env.__DEPHUB.BloxFruits == self then env.__DEPHUB.BloxFruits = nil end
end

function State:Start()
    if self.Destroyed or self.Started then return false end
    self.Started = true
    self.Features.CameraShake:Debug()
    if self.Toggles.ObservationHaki then self.Features.ObservationHaki:Enable() end
    for _, name in ipairs({"PlayerESP", "FruitESP", "UnbreakableAll", "DashCustomizer", "FlashstepNoCooldown", "WaterWalking"}) do
        if self.Toggles[name] then
            local ok = self.Features[name]:Enable()
            if not ok then self.Toggles[name] = false end
        end
    end
    if self.Toggles.AutoJoinTeam then
        local ok = self.Features.AutoJoinTeam:Enable()
        if not ok then self.Toggles.AutoJoinTeam = false end
    end
    connect(self.Connections, LocalPlayer.CharacterAdded, function(character)
        self:_reapplyCharacter(character)
        task.defer(function()
            if self.Destroyed then return end
            if not self.UI or self.UI.Destroyed then self:CreateUI() end
        end)
    end)
    return true
end

if not LocalPlayer then return false end
local ok, started = pcall(State.Start, State)
if not ok or not started then
    pcall(State.Destroy, State)
    return false
end
if not State:CreateUI() then
    pcall(State.Destroy, State)
    return false
end
return State
