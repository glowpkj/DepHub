local game = game
local task = task
local type = type
local pcall = pcall
local tostring = tostring

local Players = game:GetService("Players")
local workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Island Teleport -- pular direto pra uma ilha pelo nome.
--
-- O usuario liga o toggle, escolhe a ilha no dropdown, e o personagem voa ate
-- ela. Teleporte "de botao": nao tem alvo movel nem loop de farm -- e so um voo
-- pontual por escolha.
--
-- NAO tem motor proprio: usa o teleporte geral (options.teleport, a infra) por
-- injecao, igual a fruta faz. Um motor de voo no script, nao dois.
--
-- O destino e a INSTANCIA real no mapa (workspace.Map.<Nome>), nao uma
-- coordenada chumbada: isso nao quebra quando o mapa muda e usa exatamente os
-- nomes que o usuario confirmou. Se a instancia nao existir (mar errado, ilha
-- fora do mapa), ele AVISA em vez de voar pro vazio.
--
-- Gate de verdade: selecionar no dropdown NAO teleporta. So vai se o toggle
-- estiver ligado. Trocar a ilha com o toggle ligado voa de novo; com ele
-- desligado, so memoriza a escolha.
--
-- Ao CHEGAR, o toggle se desliga sozinho -- foi o pedido do usuario: o voo e
-- pontual, nao faz sentido deixar armado depois que chegou. So a ilha daquele
-- voo desliga (a feature tem um unico toggle; nao ha "outras" para mexer). O
-- desligamento so dispara com o personagem perto do DESTINO daquele voo, entao
-- nao dispara cedo nem re-dispara com um passinho depois de chegar (a vigia
-- para no primeiro "chegou").
--
-- Self-contained: faz os proprios game:GetService e nao depende do DepHub. So
-- pede o motor de teleporte, e mesmo assim de forma opcional (sem ele, o toggle
-- recusa em vez de fingir que voa).

local Feature = {}
Feature.__index = Feature

-- A pasta das ilhas: workspace.Map. De la saem as instancias por nome.
local MAP_CONTAINER = "Map"

-- A que distancia do destino o voo conta como CHEGOU. O teleporte chega a 5
-- studs acima do alvo (ArrivalOffset), entao o limite tem que ser maior que
-- isso, mas pequeno o bastante para nao disparar no meio do caminho. 25 studs e
-- "do lado da ilha" sem confundir com passar por cima dela.
local ARRIVAL_DISTANCE = 25

-- As ilhas do Sea 2 (o usuario confirmou: todas as ilhas dele sao do Sea 2).
-- A chave e o rotulo que aparece no dropdown; o valor e o NOME DA INSTANCIA em
-- workspace.Map. Alguns rotulos bonitos nao batem com o nome do mapa (ex.:
-- Ghost Ship -> GhostShip), por isso a tabela explicita em vez de deduzir.
local SEA2_ISLANDS = {
    { label = "Snow Mountain",       instance = "SnowMountain" },
    { label = "Indra Island",        instance = "IndraIsland" },
    { label = "Ice Castle",          instance = "IceCastle" },
    { label = "Green Bit",           instance = "GreenBit" },
    { label = "Grave Island",        instance = "GraveIsland" },
    { label = "Ghost Ship Interior", instance = "GhostShipInterior" },
    { label = "Ghost Ship",          instance = "GhostShip" },
    { label = "Forgotten Island",    instance = "ForgottenIsland" },
    { label = "Fishmen",             instance = "Fishmen" },
    { label = "Dressrosa",           instance = "Dressrosa" },
    { label = "Darkbeard Arena",     instance = "DarkbeardArena" },
    { label = "Dapper Jack Arena",   instance = "DapperJackArena" },
}

-- A lista publica de rotulos, na ordem. O backend monta o dropdown daqui.
Feature.islands = {}
for _, entry in ipairs(SEA2_ISLANDS) do
    Feature.islands[#Feature.islands + 1] = entry.label
end

-- Acha a instancia da ilha em workspace.Map.<instancia>. Devolve a instancia ou
-- nil (se a pasta nao existir ou a ilha nao estiver no mapa).
function Feature:IslandInstance(instanceName)
    local map = workspace:FindFirstChild(MAP_CONTAINER)
    if not map then return nil end
    return map:FindFirstChild(instanceName)
end

-- A posicao do HumanoidRootPart agora, ou nil se nao ha character.
function Feature:RootPosition()
    local character = LocalPlayer and LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return root and root.Position or nil
end

-- A posicao-mundo da instancia (Part -> Position; Model -> GetPivot). Espelha o
-- que o motor de teleporte usa como destino, para a vigia de chegada medir a
-- MESMA coisa que o voo persegue.
function Feature:InstancePosition(instance)
    if not instance then return nil end
    if instance:IsA("BasePart") then return instance.Position end
    if instance:IsA("Model") then
        local pivot = instance:GetPivot()
        return pivot and pivot.Position or nil
    end
    return nil
end

-- Vigia o voo ate o personagem ficar a <= ARRIVAL_DISTANCE do destino. No
-- primeiro frame que "chegou", para a vigia e chama o hook de chegada com o
-- rotulo da ilha. Nao dispara cedo (so e armada depois do Go), nem re-dispara
-- (a conexao e desligada assim que chegou).
function Feature:_WatchArrival(label, targetPosition)
    self:_StopWatching()
    if not targetPosition then return end
    if not (RunService and type(RunService.Heartbeat) == "table"
        and type(RunService.Heartbeat.Connect) == "function") then
        return
    end
    self._arrivalLabel = label
    self._arrivalTarget = targetPosition
    self._arrivalConnection = RunService.Heartbeat:Connect(function()
        local position = self:RootPosition()
        if not position then return end
        local distance = (position - self._arrivalTarget).Magnitude
        if distance <= ARRIVAL_DISTANCE then
            local arrived = self._arrivalLabel
            self:_StopWatching()
            self.LastStatus = ("arrived at %s"):format(tostring(arrived))
            -- A feature tem UM toggle (o da aba Travel). "Desligar so a ilha
            -- deste voo" = desligar esse toggle -- nao ha outro para tocar.
            if type(self.OnArrive) == "function" then
                pcall(self.OnArrive, self, arrived)
            end
        end
    end)
end

function Feature:_StopWatching()
    if self._arrivalConnection then
        pcall(function() self._arrivalConnection:Disconnect() end)
        self._arrivalConnection = nil
    end
    self._arrivalLabel = nil
    self._arrivalTarget = nil
end

function Feature.new(options)
    options = options or {}
    local self = setmetatable({}, Feature)
    self.Enabled = false
    -- A ilha escolhida no dropdown, pelo rotulo ("Snow Mountain"). Comeca na
    -- primeira da lista para o dropdown ter um valor inicial valido.
    self.Selected = options.selected or SEA2_ISLANDS[1].label
    -- So teleporta com o toggle ligado. Trocar a ilha com o toggle ligado voa de
    -- novo; desligado, so guarda.
    self.ToggleOn = false
    -- O motor de teleporte geral (infra). Sem ele o toggle recusa.
    self.Teleport = options.teleport or nil
    self.LastStatus = "idle"
    self.LastError = nil
    -- Hook de chegada: o backend liga isto ao toggle para que o toggle se
    -- desligue sozinho quando o personagem chega na ilha.
    self.OnArrive = options.onArrive or nil
    -- Estado da vigia de chegada (conexao Heartbeat + alvo do voo corrente).
    self._arrivalConnection = nil
    self._arrivalLabel = nil
    self._arrivalTarget = nil
    return self
end

function Feature:SetTeleport(motor)
    self.Teleport = motor
    return self.Teleport ~= nil
end

-- O rotulo -> o nome da instancia. Devolve nil se o rotulo nao for de ilha
-- conhecida.
function Feature:InstanceNameFor(label)
    local wanted = tostring(label or ""):lower()
    for _, entry in ipairs(SEA2_ISLANDS) do
        if entry.label:lower() == wanted then return entry.instance end
    end
    return nil
end

-- O voo de verdade. So acontece com o toggle ligado; e chamado pelo go() e
-- toda vez que a selecao muda com o toggle ja ligado.
function Feature:Go()
    local motor = self.Teleport
    if not motor then
        self.LastStatus = "no teleport motor"
        self.LastError = "sem motor de teleporte"
        return false
    end
    local instanceName = self:InstanceNameFor(self.Selected)
    if not instanceName then
        self.LastStatus = ("unknown island: %s"):format(tostring(self.Selected))
        return false
    end
    local island = self:IslandInstance(instanceName)
    if not island then
        -- A ilha nao esta no mapa agora (mar errado, ilha removida). Avisa em
        -- vez de voar pro vazio -- o objetivo e o jogador entender o porque.
        self.LastStatus = ("not in map: workspace.Map.%s"):format(instanceName)
        return false
    end
    local ok = pcall(function() motor:GoToInstance(island) end)
    if not ok then
        self.LastStatus = "teleport failed"
        self.LastError = "falha no voo"
        return false
    end
    self.LastStatus = ("flying to %s"):format(self.Selected)
    -- So agora (depois do Go deu certo) a vigia de chegada e armada: assim ela
    -- nunca dispara antes do voo comecar. O alvo e a posicao da MESMA instancia
    -- que o motor vai perseguir.
    self:_WatchArrival(self.Selected, self:InstancePosition(island))
    return true
end

-- O usuario escolheu uma ilha. So teleporta se o toggle estiver ligado (o gate
-- que o usuario pediu); se estiver desligado, so memoriza a escolha.
function Feature:Select(label)
    local instanceName = self:InstanceNameFor(label)
    if not instanceName then return false end
    self.Selected = label
    if self.ToggleOn then return self:Go() end
    return true
end

-- O toggle. Ligar voa pra ilha ja selecionada; desligar so para de agir (nao
-- cancela um voo em andamento -- o voo e pontual e termina sozinho; cancelar no
-- meio deixaria o personagem no ar no caminho).
--
-- Devolve true se ARMOU (tem motor). Se a ilha escolhida nao estiver no mapa
-- agora, continua armado e reporta em LastStatus -- assim o usuario pode so
-- trocar a ilha no dropdown sem religar o toggle.
function Feature:SetEnabled(on)
    self.ToggleOn = on == true
    if not self.ToggleOn then
        self.LastStatus = "idle"
        -- Desligar na mao cancela a vigia: sem voo rastreado, nao ha chegada
        -- para detectar.
        self:_StopWatching()
        return true
    end
    if not self.Teleport then
        self.LastError = "sem motor de teleporte"
        self.ToggleOn = false
        return false
    end
    self:Go()
    return true
end

-- --- Ciclo de vida --------------------------------------------------------

function Feature:Enable()
    if self.Enabled then return true end
    self.Enabled = true
    return true
end

function Feature:Disable()
    self.Enabled = false
    self.ToggleOn = false
    self.LastStatus = "idle"
    self:_StopWatching()
    return true
end

function Feature:IsEnabled()
    return self.Enabled == true
end

function Feature:Destroy()
    self:Disable()
    self.Teleport = nil
    self.OnArrive = nil
end

return Feature
