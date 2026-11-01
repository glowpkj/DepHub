local game = game
local task = task
local type = type
local pcall = pcall
local tostring = tostring

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Raid -- o auto raid do Blox Fruits.
--
-- Portado do parked/events.lua (M.setAutoRaid), mas no molde proprio. Ele faz o
-- ciclo inteiro: garante o Microchip (compra no NPC se nao tiver), voa ate o
-- tubo da raid, aperta o botao de start, e quando a raid comeca, limpa as waves.
--
-- Duas coisas aqui NAO sao reimplementadas -- vem por injecao, como manda a
-- convencao (um motor so de cada coisa no script):
--   * o TELEPORTE (options.teleport -> features/bloxfruits/teleport.lua). Sem
--     ele o raid recusa: nao ha como ir ao tubo.
--   * o ATAQUE (options.combat -> features/bloxfruits/bladhits.lua). Sem ele a
--     raid ainda entra, mas nao limpa wave -- porque atacar com um segundo
--     caminho seria um segundo motor de ataque no script, que e exatamente o
--     que a convencao proibe.
--
-- Self-contained: faz os proprios game:GetService e nao depende do DepHub. So
-- pede o teleporte e o ataque, e mesmo assim de forma opcional.

local Feature = {}
Feature.__index = Feature

-- O tubo da raid em cada mar. Veio inteiro do original.
local RAID_LOC = {
    Sea2 = { tube = Vector3.new(-6546.1, 310.5, -4767.7), button = Vector3.new(-6530.7, 304.8, -4798.4) },
    Sea3 = { tube = Vector3.new(-5010.1, 315.0, -2816.5), button = Vector3.new(-5010.1, 315.0, -2816.5) },
}

-- Qual mar o jogador esta. O jogo expoe isso em ReplicatedStorage.Util.Realm
-- (getCurrentSeaAsync) -- e o MESMO caminho que o script antigo usava pra
-- escolher o tubo. Sem a informacao, cai em Sea 2 (o padrao do original).
local function currentSea()
    local util = ReplicatedStorage:FindFirstChild("Util")
    local realm = util and util:FindFirstChild("Realm")
    if not realm then return nil end
    local ok, sea = pcall(function() return require(realm).getCurrentSeaAsync() end)
    return ok and sea or nil
end

-- Os elementos que o NPC de raid vende (o Microchip e por fruta). A lista veio
-- do original; quem compra escolhe o elemento no dropdown.
Feature.elements = {
    "Flame", "Ice", "Quake", "Dark", "Light", "Sand", "Magma", "Rumble", "Buddha", "Paw",
    "Gravity", "Dough", "Shadow", "Venom", "Control", "Spirit", "Bomb", "Spike", "Blizzard", "Phoenix",
}

local function commF()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    return remotes and remotes:FindFirstChild("CommF_")
end

local function raidsRemote()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    return remotes and remotes:FindFirstChild("Raids")
end

local function isChip(tool)
    if not (tool and tool:IsA("Tool")) then return false end
    if tostring(tool.Name):find("Microchip") then return true end
    local original = tool:GetAttribute("OriginalName")
    return original ~= nil and tostring(original):find("Microchip") ~= nil
end

function Feature.new(options)
    options = options or {}
    local self = setmetatable({}, Feature)
    self.Enabled = false
    self.InRaid = false
    self.AutoComplete = false
    self.AttackEnabled = false
    self.Threads = {}
    self.ChipBought = false
    self.Thread = nil
    self.RaidEvent = nil
    self.RaidConnection = nil
    self.LastStatus = "idle"
    self.LastError = nil
    -- Injetados pelo backend. Sem teleporte o Enable recusa; sem blade hit a
    -- raid entra mas nao limpa wave (o ataque nao e reimplementado aqui).
    self.Teleport = options.teleport or nil
    self.Combat = options.combat or nil
    -- O mar decide o tubo. O backend passa o que sabe do jogo; sem isso fica
    -- Sea 2, que foi o padrao do original.
    self.Sea = options.sea or nil
    self.Element = options.element or "Flame"
    -- O chip e por elemento: trocar o elemento obriga a comprar um novo.
    self.ChipElement = nil
    -- Os unicos knobs que mudam o comportamento do laco (vem do original).
    self.StartWait = options.startWait or 2.5   -- espera depois de apertar o botao
    self.ChipWait = options.chipWait or 1.5     -- espera quando o chip nao equipou
    self.ButtonRadius = options.buttonRadius or 60  -- raio de prompts no botao
    return self
end

-- --- Conexoes com o jogo ------------------------------------------------

function Feature:_hrp()
    local character = LocalPlayer and LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

-- Tarefa nomeada (o auto complete roda em thread propria, separada do loop do
-- auto raid, porque sao dois toggles independentes).
function Feature:_spawn(name, body)
    self.Threads[name] = task.spawn(body)
end

function Feature:_cancel(name)
    local thread = self.Threads[name]
    if thread then pcall(task.cancel, thread); self.Threads[name] = nil end
end

-- O evento que o servidor usa pra dizer que a raid comecou/terminou. E ele que
-- sabe se estamos dentro: o cliente nao tem como adivinhar, entao escutamos.
function Feature:ConnectRaidEvent()
    if self.RaidEvent then return true end
    local remote = raidsRemote()
    if not remote then return false end
    self.RaidEvent = remote
    self.RaidConnection = remote.OnClientEvent:Connect(function(kind)
        if kind == "StartTimer" then
            self.InRaid = true
        elseif kind == "Finished" then
            self.InRaid = false
        end
    end)
    return true
end

function Feature:DisconnectRaidEvent()
    if self.RaidConnection then
        pcall(function() self.RaidConnection:Disconnect() end)
        self.RaidConnection = nil
    end
    self.RaidEvent = nil
end

-- --- Microchip ------------------------------------------------------------

-- O chip na mao (equipado) ou na mochila. So Tool com "Microchip" no nome.
function Feature:ChipTool()
    local pools = { LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack") }
    for _, pool in ipairs(pools) do
        if pool then
            for _, child in ipairs(pool:GetChildren()) do
                if isChip(child) then return child end
            end
        end
    end
end

function Feature:ChipEquipped()
    local character = LocalPlayer.Character
    if not character then return false end
    for _, child in ipairs(character:GetChildren()) do
        if isChip(child) then return true end
    end
    return false
end

-- Equipa o chip. O original tentava algumas vezes porque o equip falha na
-- primeira (a tool ainda esta trocando de lugar) e as vezes so o reparent basta.
function Feature:EquipChip()
    if self:ChipEquipped() then return true end
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local chip = self:ChipTool()
    if not (humanoid and chip) then return false end
    for _ = 1, 4 do
        pcall(function() humanoid:EquipTool(chip) end)
        if not self:ChipEquipped() then pcall(function() chip.Parent = character end) end
        task.wait(0.15)
        if self:ChipEquipped() then return true end
    end
    return self:ChipEquipped()
end

-- Pergunta ao NPC de raid qual e o chip do elemento escolhido. Sem escolha
-- valida (elemento ja equipado, sem dinheiro) o servidor devolve nao-ok.
function Feature:BuyChip()
    local comm = commF()
    if not comm then return false end
    local ok, result = pcall(function() return comm:InvokeServer("RaidsNpc", "Select", self.Element) end)
    if ok and result then
        self.ChipBought = true
        self.ChipElement = self.Element
    end
    return ok and result ~= nil
end

function Feature:CheckRaid()
    local comm = commF()
    if not comm then return false end
    local ok, result = pcall(function() return comm:InvokeServer("RaidsNpc", "Check") end)
    return ok and result or false
end

-- --- Botao de start -------------------------------------------------------

-- Dispara todo ProximityPrompt/ClickDetector num raio da posicao. E assim que a
-- raid comeca: o botao do tubo e um prompt, nao um remote.
function Feature:TriggerNear(position, radius)
    radius = radius or self.ButtonRadius
    local fired = 0
    local fireprompt = fireproximityprompt
    local fireclick = fireclickdetector
    for _, descendant in ipairs(workspace:GetDescendants()) do
        local part
        if descendant:IsA("ProximityPrompt") then
            part = descendant.Parent
            if part and part:IsA("BasePart") and (part.Position - position).Magnitude <= radius then
                if type(fireprompt) == "function" then pcall(fireprompt, descendant) end
                fired = fired + 1
            end
        elseif descendant:IsA("ClickDetector") then
            part = descendant.Parent
            if part and part:IsA("BasePart") and (part.Position - position).Magnitude <= radius then
                if type(fireclick) == "function" then pcall(fireclick, descendant) end
                fired = fired + 1
            end
        end
    end
    return fired
end

-- --- Destino --------------------------------------------------------------

-- O tubo do mar atual. Prefere o que o jogo diz (Realm); sem isso, cai no que o
-- backend passou ou no Sea 2 (o padrao do original). Resolvido a cada uso
-- porque o jogador pode trocar de mar sem recarregar o script.
function Feature:Location()
    if self.Sea and RAID_LOC[self.Sea] then return RAID_LOC[self.Sea] end
    local sea = currentSea()
    if sea and RAID_LOC[sea] then self.Sea = sea; return RAID_LOC[sea] end
    return RAID_LOC.Sea2
end

function Feature:SetSea(sea)
    if sea == nil then return false end
    self.Sea = tostring(sea)
    return true
end

-- Voa ate o tubo e aperta o botao. Uma passada: chega, equipa de novo (o voo
-- pode ter guardado o chip) e dispara os prompts do botao.
function Feature:StartRaid()
    local motor = self.Teleport
    if not motor then
        self.LastError = "sem motor de teleporte"
        return false
    end
    local location = self:Location()
    pcall(function() motor:GoTo(location.tube) end)
    task.wait(1.6)
    self:EquipChip()
    local fired = self:TriggerNear(location.button)
    self.LastStatus = ("pressing button... chip=%s fired=%d"):format(tostring(self:ChipEquipped()), fired)
    return true
end

-- --- Limpeza das waves ----------------------------------------------------

-- Ataca com a blade hit injetada. Um passo por chamada: liga o ataque uma vez e
-- deixa o loop dela bater. Se a blade hit nao foi injetada, nao ha o que fazer
-- -- e o raid reporta isso em vez de atacar por conta propria.
function Feature:ClearStep()
    local combat = self.Combat
    if not combat then
        self.LastStatus = "no attack motor injected"
        return false
    end
    if not combat:IsEnabled() then
        if not combat:Enable() then
            self.LastStatus = "attack refused (remotes?)"
            return false
        end
    end
    self.LastStatus = "clearing waves"
    return true
end

-- --- Auto complete raid ---------------------------------------------------
-- O SEGUNDO toggle. Nao compra, nao cria, nao aperta botao: so TERMINA uma raid
-- que ja esta rolando. Acha as ilhas em workspace.Map.RaidMap, vai na mais perto
-- dele agora, mata os bixos e recalcula -- proxima mais perto, e assim por
-- diante. Nao filtra por dono: o filtro e distancia pura. (Se a raid de outro
-- jogador aparecer no SEU RaidMap, ela entra como qualquer outra -- se isso
-- virar problema, o filtro entra depois.)

local RAID_MAP_PATH = { "Map", "RaidMap" }

-- A pasta das ilhas da raid, se a raid estiver rolando. workspace.Map.RaidMap.
function Feature:RaidMap()
    local map = workspace:FindFirstChild("Map")
    if not map then return nil end
    return map:FindFirstChild("RaidMap")
end

-- As ilhas da raid: os Models dentro do RaidMap. A ilha onde o jogador esta
-- tambem conta (ele escolhe a mais perto, sem excluir a atual).
function Feature:RaidIslands()
    local raidMap = self:RaidMap()
    if not raidMap then return {} end
    local islands = {}
    for _, child in ipairs(raidMap:GetChildren()) do
        if child:IsA("Model") or child:IsA("BasePart") then
            islands[#islands + 1] = child
        end
    end
    return islands
end

-- Posicao de uma ilha. Model usa o pivot (funciona mesmo sem PrimaryPart);
-- BasePart usa .Position direto.
local function islandPosition(island)
    if island:IsA("BasePart") then return island.Position end
    local ok, pivot = pcall(function() return island:GetPivot().Position end)
    if ok and pivot then return pivot end
    return island.PrimaryPart and island.PrimaryPart.Position or nil
end

-- A ilha mais perto do jogador AGORA. E o coracao do "inteligente": ele nao
-- guarda ordem, recalcula cada passo a partir de onde o personagem esta --
-- terminou uma, a proxima passa a ser a mais perto.
function Feature:NearestIsland()
    local root = self:_hrp()
    if not root then return nil end
    local best, bestDistance
    for _, island in ipairs(self:RaidIslands()) do
        local position = islandPosition(island)
        if position then
            local distance = (position - root.Position).Magnitude
            if not bestDistance or distance < bestDistance then
                best, bestDistance = island, distance
            end
        end
    end
    return best, bestDistance
end

-- Um passo do auto complete: acha a ilha mais perto, voa pra la e garante o
-- ataque ligado. Nao espera o voo terminar aqui -- o loop chama de novo e o
-- NearestIsland recalcula; como o Go cancela o voo anterior, chamar em passo
-- curto so reinicia o mesmo destino, que fica a cada vez mais perto.
function Feature:CompleteStep()
    local motor = self.Teleport
    if not motor then
        self.LastStatus = "no teleport motor"
        return false
    end
    local island, distance = self:NearestIsland()
    if not island then
        self.LastStatus = "no raid map (not in a raid?)"
        return false
    end
    self.AttackEnabled = self.AttackEnabled or false
    local combat = self.Combat
    if combat and not combat:IsEnabled() then
        if combat:Enable() then self.AttackEnabled = true end
    end
    -- So voa se ainda estiver longe: perto da ilha, o voo a cada passo brigaria
    -- com a fisica e travaria o personagem vibrando no lugar.
    local root = self:_hrp()
    if root and distance and distance > 40 then
        pcall(function()
            local position = islandPosition(island)
            if position then motor:Go(position + Vector3.new(0, 8, 0)) end
        end)
    end
    self.LastStatus = ("raid: %s (%dm)"):format(tostring(island.Name), math.floor(distance or 0))
    return true
end

function Feature:SetAutoComplete(on)
    self.AutoComplete = on == true
    if not self.AutoComplete then
        self:_cancel("complete")
        -- Desliga junto o ataque que ESTE toggle ligou (nao mexe se o jogador
        -- ligou a blade hit por fora).
        if self.AttackEnabled and self.Combat then
            pcall(function() self.Combat:Disable() end)
            self.AttackEnabled = false
        end
        return true
    end
    if not self.Teleport then
        self.LastError = "sem motor de teleporte"
        self.AutoComplete = false
        return false
    end
    self:_spawn("complete", function()
        while self.AutoComplete do
            pcall(function() self:CompleteStep() end)
            task.wait(0.5)
        end
    end)
    return true
end

-- --- Ciclo de vida --------------------------------------------------------

function Feature:Enable()
    if self.Enabled then return true end
    if not self.Teleport then
        self.LastError = "sem motor de teleporte"
        return false
    end
    self.Enabled = true
    self.InRaid = false
    self:ConnectRaidEvent()

    local function pause(value, fallback)
        task.wait(math.max(0, tonumber(value) or fallback))
    end

    self.Thread = task.spawn(function()
        while self.Enabled do
            if self.InRaid then
                self:ClearStep()
            else
                -- Fora da raid: garante chip, compra se faltar, e tenta comecar.
                if not self:ChipTool() then
                    if self.ChipBought and self.ChipElement ~= self.Element then self.ChipBought = false end
                    if not self.ChipBought then self:BuyChip() end
                    task.wait(0.8)
                end
                if not self:EquipChip() then
                    self.LastStatus = "no Microchip -- buy/hold one"
                    pause(self.ChipWait, 1.5)
                else
                    self:StartRaid()
                    pause(self.StartWait, 2.5)
                end
            end
            task.wait(0.1)
        end
        self.Thread = nil
    end)
    return true
end

function Feature:Disable()
    self.Enabled = false
    self.InRaid = false
    if self.Thread then pcall(task.cancel, self.Thread); self.Thread = nil end
    -- O ataque foi ligado por nos: desligue so se o raid o ligou. A blade hit e
    -- do usuario tambem -- pode estar ligada por ele.
    self:DisconnectRaidEvent()
    self:SetAutoComplete(false)
    self.LastStatus = "idle"
    return true
end

function Feature:IsEnabled()
    return self.Enabled == true
end

-- --- Knobs de console (sem UI; os valores vem do modulo) ------------------

function Feature:SetElement(name)
    if type(name) ~= "string" or name == "" then return false end
    self.Element = name
    -- Chip e por elemento: o antigo nao serve mais pro novo.
    if self.ChipElement and self.ChipElement ~= self.Element then self.ChipBought = false end
    return true
end

function Feature:SetStartWait(value)
    value = tonumber(value)
    if not value or value < 0 then return false end
    self.StartWait = value
    return true
end

function Feature:SetChipWait(value)
    value = tonumber(value)
    if not value or value < 0 then return false end
    self.ChipWait = value
    return true
end

function Feature:Destroy()
    self:Disable()
    self.Teleport = nil
    self.Combat = nil
end

return Feature
