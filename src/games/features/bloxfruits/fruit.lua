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
-- ESP e grab tem ALCANCE ILIMITADO: nao ha limite de distancia configuravel (os
-- sliders "ESP max distance" e "Grab max distance" sairam). O ESP destaca toda
-- fruta no chao; o grab voa ate a fruta mais proxima, de qualquer distancia.
--
-- Self-contained: faz os proprios game:GetService e nao depende do DepHub. So
-- pede o motor de teleporte, e mesmo assim de forma opcional (sem ele o ESP e
-- o store ainda funcionam; so o grab nao voa).

local Feature = {}
Feature.__index = Feature

-- --- Deteccao de fruta no chao ---------------------------------------------
-- Uma fruta no chao aparece de DUAS formas no Blox Fruits, e a versao antiga so
-- via a segunda -- por isso a fruta SPAWNADA pelo jogo nunca ganhava ESP nem
-- grab:
--   1. Spawnada pelo jogo: um Model chamado "Fruit"/"fruit" em Workspace, SEM
--      Handle (o Handle/ProximityPrompt so nasce quando o jogador encosta). Este
--      e o caso que estava sendo jogado fora pelo filtro antigo (so aceitava
--      Tool).
--   2. Dropada por jogador / ja virada item: um Tool com OriginalName
--      ("Dragon-Dragon Fruit") e Handle.
-- A deteccao aceita as duas. Para o Tool o nome bom e o OriginalName; para o
-- Model e o proprio .Name.

-- O nome e "Fruit"-like? (spawn do jogo). Compara sem diferenciar maiuscula e
-- aceita "fruit" e "fruits" -- substring nao pega "Fruit" maiusculo se eu so
-- testar igualdade, entao testo prefixo no minusculo.
local function looksLikeFruitModel(instance)
    local name = tostring(instance.Name):lower()
    return name == "fruit" or name == "fruits" or name:sub(1, 5) == "fruit"
end

-- A parte fisica pra adorno/teleporte. Tool -> Handle ou a primeira BasePart;
-- Model/Part -> a primeira BasePart descendente (a fruta spawnada e um Model sem
-- Handle, entao a parte esta la dentro).
local function fruitPart(fruit)
    if fruit:IsA("BasePart") then return fruit end
    return fruit:FindFirstChild("Handle") or fruit:FindFirstChildWhichIsA("BasePart")
end

-- Uma fruta no chao e um Tool (com OriginalName/Handle) OU um Model "Fruit" que
-- o jogo spawnou. Um Model qualquer do mapa -- com outra geometria -- nao passa:
-- so o que tem nome Fruit-like, pra nao poluir o ESP com o mapa inteiro.
local function isGroundFruit(instance)
    if instance:IsA("Tool") then
        local named = instance:GetAttribute("OriginalName") or tostring(instance.Name):find("-")
        return named ~= nil and fruitPart(instance) ~= nil
    end
    if instance:IsA("Model") or instance:IsA("BasePart") then
        return looksLikeFruitModel(instance) and fruitPart(instance) ~= nil
    end
    return false
end

-- As chaves de nome usadas pro skip/keep. Tool -> OriginalName + Name; Model
-- spawnado -> o proprio Name (que pode ser so "Fruit"; o nome real da fruta
-- aparece quando ela vira Tool). Por isso o skip/keep casa melhor em Tool --
-- mas o ESP/grab nunca dependem disso.
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

function Feature.new(options)
    options = options or {}
    local self = setmetatable({}, Feature)
    self.Enabled = false
    self.GrabEnabled = false
    self.EspEnabled = false
    self.TraceEnabled = false   -- linhas ligando o character a cada fruta
    self.StoreEnabled = false
    self.RandomEnabled = false
    self.GachaCooldownMin = 30
    self.GachaCooldownMax = 300
    self.Threads = {}
    self.EspMap = {}
    -- O Beam do tracer e criado uma vez por fruta no EspMap (junto com o
    -- Highlight e o Billboard); a visibilidade dele segue TraceEnabled. Um
    -- attachment local (na minha HRP) e um na fruta, por beam.
    --
    -- O motor de teleporte geral. Sem ele o ESP e o store ainda rodam; so o
    -- grab recusa (nao tem como voar ate a fruta).
    self.Teleport = options.teleport or nil
    -- Alcance ILIMITADO: nao ha mais limite de distancia configuravel (os dois
    -- sliders "ESP max distance" / "Grab max distance" sairam). O ESP mostra toda
    -- fruta no chao e o grab pega a mais proxima de qualquer distancia -- sem
    -- loop extra: a varredura e a mesma GetChildren + as mesmas checagens de
    -- existencia/validade de antes, so sem o corte por distancia.
    self.Skip = options.skip or {}             -- frutas nunca pegas (prefixo)
    self.Keep = options.keep or {}             -- frutas nunca guardadas
    self.StoreInterval = options.storeInterval or 2
    self.RandomCooldown = options.randomCooldown or 90
    self.LastError = nil
    self.LastGachaCooldown = nil
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

-- Todas as frutas no chao -- spawnada pelo jogo (Model "Fruit") e dropada
-- (Tool com OriginalName/Handle). A deteccao e isGroundFruit; ver o cabecalho
-- acima pro porque dos dois casos.
function Feature:GroundFruits()
    local list = {}
    for _, child in ipairs(workspace:GetChildren()) do
        if isGroundFruit(child) then list[#list + 1] = child end
    end
    return list
end

function Feature:NearestGroundFruit(skip)
    local root = self:_hrp()
    local best, bestPart, bestDistance
    -- Alcance ilimitado: sem corte por distancia. Ainda so considera fruta com
    -- parte fisica valida e fora da skip list -- as checagens eficientes de
    -- existencia/validade continuam. A mais proxima ganha pelo melhor candidato
    -- ja encontrado (o mesmo "best" de antes, so sem o teto de alcance).
    for _, fruit in ipairs(self:GroundFruits()) do
        local part = fruitPart(fruit)
        if part and not (skip and skip[fruit]) and not nameInSet(self.Skip, fruit) then
            local distance = root and (part.Position - root.Position).Magnitude or 0
            if not bestDistance or distance < bestDistance then
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

-- Destroi os adornos de UMA entrada (highlight, billboard + suas partes, e o
-- tracer com as duas attachments). Um unico ponto de limpeza: usado ao remover a
-- fruta do mapa, ao trocar a parte e no disable.
local function destroyEntry(entry)
    if not entry then return end
    pcall(function() entry.highlight:Destroy() end)
    pcall(function() entry.billboard:Destroy() end)
    if entry.beam then pcall(function() entry.beam:Destroy() end) end
    if entry.localAttachment then pcall(function() entry.localAttachment:Destroy() end) end
    if entry.fruitAttachment then pcall(function() entry.fruitAttachment:Destroy() end) end
end

function Feature:SetEsp(on)
    self.EspEnabled = on == true
    if not self.EspEnabled then
        for _, entry in pairs(self.EspMap) do destroyEntry(entry) end
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
                    -- A parte da fruta pode MUDAR: a spawnada e um Model e a
                    -- parte viva pode ser re-parented enquanto existe. Se o
                    -- adorno aponta pra uma parte que nao e mais a atual, ele
                    -- fica orfao (o "tabugado" que o usuario viu): entao
                    -- re-aponta em vez de fingir que esta tudo bem.
                    if entry and entry.part ~= part then
                        destroyEntry(entry)
                        self.EspMap[fruit] = nil
                        entry = nil
                    end
                    if not entry then
                        -- Highlight: preenchimento azul-claro com contorno branco
                        -- e uma emissao leve, pra fruta saltar do chao.
                        local highlight = Instance.new("Highlight")
                        highlight.FillColor = Color3.fromRGB(90, 200, 255)
                        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                        highlight.FillTransparency = 0.35
                        highlight.OutlineTransparency = 0
                        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        highlight.Adornee = part
                        highlight.Parent = part

                        -- Billboard: nome + distancia, cor da fruta (amarelo) pra
                        -- ler de longe sem confundir com o highlight.
                        local billboard = Instance.new("BillboardGui")
                        billboard.Size = UDim2.fromOffset(180, 22)
                        billboard.StudsOffset = Vector3.new(0, 2.8, 0)
                        billboard.AlwaysOnTop = true
                        billboard.Adornee = part
                        billboard.Parent = part
                        local label = Instance.new("TextLabel")
                        label.BackgroundTransparency = 1
                        label.Size = UDim2.fromScale(1, 1)
                        label.Font = Enum.Font.GothamBold
                        label.TextSize = 14
                        label.TextColor3 = Color3.fromRGB(255, 220, 90)
                        label.TextStrokeTransparency = 0.3
                        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                        label.Parent = billboard

                        -- Tracer: um Beam liga a MINHA HumanoidRootPart a fruta.
                        -- Nasce escondido (TraceEnabled manda na visibilidade no
                        -- ciclo abaixo). As duas attachments nascem soltas; o
                        -- attachment local e reparentado na minha HRP no update.
                        local beam = Instance.new("Beam")
                        beam.Name = "FruitTracer"
                        beam.FaceCamera = true
                        beam.LightEmission = 0.3
                        beam.LightInfluence = 0
                        beam.Width0 = 1.2
                        beam.Width1 = 1.2
                        beam.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90))
                        beam.Transparency = NumberSequence.new(0.25)
                        beam.Enabled = false
                        beam.Parent = part
                        local fruitAttachment = Instance.new("Attachment")
                        fruitAttachment.Parent = part
                        local localAttachment = Instance.new("Attachment")
                        beam.Attachment1 = fruitAttachment
                        beam.Attachment0 = localAttachment

                        entry = {
                            highlight = highlight, billboard = billboard, label = label,
                            part = part, beam = beam,
                            localAttachment = localAttachment, fruitAttachment = fruitAttachment,
                        }
                        self.EspMap[fruit] = entry
                    end
                    -- Alcance ilimitado: toda fruta no chao e destacada, a
                    -- qualquer distancia. A distancia continua no rotulo, so
                    -- deixou de ser um corte.
                    local distance = root and math.floor((part.Position - root.Position).Magnitude) or 0
                    entry.highlight.Enabled = true
                    entry.billboard.Enabled = true
                    -- Fruta spawnada chama-se so "Fruit"; mostra o nome real se
                    -- houver OriginalName, senao o proprio Name.
                    local label = fruit:GetAttribute("OriginalName") or fruit.Name
                    entry.label.Text = ("%s  %dm"):format(label, distance)

                    -- Tracer: so aparece com o toggle ligado E tendo a minha HRP.
                    -- Reparenta o attachment local na HRP (ela troca no respawn,
                    -- o beam nao pode apontar pra uma parte morta).
                    if self.TraceEnabled and root then
                        if entry.localAttachment.Parent ~= root then entry.localAttachment.Parent = root end
                        entry.beam.Enabled = true
                    else
                        entry.beam.Enabled = false
                    end
                end
            end
            for fruit, entry in pairs(self.EspMap) do
                if not live[fruit] then
                    destroyEntry(entry)
                    self.EspMap[fruit] = nil
                end
            end
            task.wait(0.5)
        end
    end)
    return true
end

-- O tracer: as linhas do character ate as frutas. E um toggle a PARTE (o
-- usuario pediu pra ligar/desligar so ele); highlight e distancia continuam
-- junto do Fruit ESP. Sem o ESP ligado, o tracer nao tem adorno pra desenhar --
-- so guarda a escolha, que o proximo ciclo do ESP aplica.
function Feature:SetTrace(on)
    self.TraceEnabled = on == true
    if not self.TraceEnabled then
        for _, entry in pairs(self.EspMap) do
            if entry.beam then entry.beam.Enabled = false end
        end
    end
    return true
end

-- --- Grab -----------------------------------------------------------------
-- Acha a fruta mais perto, voa ate ela com o motor de teleporte, e dispara o
-- ProximityPrompt da fruta (fireproximityprompt) quando ele existe. Um passo por
-- vez, com o loop indo pra proxima -- igual ao collectNearestOnce do original.
--
-- ARMADILHA (a fruta spawnada): o Model "Fruit" do jogo NAO tem Handle nem
-- ProximityPrompt enquanto ninguem encostou -- o prompt so nasce no toque. Entao
-- fireproximityprompt nao acha nada pra disparar. Nesse caso o grab E o proprio
-- TOQUE: o motor voa ATE a fruta, e encostar nela faz o jogo virar o Model em
-- Tool (ai sim coletavel). Por isso o CollectNearestOnce dispara o prompt quando
-- houver (fruta dropada: caminho mais rapido) e sempre garante o voo ate a
-- fruta -- o encosto faz o resto.

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
    -- Voa ate a fruta. GoToInstance chega em cima dela; encostar e o que faz o
    -- jogo virar o Model spawnado em Tool coletavel.
    pcall(function() motor:GoToInstance(part) end)
    -- Fruta dropada ja tem prompt: dispara (caminho mais rapido). Fruta
    -- spawnada nao tem -- e o encosto do voo que resolve.
    self:_fireFruitPrompt(fruit)
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

-- --- Auto random fruit (gacha) --------------------------------------------
-- Rola a gacha de fruta (Zioles) em cooldown. O mecanismo e o RemoteFunction
-- RF/GachaNetworkRF (Modules.Net), invocado com {Context="Purchase",
-- BoxName="ZiolesGacha"} -- o mesmo caminho que o jogo usa. A resposta traz o
-- cooldown real (um numero); enquanto for > 3 usamos ele em vez do default, pra
-- respeitar o tempo que o servidor manda.

-- Resolve o RemoteFunction da gacha. Modules.Net e o caminho atual; cai pro Net
-- solto em ReplicatedStorage em builds antigas (mesmo padrao da blade hit).
function Feature:_gachaRF()
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    local net = (modules and modules:FindFirstChild("Net")) or ReplicatedStorage:FindFirstChild("Net")
    if not net then return nil end
    return net:FindFirstChild("RF/GachaNetworkRF")
end

-- Uma rolagem. Devolve true se o remote existiu e a chamada saiu. Quando a
-- resposta traz um numero (o cooldown), guarda em self.LastGachaCooldown e
-- devolve como 2o retorno pra o loop respeitar.
function Feature:RollGacha()
    local remote = self:_gachaRF()
    if not remote then self.LastError = "gacha remote ausente"; return false end
    local ok, result = pcall(function()
        return remote:InvokeServer({ Context = "Purchase", BoxName = "ZiolesGacha" })
    end)
    if not ok then self.LastError = "gacha recusou"; return false end
    self.LastGachaCooldown = nil
    if type(result) == "number" and result > 3 then
        self.LastGachaCooldown = math.clamp(math.floor(result), self.GachaCooldownMin, self.GachaCooldownMax)
    end
    return true, self.LastGachaCooldown
end

function Feature:SetRandom(on)
    self.RandomEnabled = on == true
    if not self.RandomEnabled then self:_cancel("random"); return true end
    self:_spawn("random", function()
        while self.RandomEnabled do
            local ok, cooldown = pcall(function() return self:RollGacha() end)
            local wait = self.RandomCooldown
            if ok and type(cooldown) == "number" then wait = cooldown end
            -- Espera em fatias de 1s pra desligar rapido (o cancel do thread
            -- tambem corta, mas o loop respeita a flag alem do cancel).
            while self.RandomEnabled and wait > 0 do
                task.wait(1)
                wait = wait - 1
            end
        end
    end)
    return true
end

-- --- Knobs ----------------------------------------------------------------
-- Skip/keep sao conjuntos de PREFIXOS de nome de fruta (em minusculo): "dragon"
-- casa "Dragon-Dragon Fruit". A UI agora alimenta isso com um dropdown de
-- selecao multipla -- a lista de frutas escolhidas vira o conjunto de prefixos.
-- Os dois aceitam uma tabela-array {"Dragon","Rocket"} ou uma tabela-conjunto
-- {dragon=true}; uma string ("Dragon, Rocket") continua aceita por seguranca.

-- Normaliza um array {"Dragon","Rocket"} num conjunto {dragon=true,rocket=true}.
local function listToSet(list)
    local set = {}
    for _, name in ipairs(list) do
        local key = tostring(name):lower()
        if key ~= "" then set[key] = true end
    end
    return set
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

function Feature:SetSkip(value)
    if type(value) == "string" then self.Skip = self:ParseList(value)
    elseif type(value) == "table" then
        -- Uma tabela-conjunto ({dragon=true}) e um array ({"Dragon"}) sao
        -- distinguidas pelo primeiro: se tem [1] e um array.
        if value[1] ~= nil then self.Skip = listToSet(value) else self.Skip = value end
    else self.Skip = {} end
    return true
end

function Feature:SetKeep(value)
    if type(value) == "string" then self.Keep = self:ParseList(value)
    elseif type(value) == "table" then
        if value[1] ~= nil then self.Keep = listToSet(value) else self.Keep = value end
    else self.Keep = {} end
    return true
end

-- Cooldown default da gacha, em segundos. O servidor manda o cooldown real na
-- resposta (respeitado quando vier); isto e so o fallback ate a primeira
-- resposta -- e o que o slider do painel mexe.
function Feature:SetRandomInterval(seconds)
    local value = tonumber(seconds)
    if value then self.RandomCooldown = math.max(1, math.floor(value)) end
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
    self.RandomEnabled = false
    self:SetEsp(false)
    self:_cancel("grab")
    self:_cancel("store")
    self:_cancel("random")
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
