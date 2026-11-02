-- Steal An Exu - backend.
--
-- Esqueleto com uma feature: o Auto Steal Exu (src/games/features/stealanexu/
-- autosteal.lua). O backend sobe, carrega o modulo do repositorio, registra em
-- State.Features e monta a UI (categoria Farming, uma secao com o toggle e o
-- dropdown de Terreiro). A logica toda (teleporte, prompt, base) mora na feature.

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

local sourceBase = (env.__DEPHUB or {}).SourceBaseURL or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"

-- Mesmo caminho de fetch do backend do Blox Fruits: o resolver do bundle quando
-- existe (build empacotado), senao game:HttpGet (checkout por fonte).
local function fetch(path)
    local cb = tostring((env.__DEPHUB or {}).SourceCacheBust or "")
    local url = sourceBase .. path .. (cb ~= "" and ("?cb=" .. cb) or "")
    local resolver = (type(env.__dephubHttpGet) == "function" and env.__dephubHttpGet)
        or (type(env.__DEPHUB_HTTP_GET) == "function" and env.__DEPHUB_HTTP_GET)
        or (type(_G.__dephubHttpGet) == "function" and _G.__dephubHttpGet)
        or (type(_G.__DEPHUB_HTTP_GET) == "function" and _G.__DEPHUB_HTTP_GET)
    if resolver then
        local ok, source = pcall(resolver, url)
        if ok and type(source) == "string" and #source > 0 then return true, source end
    end
    local ok, source = pcall(function() return game:HttpGet(url) end)
    if ok and type(source) == "string" and #source > 0 then return true, source end
    return false, tostring(source)
end

-- Carrega um modulo de feature do repositorio. Nao derruba o backend se falhar:
-- sem a feature, o painel sobe e o toggle reporta indisponivel.
local function loadFeature(relativePath, validate)
    local okFetch, source = fetch(relativePath)
    if not okFetch then return nil, "fetch: " .. tostring(source) end
    local chunk, compileError = loadstring(source)
    if type(chunk) ~= "function" then return nil, "compile: " .. tostring(compileError) end
    local okRun, module = pcall(chunk)
    if not okRun or type(module) ~= "table" or not validate(module) then return nil, "run: " .. tostring(module) end
    return module
end

local AutoStealModule, autoStealError = loadFeature("src/games/features/stealanexu/autosteal.lua", function(module)
    return type(module.new) == "function"
end)

local State = {
    Version = "0.1.1",
    Destroyed = false,
    Started = false,
    Features = {},
    LastError = nil,
}

env[STATE_KEY] = State
env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.StealAnExu = State

-- Liga/desliga uma feature pelo nome. So age sobre uma feature registrada em
-- State.Features: um nome desconhecido devolve false em vez de criar estado
-- fantasma ou erro. E o contrato que a UI usa.
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

-- Instancia o Auto Steal Exu (mecanismo pronto; so roda quando o toggle ligar).
if AutoStealModule then
    State.AutoSteal = AutoStealModule.new()
    State.Features.AutoSteal = State.AutoSteal
else
    warn("[DepHub] Steal An Exu autosteal unavailable: " .. tostring(autoStealError))
end

State:Start()

-- ---------------------------------------------------------------------------
-- Apresentacao: categoria Farming, uma secao "Auto Steal Exu" com o toggle e o
-- dropdown do terreiro. Guardar um Terreiro aqui, na sua base, e o proprio
-- teleporte de volta -- por isso nao ha knob separado para "guardar".
-- ---------------------------------------------------------------------------
do
    local Kit = env.__DEPHUB and env.__DEPHUB.UIKit
    local feature = State.AutoSteal
    if Kit and feature then
        local tab = Kit.Tab("Auto Steal", "Farming")
        local section = Kit.Section(tab, "Auto Steal Exu", "Left")
        if section then
            section:CreateToggle("Auto Steal Exu", false, function(value)
                feature:SetEnabled(value)
            end)
            section:CreateDropdown("Terreiro", AutoStealModule.terreiros(), feature.Terreiro, function(choice)
                feature:SetTerreiro(choice)
            end)
        end
    end
end

return State
