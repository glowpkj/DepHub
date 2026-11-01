local game = game
local type = type
local pcall = pcall
local tostring = tostring
local tonumber = tonumber
local unpack = unpack or table.unpack

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Silent Aim -- o aimbot silencioso do Blox Fruits, no molde proprio.
--
-- Portado do script do usuario (v3.4). O que ele faz: escolhe o jogador MAIS
-- PROXIMO dentro do alcance e, se segurar a tecla de "excecao" (F, por padrao),
-- nao mexe em nada; fora disso, intercepta todo remote de saida (FireServer /
-- InvokeServer) e troca o segundo argumento (a posicao) pela posicao do alvo.
-- Assim o servidor acha que voce mirou nele, sem a mira visual mudar.
--
-- O olho do silent aim e o __namecall da metatable do game (getrawmetatable +
-- newcclosure) -- o mesmo mecanismo do script original. Sem isso nao ha silent
-- aim de verdade; e por ser gancho de metatable, o Disable PRECISA devolver o
-- __namecall original, senao o game fica com o gancho pendurado (a regra do
-- repo: ligar tem que desligar de verdade). Por isso o hook e instalado no
-- Enable e removido no Disable/Destroy.
--
-- O BEAM e o indicador visual: um Beam ligando o teu HumanoidRootPart ao do alvo
-- atual, atualizado a cada frame -- sem ele o usuario nao sabe em quem o aim
-- esta travado. Segue o script original (o roxo escuro, CameraFacing), mas o
-- beam vive no ciclo Enable/Disable/Destroy (criado ao ligar, destruido ao
-- desligar) em vez de ficar pendurado no workspace desde o load. Ele so aparece
-- quando HA alvo e o aim NAO esta em excecao -- ou seja, mostra exatamente pra
-- quem o aim vai.
--
-- Sem UI e sem toggle proprio: quem monta o painel e o backend (o toggle "Silent
-- aim", o dropdown de excecoes e o slider de alcance). Aqui so vive a logica.
--
-- Self-contained: faz os proprios game:GetService e nao depende do DepHub. O
-- hook e opcional -- se o executor nao expoe getrawmetatable/newcclosure, o
-- Enable recusa em vez de fingir que liga.

local Feature = {}
Feature.__index = Feature

-- As teclas de excecao que o usuario confirmou. Segurar QUALQUER uma delas faz o
-- silent aim largar o alvo (nao reescreve a posicao) -- util quando voce quer
-- usar a tecla no jogo sem o aim atrapalhar.
local EXCEPTION_KEYS = {
    { label = "Z", key = Enum.KeyCode.Z },
    { label = "X", key = Enum.KeyCode.X },
    { label = "C", key = Enum.KeyCode.C },
    { label = "V", key = Enum.KeyCode.V },
    { label = "F", key = Enum.KeyCode.F },
}

-- Quando a tecla de excecao e solta, o silent aim continua largado por um
-- instante (grace), pra um toque rapido na tecla nao "piscar" a mira. Do script
-- original (ExceptionGrace = 1.0).
local EXCEPTION_GRACE = 1.0

-- O fator de "grude": uma vez escolhido um alvo, so troca quando aparece um
-- mais perto por esta margem (do script original, StickyFactor = 0.2). Evita a
-- mira pular entre dois jogadores de distancia parecida.
local STICKY_FACTOR = 0.2

-- A cor do beam (do script original, Color3.fromRGB(120, 50, 200) -- roxo escuro).
local BEAM_COLOR = Color3.fromRGB(120, 50, 200)

-- Os limites do alcance, como o usuario pediu: minimo 500, padrao 500, maximo
-- 1000. O slider e montado pelo backend com estes numeros.
Feature.MIN_RANGE = 500
Feature.MAX_RANGE = 1000
Feature.DEFAULT_RANGE = 500

Feature.ExceptionKeys = EXCEPTION_KEYS

-- Os rotulos das teclas de excecao, na ordem. O backend monta o dropdown daqui.
Feature.exceptionKeys = {}
for _, entry in ipairs(EXCEPTION_KEYS) do
    Feature.exceptionKeys[#Feature.exceptionKeys + 1] = entry.label
end

-- O rotulo ("F") -> a tecla (Enum.KeyCode.F). nil se nao for uma tecla conhecida.
local function keyForLabel(label)
    if label == nil then return nil end
    local wanted = tostring(label):upper()
    for _, entry in ipairs(EXCEPTION_KEYS) do
        if entry.label:upper() == wanted then return entry.key end
    end
    return nil
end

function Feature.new(options)
    options = options or {}
    local self = setmetatable({}, Feature)
    self.Enabled = false
    -- O alcance em studs. Preso a [MIN, MAX]; o padrao e o minimo (500).
    self.MaxRange = math.clamp(tonumber(options.range) or Feature.DEFAULT_RANGE, Feature.MIN_RANGE, Feature.MAX_RANGE)
    -- As teclas que SUPRIMEM o aim (rotulos). Comeca em F, como o original.
    self.Exceptions = options.exceptions or { "F" }
    -- Estado da mira.
    self.Target = nil            -- Player alvo
    self.TargetName = nil
    self.TargetPosition = nil    -- Vector3 do alvo no ultimo frame
    self.TargetDistance = nil
    -- Estado da excecao (tecla segurada / grace).
    self.ExceptionHeld = false
    self.ExceptionTime = 0
    -- Conexoes (Heartbeat do alvo + InputBegan/Ended das teclas).
    self.Connections = {}
    -- O gancho da metatable: guarda o __namecall original pra restaurar.
    self.OriginalNamecall = nil
    self.Metatable = nil
    self.Hooked = false
    -- O indicador visual: o Beam + as duas Attachments (na tua HRP e na do
    -- alvo). Criados no Enable, destruidos no Disable/Destroy.
    self.Beam = nil
    self.LocalAttachment = nil
    self.TargetAttachment = nil
    return self
end

-- A posicao do HumanoidRootPart agora, ou nil.
local function root(character)
    return character and character:FindFirstChild("HumanoidRootPart")
end

-- A posicao do HumanoidRootPart de um player, ou nil se nao ha character vivo.
local function playerPosition(player)
    if not player or player == LocalPlayer then return nil end
    local character = player.Character
    local hrp = root(character)
    if not hrp then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health <= 0 then return nil end
    return hrp.Position
end

-- O jogador mais proximo dentro do alcance. nil se nao ha ninguem (ou sem
-- character proprio).
function Feature:FindNearest()
    local myRoot = root(LocalPlayer and LocalPlayer.Character)
    if not myRoot then return nil, nil end
    local origin = myRoot.Position
    local nearest, nearestDist = nil, math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        local position = playerPosition(player)
        if position then
            local distance = (position - origin).Magnitude
            if distance <= self.MaxRange and distance < nearestDist then
                nearest, nearestDist = player, distance
            end
        end
    end
    return nearest, nearestDist
end

-- A tecla esta na lista de excecao do usuario?
function Feature:IsExceptionKey(keyCode)
    for _, label in ipairs(self.Exceptions) do
        if keyForLabel(label) == keyCode then return true end
    end
    return false
end

-- O aim esta largado agora? (tecla segurada, ou grace depois de soltar)
function Feature:IsExceptionActive()
    if self.ExceptionHeld then return true end
    return (os.clock() - self.ExceptionTime) < EXCEPTION_GRACE
end

-- --- O beam (o indicador visual do alvo) ------------------------------------

-- Cria o Beam e as duas Attachments. O beam vive no ciclo Enable/Disable (nao
-- desde o load): nasce aqui, morre no _DestroyBeam. CameraFacing + cor roxa,
-- como o script original.
function Feature:_CreateBeam()
    if self.Beam then return end
    local beam = Instance.new("Beam")
    beam.Name = "TargetBeam"
    beam.FaceCamera = true
    beam.LightEmission = 0
    beam.LightInfluence = 0
    beam.Width0 = 2
    beam.Width1 = 2
    beam.Color = ColorSequence.new(BEAM_COLOR)
    beam.Enabled = false
    beam.Parent = workspace
    self.Beam = beam
    self.LocalAttachment = Instance.new("Attachment")
    self.LocalAttachment.Name = "BeamAtt0"
    self.TargetAttachment = Instance.new("Attachment")
    self.TargetAttachment.Name = "BeamAtt1"
end

-- Destroi o beam e as attachments. Parte do Disable/Destroy: sem isto o beam
-- ficaria pendurado no workspace depois de desligar.
function Feature:_DestroyBeam()
    for _, part in ipairs({ self.Beam, self.LocalAttachment, self.TargetAttachment }) do
        if part then pcall(function() part:Destroy() end) end
    end
    self.Beam = nil
    self.LocalAttachment = nil
    self.TargetAttachment = nil
end

-- Um frame do beam: liga-o da tua HumanoidRootPart a do alvo. So aparece quando
-- HA alvo e o aim NAO esta em excecao -- ou seja, mostra exatamente pra quem o
-- aim vai; escondido quando nao ha alvo ou a tecla de excecao esta ativa.
function Feature:_UpdateBeam()
    if not self.Beam then return end
    local myRoot = root(LocalPlayer and LocalPlayer.Character)
    local target = self.TargetName and Players:FindFirstChild(self.TargetName)
    local targetRoot = target and root(target.Character)
    local show = myRoot ~= nil and targetRoot ~= nil and not self:IsExceptionActive()
    if not show then
        self.Beam.Enabled = false
        return
    end
    if self.LocalAttachment.Parent ~= myRoot then self.LocalAttachment.Parent = myRoot end
    if self.TargetAttachment.Parent ~= targetRoot then self.TargetAttachment.Parent = targetRoot end
    self.Beam.Attachment0 = self.LocalAttachment
    self.Beam.Attachment1 = self.TargetAttachment
    self.Beam.Enabled = true
end

-- --- O gancho (o olho do silent aim) ----------------------------------------

-- Instala o gancho de __namecall. Guarda o original pra restaurar depois.
-- Devolve true se instalou. Sem getrawmetatable/newcclosure (executor que nao
-- expoe) devolve false -- o Enable entao recusa, em vez de ligar um no-op.
function Feature:InstallHook()
    if self.Hooked then return true end
    if type(getrawmetatable) ~= "function" or type(newcclosure) ~= "function" then
        return false
    end
    local mt = getrawmetatable(game)
    if not mt then return false end
    local original = mt.__namecall
    if type(original) ~= "function" then return false end

    self.Metatable = mt
    self.OriginalNamecall = original
    -- A metatable e protegida (readonly); liberar antes de escrever.
    if type(setreadonly) == "function" then pcall(setreadonly, mt, false) end

    local self_ = self
    mt.__namecall = newcclosure(function(...)
        local method = getnamecallmethod()
        -- So mexe em chamadas de saida pro servidor.
        if method == "FireServer" or method == "InvokeServer" then
            local args = { ... }
            -- args[1] e o proprio remote; so age se ele parecer um remote.
            local remote = args[1]
            if typeof(remote) == "Instance"
                and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
                -- O segundo argumento e a posicao. Nao mexe quando ha alvo nulo,
                -- quando o aim esta em excecao, ou quando arg2 e booleano (alguns
                -- remotes usam bool no slot 2; reescrever quebraria o comando).
                local target = self_.TargetPosition
                local arg2 = args[2]
                if target ~= nil
                    and not self_:IsExceptionActive()
                    and not (arg2 == true or arg2 == false) then
                    args[2] = target
                end
            end
            return original(unpack(args))
        end
        return original(...)
    end)
    self.Hooked = true
    return true
end

-- Restaura o __namecall original. Sem isso o game ficaria com o gancho pendurado.
function Feature:RemoveHook()
    if not self.Hooked then return end
    self.Hooked = false
    if self.Metatable and self.OriginalNamecall then
        pcall(function()
            if type(setreadonly) == "function" then pcall(setreadonly, self.Metatable, false) end
            self.Metatable.__namecall = self.OriginalNamecall
        end)
    end
    self.Metatable = nil
    self.OriginalNamecall = nil
end

-- --- Selecao de alvo --------------------------------------------------------

function Feature:_ClearTarget()
    self.Target = nil
    self.TargetName = nil
    self.TargetPosition = nil
    self.TargetDistance = nil
end

-- Um passo da selecao (roda no Heartbeat). Escolhe o mais proximo; uma vez com
-- alvo, so troca se aparecer outro mais perto pela margem de grude.
function Feature:_SelectStep()
    local target, distance = self:FindNearest()
    if not target then
        self:_ClearTarget()
        return
    end
    if self.TargetName ~= target.Name then
        -- Sem alvo ainda: pega o mais proximo. Com alvo: so troca se o novo
        -- estiver bem mais perto (sticky).
        if self.TargetDistance == nil or distance < (self.TargetDistance * (1 - STICKY_FACTOR)) then
            self.Target = target
            self.TargetName = target.Name
            self.TargetDistance = distance
        end
    else
        self.Target = target
        self.TargetDistance = distance
    end
    -- Atualiza a posicao do alvo a cada passo (e o que o hook reescreve).
    local current = Players:FindFirstChild(self.TargetName)
    self.TargetPosition = playerPosition(current)
    if not self.TargetPosition then
        -- Alvo morreu/saiu: solta pra reescolher no proximo passo.
        self:_ClearTarget()
    end
end

-- --- Ciclo de vida ---------------------------------------------------------

function Feature:SetRange(value)
    value = tonumber(value)
    if not value then return false end
    self.MaxRange = math.clamp(value, Feature.MIN_RANGE, Feature.MAX_RANGE)
    return true
end

-- As teclas de excecao (rotulos). Aceita uma tabela; filtra pro que existe.
function Feature:SetExceptions(labels)
    local list = {}
    for _, label in ipairs(type(labels) == "table" and labels or {}) do
        if keyForLabel(label) then list[#list + 1] = tostring(label):upper() end
    end
    self.Exceptions = list
    return true
end

function Feature:Enable()
    if self.Enabled then return true end
    if not self:InstallHook() then
        self.LastError = "sem getrawmetatable/newcclosure"
        return false
    end
    self.Enabled = true
    self.ExceptionHeld = false
    self.ExceptionTime = 0

    -- O indicador visual nasce aqui e morre no Disable.
    self:_CreateBeam()

    -- A selecao de alvo roda no Heartbeat (nao no RenderStepped: a mira e logica,
    -- nao precisa desenhar nada).
    self.Connections[#self.Connections + 1] = RunService.Heartbeat:Connect(function()
        if not self.Enabled then return end
        pcall(function() self:_SelectStep() end)
    end)

    -- O beam segue a cada frame: liga a tua HRP a do alvo, ou esconde quando nao
    -- ha alvo / a excecao esta ativa.
    self.Connections[#self.Connections + 1] = RunService.RenderStepped:Connect(function()
        if not self.Enabled then return end
        pcall(function() self:_UpdateBeam() end)
    end)

    -- Teclas de excecao: segurar larga o aim; soltar conta o grace.
    self.Connections[#self.Connections + 1] = UserInputService.InputBegan:Connect(function(io)
        if self:IsExceptionKey(io.KeyCode) then
            self.ExceptionHeld = true
            self.ExceptionTime = os.clock()
        end
    end)
    self.Connections[#self.Connections + 1] = UserInputService.InputEnded:Connect(function(io)
        if self:IsExceptionKey(io.KeyCode) then
            self.ExceptionHeld = false
            self.ExceptionTime = os.clock()
        end
    end)

    return true
end

function Feature:Disable()
    self.Enabled = false
    for _, connection in ipairs(self.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    self.Connections = {}
    self:_ClearTarget()
    self:_DestroyBeam()
    self:RemoveHook()
    return true
end

function Feature:IsEnabled()
    return self.Enabled == true
end

function Feature:Destroy()
    self:Disable()
    self.Exceptions = nil
end

return Feature
