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
    -- O gancho da metatable: guarda o __namecall original pra restaurar.
    self.OriginalNamecall = nil
    self.Metatable = nil
    self.Hooked = false
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

-- O hitId pro RegisterHit forjado. Prefere o ultimo capturado de um RegisterHit
-- real do jogo (o formato que o servidor ja aceitou); sem nenhum ainda, gera um
-- no mesmo formato que o script antigo usava quando nao tinha captura
-- (UserId + algo unico) -- o hitId do BF e um nonce do CLIENTE, nao um token do
-- servidor, entao um gerado aqui e valido.
function Feature:_HitId()
    if self.HitId ~= nil then return self.HitId end
    local me = LocalPlayer
    local userId = me and tostring(me.UserId) or "0"
    return userId:sub(2, 4) .. tostring(os.clock()):gsub("%D", ""):sub(-4)
end

-- Resolve os remotes de ataque do BF. O CLIQUE (M1/ar) e o RegisterHit: ele
-- manda (part, {}, nil, hitId). As SKILLS mandam a posicao no slot 2 de outros
-- remotes. Sem achar o RegisterHit, o aim das skills continua funcionando e so
-- o clique nao e redirecionado -- nao e fatal.
--
-- RegisterAttack tambem e resolvido: e o "comeco do golpe" (FireServer(0.4,
-- combo)). E o gatilho pra RE-REGISTRAR o hit no alvo (ver InstallHook): quando
-- o golpe comeca, o aim dispara um RegisterHit no alvo travado -- o caminho que
-- de fato registra dano no BF (o mesmo que a blade hit usa).
function Feature:ResolveRemotes()
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    local net = (modules and modules:FindFirstChild("Net")) or ReplicatedStorage:FindFirstChild("Net")
    if not net then return false end
    local hit = net:FindFirstChild("RE/RegisterHit")
    if not hit then return false end
    self.RegisterHit = hit
    self.RegisterAttack = net:FindFirstChild("RE/RegisterAttack")
    return true
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
--
-- O corpo do gancho e IDENTICO ao script original do usuario (v3.4), que e o
-- que funcionava sem bugar nada:
--   * `local args = {...}` e `old(unpack(args))` -- a tabela de varargs e
--     remontada e reenviada inteira, exatamente como no original.
--   * deteccao de remote pelo tostring de args[1] ("RemoteEvent"/"RemoteFunction").
--   * SO reescreve quando ha alvo (TargetPosition ~= nil) e o aim nao esta em
--     excecao. Sem alvo, a chamada sai intacta pelo caminho normal.
--   * SEM pcall: o original nao tinha, e um pcall em volta do corpo muda o
--     caminho da chamada (o executor entrega de outro jeito) e era o que saia do
--     personagem so por ligar o toggle. O corpo aqui nao deve levantar: so le
--     campos do proprio modulo e chama o original.
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
    -- A metatable e protegida (readonly); liberar antes de escrever. Guardamos o
    -- estado pra reativar no RemoveHook (nao deixar a metatable destravada).
    if type(isreadonly) == "function" then
        self.MetatableWasReadonly = pcall(isreadonly, mt) and isreadonly(mt) == true
    end
    if type(setreadonly) == "function" then pcall(setreadonly, mt, false) end

    local self_ = self
    mt.__namecall = newcclosure(function(...)
        local method = getnamecallmethod()
        local args = { ... }

        local isFire = tostring(method) == "FireServer"
        local isInvoke = tostring(method) == "InvokeServer"

        if isFire or isInvoke then
            -- Deteccao de remote IDENTICA ao script original do usuario.
            local arg1Str = tostring(args[1])
            local isRemote = (arg1Str == "RemoteEvent" or arg1Str == "RemoteFunction")

            if isRemote then
                -- O CLIQUE (M1/ar) sai pelo RegisterHit com a PART do alvo no
                -- slot 2: (part, {}, nil, hitId) -- args[1] e o proprio remote.
                -- Aqui o aim redireciona essa part pra HumanoidRootPart do alvo
                -- travado, sem encostar nos outros slots (o hitId continua o do
                -- jogo). So o proprio RegisterHit e tocado.
                if self_.RegisterHit ~= nil and args[1] == self_.RegisterHit then
                    -- Guarda o hitId (4. argumento) -- e o token que o servidor
                    -- validou no golpe; o RegisterHit forjado abaixo reusa ele.
                    if args[4] ~= nil then self_.HitId = args[4] end
                    local targetRoot = self_:_TargetRoot()
                    if targetRoot ~= nil then
                        args[2] = targetRoot
                    end
                    return original(unpack(args))
                end

                -- O GOLPE ABRIU (RegisterAttack:FireServer(0.4, combo)). Este e
                -- o ponto em que o aim REGISTRA o dano no alvo: dispara um
                -- RegisterHit no HumanoidRootPart do alvo travado, que e o
                -- caminho que de fato acerta no BF (o mesmo da blade hit). A
                -- POSICAO reescrita nos outros remotes sozinha nao garante o
                -- acerto -- o RegisterHit garante.
                if self_.RegisterAttack ~= nil and args[1] == self_.RegisterAttack then
                    local root = original(unpack(args))
                    local self2 = self_
                    -- Fora do __namecall (task.spawn): disparar o FireServer
                    -- aqui dentro re-entraria no proprio gancho de forma
                    -- sincrona logo apos o original. Spawnado, ele sai pelo
                    -- caminho normal no proximo passo do scheduler.
                    if not self2:IsExceptionActive() then
                        local now = os.clock()
                        -- No maximo um RegisterHit forjado a cada 20ms (o golpe
                        -- abre uma vez; RegisterAttack pode repetir rapido).
                        if (now - self2.LastAttackAt) > 0.02 then
                            local targetRoot = self2:_TargetRoot()
                            if targetRoot ~= nil then
                                self2.LastAttackAt = now
                                local hitRemote, hitId = self2.RegisterHit, self2:_HitId()
                                task.spawn(function()
                                    pcall(function() hitRemote:FireServer(targetRoot, {}, nil, hitId) end)
                                end)
                            end
                        end
                    end
                    return root
                end

                -- As SKILLS de teclado mandam a POSICAO no slot 2. Reescrito
                -- como no script original.
                local arg2Str = tostring(args[2])
                local isBool = (arg2Str == "true" or arg2Str == "false")

                if not isBool and self_.TargetPosition ~= nil and not self_:IsExceptionActive() then
                    args[2] = self_.TargetPosition
                end
            end
        end

        return original(unpack(args))
    end)
    -- Guarda a closure INSTALADA: o RemoveHook so restaura se o __namecall atual
    -- ainda for esta -- se outro script (ou outra instancia) instalou uma camada
    -- depois, nao sobrescrevemos a dele com o nosso original obsoleto.
    self.InstalledNamecall = mt.__namecall
    self.Hooked = true
    return true
end

-- Restaura o __namecall original. Sem isso o game ficaria com o gancho pendurado.
-- Restaura SO se o valor atual ainda for o NOSSO gancho (senao outra camada
-- assumiu o __namecall e apagar aqui destruiria a dela).
function Feature:RemoveHook()
    if not self.Hooked then return end
    self.Hooked = false
    local mt = self.Metatable
    if mt and self.OriginalNamecall then
        pcall(function()
            if type(setreadonly) == "function" then pcall(setreadonly, mt, false) end
            -- So restaura se ainda for o nosso gancho. Se mudou, so reativa a
            -- readonly (deixamos a metatable como estava) e nao mexemos no valor.
            if self.InstalledNamecall == nil or mt.__namecall == self.InstalledNamecall then
                mt.__namecall = self.OriginalNamecall
            end
            if self.MetatableWasReadonly and type(setreadonly) == "function" then
                pcall(setreadonly, mt, true)
            end
        end)
    end
    self.Metatable = nil
    self.OriginalNamecall = nil
    self.InstalledNamecall = nil
    self.MetatableWasReadonly = nil
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
