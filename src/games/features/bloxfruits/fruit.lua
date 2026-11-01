local game = game
local task = task
local type = type
local pcall = pcall
local tostring = tostring
local tonumber = tonumber
local math = math

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Fruits -- pegar fruta do chao, no molde proprio.
--
-- Portado do script antigo (parked/fruits.lua), mas so a parte de FRUTA:
-- ESP, grab e store. O que estava misturado la (gacha, dealer, awakening,
-- baús) fica de fora -- se for trazido, e noutra feature.
--
-- A parte que importa: isto NAO tem teleporte proprio. Ele pega o motor geral
-- (features/bloxfruits/teleport.lua) por injeção e usa tp:GoToInstance(part).
-- Era assim no script antigo tambem -- fruits chamava o modulo de teleporte.
-- A blade hit e a fruta agora compartilham UM teleporte, testado.
--
-- Self-contained: faz os proprios game:GetService e nao depende do DepHub. So
-- pede o motor de teleporte, e mesmo assim de forma opcional (sem ele o ESP e
-- o store ainda funcionam; so o grab nao voa).

local Feature = {}
Feature.__index = Feature

-- Uma fruta no chao e um Tool. O nome de verdade fica no atributo
-- "OriginalName" ("Dragon-Dragon Fruit"); o .Name pode vir localizado. As duas
-- chaves entram na comparacao, sem diferenciar maiuscula e por prefixo, pra
-- "dragon" achar "Dragon-Dragon Fruit".
local function fruitNameKeys(fruit)
    local keys = {}
    local original = fruit:GetAttribute("OriginalName")
    if original then keys[#keys + 1] = tostring(original):lower() end
    if fruit.Name then keys[#keys + 1] = tostring(fruit.Name):lower() end
    return keys
end

local function nameInSet(set, fruit)
    if not set or not next(set) then return false end
    for _, key in ipairs(fruitNameKeys(fruit)) do
        for name in pairs(set) do
            if key:find(name, 1, true) == 1 then return true end
        end
    end
    return false
end

local function fruitPart(fruit)
    return fruit:FindFirstChild("Handle") or fruit:FindFirstChildWhichIsA("BasePart")
end

function Feature.new(options)
    options = options or {}
    local self = setmetatable({}, Feature)
    self.Enabled = false
    self.GrabEnabled = false
    self.EspEnabled = false
    self.StoreEnabled = false
    self.Threads = {}
    self.EspMap = {}
    -- O motor de teleporte geral. Sem ele o ESP e o store ainda rodam; so o
    -- grab recusa (nao tem como voar ate a fruta).
    self.Teleport = options.teleport or nil
    self.Range = options.range or 0            -- 0 = pega de qualquer distancia
    self.EspRange = options.espRange or 0      -- 0 = mostra toda fruta
    self.Skip = options.skip or {}             -- frutas nunca pegas (prefixo)
    self.Keep = options.keep or {}             -- frutas nunca guardadas
    self.StoreInterval = options.storeInterval or 2
    self.LastError = nil
    return self
end

function Feature:SetTeleport(motor)
    self.Teleport = motor
    return self.Teleport ~= nil
end

function Feature:_hrp()
    local character = LocalPlayer and LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

function Feature:_commF()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    return remotes and remotes:FindFirstChild("CommF_")
end

-- Todas as frutas no chao. Uma fruta e um Tool em Workspace com um
-- OriginalName (ou um "-" no nome, que e o sufixo "-X Fruit") e um Handle.
function Feature:GroundFruits()
    local list = {}
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Tool") then
            local named = child:GetAttribute("OriginalName") or tostring(child.Name):find("-")
            if named and fruitPart(child) then list[#list + 1] = child end
        end
    end
    return list
end

function Feature:NearestGroundFruit(skip)
    local root = self:_hrp()
    local best, bestPart, bestDistance
    local maxRange = tonumber(self.Range) or 0
    for _, fruit in ipairs(self:GroundFruits()) do
        local part = fruitPart(fruit)
        if part and not (skip and skip[fruit]) and not nameInSet(self.Skip, fruit) then
            local distance = root and (part.Position - root.Position).Magnitude or 0
            if (maxRange <= 0 or distance <= maxRange) and (not bestDistance or distance < bestDistance) then
                best, bestPart, bestDistance = fruit, part, distance
            end
        end
    end
    return best, bestPart
end

-- --- ESP ------------------------------------------------------------------
-- Destaca as frutas no chao com Highlight + BillboardGui mostrando nome e
-- distancia. O mapa de adornos e mantido entre frames e limpo no disable.

function Feature:_spawn(name, body)
    self.Threads[name] = task.spawn(body)
end

function Feature:_cancel(name)
    local thread = self.Threads[name]
    if thread then pcall(task.cancel, thread); self.Threads[name] = nil end
end

function Feature:SetEsp(on)
    self.EspEnabled = on == true
    if not self.EspEnabled then
        for _, entry in pairs(self.EspMap) do
            pcall(function() entry.highlight:Destroy(); entry.billboard:Destroy() end)
        end
        self.EspMap = {}
        self:_cancel("esp")
        return true
    end
    self:_spawn("esp", function()
        while self.EspEnabled do
            local live = {}
            local root = self:_hrp()
            for _, fruit in ipairs(self:GroundFruits()) do
                local part = fruitPart(fruit)
                if part then
                    live[fruit] = true
                    local entry = self.EspMap[fruit]
                    if not entry then
                        local highlight = Instance.new("Highlight")
                        highlight.FillColor = Color3.fromRGB(120, 220, 255)
                        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                        highlight.Adornee = part
                        highlight.Parent = part
                        local billboard = Instance.new("BillboardGui")
                        billboard.Size = UDim2.fromOffset(150, 20)
                        billboard.StudsOffset = Vector3.new(0, 2.5, 0)
                        billboard.AlwaysOnTop = true
                        billboard.Adornee = part
                        billboard.Parent = part
                        local label = Instance.new("TextLabel")
                        label.BackgroundTransparency = 1
                        label.Size = UDim2.fromScale(1, 1)
                        label.Font = Enum.Font.GothamBold
                        label.TextSize = 13
                        label.TextColor3 = Color3.fromRGB(120, 220, 255)
                        label.TextStrokeTransparency = 0.4
                        label.Parent = billboard
                        entry = {highlight = highlight, billboard = billboard, label = label, part = part}
                        self.EspMap[fruit] = entry
                    end
                    local distance = root and math.floor((part.Position - root.Position).Magnitude) or 0
                    local maxRange = tonumber(self.EspRange) or 0
                    local shown = (maxRange <= 0) or (distance <= maxRange)
                    entry.highlight.Enabled = shown
                    entry.billboard.Enabled = shown
                    entry.label.Text = ("%s  %dm"):format(fruit.Name, distance)
                end
            end
            for fruit, entry in pairs(self.EspMap) do
                if not live[fruit] then
                    pcall(function() entry.highlight:Destroy(); entry.billboard:Destroy() end)
                    self.EspMap[fruit] = nil
                end
            end
            task.wait(0.5)
        end
    end)
    return true
end

-- --- Grab -----------------------------------------------------------------
-- Acha a fruta mais perto, voa ate ela com o motor de teleporte, e dispara a
-- ProximityPrompt da fruta (fireproximityprompt) assim que chega. Um passo por
-- vez, com o loop indo pra proxima -- igual ao collectNearestOnce do original.

function Feature:_fireFruitPrompt(fruit)
    local prompt = fruit:FindFirstChildWhichIsA("ProximityPrompt")
    if not prompt then
        for _, descendant in ipairs(fruit:GetDescendants()) do
            if descendant:IsA("ProximityPrompt") then prompt = descendant break end
        end
    end
    if not prompt then return false end
    local fire = fireproximityprompt
    if type(fire) ~= "function" then return false end
    local ok = pcall(fire, prompt)
    return ok
end

function Feature:CollectNearestOnce()
    local fruit, part = self:NearestGroundFruit()
    if not (fruit and part) then return false end
    local motor = self.Teleport
    if not motor then
        self.LastError = "teleport motor ausente"
        return false
    end
    -- Voa ate a Handle da fruta, chegando um pouco acima e na frente.
    pcall(function() motor:GoToInstance(part) end)
    return true
end

function Feature:SetGrab(on)
    self.GrabEnabled = on == true
    if not self.GrabEnabled then self:_cancel("grab"); return true end
    self:_spawn("grab", function()
        while self.GrabEnabled do
            local done = pcall(function() return self:CollectNearestOnce() end)
            if not done then self.LastError = "grab step falhou" end
            task.wait(0.5)
        end
    end)
    return true
end

-- --- Store ----------------------------------------------------------------
-- Guarda as frutas que voce ja tem (Tools carregados ou na mochila) via o
-- remote StoreFruit, respeitando a lista de "nunca guardar".

function Feature:StoreHeld()
    local comm = self:_commF()
    if not comm then return false end
    local pools = {}
    if LocalPlayer.Character then pools[#pools + 1] = LocalPlayer.Character end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then pools[#pools + 1] = backpack end
    for _, pool in ipairs(pools) do
        for _, tool in ipairs(pool:GetChildren()) do
            if tool:IsA("Tool") then
                local original = tool:GetAttribute("OriginalName")
                -- Fruta tem "-" no OriginalName ("Dragon-Dragon Fruit"); nao
                -- confundir com espada nem com item qualquer.
                if original and tostring(original):find("-") and not nameInSet(self.Keep, tool) then
                    pcall(function() comm:InvokeServer("StoreFruit", original, tool) end)
                end
            end
        end
    end
    return true
end

function Feature:SetStore(on)
    self.StoreEnabled = on == true
    if not self.StoreEnabled then self:_cancel("store"); return true end
    self:_spawn("store", function()
        while self.StoreEnabled do
            pcall(function() self:StoreHeld() end)
            task.wait(self.StoreInterval)
        end
    end)
    return true
end

-- --- Knobs ----------------------------------------------------------------
function Feature:SetRange(value)
    value = tonumber(value)
    if not value or value < 0 then return false end
    self.Range = value
    return true
end

function Feature:SetEspRange(value)
    value = tonumber(value)
    if not value or value < 0 then return false end
    self.EspRange = value
    return true
end

-- "dragon rocket" -> {dragon=true, rocket=true}
function Feature:ParseList(text)
    local set = {}
    for token in tostring(text or ""):gmatch("[^,%s]+") do
        local name = token:lower()
        if name ~= "" then set[name] = true end
    end
    return set
end

function Feature:SetSkip(text)
    if type(text) == "string" then self.Skip = self:ParseList(text) else self.Skip = text or {} end
    return true
end

function Feature:SetKeep(text)
    if type(text) == "string" then self.Keep = self:ParseList(text) else self.Keep = text or {} end
    return true
end

-- --- Ciclo de vida --------------------------------------------------------
-- A feature so faz alguma coisa com pelo menos um dos tres ligado. Enable()
-- fica ligada enquanto qualquer um estiver; Disable() derruba todos.

function Feature:Enable()
    if self.Enabled then return true end
    self.Enabled = true
    return true
end

function Feature:Disable()
    self.Enabled = false
    self.GrabEnabled = false
    self.StoreEnabled = false
    self:SetEsp(false)
    self:_cancel("grab")
    self:_cancel("store")
    return true
end

function Feature:IsEnabled()
    return self.Enabled == true
end

function Feature:Destroy()
    self:Disable()
    self.Teleport = nil
    self.EspMap = {}
end

return Feature
