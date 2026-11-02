-- Steal An Exu - esqueleto do backend.
--
-- Ainda nao tem NENHUMA feature: o backend so sobe, publica o proprio estado e
-- fica pronto para as features que vierem. Sem UI, de proposito - quem monta
-- aba/secao aqui e a feature, quando existir. Assim o jogo ja e reconhecido pelo
-- hub (rota propria, nao cai no universal) e o script carrega limpo no executor.

local game, task, type, tostring, pcall = game, task, type, tostring, pcall
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local env = type(getgenv) == "function" and getgenv() or _G
local STATE_KEY = "__DEPHUB_STEALANEXU"

-- Um reload limpo: derruba a sessao anterior antes de subir a nova.
local previous = env[STATE_KEY]
if type(previous) == "table" and type(previous.Destroy) == "function" then
    pcall(previous.Destroy, previous)
end

if not LocalPlayer then
    return false
end

local State = {
    Version = "0.1.0",
    Destroyed = false,
    Started = false,
    Features = {},
    LastError = nil,
}

env[STATE_KEY] = State
env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.StealAnExu = State

-- Liga/desliga uma feature pelo nome. Ainda nao existem features: um nome
-- desconhecido devolve false em vez de criar estado fantasma. Quando as
-- features chegarem, cada uma se registra em State.Features e este metodo passa
-- a chama-la -- o contrato para quem for montar o painel ja fica definido.
function State:SetFeature(name, enabled)
    if self.Destroyed or type(name) ~= "string" then return false end
    local feature = self.Features[name]
    if type(feature) ~= "table" or type(feature.SetEnabled) ~= "function" then
        return false
    end
    local ok, result = pcall(feature.SetEnabled, feature, enabled == true)
    if not ok then
        self.LastError = tostring(result)
        return false
    end
    return result ~= false
end

function State:IsEnabled(name)
    if self.Destroyed or type(name) ~= "string" then return false end
    local feature = self.Features[name]
    if type(feature) ~= "table" then return false end
    if type(feature.IsEnabled) == "function" then return feature.IsEnabled(feature) == true end
    return feature.Enabled == true
end

function State:Start()
    if self.Started or self.Destroyed then return false end
    self.Started = true
    return true
end

function State:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true

    -- Derruba toda feature registrada (cada uma limpa o que ligou).
    for _, feature in pairs(self.Features) do
        if type(feature) == "table" and type(feature.Destroy) == "function" then
            pcall(feature.Destroy, feature)
        end
    end
    self.Features = {}

    if env[STATE_KEY] == self then
        env[STATE_KEY] = nil
    end
    if env.__DEPHUB and env.__DEPHUB.StealAnExu == self then
        env.__DEPHUB.StealAnExu = nil
    end
end

State:Start()

return State
