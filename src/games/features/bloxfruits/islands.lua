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
-- O destino e uma POSICAO fixa (Vector3) na lista: o personagem voa ate o ponto
-- que o script OpenSource usa, que o usuario confirmou estar certo no mapa. Todos
-- os destinos do dropdown sao por posicao -- nao ha mais lookup de instancia
-- (workspace.Map.<Nome>): o usuario preferiu os pontos do OpenSource a instancia,
-- que nem sempre existe com o nome esperado. (O caminho por INSTANCIA continua
-- suportado no Go() caso alguma entrada futura use `instance`, mas nenhuma usa
-- hoje.)
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
-- Cada entrada tem um `label` (o rotulo que aparece) e a POSICAO fixa
-- (`pos = Vector3.new(x,y,z)`) do lugar no mundo. A rotacao do CFrame NAO e
-- usada: o motor so voa ate a posicao. (O Go() ainda aceita `instance =
-- "NomeNoMapa"` para um destino que seja a instancia real em workspace.Map.<Nome>,
-- mas a lista atual e toda por posicao.)
-- A tabela e explicita porque o rotulo bonito nao bate com nome de mapa nenhum.
--
-- Os mapas vem PRONTOS: as posicoes (Vector3) sao as do script OpenSource
-- Blox Fruits, que o usuario confirmou em jogo (as dele estavam erradas e as do
-- OpenSource voam no ponto certo). Sao TUDO por POSICAO -- o usuario preferiu os
-- pontos do OpenSource a instancia do mapa: os devs do jogo nao mudam essas
-- coordenadas, e a instancia nem sempre existe com o nome que a gente adivinha.
-- Por isso nao ha mais `instance` aqui.
--
-- Uma lista POR MAR: cada mar tem o seu mapa, entao o dropdown mostra SO as
-- ilhas do mar corrente (o backend descobre o mar e chama SetSea). Sem bosses --
-- o usuario pediu so as ilhas.
local SEA_ISLANDS = {
    Sea1 = {
        { label = "Middle Town",        pos = Vector3.new(-1193.9, 12, -549.8) },
        { label = "Pirate Starter",     pos = Vector3.new(1038, 15, 1550) },
        { label = "Marine Starter",     pos = Vector3.new(-2674.5, 32.1, 2187.0) },
        { label = "Jungle",             pos = Vector3.new(-1866.3, 29.9, 21.6) },
        { label = "Buggy Island",       pos = Vector3.new(-981.0, 30.4, 3966.8) },
        { label = "Desert Island",      pos = Vector3.new(999.9, 7.6, 4490.3) },
        { label = "Snow Island",        pos = Vector3.new(1519.5, 78.0, -1510.9) },
        { label = "Marineford",         pos = Vector3.new(-4763.7, 13.4, 4288.8) },
        { label = "Sky Islands",        pos = Vector3.new(-4973.7, 280.7, -1119.4) },
        { label = "Mob Island (Saber)", pos = Vector3.new(-1527.2, 34.1, -33.2) },
        { label = "Impel Down",         pos = Vector3.new(5278.6, 7.1, 391.6) },
        { label = "Colosseum",          pos = Vector3.new(-1973.1, 9.0, -2744.9) },
        { label = "Volcano",            pos = Vector3.new(-5623.8, 17.0, 8314.1) },
        { label = "Fishman Island",     pos = Vector3.new(3894.3, 4.0, -1915.2) },
        { label = "Upper Sky Islands",  pos = Vector3.new(-6040.2, 5468.0, 1734.2) },
        { label = "Water 7",            pos = Vector3.new(5430.4, 78.0, 3953.6) },
    },
    Sea2 = {
        { label = "Kingdom of Rose",  pos = Vector3.new(-195.1, 155.3, 279.9) },
        { label = "Cafe",             pos = Vector3.new(-380.4, 72.8, 303.2) },
        { label = "Mansion",          pos = Vector3.new(-393.3, 367.3, 687.5) },
        { label = "Colosseum",        pos = Vector3.new(-1836.4, 72.8, 1360.2) },
        { label = "Swan's Room",      pos = Vector3.new(2293.7, 12.5, 663.1) },
        { label = "Factory",          pos = Vector3.new(431.0, 238.4, -433.2) },
        { label = "Green Zone",       pos = Vector3.new(-2340.8, 155.3, -3396.3) },
        { label = "Dark Arena",       pos = Vector3.new(3807.1, 11.8, -3452.2) },
        { label = "Graveyard Island", pos = Vector3.new(-5577.9, 87.6, -782.2) },
        { label = "Snow Mountain",    pos = Vector3.new(856.2, 50.3, -5278.3) },
        { label = "Hot and Cold",     pos = Vector3.new(-5734.3, 49.4, -5146.4) },
        { label = "Cursed Ship",      pos = Vector3.new(900.9, 144.0, 33072.6) },
        { label = "Ice Castle",       pos = Vector3.new(6062.3, 155.3, -6880.9) },
        { label = "Forgotten Island", pos = Vector3.new(-3194.2, 155.3, -10795.3) },
    },
    Sea3 = {
        { label = "Port Town",              pos = Vector3.new(-610.4, 57.8, 6436.3) },
        { label = "Dragon Dojo",            pos = Vector3.new(5704.4, 1168.1, 937.0) },
        { label = "Castle on the Sea",      pos = Vector3.new(-5436.6, 815.6, -2701.7) },
        { label = "Floating Turtle",        pos = Vector3.new(-12164.6, -548.9, -8454.9) },
        { label = "Friendly Arena",         pos = Vector3.new(5012.8, 72.8, -1570.6) },
        { label = "Great Tree",             pos = Vector3.new(3036.3, 815.6, -7149.9) },
        { label = "Haunted Castle",         pos = Vector3.new(-9530.6, -132.9, 5763.1) },
        { label = "Beautiful Pirate Domain",pos = Vector3.new(5366.6, 71.2, -225.9) },
        { label = "Mansion",                pos = Vector3.new(-12547.7, 290.1, -7487.1) },
        { label = "North Pole",             pos = Vector3.new(-1141.1, 57.8, -14480.7) },
        { label = "Sea of Treats",          pos = Vector3.new(-1505.3, 57.8, -10724.1) },
        { label = "Secret Temple",          pos = Vector3.new(5226.2, 63.5, 858.8) },
        { label = "Tiki Outpost",           pos = Vector3.new(-16641.5, 213.3, 435.4) },
        { label = "Heavenly Dimension",     pos = Vector3.new(-22709.6, 5259.0, 3886.6) },
        { label = "Hell Dimension",         pos = Vector3.new(-22737.6, 5120.0, 2234.6) },
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

-- A posicao do HumanoidRootPart agora, ou nil se nao ha character.
function Feature:RootPosition()
    local character = LocalPlayer and LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return root and root.Position or nil
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
-- Destino por POSICAO: manda o motor direto pra posicao da entrada (GoTo) e a
-- vigia de chegada mede a mesma coisa que o motor persegue. A lista atual e toda
-- por posicao (ver SEA_ISLANDS), entao este e o unico caminho.
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

    -- Captura o SEGUNDO retorno do pcall: o pcall so diz que nao lancou; o motor
    -- pode devolver nil (sem character/HRP) sem erro nenhum. Sem olhar esse
    -- retorno, a feature armava a vigia e dizia "flying" sem voo.
    local ok, started = pcall(function() return motor:GoTo(entry.pos) end)
    if not ok then
        self.LastStatus = "teleport failed"
        self.LastError = "falha no voo"
        return false
    end
    if started == nil then
        self.LastStatus = "character not ready"
        self.LastError = "sem personagem"
        return false
    end
    self.LastStatus = ("flying to %s"):format(self.Selected)
    self:_WatchArrival(self.Selected, entry.pos)
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
    -- Propaga o RESULTADO REAL do voo. Antes retornava true sempre, entao o
    -- toggle ficava marcado como ligado mesmo quando nao havia personagem --
    -- agora, se o voo nao comecou (sem character), SetEnabled devolve false e o
    -- backend avisa o motivo (LastStatus/LastError) em vez de fingir sucesso.
    -- A ilha fora do mapa mantem o toggle armado: o usuario so troca no dropdown.
    local started = self:Go()
    if not started and self.LastStatus == "character not ready" then
        self.ToggleOn = false
        return false
    end
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
