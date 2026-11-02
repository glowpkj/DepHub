-- Steal An Exu -- Auto Steal Exu (toggle).
--
-- O mecanismo e' o script de referencia do usuario. Ligado, ele:
--
--   1) monta a lista de alvos: cada filho do workspace.Runtime com
--      Root.ProximityPrompt ({prompt, ref = Root});
--   2) cicla pela lista (i = i % #targets + 1);
--   3) se o alvo atual sumiu, REMONTA a lista UMA vez (o Runtime muda o tempo
--      todo: exu clonado/removido pelo servidor) e tenta de novo;
--   4) abre o prompt (MaxActivationDistance=1000, HoldDuration=0,
--      RequiresLineOfSight=false) e teleporta pra ref.Position + Vector3.new(0,3,0);
--   5) task.wait(0.15), dispara (InputHoldBegin + InputHoldEnd, dentro de pcall);
--   6) volta pra posicao original, task.wait(0.1), proximo.
--
-- A UNICA diferenca pro script original e' o passo 3: ele nunca fica preso a uma
-- lista velha. Com o mundo estavel isso nunca dispara (a lista segue a mesma);
-- ele so reage quando o alvo sumiu -- que era o "as vezes nao pega o prompt".
-- Nada mais mudou: sem noclip, sem ancoragem, sem mapear a base.
--
-- API: AutoSteal.new(ctx) -> obj com SetEnabled(on) / IsEnabled() / Destroy() e o
--      campo Enabled.

local game = game
local task = task
local type = type
local pcall = pcall
local tostring = tostring
local table = table
local select = select

-- TEMPOS (iguais ao script de referencia).
local SETTLE_WAIT = 0.15   -- depois do teleporte, antes de disparar
local POST_WAIT = 0.1      -- depois de disparar, ao voltar pra base

local AutoSteal = {}
AutoSteal.__index = AutoSteal

-- --- Debug ----------------------------------------------------------------

AutoSteal.DebugEnabled = true
local DEBUG_TAG = "[StealAnExu]"
local env = type(getgenv) == "function" and getgenv() or _G

local function debugLog(self, ...)
    local parts = {}
    for index = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(index, ...))
    end
    local message = DEBUG_TAG .. " Steal: " .. table.concat(parts, " ")
    self.DebugLog = self.DebugLog or {}
    self.DebugLog[#self.DebugLog + 1] = message
    if #self.DebugLog > 200 then table.remove(self.DebugLog, 1) end
    if AutoSteal.DebugEnabled then
        print(message)
        local diag = env.__DEPHUB and env.__DEPHUB.Diagnostics
        if type(diag) == "table" and type(diag.Note) == "function" then
            pcall(diag.Note, diag, message)
        end
    end
end

-- --- Construtor -----------------------------------------------------------

function AutoSteal.new(ctx)
    local self = setmetatable({}, AutoSteal)
    self.Ctx = ctx or {}
    self.Enabled = false
    self.Thread = nil
    self.LastError = nil
    self.Destroyed = false
    self.DebugLog = {}
    return self
end

function AutoSteal:Logs()
    return self.DebugLog or {}
end

function AutoSteal:IsEnabled()
    return self.Enabled == true
end

-- --- Personagem -----------------------------------------------------------

-- O HumanoidRootPart do personagem (o script de referencia escreve a CFrame nele).
function AutoSteal:_root()
    local player = game:GetService("Players").LocalPlayer
    local character = player and player.Character
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart")
end

-- --- O loop (o script de referencia) --------------------------------------

-- Coleta a lista de alvos: {prompt, ref = Root} de cada filho do Runtime que tem
-- Root.ProximityPrompt. Devolve a lista, ou nil + motivo. O loop remonta a lista
-- quando o alvo atual sumiu (o Runtime muda o tempo todo).
function AutoSteal:_targets()
    local runtime = game:GetService("Workspace"):FindFirstChild("Runtime")
    if not runtime then
        return nil, "workspace.Runtime nao encontrado"
    end
    local targets = {}
    for _, child in ipairs(runtime:GetChildren()) do
        local ref = child:FindFirstChild("Root")
        local prompt = ref and ref:FindFirstChild("ProximityPrompt")
        if prompt then
            targets[#targets + 1] = {prompt = prompt, ref = ref}
        end
    end
    return targets
end

-- Um alvo esta vivo? O prompt existe, ainda esta na arvore, e a ref tambem.
function AutoSteal:_alive(target)
    return target ~= nil
        and target.prompt ~= nil and target.prompt.Parent ~= nil
        and target.ref ~= nil and target.ref.Parent ~= nil
end

-- UM passo (a iteracao do script de referencia) no alvo `target`:
--   abre o prompt, teleporta pra cima do Root, espera, dispara, volta.
-- Separado do while pra o teste poder dirigir uma iteracao por vez (o harness
-- nao roda o loop infinito). O mecanismo e' identico ao script.
function AutoSteal:_step(target, root, originalPos)
    local prompt = target and target.prompt
    local ref = target and target.ref
    if not prompt or not ref then return false end

    -- Abre o prompt.
    pcall(function() prompt.MaxActivationDistance = 1000 end)
    pcall(function() prompt.HoldDuration = 0 end)
    pcall(function() prompt.RequiresLineOfSight = false end)

    -- Teleporta pra cima do Root.
    local pos = ref.Position
    pcall(function() root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) end)
    task.wait(SETTLE_WAIT)

    -- Dispara.
    pcall(function()
        prompt:InputHoldBegin()
        prompt:InputHoldEnd()
    end)

    -- Volta.
    pcall(function() root.CFrame = originalPos end)
    task.wait(POST_WAIT)

    return true
end

function AutoSteal:_loop()
    local root = self:_root()
    if not root then
        self.LastError = "sem personagem"
        debugLog(self, "ABORTA: sem personagem")
        return
    end

    -- Posicao original: pra onde voltar depois de cada roubo.
    local originalPos = root.CFrame

    local targets, reason = self:_targets()
    if not targets then
        self.LastError = reason
        debugLog(self, "ABORTA:", tostring(reason))
        return
    end

    debugLog(self, "Encontrados", #targets, "prompts")

    if #targets == 0 then
        self.LastError = "Nenhum ProximityPrompt encontrado"
        debugLog(self, "ABORTA: nenhum ProximityPrompt encontrado")
        return
    end

    local i = 1
    while self.Enabled do
        local t = targets[i]

        -- Alvo morto (o servidor levou o exu): remonta a lista UMA vez -- assim um
        -- exu que apareceu no Runtime DEPOIS do toggle entra na proxima passada,
        -- em vez de ficar de fora pra sempre. So remonta quando o alvo sumiu; com
        -- o mundo estavel a lista segue a mesma (nada muda pro script original).
        if not self:_alive(t) then
            local refreshed = select(1, self:_targets())
            if refreshed and #refreshed > 0 then
                targets = refreshed
            end
            i = i % #targets + 1
        else
            self:_step(t, root, originalPos)
            i = i % #targets + 1
        end
    end

    self.Thread = nil
    debugLog(self, "loop Auto Steal Exu parado")
end

-- --- Ligar / desligar -----------------------------------------------------

-- Idempotente: ligar duas vezes nao abre dois loops; desligar duas vezes nao
-- quebra. Ao desligar, o loop sai no proximo tick (self.Enabled = false).
function AutoSteal:SetEnabled(on)
    on = on == true
    if self.Destroyed then
        debugLog(self, "SetEnabled ignorado: feature destruida")
        return false
    end
    if on == self.Enabled then return true end
    self.Enabled = on
    if on then
        self.LastError = nil
        debugLog(self, "ON")
        self.Thread = task.spawn(function()
            local ok, err = pcall(function() return self:_loop() end)
            if not ok then
                self.LastError = tostring(err)
                debugLog(self, "ERRO no loop:", tostring(err))
            end
        end)
    else
        debugLog(self, "OFF")
    end
    return true
end

function AutoSteal:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self.Enabled = false
    if self.Thread then
        pcall(task.cancel, self.Thread)
        self.Thread = nil
    end
    self.DebugLog = {}
end

-- Devolve a fabrica.
return AutoSteal
