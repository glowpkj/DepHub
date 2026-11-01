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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Silent Aim -- o aimbot silencioso do Blox Fruits, no molde proprio.
--
-- Portado do script do usuario (v3.4). O que ele faz: escolhe o jogador MAIS
-- PROXIMO dentro do alcance e, se segurar a tecla de "excecao" (F, por padrao),
-- nao mexe em nada; fora disso, intercepta todo remote de saida (FireServer /
-- InvokeServer) e troca o segundo argumento (a posicao) pela posicao do alvo.
-- Assim o servidor acha que voce mirou nele, sem a mira visual mudar.
--
-- O olho do silent aim e o __namecall da metatable do game -- o mesmo mecanismo
-- do script original. Mas aqui ele NAO instala o proprio gancho: usa o gancho
-- COMPARTILHADO (options.hook, a infra net-hook), onde se INSCREVE. Isso deixa
-- silent aim e blade hit dividindo UMA camada de __namecall em vez de empilhar
-- dois. Sem o gancho compartilhado (executor sem getrawmetatable/newcclosure) ou
-- sem hook injetado, o Enable recusa em vez de fingir que liga. O RemoveHook
-- cancela a inscricao; o gancho so sai da metatable quando o ULTIMO assinante
-- sai (ref-count no net-hook) -- a regra do repo: ligar tem que desligar de
-- verdade.
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
-- Self-contained: faz os proprios game:GetService e nao depende do DepHub. So
-- pede o gancho compartilhado por injecao (options.hook) -- se faltar, recusa.

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

-- Grude FORTE (pedido do usuario: "nao pode parar de ficar no player"). Uma vez
-- travado, so troca de alvo se o novo estiver a menos desta FRACAO da distancia
-- do atual (0.6 = o novo tem que ser 40% mais perto pra valer a troca). Enquanto
-- o alvo atual estiver vivo, a mira nao pisca entre dois players.
local LOCK_MARGIN = 0.6

-- Quanto tempo segurar o alvo quando o Character dele desaparece por um frame
-- (morte/respawn/dash que recarrega o Character). Dentro desse tempo a mira
-- continua "dele" em vez de soltar e reescolher -- era isso que fazia o aim
-- parar de ficar no player no PvP.
local TARGET_GRACE = 0.75

-- A cor do beam (do script original, Color3.fromRGB(120, 50, 200) -- roxo escuro).
local BEAM_COLOR = Color3.fromRGB(120, 50, 200)

-- Quantas vezes o Heartbeat ainda tenta resolver os remotes que faltam. Com o
-- aim ligado antes do Net do jogo existir, isto cobre uns bons segundos de
-- tentativas; depois para -- nao fica re-tentando 60x/s pra sempre.
local REMOTE_RESOLVE_RETRIES = 120

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
    self.TargetLostAt = nil      -- os.clock() do instante em que o alvo sumiu
    -- Estado da excecao (tecla segurada / grace).
    self.ExceptionHeld = false
    self.ExceptionTime = 0
    -- Conexoes (Heartbeat do alvo + InputBegan/Ended das teclas).
    self.Connections = {}
    -- O gancho COMPARTILHADO de __namecall (injetado por options.hook, a infra
    -- net-hook). O silent aim se INSCREVE nele; nao instala gancho proprio.
    self.Hook = options.hook or nil
    -- O id da nossa inscricao no gancho (pra cancelar no RemoveHook). O gancho
    -- so sai da metatable quando o ultimo assinante sai.
    self.HookId = nil
    -- O remote do CLIQUE (M1/ar): RegisterHit. Redirecionado pro alvo no slot 1.
    self.RegisterHit = nil
    -- O remote que abre o golpe (RegisterAttack): quando ele sai, o aim dispara
    -- um RegisterHit no alvo travado, registrando o dano nele.
    self.RegisterAttack = nil
    -- O ultimo hitId visto no RegisterHit do jogo (4. argumento). Reaproveitado
    -- no RegisterHit que o aim forja -- o servidor so aceita hit com hitId
    -- valido, entao mandar um forjado sem o do jogo seria ignorado.
    self.HitId = nil
    -- Anti-spam: nao disparar o RegisterHit forjado mais de uma vez por golpe.
    self.LastAttackAt = 0
    -- O indicador visual: o Beam + as duas Attachments (na tua HRP e na do
    -- alvo). Criados no Enable, destruidos no Disable/Destroy.
    self.Beam = nil
    self.LocalAttachment = nil
    self.TargetAttachment = nil
    -- As closures hoistadas dos handlers de frame e o contador de tentativas de
    -- re-resolver os remotes. Zerados no new; o Enable os (re)arma.
    self._selectStep = nil
    self._updateBeam = nil
    self._remoteRetries = 0
    return self
end

-- A posicao do HumanoidRootPart agora, ou nil.
local function root(character)
    return character and character:FindFirstChild("HumanoidRootPart")
end

-- A posicao do HumanoidRootPart de um player, ou nil se nao ha character/HRP.
-- Mesma regra do script original: so exige Character + HumanoidRootPart (nao
-- filtra por Health -- o original nao filtrava, e Health nem sempre e numero no
-- executor; descartar alvo aqui mudaria o comportamento que ja funcionava).
local function playerPosition(player)
    if not player or player == LocalPlayer then return nil end
    local hrp = root(player.Character)
    if not hrp then return nil end
    return hrp.Position
end

-- A MINHA posicao (HumanoidRootPart), ou a origem se eu ainda nao tenho uma.
function Feature:_MyPosition()
    local hrp = root(LocalPlayer and LocalPlayer.Character)
    return hrp and hrp.Position or Vector3.new(0, 0, 0)
end

-- A HumanoidRootPart do alvo travado, ou nil. E o que o CLIQUE manda no slot 1
-- do RegisterHit (o M1/ar do BF manda a PART do alvo, nao a posicao).
function Feature:_TargetRoot()
    if not self.TargetName then return nil end
    local target = Players:FindFirstChild(self.TargetName)
    if not target then return nil end
    return root(target.Character)
end

-- O hitId pro RegisterHit forjado. Prefere o ultimo capturado pelo gancho
-- COMPARTILHADO (a infra net-hook le o 4. argumento do RegisterHit do jogo e
-- guarda em Hook.LastHitId); senao, o que a propria feature guardou; sem nenhum
-- ainda, gera um no mesmo formato do script antigo (UserId + algo unico) -- o
-- hitId do BF e um nonce do CLIENTE, nao um token do servidor, entao um gerado
-- aqui e valido.
function Feature:_HitId()
    local hook = self.Hook
    if hook and hook.LastHitId ~= nil then return hook.LastHitId end
    if self.HitId ~= nil then return self.HitId end
    local me = LocalPlayer
    local userId = me and tostring(me.UserId) or "0"
    return userId:sub(2, 4) .. tostring(os.clock()):gsub("%D", ""):sub(-4)
end

-- Resolve os remotes de ataque do BF a partir do gancho COMPARTILHADO. O CLIQUE
-- (M1/ar) e o RegisterHit: ele manda (part, {}, nil, hitId). As SKILLS mandam a
-- posicao no slot 2 de outros remotes. Sem achar o RegisterHit, o aim das skills
-- continua funcionando e so o clique nao e redirecionado -- nao e fatal.
--
-- RegisterAttack tambem e resolvido: e o "comeco do golpe" (FireServer(0.4,
-- combo)). E o gatilho pra RE-REGISTRAR o hit no alvo (ver _OnRemote).
function Feature:ResolveRemotes()
    local hook = self.Hook
    if not hook then return false end
    if type(hook.Resolve) == "function" then pcall(hook.Resolve, hook) end
    self.RegisterHit = hook.RegisterHit
    self.RegisterAttack = hook.RegisterAttack
    return self.RegisterHit ~= nil
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

-- A NOSSA parte do gancho compartilhado: chamada pelo net-hook a cada remote que
-- sai (FireServer/InvokeServer), com a tabela `args` que sera enviada. Aqui vive
-- a logica do silent aim -- o net-hook ja cuidou da deteccao de remote e da
-- captura do hitId; esta callback so REESCREVE.
--
-- O corpo e IDENTICO ao script original do usuario (v3.4), que funcionava sem
-- bugar nada:
--   * o RegisterHit do clique manda (part, {}, nil, hitId) -- reescrevemos a
--     PART (args[2]) pela HumanoidRootPart do alvo travado, sem tocar nos outros.
--   * o RegisterAttack (FireServer(0.4, combo)) e o gatilho pra forjar um
--     RegisterHit no alvo -- o caminho que de fato registra dano no BF.
--   * as SKILLS mandam a POSICAO no slot 2; reescrevemos quando ha alvo e o aim
--     nao esta em excecao (e o slot 2 nao e booleano).
function Feature:_OnRemote(args)
    local RegisterHit = self.RegisterHit
    local RegisterAttack = self.RegisterAttack

    -- O CLIQUE (M1/ar): (part, {}, nil, hitId) -- args[1] e o proprio RegisterHit.
    if RegisterHit ~= nil and args[1] == RegisterHit then
        local targetRoot = self:_TargetRoot()
        if targetRoot ~= nil then args[2] = targetRoot end
        return
    end

    -- O GOLPE ABRIU (RegisterAttack): forja um RegisterHit no alvo travado. Fora
    -- do __namecall (task.spawn) -- disparar aqui dentro re-entraria no gancho.
    if RegisterAttack ~= nil and args[1] == RegisterAttack then
        if not self:IsExceptionActive() then
            local now = os.clock()
            -- No maximo um RegisterHit forjado a cada 20ms (o golpe abre uma vez;
            -- RegisterAttack pode repetir rapido).
            if (now - self.LastAttackAt) > 0.02 then
                local targetRoot = self:_TargetRoot()
                if targetRoot ~= nil then
                    self.LastAttackAt = now
                    local hitRemote, hitId = RegisterHit, self:_HitId()
                    task.spawn(function()
                        pcall(function() hitRemote:FireServer(targetRoot, {}, nil, hitId) end)
                    end)
                end
            end
        end
        return
    end

    -- As SKILLS de teclado mandam a POSICAO no slot 2. Reescrita como no original.
    if self.TargetPosition ~= nil and not self:IsExceptionActive() then
        local arg2Str = tostring(args[2])
        local isBool = (arg2Str == "true" or arg2Str == "false")
        if not isBool then args[2] = self.TargetPosition end
    end
end

-- Inscreve o silent aim no gancho COMPARTILHADO (options.hook, a infra net-hook).
-- Devolve true se inscreveu. Sem gancho injetado ou sem getrawmetatable/newcclosure
-- (executor que nao expoe) devolve false -- o Enable entao recusa, em vez de ligar
-- um no-op. Tambem resolve os remotes no gancho.
function Feature:InstallHook()
    if self.HookId ~= nil then return true end
    local hook = self.Hook
    if not hook or type(hook.Add) ~= "function" then
        self.LastError = "sem gancho compartilhado"
        return false
    end
    -- Os remotes de ataque sao resolvidos no proprio gancho compartilhado (ele
    -- captura o hitId e sabe o RegisterHit); aqui pegamos as referencias pra
    -- comparar nos args.
    if type(hook.Resolve) == "function" then pcall(hook.Resolve, hook) end
    self.RegisterHit = hook.RegisterHit
    self.RegisterAttack = hook.RegisterAttack
    local id = hook:Add(function(args)
        pcall(self._OnRemote, self, args)
    end)
    if id == nil then
        self.LastError = "sem getrawmetatable/newcclosure"
        return false
    end
    self.HookId = id
    return true
end

-- Cancela a nossa inscricao. O gancho so sai da metatable quando o ULTIMO
-- assinante sai (ref-count no net-hook) -- entao desligar o silent aim nao derruba
-- o gancho debaixo da blade hit, e vice-versa.
function Feature:RemoveHook()
    if self.HookId == nil then return end
    local hook = self.Hook
    if hook and type(hook.Remove) == "function" then
        pcall(hook.Remove, hook, self.HookId)
    end
    self.HookId = nil
end

-- --- Selecao de alvo --------------------------------------------------------

-- Solta o alvo de vez (limpa tudo, inclusive o timer de persistencia).
function Feature:_ClearTarget()
    self.Target = nil
    self.TargetName = nil
    self.TargetPosition = nil
    self.TargetDistance = nil
    self.TargetLostAt = nil
end

-- Um passo da selecao (roda no Heartbeat a cada frame -- a mira e o ponto mais
-- sensivel do aim, entao ela refina todo frame e nao uma vez por intervalo).
--
-- Grude FORTE (o que o usuario pediu):
--   * Com alvo vivo: CONTINUA nele. So troca se o alvo morreu/saiu, ou se outro
--     ficou MUITO mais perto (LOCK_MARGIN). Nenhum piscar entre dois alvos de
--     distancia parecida.
--   * O alvo "desaparece" por um frame (morte, respawn, dash que recarrega o
--     Character): em vez de soltar na hora, segura o alvo por TARGET_GRACE
--     segundos. Se ele voltar nesse tempo, a mira nunca saiu dele -- e o que
--     fazia o aim "parar de ficar no player" no PvP.
--   * Sem NENHUM alvo muito mais perto e sem alvo proprio: cai no mais proximo
--     dentro do alcance.
function Feature:_SelectStep()
    local now = os.clock()

    -- 1) O alvo atual ainda vale? Recalcula a posicao e mantem se der.
    if self.TargetName then
        local current = Players:FindFirstChild(self.TargetName)
        local pos = playerPosition(current)
        if pos then
            -- Grudado: so troca se aparecer alguem MUITO mais perto.
            local nearest, nearestDist = self:FindNearest()
            if nearest and nearest.Name ~= self.TargetName
                and nearestDist < (self.TargetDistance or math.huge) * LOCK_MARGIN then
                self.Target = nearest
                self.TargetName = nearest.Name
                self.TargetDistance = nearestDist
                self.TargetPosition = playerPosition(nearest)
                self.TargetLostAt = nil
            else
                self.Target = current
                self.TargetPosition = pos
                self.TargetDistance = (pos - self:_MyPosition()).Magnitude
                self.TargetLostAt = nil
            end
            return
        end
    end

    -- 2) O alvo sumiu neste frame. Segura por um instante antes de soltar: o
    -- Character do alvo pode estar recarregando (morte/respawn/dash) e volta
    -- logo -- soltar aqui era o que tirava a mira do player no PvP. Na PRIMEIRA
    -- vez que ele some, marca o instante; enquanto o grace nao estourar, mantem
    -- o alvo (e nao reescolhe outro no meio).
    if self.TargetName then
        if not self.TargetLostAt then
            self.TargetLostAt = now
            return
        end
        if (now - self.TargetLostAt) < TARGET_GRACE then
            return
        end
    end

    -- 3) Passou o grace (ou nunca teve alvo): escolhe o mais proximo do zero.
    local target, distance = self:FindNearest()
    if not target then
        self:_ClearTarget()
        return
    end
    self.Target = target
    self.TargetName = target.Name
    self.TargetDistance = distance
    self.TargetPosition = playerPosition(target)
    if self.TargetPosition then
        self.TargetLostAt = nil
    else
        self.TargetLostAt = now
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

    -- O remote do clique (M1/ar). Se nao achar, o aim das skills segue normal.
    self:ResolveRemotes()
    -- Quantas vezes ainda vale tentar re-resolver os remotes que faltam. Antes
    -- isto tentava TODO frame, sem teto: se um remote nunca aparecesse (nome
    -- diferente, remoto removido), ficaria 60 tentativas/s pra sempre. Agora
    -- tenta por um instante e para -- se os dois resolverem antes, para na hora.
    self._remoteRetries = REMOTE_RESOLVE_RETRIES

    -- O indicador visual nasce aqui e morre no Disable.
    self:_CreateBeam()

    -- A selecao de alvo roda no Heartbeat (nao no RenderStepped: a mira e logica,
    -- nao precisa desenhar nada). As closures de pcall sao HOISTADAS (criadas uma
    -- vez, nao a cada frame): alocar duas closures por frame era lixo de GC a
    -- toa num loop que roda 60x/s.
    local function selectStep()
        if not self.Enabled then return end
        pcall(self._SelectStep, self)
        -- Os remotes (RegisterHit/RegisterAttack) podem ainda nao existir quando
        -- o aim liga (o jogo monta o Net depois). Tenta mais algumas vezes pra o
        -- CLIQUE e o gatilho do golpe serem pegos -- mas com teto.
        if self._remoteRetries > 0 and (self.RegisterHit == nil or self.RegisterAttack == nil) then
            self._remoteRetries = self._remoteRetries - 1
            pcall(self.ResolveRemotes, self)
        end
    end
    self._selectStep = selectStep
    self.Connections[#self.Connections + 1] = RunService.Heartbeat:Connect(selectStep)

    -- O beam segue a cada frame: liga a tua HRP a do alvo, ou esconde quando nao
    -- ha alvo / a excecao esta ativa.
    local function updateBeam()
        if not self.Enabled then return end
        pcall(self._UpdateBeam, self)
    end
    self._updateBeam = updateBeam
    self.Connections[#self.Connections + 1] = RunService.RenderStepped:Connect(updateBeam)

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
    self.RegisterHit = nil
    self.RegisterAttack = nil
    self.HitId = nil
    self.LastAttackAt = 0
    -- Solta as closures dos handlers (elas fechavam sobre o self; mantendo-as
    -- aqui o self nunca seria coletado depois de um Disable).
    self._selectStep = nil
    self._updateBeam = nil
    self._remoteRetries = 0
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
