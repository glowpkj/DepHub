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
-- O destino e, por padrao, a INSTANCIA real no mapa (workspace.Map.<Nome>), nao
-- uma coordenada chumbada: isso nao quebra quando o mapa muda e usa exatamente os
-- nomes que o usuario confirmou. Se a instancia nao existir (mar errado, ilha
-- fora do mapa), ele AVISA em vez de voar pro vazio. Alguns destinos que nao sao
-- instancia do mapa (ex.: Cafe no Sea 2, Castle on Sea no Sea 3) usam uma POSICAO
-- fixa (Vector3) na mesma lista -- o resto do fluxo (gate do toggle, vigia de
-- chegada, auto-desligar) e igual.
--
-- A lista de destinos e POR MAR (SEA_ISLANDS): Sea 1, Sea 2 e Sea 3 tem mapas e
-- pontos fixos diferentes, entao o dropdown mostra so as ilhas do mar atual. O
-- backend descobre o mar (ReplicatedStorage.Util.Realm) e chama SetSea; trocar o
-- mar troca a lista.
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

-- Os destinos do dropdown de teleporte, POR MAR. Cada mar tem suas proprias
-- ilhas e pontos fixos -- o mapa de Sea 1, Sea 2 e Sea 3 sao completamente
-- diferentes, entao nao faz sentido oferecer ilha de Sea 3 estando no Sea 1 (o
-- usuario deixou isso claro). O backend descobre o mar atual e o dropdown e
-- montado so a partir da lista daquele mar.
--
-- Cada entrada tem um `label` (o rotulo que aparece) e UM tipo de destino:
--   * `instance = "NomeNoMapa"` -- a INSTANCIA real em workspace.Map.<Nome>. Usado
--     pelas ilhas: nao quebra quando o mapa muda de posicao e usa os nomes que o
--     usuario confirmou.
--   * `pos = Vector3.new(x,y,z)` -- uma POSICAO fixa no mundo. Usado por lugares
--     que NAO sao uma instancia do mapa (ex.: Cafe, Castle on Sea -- um ponto
--     dentro de uma cidade). A posicao e o ponto real do lugar (a rotacao do
--     CFrame NAO e usada: o motor so voa ate a posicao).
-- A tabela e explicita em vez de deduzida porque alguns rotulos bonitos nao
-- batem com o nome do mapa (ex.: Ghost Ship -> GhostShip).
--
-- Os mapas vao sendo preenchidos conforme o usuario confirma os nomes/posicoes
-- de cada mar; um mar sem lista fica vazio (o dropdown avisa em vez de oferecer
-- destinos errados).
local SEA_ISLANDS = {
    Sea1 = {
        -- A confirmar pelo usuario (nome das ilhas + pontos fixos do Sea 1).
    },
    Sea2 = {
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
        -- Destinos por POSICAO fixa (nao sao instancias do mapa). A posicao e o
        -- ponto real do lugar (o motor so voa ate a posicao; rotacao nao e aplicada).
        { label = "Cafe",                pos = Vector3.new(-379.38089, 73.6452713, 303.899628) },
    },
    Sea3 = {
        -- Castle on Sea e um ponto fixo do Sea 3 (posicao confirmada pelo usuario).
        { label = "Castle on Sea",       pos = Vector3.new(-5436.60986, 500, -3000) },
    },
}

-- O mar padrao quando o jogo ainda nao disse em qual estamos. Sea 2 e o padrao
-- historico (era o unico mar com lista ate agora).
local DEFAULT_SEA = "Sea2"

-- Normaliza o que o jogo devolve (ReplicatedStorage.Util.Realm vai de 1 a 3) para
-- a chave da lista ("Sea1"/"Sea2"/"Sea3"). Aceita 1, "1", "Sea1", "sea 1", etc.
local function normalizeSea(value)
    if value == nil then return nil end
    local n = tonumber(value)
    if not n then
        n = tonumber(tostring(value):match("(%d+)"))
    end
    if n and n >= 1 and n <= 3 then return "Sea" .. n end
    return nil
end

Feature.SeaIslands = SEA_ISLANDS
Feature.DEFAULT_SEA = DEFAULT_SEA

-- A lista publica de rotulos do MAR ATIVO, na ordem. O backend monta o dropdown
-- daqui; trocar o mar (SetSea) troca esta lista.
function Feature:IslandLabels(sea)
    local list = SEA_ISLANDS[normalizeSea(sea) or self.CurrentSea or DEFAULT_SEA] or {}
    local labels = {}
    for _, entry in ipairs(list) do
        labels[#labels + 1] = entry.label
    end
    return labels
end

-- A lista ativa (o array de entradas) do mar corrente.
function Feature:_ActiveList()
    return SEA_ISLANDS[self.CurrentSea or DEFAULT_SEA] or {}
end

-- O mar que a lista esta mostrando agora.
Feature.CurrentSea = DEFAULT_SEA

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
    if not RunService then return end
    -- Heartbeat e um RBXScriptSignal, NAO uma tabela Lua. Checar
    -- type(RunService.Heartbeat) == "table" era falso no Roblox (o typeof e
    -- "RBXScriptSignal") e por isso a vigia nunca conectava -- a chegada nunca
    -- era detectada e o toggle nunca se desligava sozinho. A tentativa de
    -- conectar e a propria validacao: pcall + o evento conectado.
    local ok, connection = pcall(function()
        return RunService.Heartbeat:Connect(function()
            local position = self:RootPosition()
            if not position then return end
            local distance = (position - self._arrivalTarget).Magnitude
            if distance <= ARRIVAL_DISTANCE then
                local arrived = self._arrivalLabel
                self:_StopWatching()
                self.LastStatus = ("arrived at %s"):format(tostring(arrived))
                -- A feature tem UM toggle (o da aba Travel). "Desligar so a
                -- ilha deste voo" = desligar esse toggle -- nao ha outro para
                -- tocar.
                if type(self.OnArrive) == "function" then
                    pcall(self.OnArrive, self, arrived)
                end
            end
        end)
    end)
    if not ok or not connection then return end
    self._arrivalLabel = label
    self._arrivalTarget = targetPosition
    self._arrivalConnection = connection
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
    -- O mar corrente: define qual lista o dropdown mostra. O backend chama
    -- SetSea com o mar que o jogo reportou (ReplicatedStorage.Util.Realm); sem
    -- isso, fica no padrao.
    self.CurrentSea = normalizeSea(options.sea) or DEFAULT_SEA
    -- A entrada escolhida no dropdown, pelo rotulo. Comeca na primeira da lista
    -- ATIVA para o dropdown ter um valor inicial valido (ou nil se o mar nao tem
    -- lista ainda).
    local first = self:_ActiveList()[1]
    self.Selected = options.selected or (first and first.label) or nil
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

-- Troca o mar mostrado. Se a selecao corrente nao existir no mar novo, cai na
-- primeira entrada do mar (ou nil se o mar ainda nao tem lista). Nao teleporta
-- sozinho: quem decide voar e o toggle/chamada de Select. Devolve os rotulos do
-- mar novo, para o backend reconstruir o dropdown.
function Feature:SetSea(sea)
    local normalized = normalizeSea(sea)
    if not normalized then return self:IslandLabels() end
    if normalized == self.CurrentSea then return self:IslandLabels() end
    self.CurrentSea = normalized
    if not self:EntryFor(self.Selected) then
        local first = self:_ActiveList()[1]
        self.Selected = first and first.label or nil
    end
    return self:IslandLabels()
end

function Feature:SetTeleport(motor)
    self.Teleport = motor
    return self.Teleport ~= nil
end

-- O rotulo -> a entrada da lista DO MAR ATIVO (com `instance` ou `pos`). Devolve
-- nil se o rotulo nao for de um destino conhecido deste mar.
function Feature:EntryFor(label)
    if not label then return nil end
    local wanted = tostring(label):lower()
    for _, entry in ipairs(self:_ActiveList()) do
        if entry.label:lower() == wanted then return entry end
    end
    return nil
end

-- O voo de verdade. So acontece com o toggle ligado; e chamado pelo go() e
-- toda vez que a selecao muda com o toggle ja ligado.
--
-- Destino por INSTANCIA: acha em workspace.Map e manda o motor perseguir a
-- instancia (GoToInstance), com o alvo da vigia sendo a posicao dela. Destino
-- por POSICAO: manda o motor direto pra posicao (GoTo) e a vigia usa a mesma.
-- Nos dois casos a vigia mede a MESMA coisa que o motor persegue.
function Feature:Go()
    local motor = self.Teleport
    if not motor then
        self.LastStatus = "no teleport motor"
        self.LastError = "sem motor de teleporte"
        return false
    end
    local entry = self:EntryFor(self.Selected)
    if not entry then
        self.LastStatus = ("unknown island: %s"):format(tostring(self.Selected))
        return false
    end

    -- Destino por posicao fixa (ex.: Cafe): vai direto pro ponto.
    if entry.pos then
        local ok = pcall(function() motor:GoTo(entry.pos) end)
        if not ok then
            self.LastStatus = "teleport failed"
            self.LastError = "falha no voo"
            return false
        end
        self.LastStatus = ("flying to %s"):format(self.Selected)
        self:_WatchArrival(self.Selected, entry.pos)
        return true
    end

    -- Destino por instancia no mapa (as ilhas).
    local island = self:IslandInstance(entry.instance)
    if not island then
        -- A instancia nao esta no mapa agora (mar errado, ilha removida). Avisa
        -- em vez de voar pro vazio -- o objetivo e o jogador entender o porque.
        self.LastStatus = ("not in map: workspace.Map.%s"):format(tostring(entry.instance))
        return false
    end
    local ok = pcall(function() motor:GoToInstance(island) end)
    if not ok then
        self.LastStatus = "teleport failed"
        self.LastError = "falha no voo"
        return false
    end
    self.LastStatus = ("flying to %s"):format(self.Selected)
    self:_WatchArrival(self.Selected, self:InstancePosition(island))
    return true
end

-- O usuario escolheu uma ilha. So teleporta se o toggle estiver ligado (o gate
-- que o usuario pediu); se estiver desligado, so memoriza a escolha.
function Feature:Select(label)
    if not self:EntryFor(label) then return false end
    self.Selected = label
    if self.ToggleOn then return self:Go() end
    return true
end

-- O toggle. Ligar voa pra ilha ja selecionada; desligar PARA de teleportar de
-- verdade -- cancela o voo em andamento (o motor para o tween) e desliga a
-- vigia de chegada. Era o pedido do usuario: desligar o toggle (ou qualquer
-- coisa ligada a ele) tem que estancar o teleporte na hora, nao so "parar de
-- comecar voos novos" e deixar o personagem seguindo ate o fim.
--
-- Devolve true se ARMOU (tem motor). Se a ilha escolhida nao estiver no mapa
-- agora, continua armado e reporta em LastStatus -- assim o usuario pode so
-- trocar a ilha no dropdown sem religar o toggle.
function Feature:SetEnabled(on)
    self.ToggleOn = on == true
    if not self.ToggleOn then
        self.LastStatus = "idle"
        -- Para o voo corrente: cancela o tween do motor (o personagem parou de
        -- ser arrastado) e desarma a vigia de chegada. Sem isto o voo continuava
        -- ate o fim mesmo com o toggle desligado.
        if self.Teleport and type(self.Teleport.Cancel) == "function" then
            pcall(self.Teleport.Cancel, self.Teleport)
        end
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
    -- Passa pelo SetEnabled(false) para reaproveitar o cancelamento do voo (o
    -- mesmo caminho do toggle) -- desligar a feature tambem tem que parar o
    -- teleporte, nao so a vigia.
    self:SetEnabled(false)
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
