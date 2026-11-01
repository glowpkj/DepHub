-- Volleyball 4.2 - Jump Anywhere + impulso extra. Um unico recurso, um unico
-- toggle: liga as DUAS coisas juntas --
--   1) JUMP BYPASS: patcheia o upvalue de checagem dentro de
--      CharacterActions.Jump para que "NoJump" (o veto de pulo do jogo) vire
--      nil; dali pra frente o pulo funciona em qualquer lugar da quadra.
--   2) IMPULSO EXTRA: quando o jogador pula de fato (CA.State.Jumped sobe), no
--      frame seguinte forca AssemblyLinearVelocity.Y para a velocidade de altura
--      padrao * (1 + Aumento/100). Sem impulso (0%), o pulo original fica igual.
--
-- IMPORTANTE -- o impulso e INDEPENDENTE do bypass. O CharacterActions (CA) e o
-- modulo do PROPRIO jogo que guarda o flag `State.Jumped`; ele existe com ou sem
-- o patch. Antes, o CA so era gravado quando o patch dava certo, entao num
-- executor sem debug.getupvalue (ou com o indice do upvalue diferente) o CA
-- ficava nil e o impulso NUNCA rodava -- o "nao aumenta o impulso" que o usuario
-- viu. Agora o CA e resolvido sempre, e re-tentado enquanto nao existir: o
-- loader sobe o hub na hora, entao e normal o CharacterActions ainda nao ter
-- replicado no primeiro frame.
--
-- O patch do upvalue em si segue por debug.getupvalue/setupvalue (primitivas de
-- executor). Se ele nao aplicar, o modulo NAO derruba o backend: o bypass fica
-- "unavailable" e o impulso continua funcionando. O Destroy SEMPRE restaura o
-- upvalue original se ele ainda for o nosso patch.
--
-- Sem UI aqui: quem monta o toggle/slider e o backend (viz. volleyball42.lua).
-- O modulo so publica Enable/Disable/SetImpulse/Start/Stop/Destroy.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local workspaceService = game:GetService("Workspace")

local Visual = {}
Visual.__index = Visual

Visual.Id = "DepHub_JumpAnywhere"
-- Caminho do modulo do jogo que guarda as acoes do personagem. E um ModuleScript
-- dentro de um Folder cujo nome e o do dev do mapa; resolvido lazy e sem
-- WaitForChild bloqueante.
Visual.ScriptPath = {"guilhermealone1", "CharacterScript", "CharacterActions"}
-- Indice do upvalue que guarda a funcao de checagem de pulo dentro de CA.Jump
-- (checkLinefault). O script do jogo nao exporta esse nome, entao a posicao e o
-- contrato observado; se mudar num patch, o assert de tipo pega.
Visual.CheckUpvalue = 3
-- Altura do pulo padrao do jogo, em studs: v^2 = 2*g*h com v=50, g=196.2.
Visual.DefaultJumpHeight = (50 * 50) / (2 * 196.2)
-- De quantos em quantos frames re-tenta achar o CharacterActions enquanto ele
-- nao existe (30 frames ~ 0.5s a 60fps). Sem isso, se o hub subir antes do
-- modulo do jogo replicar, o impulso nunca mais seria armado nesta sessao.
Visual.ResolveRetryFrames = 30
-- Numero minimo de frames entre dois impulsos. O gatilho e por BORDA (Jumped
-- false -> true), mas se o jogo piscar o flag isso evita empilhar boost.
Visual.ImpulseCooldownFrames = 3

local function childPath(root, path)
    local node = root
    for _, name in ipairs(path) do
        node = node and node:FindFirstChild(name)
    end
    return node
end

local function resolveCharacterActions()
    local module = childPath(workspaceService, Visual.ScriptPath)
    if not module then return nil end
    local ok, data = pcall(require, module)
    if not ok or type(data) ~= "table" then return nil end
    return data
end

local function getDebug()
    local env = type(getgenv) == "function" and getgenv() or _G
    local library = env.debug or debug
    if type(library) ~= "table" then return nil end
    if type(library.getupvalue) ~= "function" or type(library.setupvalue) ~= "function" then return nil end
    return library
end

-- Le um upvalue por indice tolerando as duas assinaturas de getupvalue que
-- circulam nos executores: (indice) -> nome, valor  OU  (indice) -> valor.
local function readUpvalue(library, fn, index)
    local ok, a, b = pcall(library.getupvalue, fn, index)
    if not ok then return nil, nil end
    if type(a) == "string" then return a, b end
    return nil, a
end

local function writeUpvalue(library, fn, index, value)
    local ok = pcall(library.setupvalue, fn, index, value)
    if not ok then return false end
    local _, current = readUpvalue(library, fn, index)
    return current == value
end

-- O flag de pulo do jogo virou "true" neste frame? Aceita booleano (o caso
-- documentado) e numero (um contador que sobe), porque os dois formatos
-- aparecem em versoes do script e tratar so booleano deixava o impulso morto.
local function jumpStarted(current, previous)
    if type(current) == "number" then
        return current > (tonumber(previous) or 0)
    end
    return current == true and previous ~= true
end

function Visual.new()
    local State = setmetatable({}, Visual)
    State.Active = false
    State.Impulse = 0          -- 0..150 (%)
    State.BypassReady = false  -- o patch de upvalue esta aplicado?
    State.BypassError = nil
    State.PreviousJumped = false
    State.Original = nil       -- funcao de check original, para restaurar
    State.Patched = nil
    State.CA = nil             -- CharacterActions do jogo (independente do patch)
    State.Connections = {}
    State.ResolveCountdown = 0 -- frames ate a proxima tentativa de achar o CA
    State.ImpulseCooldown = 0  -- frames ate poder aplicar o proximo impulso
    return State
end

-- Aplica o patch do upvalue de check. Devolve true se ficou aplicado.
--
-- O CA e gravado SEMPRE que for encontrado, ANTES de exigir o debug: o impulso
-- le `CA.State.Jumped` e nao depende do patch. So o patch exige a primitiva.
function Visual:_applyBypass()
    if self.BypassReady then return true end

    local ca = self.CA or resolveCharacterActions()
    if type(ca) == "table" then self.CA = ca end

    local library = getDebug()
    if not library then return false, "debug.getupvalue/setupvalue ausente no executor" end
    if not ca then return false, "CharacterActions indisponivel" end
    if type(ca.Jump) ~= "function" then return false, "CA.Jump ausente" end
    if type(ca.State) ~= "table" then return false, "CA.State ausente" end

    local _, original = readUpvalue(library, ca.Jump, Visual.CheckUpvalue)
    if type(original) ~= "function" then
        return false, "upvalue " .. Visual.CheckUpvalue .. " de CA.Jump nao e funcao"
    end

    -- "NoJump" e o veto do jogo: devolver nil equivale a "pode pular".
    local patched = function(...)
        local result = original(...)
        if result == "NoJump" then return nil end
        return result
    end

    if not writeUpvalue(library, ca.Jump, Visual.CheckUpvalue, patched) then
        return false, "falha ao escrever o upvalue"
    end

    self.Original = original
    self.Patched = patched
    self.BypassReady = true
    return true
end

function Visual:_restoreBypass()
    if not self.BypassReady or not self.CA then return end
    local library = getDebug()
    if library then
        local _, current = readUpvalue(library, self.CA.Jump, Visual.CheckUpvalue)
        -- So restaura se o upvalue ainda for o NOSSO patch (outro script pode
        -- ter patcheado depois; nao desfazemos o trabalho alheio as cegas).
        if current == self.Patched then
            writeUpvalue(library, self.CA.Jump, Visual.CheckUpvalue, self.Original)
        end
    end
    self.BypassReady = false
    self.Original = nil
    self.Patched = nil
end

-- No frame do pulo, forca a velocidade vertical para a altura padrao
-- multiplicada pelo impulso. Sem impulso (0%), mantem o pulo original.
function Visual:_applyImpulse()
    if not self.Active then return end
    if self.Impulse <= 0 then return end

    local player = Players.LocalPlayer
    local character = player and player.Character
    if not character then return end

    -- Pode haver mais de um HumanoidRootPart em Model malformado: pega o que
    -- realmente pertence ao Humanoid atual.
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local gravity = workspaceService and workspaceService.Gravity
    if type(gravity) ~= "number" or gravity <= 0 then return end

    local baseVelocity = math.sqrt(2 * gravity * Visual.DefaultJumpHeight)
    local multiplier = 1 + self.Impulse / 100
    local velocity = hrp.AssemblyLinearVelocity
    if type(velocity) ~= "table" and type(velocity) ~= "userdata" then return end

    -- Impulso e um BOOST de pulo: mantem X/Z (direcao) e sobe o Y.
    hrp.AssemblyLinearVelocity = Vector3.new(
        velocity.X,
        baseVelocity * multiplier,
        velocity.Z
    )
end

-- Resolve o CharacterActions se possivel e (se ainda nao houver patch) tenta
-- aplica-lo. Chamado no Start e re-tentado a cada ResolveRetryFrames enquanto o
-- CA estiver ausente OU o patch nao tiver entrado -- porque o hub sobe antes do
-- modulo do jogo replicar e o patch pode falhar por um motivo temporario.
function Visual:_arm()
    if not self.CA then
        local ca = resolveCharacterActions()
        if type(ca) == "table" then self.CA = ca end
    end
    if self.CA and not self.BypassReady then
        local ok, err = self:_applyBypass()
        if not ok then self.BypassError = err end
    end
    return self.BypassReady
end

function Visual:Start()
    if self.Active then return false end
    self.Active = true
    self.PreviousJumped = false
    self.ImpulseCooldown = 0
    self.ResolveCountdown = 0

    -- Resolve o CA e tenta o patch. O resultado do patch (ok/erro) e o que o
    -- backend usa pra avisar no toggle; o impulso nao depende dele.
    self:_arm()
    local bypassOk = self.BypassReady
    local bypassErr = (not bypassOk) and self.BypassError or nil

    local connection = RunService.Heartbeat:Connect(function()
        if not self.Active then return end

        -- Re-tenta achar o CA / aplicar o patch enquanto faltar um dos dois (o
        -- hub sobe na hora, entao e normal o CA ainda nao existir no load).
        if not self.CA or not self.BypassReady then
            self.ResolveCountdown = (self.ResolveCountdown or 0) - 1
            if self.ResolveCountdown <= 0 then
                self.ResolveCountdown = Visual.ResolveRetryFrames
                self:_arm()
            end
        end

        if self.ImpulseCooldown > 0 then
            self.ImpulseCooldown = self.ImpulseCooldown - 1
        end

        local ca = self.CA
        if not ca then return end

        local jumped = ca.State and ca.State.Jumped
        if jumpStarted(jumped, self.PreviousJumped) and self.ImpulseCooldown <= 0 then
            -- Aplica um frame depois: a velocidade do impulso so existe no
            -- frame seguinte ao pulo, igual ao script de referencia.
            self.ImpulseCooldown = Visual.ImpulseCooldownFrames
            task.spawn(function()
                RunService.Heartbeat:Wait()
                self:_applyImpulse()
            end)
        end

        self.PreviousJumped = jumped
    end)
    self.Connections[#self.Connections + 1] = connection

    return bypassOk, bypassErr
end

function Visual:Stop()
    if not self.Active and not self.BypassReady then return end
    self.Active = false
    self.PreviousJumped = false
    self.ImpulseCooldown = 0

    for _, connection in ipairs(self.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    self.Connections = {}

    self:_restoreBypass()
    return true
end

-- Impulso em % (0-150). 0 = so o bypass, pulo original.
function Visual:SetImpulse(percent)
    if type(percent) ~= "number" then return false end
    self.Impulse = math.clamp(math.floor(percent + 0.5), 0, 150)
    return true
end

function Visual:Destroy()
    self:Stop()
    self.CA = nil
    return true
end

return Visual
