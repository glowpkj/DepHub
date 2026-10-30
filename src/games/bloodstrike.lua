local game, task, type, tostring, tonumber, pairs, ipairs, pcall, math = game, task, type, tostring, tonumber, pairs, ipairs, pcall, math
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local env = type(getgenv) == "function" and getgenv() or _G
local STATE_KEY = "__DEPHUB_BLOODSTRIKE"

local previous = env[STATE_KEY]
if type(previous) == "table" and type(previous.Destroy) == "function" then
    pcall(previous.Destroy, previous)
end

if not LocalPlayer then
    return false
end

-- Blood Strike backend.
--
-- The game keeps every fighter (players and bots) as a Model under
-- workspace.Characters, named after the owner, instead of relying on the usual
-- Players.Character mirror. So the ESP resolves a character by matching the
-- Model name against the player list, then falls back to the standard
-- LocalPlayer/Players surface when that container is missing (menu, loading, a
-- private server variant) so the panel still works instead of going blank.

local State = {
    Version = "0.1.0",
    Destroyed = false,
    Started = false,
    Root = nil,
    Connections = {},
    Toggles = {
        ESP = false,
        TeamCheck = true,
        ESPNames = true,
        ESPDistance = true,
        ESPHealth = false,
        Chams = true,
    },
    ToggleLabels = {
        ESP = "ESP ativado",
        TeamCheck = "Ignorar time aliado",
        ESPNames = "Mostrar nome",
        ESPDistance = "Mostrar distancia",
        ESPHealth = "Mostrar vida",
        Chams = "Chams (contorno)",
    },
    Values = {
        Range = 1000,
        ESPColor = Color3.fromRGB(255, 70, 70),
        EnemyColor = Color3.fromRGB(255, 70, 70),
        AllyColor = Color3.fromRGB(80, 200, 255),
        TextSize = 13,
    },
    ESPObjects = {},
}

env[STATE_KEY] = State
env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.BloodStrike = State

local function characterParts(player)
    local character = player.Character
    if not character then return nil, nil, nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
    return character, humanoid, root
end

-- A character Model in workspace.Characters is named after its owner. Resolve it
-- back to the Player so team checks and the player list stay authoritative.
local function playerForModel(model)
    if not model then return nil end
    local player = Players:GetPlayerFromCharacter(model)
    if player then return player end
    local name = model.Name
    for _, candidate in ipairs(Players:GetPlayers()) do
        if candidate.Name == name or candidate.DisplayName == name then return candidate end
    end
    return nil
end

-- The ESP is driven off workspace.Characters when it exists; otherwise it falls
-- back to the players whose Character lives under the standard container. Both
-- paths yield {model, player} pairs the rest of the module treats identically.
local function eachFighter()
    local list = {}
    local container = Workspace:FindFirstChild("Characters")
    if container then
        for _, model in ipairs(container:GetChildren()) do
            if model:IsA("Model") then
                list[#list + 1] = {model = model, player = playerForModel(model)}
            end
        end
    end
    if #list == 0 then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                list[#list + 1] = {model = player.Character, player = player}
            end
        end
    end
    return list
end

local function isAlly(player)
    if not player or not LocalPlayer then return false end
    if player == LocalPlayer then return true end
    if LocalPlayer.Team ~= nil and player.Team ~= nil then return player.Team == LocalPlayer.Team end
    if LocalPlayer.TeamColor ~= nil and player.TeamColor ~= nil then return player.TeamColor == LocalPlayer.TeamColor end
    return false
end

local function colorFor(player)
    if State.Toggles.TeamCheck and isAlly(player) then return State.Values.AllyColor end
    return State.Values.EnemyColor
end

function State:RemoveESP(model)
    local record = self.ESPObjects[model]
    if not record then return end
    self.ESPObjects[model] = nil
    for _, object in pairs(record) do
        if typeof(object) == "Instance" then pcall(object.Destroy, object) end
    end
end

function State:ClearESP()
    for model in pairs(self.ESPObjects) do
        self:RemoveESP(model)
    end
end

function State:CreateESP(model, player)
    self:RemoveESP(model)
    if self.Destroyed or not self.Toggles.ESP or not model then return end
    if self.Toggles.TeamCheck and isAlly(player) then return end
    local head = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
    if not head then return end

    local color = colorFor(player)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "DepHubESP"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.fromOffset(220, 46)
    billboard.StudsOffset = Vector3.new(0, 2.8, 0)
    billboard.Adornee = head
    billboard.Parent = head

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextStrokeTransparency = 0.35
    label.TextColor3 = color
    label.TextSize = self.Values.TextSize
    label.Parent = billboard

    local highlight
    if self.Toggles.Chams then
        highlight = Instance.new("Highlight")
        highlight.Name = "DepHubChams"
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillColor = color
        highlight.FillTransparency = 0.55
        highlight.OutlineColor = Color3.new(1, 1, 1)
        highlight.Adornee = model
        highlight.Parent = model
    end

    self.ESPObjects[model] = {Billboard = billboard, Label = label, Highlight = highlight}
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

-- Reconcile every frame: create records for fighters in range, drop stale ones,
-- and repaint the survivors. Team check and range are re-evaluated live so a
-- toggle or slider change is visible without a relock.
function State:Refresh()
    if self.Destroyed or not self.Toggles.ESP then return end
    local _, _, localRoot = characterParts(LocalPlayer)
    local seen = {}
    for _, entry in ipairs(eachFighter()) do
        local model, player = entry.model, entry.player
        if model ~= (LocalPlayer.Character) then
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
            local distance = 0
            if localRoot and root and localRoot.Position and root.Position then
                local delta = root.Position - localRoot.Position
                distance = math.floor(delta.Magnitude or 0)
            end
            local ally = self.Toggles.TeamCheck and isAlly(player)
            local visible = not ally and distance <= self.Values.Range
            if visible then
                seen[model] = true
                local record = self.ESPObjects[model]
                if not record then
                    self:CreateESP(model, player)
                    record = self.ESPObjects[model]
                end
                if record then
                    local color = colorFor(player)
                    record.Label.TextColor3 = color
                    if record.Highlight then record.Highlight.FillColor = color end
                    local text = {}
                    if self.Toggles.ESPNames then
                        text[#text + 1] = player and (player.DisplayName or player.Name) or model.Name
                    end
                    if self.Toggles.ESPHealth and humanoid and humanoid.Health then text[#text + 1] = math.floor(humanoid.Health) .. " HP" end
                    if self.Toggles.ESPDistance then text[#text + 1] = distance .. "m" end
                    record.Label.Text = table.concat(text, " | ")
                    record.Label.TextSize = self.Values.TextSize
                    record.Billboard.Enabled = true
                    if record.Highlight then record.Highlight.Enabled = true end
                end
            end
        end
    end
    for model in pairs(self.ESPObjects) do
        if not seen[model] then self:RemoveESP(model) end
    end
end

function State:SetToggle(name, enabled)
    if self.Destroyed or type(name) ~= "string" then return false end
    if self.Toggles[name] == nil then return false end
    self.Toggles[name] = enabled == true
    if name == "ESP" then
        return self:SetESP(enabled)
    elseif name == "TeamCheck" or name == "Chams" then
        -- A team/chams change alters which records exist, so rebuild.
        if self.Toggles.ESP then self:ClearESP(); self:Refresh() end
    end
    return true
end

function State:GetToggle(name)
    if self.Destroyed or type(name) ~= "string" then return false end
    return self.Toggles[name] == true
end

function State:SetRange(value)
    value = tonumber(value)
    if not value or value ~= value or value < 1 then return false end
    self.Values.Range = math.clamp(math.floor(value), 1, 100000)
    return true
end

function State:SetTextSize(value)
    value = tonumber(value)
    if not value or value ~= value then return false end
    self.Values.TextSize = math.clamp(math.floor(value), 6, 40)
    return true
end

function State:Start()
    if self.Started or self.Destroyed then return false end
    self.Started = true
    local connection = RunService.RenderStepped:Connect(function()
        if not self.Destroyed and self.Toggles.ESP then self:Refresh() end
    end)
    self.Connections[#self.Connections + 1] = connection
    return true
end

function State:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self:ClearESP()
    for _, connection in ipairs(self.Connections) do
        if typeof(connection) == "Instance" or type(connection) == "table" then
            pcall(function() connection:Disconnect() end)
        end
    end
    self.Connections = {}
    if env[STATE_KEY] == self then env[STATE_KEY] = nil end
    if env.__DEPHUB and env.__DEPHUB.BloodStrike == self then env.__DEPHUB.BloodStrike = nil end
end

-- ---------------------------------------------------------------------------
-- Presentation: the shared shell. Tabs and sections are the backend's job.
-- The shared shell adapter's tab:CreateSection(title, column) takes the title
-- and the column ("Left"/"Right") only; the library rejects any other column.
-- Passing a summary where the column belongs made the section error inside the
-- pcall and the whole tab came up empty. Keep the two arguments it reads.
local function sectionFor(tab, name, column)
    if not (tab and type(tab.CreateSection) == "function") then return nil end
    local ok, section = pcall(function() return tab:CreateSection(name, column) end)
    if ok then return section end
    return nil
end

do
    local UI = env.__DEPHUB and env.__DEPHUB.UI
    if type(UI) == "table" and type(UI.CreateTab) == "function" then
        local okTab, tab = pcall(function() return UI:CreateTab("ESP", "All") end)
        if okTab and tab then
            local visual = sectionFor(tab, "Jogadores", "Left")
            if visual then
                visual:CreateToggle("ESP ativado", State.Toggles.ESP, function(v) State:SetToggle("ESP", v) end)
                visual:CreateToggle("Ignorar time aliado", State.Toggles.TeamCheck, function(v) State:SetToggle("TeamCheck", v) end)
                visual:CreateToggle("Chams (contorno)", State.Toggles.Chams, function(v) State:SetToggle("Chams", v) end)
            end
            local info = sectionFor(tab, "Informacao", "Right")
            if info then
                info:CreateToggle("Mostrar nome", State.Toggles.ESPNames, function(v) State.Toggles.ESPNames = v == true end)
                info:CreateToggle("Mostrar distancia", State.Toggles.ESPDistance, function(v) State.Toggles.ESPDistance = v == true end)
                info:CreateToggle("Mostrar vida", State.Toggles.ESPHealth, function(v) State.Toggles.ESPHealth = v == true end)
                info:CreateSlider("Distancia maxima", 50, 5000, State.Values.Range, function(v) State:SetRange(v) end)
                info:CreateSlider("Tamanho do texto", 8, 30, State.Values.TextSize, function(v) State:SetTextSize(v) end)
            end
        end
    end
end

State:Start()

do
    local Diag = env.__DEPHUB and env.__DEPHUB.Diagnostics
    if Diag and type(Diag.RegisterModule) == "function" then
        Diag:RegisterModule("src/games/bloodstrike.lua")
        Diag:Feature("BloodStrike.ESP", function() return State.Toggles.ESP and "ON" or "off" end)
        Diag:Feature("BloodStrike.TeamCheck", function() return State.Toggles.TeamCheck and "ON" or "off" end)
        Diag:Watch("BloodStrike alvos", function() return tostring((function()
            local n = 0
            for _ in pairs(State.ESPObjects) do n = n + 1 end
            return n
        end)()) end)
        Diag:Command("bs", function()
            local container = Workspace:FindFirstChild("Characters")
            return "esp=" .. tostring(State.Toggles.ESP) ..
                " team=" .. tostring(State.Toggles.TeamCheck) ..
                " characters=" .. tostring(container and #container:GetChildren() or 0)
        end)
    end
end

env.BS = State

return State
