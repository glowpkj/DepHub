local game, task, type, tostring, tonumber, pairs, ipairs, pcall, math, os = game, task, type, tostring, tonumber, pairs, ipairs, pcall, math, os
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local env = type(getgenv) == "function" and getgenv() or _G
local STATE_KEY = "__DEPHUB_VIOLENCE_DISTRICT"

local previous = env[STATE_KEY]
if type(previous) == "table" and type(previous.Destroy) == "function" then
    pcall(previous.Destroy, previous)
end

if not LocalPlayer then
    return false
end

-- [CURE] Violence District backend.
--
-- Asymmetrical 1-vs-all horror: one Killer, the rest Survivors repairing
-- generators and escaping. Every mechanism below was confirmed against the live
-- game (see the notes the earlier reverse-engineering pass left behind), so the
-- features talk to the same objects the game itself uses:
--   * ESP         - Highlight + name billboard on each Killer/Survivor, read
--                   from Player.Team (Teams.Killer / Teams.Survivors).
--   * Auto Repair - fires Remotes.Generator.RepairEvent(point, true) at the
--                   nearest GeneratorPointN and stops when out of range.
--   * Auto Skill  - when the Skillcheck-gen object appears on the character,
--                   fires Remotes.Generator.SkillCheckResultEvent("success", ...).
--   * Auto Parry  - fires the Parrying Dagger's parry remote when the Killer
--                   plays a known parryable attack animation.
-- Remotes and the map are optional and resolved defensively: a missing one just
-- leaves that single feature idle instead of erroring the backend. Nothing here
-- hooks metatables or drives raw input; it only calls the game's own remotes.

local State = {
    Version = "1.0.0",
    Destroyed = false,
    Started = false,
    Connections = {},
    Toggles = {
        ESP = false,
        ESPKiller = true,
        ESPSurvivor = true,
        ESPNames = true,
        ESPDistance = true,
        Chams = true,
        GeneratorESP = false,
        AutoRepair = false,
        AutoSkillCheck = false,
        AutoParry = false,
        AutoEquip = true,
    },
    ToggleLabels = {
        ESP = "ESP ativado",
        ESPKiller = "Mostrar Killer",
        ESPSurvivor = "Mostrar Survivors",
        ESPNames = "Mostrar nome e funcao",
        ESPDistance = "Mostrar distancia",
        Chams = "Chams (contorno)",
        GeneratorESP = "ESP de geradores",
        AutoRepair = "Reparar gerador sozinho",
        AutoSkillCheck = "Acertar o skill check sozinho",
        AutoParry = "Auto Parry",
        AutoEquip = "Equipar adaga sozinho",
    },
    Values = {
        Range = 2000,
        KillerColor = Color3.fromRGB(255, 74, 74),
        SurvivorColor = Color3.fromRGB(76, 188, 255),
        TextSize = 13,
        GeneratorRange = 2000,
        GeneratorColor = Color3.fromRGB(255, 190, 70),
        RepairRange = 14,
        ParryRange = 18,
        ParryCooldown = 1.0,
    },
    ESPObjects = {},
    GeneratorESPObjects = {},
    LastGeneratorScan = 0,
    RepairActive = false,
    RepairPoint = nil,
    RepairGenerator = nil,
}

env[STATE_KEY] = State
env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.ViolenceDistrict = State

local function track(connection)
    if connection then State.Connections[#State.Connections + 1] = connection end
    return connection
end

local function removed(object)
    return not object or object.Parent == nil
end

-- ---------------------------------------------------------------------------
-- Remotes are resolved lazily: a slow (or absent) remote must never block or
-- delay the panel building, so the tab is created first and resolveRemotes()
-- fills them in right after. Each stays nil-safe; the feature that needs it
-- simply does nothing while it is missing.
local RepairEvent, SkillCheckResult, ParryEvent

local function resolveRemotes()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local generators = remotes and remotes:FindFirstChild("Generator")
    local items = remotes and remotes:FindFirstChild("Items")
    local dagger = items and items:FindFirstChild("Parrying Dagger")
    RepairEvent = (generators and generators:FindFirstChild("RepairEvent")) or RepairEvent
    SkillCheckResult = (generators and generators:FindFirstChild("SkillCheckResultEvent")) or SkillCheckResult
    ParryEvent = (dagger and dagger:FindFirstChild("parry")) or ParryEvent
end

-- ---------------------------------------------------------------------------
-- Shared helpers.
-- ---------------------------------------------------------------------------
local function roleOf(player)
    local team = player and player.Team
    local name = team and tostring(team.Name):lower() or ""
    if name:find("kill", 1, true) then return "Killer" end
    if name:find("surviv", 1, true) then return "Survivor" end
    return nil
end

local function roleColor(role)
    if role == "Killer" then return State.Values.KillerColor end
    return State.Values.SurvivorColor
end

local function characterRoot(character)
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("RootPart")
end

local function headOf(character)
    if not character then return nil end
    return character:FindFirstChild("Head")
end

local function localCharacter()
    return LocalPlayer.Character
end

local function localRoot()
    local character = localCharacter()
    return character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head"))
end

local function normalizeObjectName(value)
    return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function isMapContainer(instance)
    if not (instance:IsA("Folder") or instance:IsA("Model")) then return false end
    local name = normalizeObjectName(instance.Name)
    return name == "map"
        or name == "currentmap"
        or name == "activemap"
        or name == "gamemap"
        or name == "mapcontainer"
        or name:match("^map%d+$") ~= nil
end

local function mapRoot()
    local direct = Workspace:FindFirstChild("Map")
    if direct then return direct end
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if isMapContainer(descendant) then return descendant end
    end
    return nil
end

local function buildLabel(character, role, distance)
    local parts = {}
    if State.Toggles.ESPNames then
        local player = Players:GetPlayerFromCharacter(character)
        local name = player and (player.DisplayName or player.Name) or character.Name
        parts[#parts + 1] = "[" .. role:upper() .. "] " .. name
    end
    if State.Toggles.ESPDistance and distance then parts[#parts + 1] = distance .. "m" end
    return table.concat(parts, " | ")
end

-- ---------------------------------------------------------------------------
-- ESP. Reconcile per frame: create records for what is visible and in range,
-- drop stale ones, repaint the rest. Role toggles, range and chams are all
-- re-evaluated live, so a slider or toggle takes effect without a relock.
-- ---------------------------------------------------------------------------
function State:RemoveESP(character)
    local record = self.ESPObjects[character]
    if not record then return end
    self.ESPObjects[character] = nil
    if record.Highlight then pcall(record.Highlight.Destroy, record.Highlight) end
    if record.Billboard then pcall(record.Billboard.Destroy, record.Billboard) end
end

function State:ClearESP()
    for character in pairs(self.ESPObjects) do
        self:RemoveESP(character)
    end
end

function State:CreateESP(character, role)
    self:RemoveESP(character)
    if self.Destroyed or not self.Toggles.ESP or removed(character) then return end
    local color = roleColor(role)

    local highlight = Instance.new("Highlight")
    highlight.Name = "DepHubVDHighlight"
    highlight.Adornee = character
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = color
    highlight.FillTransparency = 0.42
    highlight.OutlineTransparency = 1
    highlight.Parent = character
    if not self.Toggles.Chams then highlight.Enabled = false end

    local billboard
    local label
    local head = headOf(character)
    if head then
        billboard = Instance.new("BillboardGui")
        billboard.Name = "DepHubVDName"
        billboard.Adornee = head
        billboard.AlwaysOnTop = true
        billboard.LightInfluence = 0
        billboard.Size = UDim2.fromOffset(220, 40)
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.9, 0)
        billboard.Parent = head

        label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.BorderSizePixel = 0
        label.Size = UDim2.fromScale(1, 1)
        label.Font = Enum.Font.GothamMedium
        label.TextColor3 = color
        label.TextStrokeTransparency = 1
        label.TextSize = self.Values.TextSize
        label.Text = buildLabel(character, role)
        label.Parent = billboard
    end

    self.ESPObjects[character] = {
        Highlight = highlight,
        Billboard = billboard,
        Label = label,
        Character = character,
        Role = role,
    }
end

function State:Refresh()
    if self.Destroyed or not self.Toggles.ESP then return end
    local me = localRoot()
    local seen = {}
    local range = self.Values.Range

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local role = roleOf(player)
            local enabled = role == "Killer" and self.Toggles.ESPKiller
                or role == "Survivor" and self.Toggles.ESPSurvivor
            local character = player.Character
            if role and enabled and not removed(character) then
                local adornee = characterRoot(character) or headOf(character)
                local distance
                if me and adornee and adornee.Position then
                    distance = math.floor((adornee.Position - me.Position).Magnitude)
                end
                if not distance or distance <= range then
                    seen[character] = true
                    local record = self.ESPObjects[character]
                    if not record or record.Role ~= role then
                        self:CreateESP(character, role)
                        record = self.ESPObjects[character]
                    end
                    if record then
                        if record.Label then
                            record.Label.Text = buildLabel(character, role, distance)
                            record.Label.TextSize = self.Values.TextSize
                        end
                        if record.Highlight then record.Highlight.Enabled = self.Toggles.Chams end
                    end
                end
            end
        end
    end

    for character in pairs(self.ESPObjects) do
        if not seen[character] then self:RemoveESP(character) end
    end
end

function State:SetESP(enabled)
    self.Toggles.ESP = enabled == true
    if not self.Toggles.ESP then
        self:ClearESP()
        return true
    end
    self:Refresh()
    return true
end

-- ---------------------------------------------------------------------------
-- Generator ESP. Resolve the active map semantically instead of relying on a
-- fixed Workspace.Map.Generators path. Maps often wrap this folder in extra
-- Models/Folders or rename the map root between rounds.
local function isGeneratorPointName(name)
    return name:find("generatorpoint", 1, true) ~= nil
        or name:find("repairpoint", 1, true) ~= nil
        or name:find("skillcheck", 1, true) ~= nil
end

local function isGeneratorContainer(instance)
    local name = normalizeObjectName(instance.Name)
    return name == "generators"
        or name == "generatorfolder"
        or name == "generatorcontainer"
        or name == "generatorobjects"
end

local function hasGeneratorGeometry(instance)
    if instance:IsA("BasePart") then return true end
    return (instance:IsA("Model") or instance:IsA("Folder"))
        and instance:FindFirstChildWhichIsA("BasePart", true) ~= nil
end

local function addGeneratorTarget(targets, instance)
    if not instance or not instance.Parent or not hasGeneratorGeometry(instance) then return end
    if not (instance:IsA("Model") or instance:IsA("BasePart")) then return end
    local name = normalizeObjectName(instance.Name)
    if isGeneratorPointName(name) or isGeneratorContainer(instance) then return end
    targets[instance] = true
end

local function collectGeneratorTargets(root)
    local targets = {}
    if not root then return targets end
    local descendants = root:GetDescendants()
    local containers = {}

    for _, descendant in ipairs(descendants) do
        if isGeneratorContainer(descendant) then
            containers[#containers + 1] = descendant
        end

        local name = normalizeObjectName(descendant.Name)
        if name:find("generator", 1, true) and not isGeneratorPointName(name) then
            addGeneratorTarget(targets, descendant)
        end
    end

    for _, container in ipairs(containers) do
        local foundModels = false
        for _, descendant in ipairs(container:GetDescendants()) do
            if descendant:IsA("Model") and hasGeneratorGeometry(descendant) then
                local ancestor = descendant.Parent
                local nestedInModel = false
                while ancestor and ancestor ~= container do
                    if ancestor:IsA("Model") then
                        nestedInModel = true
                        break
                    end
                    ancestor = ancestor.Parent
                end
                if not nestedInModel then
                    addGeneratorTarget(targets, descendant)
                    foundModels = true
                end
            end
        end

        if not foundModels then
            for _, descendant in ipairs(container:GetDescendants()) do
                if descendant:IsA("BasePart") and descendant.Parent == container then
                    addGeneratorTarget(targets, descendant)
                end
            end
        end
    end

    for target in pairs(targets) do
        local ancestor = target.Parent
        while ancestor and ancestor ~= root do
            if targets[ancestor] then
                targets[target] = nil
                break
            end
            ancestor = ancestor.Parent
        end
    end

    return targets
end

local function findGeneratorTargets()
    local map = mapRoot()
    local targets = collectGeneratorTargets(map or Workspace)
    if next(targets) == nil and map and map ~= Workspace then
        targets = collectGeneratorTargets(Workspace)
    end
    return targets
end

local function generatorAdornee(target)
    if not target or not target.Parent then return nil end
    if target:IsA("BasePart") then return target end
    if target:IsA("Model") then
        return target.PrimaryPart
            or target:FindFirstChild("HumanoidRootPart", true)
            or target:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

function State:RemoveGeneratorESP(target)
    local record = self.GeneratorESPObjects[target]
    if not record then return end
    self.GeneratorESPObjects[target] = nil
    if record.Highlight then pcall(record.Highlight.Destroy, record.Highlight) end
    if record.Billboard then pcall(record.Billboard.Destroy, record.Billboard) end
end

function State:ClearGeneratorESP()
    for target in pairs(self.GeneratorESPObjects) do
        self:RemoveGeneratorESP(target)
    end
end

function State:CreateGeneratorESP(target, adornee)
    self:RemoveGeneratorESP(target)
    if self.Destroyed or not self.Toggles.GeneratorESP or not adornee then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "DepHubGeneratorHighlight"
    highlight.Adornee = target
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = self.Values.GeneratorColor
    highlight.FillTransparency = 0.58
    highlight.OutlineColor = self.Values.GeneratorColor
    highlight.OutlineTransparency = 0.08
    highlight.Parent = target

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "DepHubGeneratorLabel"
    billboard.Adornee = adornee
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.Size = UDim2.fromOffset(150, 28)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
    billboard.Parent = adornee

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = self.Values.GeneratorColor
    label.TextStrokeTransparency = 0.45
    label.TextSize = self.Values.TextSize
    label.Text = "GERADOR"
    label.Parent = billboard

    self.GeneratorESPObjects[target] = {
        Highlight = highlight,
        Billboard = billboard,
        Label = label,
        Adornee = adornee,
    }
end

function State:RefreshGeneratorESP()
    if self.Destroyed or not self.Toggles.GeneratorESP then
        self:ClearGeneratorESP()
        return
    end

    local myRoot = localRoot()
    local seen = {}
    local targets = findGeneratorTargets()

    for target in pairs(targets) do
        local adornee = generatorAdornee(target)
        if adornee then
            local distance
            if myRoot then distance = (adornee.Position - myRoot.Position).Magnitude end
            if not distance or distance <= self.Values.GeneratorRange then
                seen[target] = true
                local record = self.GeneratorESPObjects[target]
                if not record or record.Adornee ~= adornee or not record.Highlight.Parent then
                    self:CreateGeneratorESP(target, adornee)
                    record = self.GeneratorESPObjects[target]
                end
                if record and record.Label then
                    local distanceText = distance and (" | " .. tostring(math.floor(distance)) .. "m") or ""
                    record.Label.Text = "GERADOR" .. distanceText
                    record.Label.TextSize = self.Values.TextSize
                end
            end
        end
    end

    for target in pairs(self.GeneratorESPObjects) do
        if not seen[target] then self:RemoveGeneratorESP(target) end
    end

    self.LastGeneratorScan = os.clock()
end

function State:SetGeneratorESP(enabled)
    self.Toggles.GeneratorESP = enabled == true
    if not self.Toggles.GeneratorESP then
        self:ClearGeneratorESP()
        return true
    end
    self.LastGeneratorScan = 0
    self:RefreshGeneratorESP()
    return true
end

-- ---------------------------------------------------------------------------
-- Auto Repair: fire RepairEvent(point, true) at the nearest GeneratorPointN
-- under the map and hold it until the point leaves range or the feature stops.
-- ---------------------------------------------------------------------------
local function nearestRepairPoint(maxRange)
    local root = localRoot()
    local map = mapRoot()
    if not root or not map then return nil, nil end
    local bestPoint, bestGenerator, bestDistance
    for _, descendant in ipairs(map:GetDescendants()) do
        if descendant.Name:match("^GeneratorPoint%d+$") then
            local part = descendant:IsA("BasePart") and descendant or descendant:FindFirstChildWhichIsA("BasePart")
            if part then
                local distance = (part.Position - root.Position).Magnitude
                if (not bestDistance or distance < bestDistance) and (not maxRange or distance <= maxRange) then
                    bestPoint, bestDistance = descendant, distance
                    local current = descendant.Parent
                    while current and current ~= map do
                        if current:IsA("Model") and current.Name:lower():find("generator", 1, true) then
                            bestGenerator = current
                            break
                        end
                        current = current.Parent
                    end
                end
            end
        end
    end
    return bestPoint, bestGenerator
end

function State:StopRepair(reason)
    if not self.RepairActive then return end
    local point = self.RepairPoint
    self.RepairActive = false
    self.RepairPoint = nil
    self.RepairGenerator = nil
    if point and point.Parent and RepairEvent then
        pcall(function() RepairEvent:FireServer(point, false) end)
    end
end

local function stepRepair()
    if State.Destroyed or not State.Toggles.AutoRepair then
        State:StopRepair()
        return
    end
    if State.RepairActive then
        local root = localRoot()
        local point = State.RepairPoint
        local part = point and point.Parent and (point:IsA("BasePart") and point or point:FindFirstChildWhichIsA("BasePart"))
        if not root or not part then
            State:StopRepair()
            return
        end
        if (part.Position - root.Position).Magnitude > State.Values.RepairRange + 2 then
            State:StopRepair()
        end
        return
    end
    if not RepairEvent then return end
    local point, generator = nearestRepairPoint(State.Values.RepairRange)
    if not point then return end
    State.RepairActive = true
    State.RepairPoint = point
    State.RepairGenerator = generator
    pcall(function() RepairEvent:FireServer(point, true) end)
end

-- ---------------------------------------------------------------------------
-- Auto Skill Check: the game spawns a Skillcheck-gen object on the character
-- while a check is up. Fire the success result remote at the generator we are
-- repairing, with an index read from the object (fallback 1).
-- ---------------------------------------------------------------------------
local lastSkillAt = 0

local function skillIndex(skillObject)
    if skillObject then
        for _, name in ipairs({"Index", "SkillCheckIndex", "SkillcheckIndex", "Check", "Number", "Stage"}) do
            local value = tonumber(skillObject:GetAttribute(name))
            if value then return value end
        end
    end
    return 1
end

local function submitSkillCheck()
    if State.Destroyed or not State.Toggles.AutoSkillCheck then return end
    if not SkillCheckResult then return end
    if os.clock() - lastSkillAt < 0.18 then return end

    local character = localCharacter()
    local skillTag = character and character:FindFirstChild("Skillcheck-gen")
    if not skillTag then return end

    local point, generator = State.RepairPoint, State.RepairGenerator
    if not (point and generator) then
        point, generator = nearestRepairPoint(math.max(State.Values.RepairRange, 24))
    end
    if not (point and generator) then return end

    lastSkillAt = os.clock()
    local index = skillIndex(skillTag)
    pcall(function() SkillCheckResult:FireServer("success", index, generator, point) end)
end

-- ---------------------------------------------------------------------------
-- Auto Parry: fire the Parrying Dagger's parry remote when the Killer plays a
-- known parryable attack animation inside range. Only animations that can be
-- parried belong here: charge/hold tells must not trigger it. The list is
-- intentionally short and documented -- only killer "veil" is confirmed so far,
-- so parry silently does nothing for a killer whose attack animation is not
-- listed. Add ids as they are confirmed in game.
-- ---------------------------------------------------------------------------
local PARRYABLE = {
    ["78935059863801"] = true, -- veil, basic attack
}

local parryReady = true

function State:TryParry()
    if self.Destroyed or not self.Toggles.AutoParry or not parryReady or not ParryEvent then return end
    local character = localCharacter()
    if not character then return end
    local dagger = character:FindFirstChild("Parrying Dagger")
        or (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Parrying Dagger"))
    if not dagger then return end

    if self.Toggles.AutoEquip and dagger.Parent ~= character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then pcall(function() humanoid:EquipTool(dagger) end) end
    end
    if not character:FindFirstChild("Parrying Dagger") then return end

    parryReady = false
    pcall(function() ParryEvent:FireServer() end)
    task.delay(self.Values.ParryCooldown, function() parryReady = true end)
end

local function watchKiller(character)
    if State.Destroyed or not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local animator = humanoid and humanoid:FindFirstChild("Animator")
    if not animator then return end
    track(animator.AnimationPlayed:Connect(function(track_)
        if State.Destroyed or not State.Toggles.AutoParry then return end
        local id = track_ and track_.Animation and tostring(track_.Animation.AnimationId)
        if not id or not PARRYABLE[id:match("%d+")] then return end
        local hrp = localRoot()
        local khrp = characterRoot(character)
        if not hrp or not khrp then return end
        if (hrp.Position - khrp.Position).Magnitude > State.Values.ParryRange then return end
        State:TryParry()
    end))
end

local function watchPlayerForKiller(player)
    if player == LocalPlayer or not player then return end
    local function try(character)
        task.defer(function()
            if not State.Destroyed and roleOf(player) == "Killer" then watchKiller(character) end
        end)
    end
    if player.Character then try(player.Character) end
    track(player.CharacterAdded:Connect(try))
end

-- ---------------------------------------------------------------------------
-- Public setters
-- ---------------------------------------------------------------------------
function State:SetToggle(name, enabled)
    if self.Destroyed or type(name) ~= "string" then return false end
    if self.Toggles[name] == nil then return false end
    self.Toggles[name] = enabled == true
    if name == "ESP" then
        return self:SetESP(enabled)
    elseif name == "GeneratorESP" then
        return self:SetGeneratorESP(enabled)
    elseif name == "ESPKiller" or name == "ESPSurvivor" or name == "Chams"
        or name == "ESPNames" or name == "ESPDistance" then
        if self.Toggles.ESP then self:Refresh() end
    elseif name == "AutoRepair" and not self.Toggles.AutoRepair then
        self:StopRepair()
    end
    return true
end

function State:GetToggle(name)
    if self.Destroyed or type(name) ~= "string" then return false end
    return self.Toggles[name] == true
end

function State:SetValue(name, value)
    if self.Destroyed or type(name) ~= "string" then return false end
    if self.Values[name] == nil then return false end
    value = tonumber(value)
    if not value or value ~= value then return false end
    self.Values[name] = value
    return true
end

function State:Start()
    if self.Started or self.Destroyed then return false end
    self.Started = true

    resolveRemotes()
    task.defer(function()
        if not self.Destroyed then resolveRemotes() end
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        watchPlayerForKiller(player)
    end
    track(Players.PlayerAdded:Connect(watchPlayerForKiller))

    track(RunService.RenderStepped:Connect(function()
        if not self.Destroyed and self.Toggles.ESP then self:Refresh() end
    end))
    track(RunService.Heartbeat:Connect(function()
        if self.Destroyed then return end
        stepRepair()
        submitSkillCheck()
        if self.Toggles.GeneratorESP and os.clock() - self.LastGeneratorScan >= 1 then
            self:RefreshGeneratorESP()
        end
    end))
    return true
end

function State:Destroy()
    if self.Destroyed then return end
    self:StopRepair()
    self.Destroyed = true
    self:ClearESP()
    self:ClearGeneratorESP()
    for _, connection in ipairs(self.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    self.Connections = {}
    if env[STATE_KEY] == self then env[STATE_KEY] = nil end
    if env.__DEPHUB and env.__DEPHUB.ViolenceDistrict == self then env.__DEPHUB.ViolenceDistrict = nil end
end

-- ---------------------------------------------------------------------------
-- Presentation: the shared shell. Tabs and sections are the backend's job.
-- ---------------------------------------------------------------------------
-- The shared shell's tab:CreateSection(title, column) adapter takes the title
-- and the column ("Left"/"Right") only; the library rejects any other column
-- value with an error. Passing a summary string as the second argument made the
-- column invalid, the pcall swallowed the error, and the whole tab came up empty
-- (which is exactly what happened here). Keep the call to the two arguments the
-- adapter actually reads.
local function sectionFor(tab, name, column)
    if not (tab and type(tab.CreateSection) == "function") then return nil end
    local ok, section = pcall(function() return tab:CreateSection(name, column) end)
    if ok then return section end
    return nil
end

do
    local UI = env.__DEPHUB and env.__DEPHUB.UI
    if type(UI) == "table" and type(UI.CreateTab) == "function" then
        local function createTab(name)
            local ok, tab = pcall(function() return UI:CreateTab(name, "All") end)
            return ok and tab or nil
        end

        local espTab = createTab("ESP")
        if espTab then
            local players = sectionFor(espTab, "Jogadores", "Left")
            if players then
                players:CreateToggle(State.ToggleLabels.ESP, State.Toggles.ESP, function(v) State:SetToggle("ESP", v) end)
                players:CreateToggle(State.ToggleLabels.ESPKiller, State.Toggles.ESPKiller, function(v) State:SetToggle("ESPKiller", v) end)
                players:CreateToggle(State.ToggleLabels.ESPSurvivor, State.Toggles.ESPSurvivor, function(v) State:SetToggle("ESPSurvivor", v) end)
                players:CreateToggle(State.ToggleLabels.Chams, State.Toggles.Chams, function(v) State:SetToggle("Chams", v) end)
                players:CreateToggle(State.ToggleLabels.ESPNames, State.Toggles.ESPNames, function(v) State:SetToggle("ESPNames", v) end)
                players:CreateToggle(State.ToggleLabels.ESPDistance, State.Toggles.ESPDistance, function(v) State:SetToggle("ESPDistance", v) end)
                players:CreateSlider("Distância máxima", 50, 5000, State.Values.Range, function(v) State:SetValue("Range", v) end)
                players:CreateSlider("Tamanho do texto", 8, 30, State.Values.TextSize, function(v) State:SetValue("TextSize", v) end)
            end

            local generators = sectionFor(espTab, "Geradores", "Right")
            if generators then
                generators:CreateToggle(State.ToggleLabels.GeneratorESP, State.Toggles.GeneratorESP, function(v) State:SetToggle("GeneratorESP", v) end)
                generators:CreateSlider("Distância máxima", 50, 5000, State.Values.GeneratorRange, function(v) State:SetValue("GeneratorRange", v) end)
            end
        end

        local generatorTab = createTab("Geradores")
        if generatorTab then
            local automation = sectionFor(generatorTab, "Automação", "Left")
            if automation then
                automation:CreateToggle(State.ToggleLabels.AutoRepair, State.Toggles.AutoRepair, function(v) State:SetToggle("AutoRepair", v) end)
                automation:CreateToggle(State.ToggleLabels.AutoSkillCheck, State.Toggles.AutoSkillCheck, function(v) State:SetToggle("AutoSkillCheck", v) end)
                automation:CreateSlider("Alcance do reparo", 4, 40, State.Values.RepairRange, function(v) State:SetValue("RepairRange", v) end)
            end
        end

        local combatTab = createTab("Combate")
        if combatTab then
            local combat = sectionFor(combatTab, "Auto Parry", "Left")
            if combat then
                combat:CreateToggle(State.ToggleLabels.AutoParry, State.Toggles.AutoParry, function(v) State:SetToggle("AutoParry", v) end)
                combat:CreateToggle(State.ToggleLabels.AutoEquip, State.Toggles.AutoEquip, function(v) State:SetToggle("AutoEquip", v) end)
                combat:CreateSlider("Alcance do parry", 5, 40, State.Values.ParryRange, function(v) State:SetValue("ParryRange", v) end)
                combat:CreateSlider("Recarga do parry", 0.5, 5, State.Values.ParryCooldown, function(v) State:SetValue("ParryCooldown", v) end)
            end
        end
    end
end

State:Start()

do
    local Diag = env.__DEPHUB and env.__DEPHUB.Diagnostics
    if Diag and type(Diag.RegisterModule) == "function" then
        Diag:RegisterModule("src/games/violence-district.lua")
        Diag:Feature("ViolenceDistrict.ESP", function() return State.Toggles.ESP and "ON" or "off" end)
        Diag:Feature("ViolenceDistrict.AutoRepair", function() return State.Toggles.AutoRepair and "ON" or "off" end)
        Diag:Feature("ViolenceDistrict.AutoParry", function() return State.Toggles.AutoParry and "ON" or "off" end)
        Diag:Watch("ViolenceDistrict alvos", function()
            local n = 0
            for _ in pairs(State.ESPObjects) do n = n + 1 end
            return n
        end)
        Diag:Command("vd", function()
            return "esp=" .. tostring(State.Toggles.ESP)
                .. " repair=" .. tostring(State.Toggles.AutoRepair)
                .. " parry=" .. tostring(State.Toggles.AutoParry)
                .. " repairRemote=" .. tostring(RepairEvent ~= nil)
                .. " parryRemote=" .. tostring(ParryEvent ~= nil)
        end)
    end
end

env.VD = State

return State
