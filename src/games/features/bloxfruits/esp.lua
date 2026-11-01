local game = game
local task = task
local type = type
local pcall = pcall
local tostring = tostring
local tonumber = tonumber
local math = math
local table = table
local ipairs = ipairs
local pairs = pairs
local next = next
local os = os

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- ESP -- os outros jogadores, e as MINHAS infos.
--
-- Portado do script OpenSource (o mesmo que ja deu o silent aim e a haki).
-- Tem duas partes:
--
-- 1. INFOS DO LOCAL PLAYER (captura so, sem UI): level, Beli (dinheiro),
--    Fragments, Race, DevilFruit e as armas equipadas (Sword/Gun/Melee). O
--    caminho e o que o OpenSource usa:
--      * LP.Data.<Nome>.Value  -- level/beli/fragments/race/fruit (Number/StringValue
--        filho de LocalPlayer.Data; alguns podem nao existir em todo build, por
--        isso a leitura e pcall e devolve nil quando sumiu).
--      * arma equipada -- varre LP.Character e LP.Backpack procurando um Tool
--        cujo ToolTip seja o tipo ("Sword"/"Gun"/"Melee"/"Fruit") e devolve o
--        .Name. Isso e o que o OpenSource chama de equipped(kind).
--    O usuario pediu "guarda isso pronto pra eu usar": a captura roda em loop e
--    publica em self.Stats; nenhuma feature le ainda -- o usuario vai construir
--    em cima.
--
-- 2. ESP DOS OUTROS JOGADORES: um Highlight (achar o corpo) e um Billboard com
--    nome + level + vida + distancia (achar ONDE exatamente esta). O rotulo
--    segue o jogador pelo Adornee da HumanoidRootPart; o Level sai do mesmo
--    dataVal("Level") do proprio alvo; a vida sai do Humanoid.Health/MaxHealth.
--
-- Gate de verdade: cada toggle liga/desliga o proprio pedaco; desligar o ESP
-- destroi TODOS os adornos e limpa o mapa; a captura para junto. Nada de
-- residuo no character de ninguem.
--
-- Self-contained: faz os proprios game:GetService e publica new()/Enable()/
-- Disable()/Destroy()/SetEsp()/SetLocator()/GetStats(). Sem UI: quem monta o
-- painel e o backend.

local Feature = {}
Feature.__index = Feature

-- Cadencia do loop de ESP (segundos). 0.5 e o mesmo passo do OpenSource: rapido
-- o bastante pro rotulo nao "arrastar" atras do jogador.
local ESP_INTERVAL = 0.5
-- Cadencia da captura das minhas infos. Nao precisa ser rapida -- o usuario so
-- quer os valores prontos -- entao 2s e de sobra.
local STATS_INTERVAL = 2

-- --- Leitura das minhas infos ----------------------------------------------

-- LP.Data[nome].Value com o MESMO guard do OpenSource: alguns campos podem nao
-- existir em todo build do jogo, entao a leitura e protegida e devolve nil
-- quando o caminho nao existe (em vez de estourar).
local function dataVal(name)
    local ok, value = pcall(function() return LocalPlayer.Data[name].Value end)
    return ok and value or nil
end

-- A arma equipada de um tipo. O OpenSource procura por ToolTip == tipo no
-- character E na mochila (o character pode estar com ela equipada ou guardada).
-- Devolve o .Name do Tool, ou "-" (mesmo sentinela do original).
local function equipped(kind)
    for _, pool in ipairs({ LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack") }) do
        if pool then
            for _, tool in ipairs(pool:GetChildren()) do
                if tool:IsA("Tool") and tool.ToolTip == kind then return tool.Name end
            end
        end
    end
    return "-"
end

-- Formata um numero com separador de milhar (o Beli/Fragments chegam inteiros
-- grandes). Igual ao comma() do OpenSource.
local function comma(n)
    if type(n) ~= "number" then return tostring(n) end
    local s = tostring(math.floor(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

function Feature.new(options)
    options = options or {}
    local self = setmetatable({}, Feature)
    self.Enabled = false
    -- Pedidos independentes: o ESP (adornos nos outros jogadores) e o locator
    -- (a linha/distancia ate cada jogador). Comecam desligados.
    self.EspOn = false
    self.LocatorOn = false
    -- Captura das minhas infos: sempre que a feature esta ligada.
    self.CaptureOn = true
    -- Publicado pela captura. Comeca vazio e vai enchendo.
    self.Stats = {
        Level = nil, Beli = nil, Fragments = nil, Race = nil, DevilFruit = nil,
        Sword = "-", Gun = "-", Melee = "-",
    }
    self.Threads = {}
    -- Mapa player -> { highlight, billboard, label, tracer... } dos adornos
    -- vivos. E por aqui que o cleanup acha tudo pra destruir.
    self.EspMap = {}
    -- A minha HumanoidRootPart (pro distance e pro tracer do locator).
    self.MyRoot = nil
    self.LastUpdated = nil
    return self
end

-- --- Minhas infos -----------------------------------------------------------

-- Tira um retrato dos valores AGORA e publica em self.Stats. Idempotente e
-- sem efeito colateral: so le. Devolve a propria tabela.
function Feature:SampleStats()
    self.Stats.Level = dataVal("Level")
    self.Stats.Beli = dataVal("Beli")
    self.Stats.Fragments = dataVal("Fragments")
    self.Stats.Race = dataVal("Race")
    self.Stats.DevilFruit = dataVal("DevilFruit")
    self.Stats.Sword = equipped("Sword")
    self.Stats.Gun = equipped("Gun")
    self.Stats.Melee = equipped("Melee")
    self.LastUpdated = os.clock()
    return self.Stats
end

-- Uma visao PRONTA pra exibir: strings formatadas (o Beli/Fragments com
-- separador de milhar, o resto direto). O usuario consome isso quando for montar
-- a UI dele.
function Feature:GetStats()
    local s = self.Stats
    return {
        Level = s.Level ~= nil and tostring(s.Level) or "?",
        Beli = comma(s.Beli or 0),
        Fragments = comma(s.Fragments or 0),
        Race = s.Race ~= nil and tostring(s.Race) or "?",
        DevilFruit = s.DevilFruit ~= nil and tostring(s.DevilFruit) or "None",
        Sword = tostring(s.Sword or "-"),
        Gun = tostring(s.Gun or "-"),
        Melee = tostring(s.Melee or "-"),
    }
end

-- --- ESP dos outros jogadores ----------------------------------------------

-- Os outros jogadores com character vivo (sem mim, sem quem nao tem corpo).
function Feature:Others()
    local list = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            list[#list + 1] = player
        end
    end
    return list
end

-- A HumanoidRootPart de um character, ou nil.
local function rootOf(character)
    return character and character:FindFirstChild("HumanoidRootPart")
end

-- A Humanoid de um character, ou nil.
local function humanoidOf(character)
    return character and character:FindFirstChildOfClass("Humanoid")
end

-- O level do ALVO, pelo mesmo caminho do local (LP.Data -> jogador.Data). E o
-- pedaco que o usuario quis: "esp de level e vida nos player".
local function targetLevel(player)
    local ok, value = pcall(function() return player.Data.Level.Value end)
    return (ok and value) or nil
end

-- A vida do alvo, pelo Humanoid. Devolve "atual/max" arredondado.
local function targetHealth(character)
    local humanoid = humanoidOf(character)
    if not humanoid then return nil end
    local current = humanoid.Health
    local max = humanoid.MaxHealth
    if type(current) ~= "number" then return nil end
    if type(max) ~= "number" or max <= 0 then return math.floor(current) end
    return ("%d/%d"):format(math.floor(current), math.floor(max))
end

-- Monta os adornos de um character: Highlight (achar o corpo) + Billboard com o
-- rotulo. O rotulo e preenchido no ciclo (muda a cada passo).
function Feature:_makeEsp(character)
    local root = rootOf(character)
    local highlight = Instance.new("Highlight")
    highlight.FillColor = Color3.fromRGB(255, 80, 80)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.6
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = character
    highlight.Parent = character

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.fromOffset(200, 40)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = root or character
    billboard.Parent = character

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0.4
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Text = ""
    label.Parent = billboard

    return { highlight = highlight, billboard = billboard, label = label, character = character, root = root }
end

-- Destroi os adornos de uma entrada, best-effort. Nao deixa residuo.
local function destroyEntry(entry)
    if not entry then return end
    pcall(function() entry.highlight:Destroy() end)
    pcall(function() entry.billboard:Destroy() end)
end

-- Um passo do ESP: garante um adorno por jogador vivo e reescreve o rotulo com
-- nome + level + vida + distancia. Remove o adorno de quem saiu ou trocou de
-- character (o Adornee velho seria uma parte morta).
function Feature:EspStep()
    local live = {}
    local myRoot = rootOf(LocalPlayer.Character)
    self.MyRoot = myRoot
    for _, player in ipairs(self:Others()) do
        local character = player.Character
        if character then
            live[player] = true
            local entry = self.EspMap[player]
            -- Character trocou (respawn): o adorno antigo aponta pra um corpo
            -- morto -- derruba e remonta.
            if entry and entry.character ~= character then
                destroyEntry(entry)
                self.EspMap[player] = nil
                entry = nil
            end
            if not entry then
                entry = self:_makeEsp(character)
                self.EspMap[player] = entry
            end
            local root = rootOf(character)
            entry.root = root
            -- Locator: a distancia exata ate o alvo (o "onde ta o player").
            local distance = (root and myRoot) and math.floor((root.Position - myRoot.Position).Magnitude) or 0
            local level = targetLevel(player)
            local health = targetHealth(character)
            local parts = { player.Name }
            if level ~= nil then parts[#parts + 1] = "Lv " .. tostring(level) end
            if health ~= nil then parts[#parts + 1] = "HP " .. tostring(health) end
            if self.LocatorOn then parts[#parts + 1] = tostring(distance) .. "m" end
            entry.label.Text = table.concat(parts, "\n")
        end
    end
    -- Faxina: jogador que saiu (ou sem character) perde o adorno.
    for player, entry in pairs(self.EspMap) do
        if not live[player] then
            destroyEntry(entry)
            self.EspMap[player] = nil
        end
    end
    return true
end

-- --- Controles (chamados pelo backend) --------------------------------------

-- ESP: destaca os outros jogadores e mostra nome + level + vida. Desligar
-- destroi tudo e para o loop (se o locator tambem estiver off).
function Feature:SetEsp(on)
    self.EspOn = on == true
    if self.EspOn then
        self:Enable()
        self:_spawn("esp")
    else
        self:_stopEsp()
    end
    return true
end

-- Locator: adiciona a distancia ao rotulo (achar onde o jogador esta). O
-- locator sozinho nao monta adorno -- ele precisa do ESP pro Highlight/rotulo
-- existirem; guarda a escolha e o proximo passo do ESP a aplica.
function Feature:SetLocator(on)
    self.LocatorOn = on == true
    if self.LocatorOn then self:Enable() end
    return true
end

-- --- Loops ------------------------------------------------------------------

-- Spawna (uma vez) o loop do ESP enquanto o ESP ou a captura estiverem ligados.
function Feature:_spawn(key)
    if key == "esp" then
        if self.Threads.esp then return end
        self.Threads.esp = task.spawn(function()
            while self.EspOn do
                pcall(function() self:EspStep() end)
                task.wait(ESP_INTERVAL)
            end
            self.Threads.esp = nil
        end)
    elseif key == "capture" then
        if self.Threads.capture then return end
        self.Threads.capture = task.spawn(function()
            while self.CaptureOn and self.Enabled do
                pcall(function() self:SampleStats() end)
                task.wait(STATS_INTERVAL)
            end
            self.Threads.capture = nil
        end)
    end
end

function Feature:_cancel(key)
    if self.Threads[key] then
        pcall(function() task.cancel(self.Threads[key]) end)
        self.Threads[key] = nil
    end
end

-- Derruba os adornos do ESP (sem mexer no pedido do locator).
function Feature:_stopEsp()
    self:_cancel("esp")
    for _, entry in pairs(self.EspMap) do destroyEntry(entry) end
    self.EspMap = {}
end

-- --- Ciclo de vida ----------------------------------------------------------

function Feature:Enable()
    if self.Enabled then return true end
    self.Enabled = true
    self.CaptureOn = true
    -- Captura imediata (nao espera o primeiro intervalo) + loop.
    pcall(function() self:SampleStats() end)
    self:_spawn("capture")
    if self.EspOn then self:_spawn("esp") end
    return true
end

function Feature:Disable()
    self.Enabled = false
    self.CaptureOn = false
    self:_cancel("capture")
    self:_stopEsp()
    return true
end

function Feature:IsEnabled()
    return self.Enabled == true
end

function Feature:Destroy()
    self:Disable()
end

return Feature
