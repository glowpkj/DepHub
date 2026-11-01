-- Volleyball 4.2 - Jump Anywhere + impulso extra. Um unico recurso, um unico
-- toggle: liga as DUAS coisas juntas --
--   1) IMPULSO EXTRA: quando o jogador pula de fato, no frame seguinte
--      multiplica AssemblyLinearVelocity.Y por (1 + Aumento/100). Este e o
--      recurso PRINCIPAL e o unico que depende so do proprio personagem
--      (Humanoid) -- nao precisa de modulo nenhum do jogo.
--   2) JUMP BYPASS (best-effort): procura o modulo CharacterActions do jogo e
--      patcheia o upvalue de checagem de pulo para que "NoJump" (o veto) vire
--      nil. Se o modulo nao existir / o executor nao tiver debug.getupvalue, o
--      bypass apenas nao entra -- o IMPULSO continua funcionando com o Humanoid.
--
-- Historico do bug: antes, o impulso rodava dentro de um heartbeat que exigia
-- `self.CA` (o CharacterActions). Como o CA so era gravado quando o patch do
-- upvalue dava certo -- e neste jogo o caminho do modulo nem batia -- o CA ficava
-- nil e o impulso NUNCA rodava. O log do usuario provava: "CharacterActions
-- indisponivel" e depois "bypass". Agora o impulso nao depende disso.
--
-- O gatilho do impulso e o EVENTO do Humanoid (`Jumping`) e, como reserva, a
-- transicao para o ar (FloorMaterial/GetState) com velocidade vertical subindo.
-- O flag CA.State.Jumped fica como terceiro gatilho. Um cooldown curto evita
-- aplicar duas vezes o mesmo pulo.
--
-- Sem UI aqui: quem monta o toggle/slider e o backend (viz. volleyball42.lua).
-- O modulo so publica new/Start/Stop/SetImpulse/Destroy.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspaceService = game:GetService("Workspace")

local Visual = {}
Visual.__index = Visual

Visual.Id = "DepHub_JumpAnywhere"
-- Caminho preferido do modulo do jogo que guarda as acoes do personagem. E um
-- ModuleScript dentro de um Folder cujo nome e o do dev do mapa. Se esse caminho
-- mudar (o dev renomeia a pasta), resolveCharacterActions cai pra busca recursiva
-- por nome no Workspace.
Visual.ScriptPath = {"guilhermealone1", "CharacterScript", "CharacterActions"}
Visual.ScriptName = "CharacterActions"
-- Indice PREFERIDO do upvalue de checagem dentro de CA.Jump. Nao e o unico: se
-- o upvalue desse indice nao for a funcao de check, findCheckUpvalue procura uma
-- funcao cujo nome contenha "check" e, na falta dela, a primeira funcao. O script
-- do jogo nao exporta o nome, entao confiar so no indice quebrava num build novo.
Visual.CheckUpvalue = 3
-- Re-tenta achar o CharacterActions / aplicar o patch a cada N frames enquanto
-- faltar um dos dois (o hub sobe na hora; o modulo do jogo pode vir depois).
Visual.ResolveRetryFrames = 30
-- Frames de re-tentativa do impulso quando a velocidade do pulo ainda nao foi
-- escrita pela fisica. Curto de proposito: cobre a corrida sem empilhar boost.
Visual.ImpulseRetryFrames = 4
-- Frames minimos entre dois impulsos. Vários gatilhos podem ver o mesmo pulo.
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
    if not module then
        -- O caminho fixo pode ter mudado, ou o modulo pode morar fora do
        -- Workspace (ReplicatedStorage e o lugar comum para um ModuleScript de
        -- cliente). Procura pelo nome, recursivamente, nos dois.
        for _, root in ipairs({workspaceService, ReplicatedStorage}) do
            local ok, found = pcall(function()
                return root:FindFirstChild(Visual.ScriptName, true)
            end)
            if ok and found then module = found; break end
        end
    end
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

-- Acha o upvalue que guarda a checagem de pulo. Prefere o indice conhecido; se
-- ele nao for funcao, procura um nome com "check"; por ultimo aceita a primeira
-- funcao. Devolve indice, valor (ou nil).
local function findCheckUpvalue(library, fn, preferred)
    local firstFunction
    for index = 1, 64 do
        local name, value = readUpvalue(library, fn, index)
        if value == nil then break end
        if type(value) == "function" then
            if index == preferred then return index, value end
            if not firstFunction then firstFunction = {index, value} end
            if type(name) == "string" and name:lower():find("check", 1, true) then
                return index, value
            end
        end
    end
    if firstFunction then return firstFunction[1], firstFunction[2] end
    return nil, nil
end

-- O flag de pulo do jogo virou "true" neste frame? Aceita booleano (o caso
-- documentado) e numero (um contador que sobe).
local function jumpStarted(current, previous)
    if type(current) == "number" then
        return current > (tonumber(previous) or 0)
    end
    return current == true and previous ~= true
end

-- O Humanoid do personagem atual, ou nil.
local function currentHumanoid()
    local player = Players.LocalPlayer
    local character = player and player.Character
    if not character then return nil end
    return character:FindFirstChildOfClass("Humanoid")
end

-- O personagem esta no ar? Devolve true/false, ou nil quando nao da pra saber
-- (executor/sandbox sem FloorMaterial e sem GetState). nil significa "nao usa
-- este sinal".
local function isAirborne(humanoid)
    local floor = humanoid.FloorMaterial
    if floor ~= nil then
        return floor == Enum.Material.Air
    end
    local ok, state = pcall(humanoid.GetState, humanoid)
    if ok then
        return state == Enum.HumanoidStateType.Jumping
            or state == Enum.HumanoidStateType.Freefall
    end
    return nil
end

function Visual.new()
    local self = setmetatable({}, Visual)
    self.Active = false
    self.Impulse = 0          -- 0..150 (%)
    self.BypassReady = false  -- o patch de upvalue esta aplicado?
    self.BypassError = nil
    self.CA = nil             -- CharacterActions do jogo (opcional)
    self.CheckIndex = nil     -- indice do upvalue que patchamos
    self.Original = nil
    self.Patched = nil
    self.Connections = {}
    self.HumanoidConnections = {}
    self.Humanoid = nil
    self.WasAirborne = false
    self.PreviousJumped = false
    self.ResolveCountdown = 0
    self.ImpulseCooldown = 0
    return self
end

-- Aplica o patch do upvalue de check. Devolve true se ficou aplicado.
--
-- O CA e gravado SEMPRE que for encontrado, ANTES de exigir o debug: o impulso
-- nao depende do patch. So o patch exige a primitiva.
function Visual:_applyBypass()
    if self.BypassReady then return true end
    local library = getDebug()
    if not library then return false, "debug.getupvalue/setupvalue ausente no executor" end
    local ca = self.CA
    if not ca then return false, "CharacterActions indisponivel" end
    if type(ca.Jump) ~= "function" then return false, "CA.Jump ausente" end
    if type(ca.State) ~= "table" then return false, "CA.State ausente" end

    local index, original = findCheckUpvalue(library, ca.Jump, Visual.CheckUpvalue)
    if type(original) ~= "function" then
        return false, "nenhum upvalue de funcao em CA.Jump"
    end

    -- "NoJump" e o veto do jogo: devolver nil equivale a "pode pular". Para
    -- qualquer outro retorno, o wrapper e um repasse identico -- patchar o
    -- upvalue errado nao muda comportamento nenhum.
    local patched = function(...)
        local result = original(...)
        if result == "NoJump" then return nil end
        return result
    end

    if not writeUpvalue(library, ca.Jump, index, patched) then
        return false, "falha ao escrever o upvalue"
    end

    self.CheckIndex = index
    self.Original = original
    self.Patched = patched
    self.BypassReady = true
    return true
end

function Visual:_restoreBypass()
    if not self.BypassReady or not self.CA then return end
    local library = getDebug()
    if library and self.CheckIndex then
        local _, current = readUpvalue(library, self.CA.Jump, self.CheckIndex)
        -- So restaura se o upvalue ainda for o NOSSO patch (outro script pode
        -- ter patcheado depois; nao desfazemos o trabalho alheio as cegas).
        if current == self.Patched then
            writeUpvalue(library, self.CA.Jump, self.CheckIndex, self.Original)
        end
    end
    self.BypassReady = false
    self.CheckIndex = nil
    self.Original = nil
    self.Patched = nil
end

-- Tenta resolver o CA e aplicar o patch. Nunca derruba nada: guarda o motivo em
-- BypassError. O impulso nao depende do resultado.
function Visual:_arm()
    if not self.CA then
        local ca = resolveCharacterActions()
        if type(ca) == "table" then self.CA = ca end
    end
    if not self.CA then
        self.BypassError = "CharacterActions indisponivel"
        return false
    end
    if not self.BypassReady then
        local ok, err = self:_applyBypass()
        if not ok then self.BypassError = err end
    end
    return self.BypassReady
end

-- Liga/religa os eventos do Humanoid atual (Jumping/StateChanged). Re-chamado
-- todo frame para acompanhar respawn (o Humanoid muda).
function Visual:_watchHumanoid()
    local humanoid = currentHumanoid()
    if humanoid == self.Humanoid then return end

    for _, connection in ipairs(self.HumanoidConnections) do
        pcall(function() connection:Disconnect() end)
    end
    self.HumanoidConnections = {}
    self.Humanoid = humanoid
    self.WasAirborne = false
    if not humanoid then return end

    -- `Jumping` e o sinal ideal: dispara no inicio do pulo. Em sandbox/executor
    -- que nao exponha o sinal, o pcall apenas falha e o gatilho de estado cobre.
    pcall(function()
        local connection = humanoid.Jumping:Connect(function()
            self:_queueImpulse()
        end)
        self.HumanoidConnections[#self.HumanoidConnections + 1] = connection
    end)
    pcall(function()
        local connection = humanoid.StateChanged:Connect(function(_, newState)
            if newState == Enum.HumanoidStateType.Jumping
                or newState == Enum.HumanoidStateType.Freefall then
                self:_queueImpulse()
            end
        end)
        self.HumanoidConnections[#self.HumanoidConnections + 1] = connection
    end)
end

-- Pede um impulso para o proximo frame, respeitando o cooldown. Pode ser
-- chamado por varios gatilhos vendo o mesmo pulo.
function Visual:_queueImpulse()
    if not self.Active or self.Impulse <= 0 then return end
    if self.ImpulseCooldown > 0 then return end
    self.ImpulseCooldown = Visual.ImpulseCooldownFrames
    -- Aplica um frame depois: a velocidade do pulo so esta posta no frame
    -- seguinte, igual ao script de referencia. Se ela ainda nao estiver (corrida
    -- com a fisica), re-tenta por alguns frames -- sem NUNCA inventar um pulo
    -- para um personagem parado no chao.
    task.spawn(function()
        for _ = 1, Visual.ImpulseRetryFrames do
            RunService.Heartbeat:Wait()
            if not self.Active then return end
            if self:_applyImpulse() then return end
        end
    end)
end

-- Multiplica a velocidade vertical REAL do pulo pelo impulso. Devolve true
-- quando nao ha mais o que tentar (aplicou, ou nao ha alvo). Devolve false
-- apenas quando o personagem ainda nao esta subindo -- o chamador re-tenta.
function Visual:_applyImpulse()
    if not self.Active then return true end
    if self.Impulse <= 0 then return true end

    local player = Players.LocalPlayer
    local character = player and player.Character
    if not character then return true end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return true end

    local velocity = hrp.AssemblyLinearVelocity
    if type(velocity) ~= "table" and type(velocity) ~= "userdata" then return true end
    -- So impulsa um PULO em subida. Velocidade negativa e queda de borda;
    -- zero e personagem parado (o pulo ainda nao foi escrito). Nos dois casos
    -- nao ha impulso a dar -- e nunca transformamos um deles em salto.
    if velocity.Y <= 0 then return false end

    local multiplier = 1 + self.Impulse / 100
    hrp.AssemblyLinearVelocity = Vector3.new(
        velocity.X,
        velocity.Y * multiplier,
        velocity.Z
    )
    return true
end

function Visual:Start()
    if self.Active then return false end
    self.Active = true
    self.PreviousJumped = false
    self.ImpulseCooldown = 0
    self.ResolveCountdown = 0
    self.WasAirborne = false

    -- Resolve o CA e tenta o patch (best-effort). O resultado e o que o backend
    -- usa pra avisar no toggle; o IMPULSO nao depende dele.
    self:_arm()
    local bypassOk = self.BypassReady
    local bypassErr = (not bypassOk) and (self.BypassError or "bypass") or nil

    -- Liga o Humanoid atual de imediato (se ja existir).
    self:_watchHumanoid()

    local connection = RunService.Heartbeat:Connect(function()
        if not self.Active then return end

        -- Retry do bypass/CA enquanto faltar um dos dois.
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

        -- Acompanha respawn e liga os eventos do Humanoid atual.
        self:_watchHumanoid()

        -- Gatilho de RESERVA: subiu para o ar com velocidade positiva. Cobre
        -- executor/sandbox onde o sinal `Jumping` nao chega.
        local humanoid = self.Humanoid
        if humanoid then
            local airborne = isAirborne(humanoid)
            if airborne ~= nil then
                local player = Players.LocalPlayer
                local character = player and player.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                local rising = hrp and hrp.AssemblyLinearVelocity.Y > 1
                if airborne and not self.WasAirborne and rising then
                    self:_queueImpulse()
                end
                self.WasAirborne = airborne
            end
        end

        -- Gatilho terciario: o flag do CharacterActions, quando existir.
        local ca = self.CA
        if ca then
            local jumped = ca.State and ca.State.Jumped
            if jumpStarted(jumped, self.PreviousJumped) then
                self:_queueImpulse()
            end
            self.PreviousJumped = jumped
        end
    end)
    self.Connections[#self.Connections + 1] = connection

    return bypassOk, bypassErr
end

function Visual:Stop()
    if not self.Active and not self.BypassReady then return end
    self.Active = false
    self.PreviousJumped = false
    self.ImpulseCooldown = 0
    self.WasAirborne = false

    for _, connection in ipairs(self.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    self.Connections = {}

    for _, connection in ipairs(self.HumanoidConnections) do
        pcall(function() connection:Disconnect() end)
    end
    self.HumanoidConnections = {}
    self.Humanoid = nil

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
