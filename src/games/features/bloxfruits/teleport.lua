local game = game
local task = task
local type = type
local pcall = pcall
local tostring = tostring
local tonumber = tonumber
local math = math

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- Teleport -- o MOTOR de teleporte do Blox Fruits, sem UI.
--
-- Este modulo e infraestrutura, nao uma feature de painel: ele nao tem toggle
-- proprio. Ele expoe o teleporte perfeito (o fly por CFrame do script antigo)
-- para QUE QUALQUER feature chame -- a de pegar fruta, a de farm, a de boss.
-- A ideia e: um so teleporte, testado, que todo mundo usa.
--
-- O coracao e Go(pos): um TweenService no HumanoidRootPart com a velocidade
-- calculada pela distancia (mapa do Sea 3 e enorme, entao a velocidade tem que
-- escalar). Durante o voo:
--   * a velocidade linear e zerada todo Heartbeat (senao o character "escorrega"
--     e o tween briga com a fisica), e
--   * o character fica noclip (CanCollide = false em toda BasePart).
--   * NUNCA se usa Anchor: o BF rejeita todo hit num character ancorado.
--
-- Self-contained de proposito, igual a blade hit: faz os proprios
-- game:GetService e nao depende do DepHub nem do adapter. Publica
-- new()/Enable()/Disable() + os metodos de teleporte.

local Teleport = {}
Teleport.__index = Teleport

-- Converte o getter de posicao em Vector3. Os dados de ilha/boss usam
-- Vector3.new; os de fruta podem vir como {X=,Y=,Z=} (o .Position de uma Part),
-- entao os dois entram.
local function toVector3(value)
    if typeof(value) == "Vector3" then return value end
    if type(value) == "table" then
        return Vector3.new(tonumber(value.X) or 0, tonumber(value.Y) or 0, tonumber(value.Z) or 0)
    end
    return nil
end

function Teleport.new(options)
    options = options or {}
    local self = setmetatable({}, Teleport)
    self.Enabled = false
    self.Thread = nil
    -- Velocidade em studs/s. 200 aguenta o mapa gigante do Sea 3; mais baixo se
    -- o anti-cheat der loopback/kick. E o unico knob que importa de verdade.
    self.Speed = options.speed or 200
    -- Altura somada ao destino: cair de 5 studs acima evita spawnar dentro do
    -- chao e ficar preso.
    self.ArrivalOffset = options.arrivalOffset or Vector3.new(0, 5, 0)
    self.Tween = nil
    self._heartbeat = nil
    -- Cache do noclip por character: a lista de BaseParts so e reconstruida
    -- quando o character muda (respawn). Ver Enable() para o porque.
    self._noclipParts = nil
    -- CanCollide ORIGINAL por parte (o restore devolve esse valor, nao true).
    self._originalCollide = nil
    self._root = nil
    self._character = nil
    return self
end

function Teleport:HumanoidRootPart()
    local character = LocalPlayer and LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

function Teleport:IsFlying()
    return self.Tween ~= nil
end

-- Devolve a colisao que o voo tirou: recompoe CanCollide nos BaseParts do
-- character em cache. Chamado quando o voo termina (Completed) ou e cancelado,
-- para o personagem nao ficar "atravessando" o chao depois de pousar.
-- Restaura o valor ORIGINAL de cada parte (o que ela tinha antes do voo), nao
-- um `true` cego: uma parte que ja era nao-colidivel (acessorio, decoracao) tem
-- que voltar nao-colidivel, senao o voo deixa o personagem mexido.
function Teleport:_RestoreCollision()
    local parts = self._noclipParts
    local original = self._originalCollide
    if parts then
        for index = 1, #parts do
            local part = parts[index]
            local was = original and original[part]
            if part.Parent and was ~= nil and part.CanCollide ~= was then
                pcall(function() part.CanCollide = was end)
            end
        end
    end
end

-- Cancela o voo corrente, se houver. Chamado antes de todo Go novo (um so
-- tween por vez) e no Disable/Destroy. Tambem para o arrasto na hora: o
-- personagem para de seguir o tween e a colisao volta -- e o que faz "desligar
-- o toggle parar de teleportar de verdade".
function Teleport:Cancel()
    if self.Tween then
        pcall(function() self.Tween:Cancel() end)
        self.Tween = nil
    end
    self:_RestoreCollision()
    return true
end

-- O motor. Leva o character ate `position` por CFrame, ancorando o voo no
-- Heartbeat (velocidade zero + noclip). Devolve o tween, ou nil se nao ha
-- character.
function Teleport:Go(position, offset)
    local target = toVector3(position)
    if not target then return nil end
    if offset then
        local off = toVector3(offset)
        if off then target = target + off end
    end

    local root = self:HumanoidRootPart()
    if not root then return nil end

    local distance = (root.Position - target).Magnitude
    -- Escala o tempo pela distancia, com piso de 0.05 (teleporte no lugar) e
    -- teto de 90s (um mapa cross-sea nao trava pra sempre).
    local duration = math.clamp(distance / math.max(self.Speed, 1), 0.05, 90)

    self:Cancel()
    local tween = TweenService:Create(
        root,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        { CFrame = CFrame.new(target) }
    )
    self.Tween = tween
    tween.Completed:Connect(function()
        if self.Tween == tween then self.Tween = nil end
        -- Chegou: devolve a colisao (o voo a tinha tirado).
        self:_RestoreCollision()
    end)
    tween:Play()
    return tween
end

-- Atalho: vai ate o offset padrao (5 studs acima). O Go puro deixa passar o
-- offset, mas quase todo call site quer so "chega la em cima".
function Teleport:GoTo(position)
    return self:Go(position, self.ArrivalOffset)
end

function Teleport:SetSpeed(value)
    value = tonumber(value)
    if not value or value <= 0 then return false end
    self.Speed = value
    return true
end

-- --- Teleporte por nome (ilhas/bosses) -------------------------------
-- As tabelas de posicao ficam no modulo porque varias features precisam delas
-- (pegar fruta procura nas ilhas, farm vai aos bosses). Quem so quer um destino
-- especifico pode passar a posicao direto pro Go.

Teleport.islands = {
    { name = "Middle Town",        pos = Vector3.new(-1193.9, 12, -549.8) },
    { name = "Pirate Starter",     pos = Vector3.new(1038, 15, 1550) },
    { name = "Marine Starter",     pos = Vector3.new(-2674.5, 32.1, 2187.0) },
    { name = "Jungle",             pos = Vector3.new(-1866.3, 29.9, 21.6) },
    { name = "Buggy Island",       pos = Vector3.new(-981.0, 30.4, 3966.8) },
    { name = "Desert Island",      pos = Vector3.new(999.9, 7.6, 4490.3) },
    { name = "Snow Island",        pos = Vector3.new(1519.5, 78.0, -1510.9) },
    { name = "Marineford",         pos = Vector3.new(-4763.7, 13.4, 4288.8) },
    { name = "Sky Islands",        pos = Vector3.new(-4973.7, 280.7, -1119.4) },
    { name = "Mob Island (Saber)", pos = Vector3.new(-1527.2, 34.1, -33.2) },
    { name = "Impel Down",         pos = Vector3.new(5278.6, 7.1, 391.6) },
    { name = "Colosseum",          pos = Vector3.new(-1973.1, 9.0, -2744.9) },
    { name = "Volcano",            pos = Vector3.new(-5623.8, 17.0, 8314.1) },
    { name = "Fishman Island",     pos = Vector3.new(3894.3, 4.0, -1915.2) },
    { name = "Upper Sky Islands",  pos = Vector3.new(-6040.2, 5468.0, 1734.2) },
    { name = "Water 7",            pos = Vector3.new(5430.4, 78.0, 3953.6) },
}
Teleport.islands2 = {
    { name = "Kingdom of Rose",  pos = Vector3.new(-195.1, 155.3, 279.9) },
    { name = "Café",             pos = Vector3.new(-380.4, 72.8, 303.2) },
    { name = "Mansion",          pos = Vector3.new(-393.3, 367.3, 687.5) },
    { name = "Colosseum",        pos = Vector3.new(-1836.4, 72.8, 1360.2) },
    { name = "Swan's Room",      pos = Vector3.new(2293.7, 12.5, 663.1) },
    { name = "Factory",          pos = Vector3.new(431.0, 238.4, -433.2) },
    { name = "Green Zone",       pos = Vector3.new(-2340.8, 155.3, -3396.3) },
    { name = "Dark Arena",       pos = Vector3.new(3807.1, 11.8, -3452.2) },
    { name = "Graveyard Island", pos = Vector3.new(-5577.9, 87.6, -782.2) },
    { name = "Snow Mountain",    pos = Vector3.new(856.2, 50.3, -5278.3) },
    { name = "Hot and Cold",     pos = Vector3.new(-5734.3, 49.4, -5146.4) },
    { name = "Cursed Ship",      pos = Vector3.new(900.9, 144.0, 33072.6) },
    { name = "Ice Castle",       pos = Vector3.new(6062.3, 155.3, -6880.9) },
    { name = "Forgotten Island", pos = Vector3.new(-3194.2, 155.3, -10795.3) },
}
Teleport.islands3 = {
    { name = "Port Town",              pos = Vector3.new(-610.4, 57.8, 6436.3) },
    { name = "Dragon Dojo",            pos = Vector3.new(5704.4, 1168.1, 937.0) },
    { name = "Castle on the Sea",      pos = Vector3.new(-5436.6, 815.6, -2701.7) },
    { name = "Floating Turtle",        pos = Vector3.new(-12164.6, -548.9, -8454.9) },
    { name = "Friendly Arena",         pos = Vector3.new(5012.8, 72.8, -1570.6) },
    { name = "Great Tree",             pos = Vector3.new(3036.3, 815.6, -7149.9) },
    { name = "Haunted Castle",         pos = Vector3.new(-9530.6, -132.9, 5763.1) },
    { name = "Beautiful Pirate Domain",pos = Vector3.new(5366.6, 71.2, -225.9) },
    { name = "Mansion",                pos = Vector3.new(-12547.7, 290.1, -7487.1) },
    { name = "North Pole",             pos = Vector3.new(-1141.1, 57.8, -14480.7) },
    { name = "Sea of Treats",          pos = Vector3.new(-1505.3, 57.8, -10724.1) },
    { name = "Secret Temple",          pos = Vector3.new(5226.2, 63.5, 858.8) },
    { name = "Tiki Outpost",           pos = Vector3.new(-16641.5, 213.3, 435.4) },
    { name = "Heavenly Dimension",     pos = Vector3.new(-22709.6, 5259.0, 3886.6) },
    { name = "Hell Dimension",         pos = Vector3.new(-22737.6, 5120.0, 2234.6) },
}
Teleport.bosses = {
    { name = "Chef",         pos = Vector3.new(-1120.5, 54.7, 4121.2) },
    { name = "Yeti",         pos = Vector3.new(1181.7, 104.0, -1616.9) },
    { name = "Mob Boss",     pos = Vector3.new(-2880.7, 6.7, 5430.9) },
    { name = "Saber Expert", pos = Vector3.new(-1527.2, 34.1, -33.2) },
    { name = "Warden",       pos = Vector3.new(5623.2, 1.4, 733.8) },
    { name = "Magma General",pos = Vector3.new(-5625.7, 55.4, 8623.0) },
    { name = "Fishman Lord", pos = Vector3.new(61352.9, 67.2, 1029.1) },
    { name = "Sky Warlord",  pos = Vector3.new(-6271.6, 5472.8, 1887.8) },
    { name = "Cyborg",       pos = Vector3.new(6252.4, 9.3, 4941.4) },
    { name = "Ice Admiral",  pos = Vector3.new(1212.4, 20.4, -1429.6) },
}
Teleport.bosses2 = {
    { name = "Diamond",               pos = Vector3.new(-1711.4, 206.0, -97.1) },
    { name = "Jeremy",                pos = Vector3.new(2338.0, 451.4, 700.1) },
    { name = "Smoke Admiral",         pos = Vector3.new(-4857.4, 233.7, -5583.2) },
    { name = "Awakened Ice Admiral",  pos = Vector3.new(6551.8, 325.3, -6989.9) },
    { name = "rip_indra",             pos = Vector3.new(-26952.3, 21.5, 329.4) },
}
Teleport.bosses3 = {
    { name = "Kilo Admiral",     pos = Vector3.new(2998.3, 508.8, -7344.3) },
    { name = "Captain Elephant", pos = Vector3.new(-13365.5, 321.2, -8485.0) },
    { name = "Longma",           pos = Vector3.new(-10156.2, 337.8, -9445.9) },
    { name = "Cake Queen",       pos = Vector3.new(-678.5, 381.9, -11114.3) },
    { name = "Cake Prince",      pos = Vector3.new(-2089.9, 4536.9, -14800.0) },
}

-- Busca uma entrada pelo nome (sem diferenciar maiuscula). Devolve a posicao.
function Teleport:Find(list, name)
    if type(list) ~= "table" or name == nil then return nil end
    local wanted = tostring(name):lower()
    for _, entry in ipairs(list) do
        if tostring(entry.name):lower() == wanted then return entry.pos end
    end
    return nil
end

-- Atalhos por nome. Ex.: Teleport:GoToIsland("Jungle").
function Teleport:GoToIsland(name)
    return self:GoTo(self:Find(Teleport.islands, name))
end
function Teleport:GoToIsland2(name)
    return self:GoTo(self:Find(Teleport.islands2, name))
end
function Teleport:GoToIsland3(name)
    return self:GoTo(self:Find(Teleport.islands3, name))
end
function Teleport:GoToBoss(name)
    return self:GoTo(self:Find(Teleport.bosses, name))
end
function Teleport:GoToBoss2(name)
    return self:GoTo(self:Find(Teleport.bosses2, name))
end
function Teleport:GoToBoss3(name)
    return self:GoTo(self:Find(Teleport.bosses3, name))
end

-- --- Ponto comum para features externas --------------------------------
-- Uma feature que precisa so "chegar perto de um lugar" chama Teleport:GoTo(pos),
-- mas quem varre o mundo (pegar fruta, procurar NPC) precisa de um helper que
-- aceita um Instance do mundo -- aceita Part/Model com PrimaryPart/Position.

function Teleport:GoToInstance(instance)
    if not instance then return nil end
    local position
    if instance:IsA("BasePart") then
        position = instance.Position
    elseif instance:IsA("Model") then
        position = instance:GetPivot().Position
    end
    if not position then return nil end
    return self:GoTo(position)
end

-- --- Ciclo de vida -----------------------------------------------------
-- O voo e ancorado no Heartbeat: so aqui o modulo precisa de loop. Ele fica
-- ligado enquanto Enable() estiver ativo.

function Teleport:Enable()
    if self.Enabled then return true end
    self.Enabled = true
    -- Durante o voo: velocidade zero + noclip. Nao ancora o character -- o BF
    -- rejeita todo hit num HRP ancorado, entao so zera a velocidade mesmo.
    --
    -- PERFORMANCE: o handler do Heartbeat roda a 60/s. Varrer
    -- character:GetDescendants() TODO frame era o custo pesado e desnecessario --
    -- a lista de BaseParts so muda quando o character muda (respawn) ou quando
    -- alguem entra/sai dela. Entao ela e cacheada e reconstruida apenas quando
    -- necessario; no caso normal o frame so percorre um array curto e seta
    -- CanCollide/velocidade. O cache tambem guarda a propria HRP pra evitar
    -- FindFirstChild por frame.
    self._noclipParts = nil
    self._root = nil
    self._character = nil
    self._heartbeat = RunService.Heartbeat:Connect(function()
        if not self.Tween then return end
        local character = LocalPlayer and LocalPlayer.Character
        if not character then return end
        -- Character novo (respawn) -> invalida o cache uma unica vez.
        if character ~= self._character then
            self._character = character
            self._root = character:FindFirstChild("HumanoidRootPart")
            self._noclipParts = {}
            -- Guarda o CanCollide ORIGINAL de cada parte no momento em que o
            -- cache e montado: o restore devolve exatamente o que estava la
            -- (parte que ja era nao-colidivel volta nao-colidivel).
            self._originalCollide = {}
            -- GetDescendants so aqui (mudanca de character), nao por frame.
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    self._noclipParts[#self._noclipParts + 1] = part
                    self._originalCollide[part] = part.CanCollide
                end
            end
        end
        local root = self._root
        if root and root.Parent == character then
            root.AssemblyLinearVelocity = Vector3.zero
        end
        local parts = self._noclipParts
        if parts then
            for index = 1, #parts do
                local part = parts[index]
                -- So escreve quando muda: CanCollide=true e o padrao, entao
                -- pular a escrita evita a maior parte dos sets por frame.
                if part.CanCollide then part.CanCollide = false end
            end
        end
    end)
    return true
end

function Teleport:Disable()
    self.Enabled = false
    self:Cancel()
    if self._heartbeat then
        pcall(function() self._heartbeat:Disconnect() end)
        self._heartbeat = nil
    end
    self._noclipParts = nil
    self._originalCollide = nil
    self._root = nil
    self._character = nil
    return true
end

function Teleport:SetRange(value) return self:SetSpeed(value) end
function Teleport:IsEnabled() return self.Enabled == true end

function Teleport:Destroy()
    self:Disable()
    self.Tween = nil
end

return Teleport
