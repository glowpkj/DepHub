-- Volleyball 4.2 - esqueleto do backend. As features antigas (previsao da bola,
-- auto position, pulo forcado, ceiling noclip, Auto Set Aim, parts de set) foram
-- removidas para recomecar do zero. O que fica e so a AUTOMACAO DAS ACOES DO
-- JOGO: o modulo features/volleyball/actions.lua mapeia os remotes/animacoes
-- reais (set frontal/back, spike, block, bump, dive, spawn da bola, serve) e o
-- backend expoe isso como State:Act(nome, ...) para as features novas usarem.

local game, task, type, tostring, pcall = game, task, type, tostring, pcall
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local env = type(getgenv) == "function" and getgenv() or _G
local STATE_KEY = "__DEPHUB_VOLLEYBALL42"
local BASE_URL = ((type(getgenv) == "function" and getgenv() or _G).__DEPHUB or {}).SourceBaseURL or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"

-- Um reload limpo: derruba a sessao anterior (cancela serve pendente, etc.).
local previous = env[STATE_KEY]
if type(previous) == "table" and type(previous.Destroy) == "function" then
    pcall(previous.Destroy, previous)
end

if not LocalPlayer then
    return false
end

-- Carrega os remotes/animacoes de acao do jogo a partir do modulo de feature.
-- Nao bloquear o load se falhar: o backend ainda sobe, so as acoes ficam
-- indisponiveis (State:Act devolve false, "unavailable").
local function loadActions()
    local cacheBust = tostring((env.__DEPHUB or {}).SourceCacheBust or "")
    local okGet, source = pcall(function()
        return game:HttpGet(BASE_URL .. "src/games/features/volleyball/actions.lua" .. (cacheBust ~= "" and ("?cb=" .. cacheBust) or ""))
    end)
    if not okGet or type(source) ~= "string" or #source == 0 then return nil, tostring(source) end
    local okCompile, chunk, compileError = pcall(loadstring, source)
    if not okCompile or type(chunk) ~= "function" then return nil, tostring(compileError or chunk) end
    local okRun, module = pcall(chunk)
    if not okRun or type(module) ~= "table" or type(module.Set) ~= "function" then return nil, tostring(module) end
    return module
end

local Actions, actionsError = loadActions()
if not Actions then
    warn("[DepHub] Volleyball actions unavailable: " .. tostring(actionsError))
end

-- Carrega o modulo de Jump Anywhere + impulso (um unico recurso, um unico
-- toggle). Nao bloquear o load se falhar: sem ele o backend sobe e o toggle
-- reporta indisponivel.
local function loadFeature(relativePath, validate)
    local cacheBust = tostring((env.__DEPHUB or {}).SourceCacheBust or "")
    local okGet, source = pcall(function()
        return game:HttpGet(BASE_URL .. relativePath .. (cacheBust ~= "" and ("?cb=" .. cacheBust) or ""))
    end)
    if not okGet or type(source) ~= "string" or #source == 0 then return nil, tostring(source) end
    local okCompile, chunk, compileError = pcall(loadstring, source)
    if not okCompile or type(chunk) ~= "function" then return nil, tostring(compileError or chunk) end
    local okRun, module = pcall(chunk)
    if not okRun or type(module) ~= "table" or not validate(module) then return nil, tostring(module) end
    return module
end

local JumpAnywhere, jumpError = loadFeature("src/games/features/volleyball/jump-anywhere.lua", function(module)
    return type(module.new) == "function"
end)
if not JumpAnywhere then
    warn("[DepHub] Volleyball jump feature unavailable: " .. tostring(jumpError))
end

local State = {
    Version = "0.3.0",
    Destroyed = false,
    Started = false,
    Actions = Actions,
    ActionLog = {Actions = 0},
    Serving = false,
    ServeTask = nil,
    LastAnimation = nil,
    LastError = nil,
    -- Um unico recurso ligado a um unico toggle: jump bypass + impulso.
    Jump = nil,
    JumpEnabled = false,
    JumpImpulse = 25,
}

-- O modulo de acoes conta os disparos via actor.Log; aponta para o log do State.
State.Log = State.ActionLog

env[STATE_KEY] = State
env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.Volleyball42 = State

-- Superficie publica das acoes do jogo para as automacoes (e verificacao). O
-- ator e o proprio State: ele guarda a contagem de acoes, a task do serve e o
-- LastAnimation, entao o Destroy consegue cancelar um serve em andamento.
function State:Act(name, ...)
    if self.Destroyed then return false, "destroyed" end
    local action = self.Actions and self.Actions[name]
    if type(action) ~= "function" then return false, "unavailable" end
    local ok, result, err = pcall(action, self, ...)
    if not ok then
        self.LastError = tostring(result)
        return false, self.LastError
    end
    return result, err
end

function State:Start()
    if self.Started or self.Destroyed then return false end
    self.Started = true
    return true
end

-- === JUMP ANYWHERE (bypass + impulso) ===

-- Uma unica chave liga as duas partes: o bypass (pular em qualquer lugar) e o
-- impulso (acelerar o pulo). O slider so muda a intensidade do impulso; com 0%
-- fica so o bypass, com o pulo original.
--
-- Devolve true quando ligou. Se o bypass nao pode ser aplicado (executor sem
-- debug.getupvalue/setupvalue, ou o modulo do jogo ausente), a feature ainda
-- liga para o IMPULSO e devolve false, "unavailable:<motivo>" para a UI avisar
-- -- nunca derruba o backend por causa disso.
function State:SetJumpEnabled(enabled)
    if self.Destroyed then return false end
    local wanted = enabled == true

    if wanted then
        if not self.Jump then return false, "unavailable:feature" end
        if not self.JumpEnabled then
            self.Jump:SetImpulse(self.JumpImpulse)
            local bypassOk, bypassErr = self.Jump:Start()
            self.JumpEnabled = true
            if bypassOk ~= true then return false, "unavailable:" .. tostring(bypassErr or "bypass") end
        end
    else
        if self.Jump and self.JumpEnabled then self.Jump:Stop() end
        self.JumpEnabled = false
    end
    return true
end

-- Impulso em % (0-150). Grava sempre; o efeito so vale com o toggle ligado.
function State:SetJumpImpulse(percent)
    if self.Destroyed then return false end
    local value = math.clamp(math.floor((tonumber(percent) or 0) + 0.5), 0, 150)
    self.JumpImpulse = value
    if self.Jump and self.JumpEnabled then self.Jump:SetImpulse(value) end
    return true
end

function State:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true

    -- Desliga o recurso de pulo (restaura o upvalue original do jogo e desconecta).
    if self.Jump then
        pcall(self.Jump.Stop, self.Jump)
        self.Jump = nil
    end
    self.JumpEnabled = false

    -- Cancela um serve em andamento (ele tem um task.wait interno) para nao
    -- disparar "Serving" depois do unload.
    if self.Actions and type(self.Actions.Cancel) == "function" then
        pcall(self.Actions.Cancel, self)
    end

    if env[STATE_KEY] == self then
        env[STATE_KEY] = nil
    end
    if env.__DEPHUB and env.__DEPHUB.Volleyball42 == self then
        env.__DEPHUB.Volleyball42 = nil
    end
end

-- Instancia o recurso de pulo (mecanismo pronto; so liga quando o toggle ligar).
if JumpAnywhere then
    State.Jump = JumpAnywhere.new()
end

State:Start()

-- ---------------------------------------------------------------------------
-- Apresentacao: uma aba Movement com uma secao e UM recurso. O toggle "Jump
-- Anywhere" liga o bypass + impulso juntos; o slider define a intensidade do
-- impulso. Cada um na sua linha: um SLIDER nao pode entrar num HStack estreito
-- (os internos dele sao ancorados a direita com offsets fixos, entao em meia
-- largura o label colapsa e os botoes -/+ vazam pra fora da borda).
-- ---------------------------------------------------------------------------
do
    local Kit = env.__DEPHUB and env.__DEPHUB.UIKit
    if Kit then
        local tab = Kit.Tab("Movement")
        local section = Kit.Section(tab, "Jump", "Left")
        if section then
            section:CreateToggle("Jump Anywhere", State.JumpEnabled, function(value)
                local ok, err = State:SetJumpEnabled(value)
                if not ok then
                    State.LastError = tostring(err)
                    warn("[DepHub] Jump Anywhere unavailable: " .. tostring(err))
                end
            end)
            section:CreateSlider("Impulse", 0, 150, State.JumpImpulse, function(value)
                State:SetJumpImpulse(value)
            end)
        end
    end
end

return State
