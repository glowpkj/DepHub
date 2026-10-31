-- Volleyball 4.2 - Jump Anywhere + impulso extra. Um unico recurso, um unico
-- toggle: liga as DUAS coisas juntas --
--   1) JUMP BYPASS: patcheia o upvalue de checagem dentro de
--      CharacterActions.Jump para que "NoJump" (o veto de pulo do jogo) vire
--      nil; dali pra frente o pulo funciona em qualquer lugar da quadra.
--   2) IMPULSO EXTRA: quando o jogador pula de fato (CA.State.Jumped sobe), no
--      frame seguinte forca AssemblyLinearVelocity.Y para a velocidade de altura
--      padrao * (1 + Aumento/100). Sem impulso (0%), o pulo original fica igual.
--
-- O patch e por upvalue, via debug.getupvalue/setupvalue (primitivas de
-- executor). Se o executor nao expuser debug/upvalue, o modulo NAO derruba o
-- backend: o bypass fica "unavailable" e o impulso continua funcionando. O
-- Destroy SEMPRE restaura o upvalue original se ele ainda for o nosso patch.
--
-- Sem UI aqui: quem monta o toggle/slider e o backend (viz. volleyball42.lua).
-- O modulo so publica Enable/Disable/SetImpulse/Start/Stop/Destroy.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Visual = {}

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

local function childPath(root, path)
    local node = root
    for _, name in ipairs(path) do
        node = node and node:FindFirstChild(name)
    end
    return node
end

local function resolveCharacterActions()
    local workspaceService = game:GetService("Workspace")
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

function Visual.new()
    local State = {
        Active = false,
        Impulse = 0,          -- 0..150 (%)
        BypassReady = false,  -- o patch de upvalue esta aplicado?
        PreviousJumped = false,
        Original = nil,       -- funcao de check original, para restaurar
        Patched = nil,
        CA = nil,
        Connections = {},
    }

    local function connect(signal, callback)
        local connection = signal:Connect(callback)
        State.Connections[#State.Connections + 1] = connection
        return connection
    end

    -- Aplica o patch do upvalue de check. Devolve true se ficou aplicado.
    local function applyBypass()
        if State.BypassReady then return true end
        local library = getDebug()
        if not library then return false, "debug.getupvalue/setupvalue ausente no executor" end

        local ca = resolveCharacterActions()
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

        State.CA = ca
        State.Original = original
        State.Patched = patched
        State.BypassReady = true
        return true
    end

    local function restoreBypass()
        if not State.BypassReady or not State.CA then return end
        local library = getDebug()
        if library then
            local _, current = readUpvalue(library, State.CA.Jump, Visual.CheckUpvalue)
            -- So restaura se o upvalue ainda for o NOSSO patch (outro script pode
            -- ter patcheado depois; nao desfazemos o trabalho alheio as cegas).
            if current == State.Patched then
                writeUpvalue(library, State.CA.Jump, Visual.CheckUpvalue, State.Original)
            end
        end
        State.BypassReady = false
        State.Original = nil
        State.Patched = nil
    end

    -- No frame do pulo, força a velocidade vertical para a altura padrao
    -- multiplicada pelo impulso. Sem impulso (0%), mantem o pulo original.
    local function applyImpulse()
        if not State.Active then return end
        if State.Impulse <= 0 then return end
        local player = Players.LocalPlayer
        local character = player and player.Character
        if not character then return end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local gravity = workspace.Gravity
        if type(gravity) ~= "number" or gravity <= 0 then return end

        local baseVelocity = math.sqrt(2 * gravity * Visual.DefaultJumpHeight)
        local multiplier = 1 + State.Impulse / 100
        local velocity = hrp.AssemblyLinearVelocity
        if type(velocity) ~= "table" and type(velocity) ~= "userdata" then return end

        hrp.AssemblyLinearVelocity = Vector3.new(
            velocity.X,
            baseVelocity * multiplier,
            velocity.Z
        )
    end

    function State:Start()
        if self.Active then return false end
        self.Active = true

        local bypassOk, bypassErr = applyBypass()
        if not bypassOk then
            -- Nao e fatal: o impulso funciona sozinho. O backend sinaliza no
            -- toggle se o bypass nao entrou.
            self.BypassReady = false
            self.BypassError = bypassErr
        end

        connect(RunService.Heartbeat, function()
            if not self.Active or not self.CA then return end
            local jumped = self.CA.State and self.CA.State.Jumped

            if jumped and not self.PreviousJumped then
                -- Aplica um frame depois: a velocidade do impulso so existe no
                -- frame seguinte ao pulo, igual ao script de referencia.
                task.spawn(function()
                    RunService.Heartbeat:Wait()
                    applyImpulse()
                end)
            end

            self.PreviousJumped = jumped
        end)

        return bypassOk, bypassErr
    end

    function State:Stop()
        if not self.Active and not self.BypassReady then return end
        self.Active = false
        self.PreviousJumped = false

        for _, connection in ipairs(self.Connections) do
            pcall(function() connection:Disconnect() end)
        end
        self.Connections = {}

        restoreBypass()
        return true
    end

    -- Impulso em % (0-150). 0 = so o bypass, pulo original.
    function State:SetImpulse(percent)
        if type(percent) ~= "number" then return false end
        self.Impulse = math.clamp(math.floor(percent + 0.5), 0, 150)
        return true
    end

    return State
end

return Visual
