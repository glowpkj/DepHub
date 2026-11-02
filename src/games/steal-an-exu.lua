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

local AutoUpgradeModule, autoUpgradeError = loadFeature("src/games/features/stealanexu/autoupgrade.lua", function(module)
    return type(module.new) == "function"
end)

local AutoSellModule, autoSellError = loadFeature("src/games/features/stealanexu/autosell.lua", function(module)
    return type(module.new) == "function"
end)

-- Contexto COMPARTILHADO das features: os helpers de mundo que as duas usam
-- (achar a MINHA base pelo Owner, e navegar um caminho dentro dela). Fica aqui,
-- num lugar so, pra nao duplicar a logica de Owner em cada feature.
local FeatureContext = {}
do
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local LocalPlayer = Players.LocalPlayer

    -- A minha base: varre Map.Pens e compara o atributo Owner com o MEU UserId.
    -- Nunca Pen1/Pen2 fixo -- a numeracao muda por servidor -- e funciona pra
    -- quem receber o script, nao so pra mim.
    function FeatureContext.MyPen()
        local map = Workspace:FindFirstChild("Map")
        local pens = map and map:FindFirstChild("Pens")
        if not pens then return nil end
        local myUserId = LocalPlayer and LocalPlayer.UserId
        if not myUserId then return nil end
        local wanted = tostring(myUserId)
        for _, pen in ipairs(pens:GetChildren()) do
            local owner = pen:GetAttribute("Owner")
            if owner ~= nil and tostring(owner) == wanted then return pen end
        end
        return nil
    end

    -- Navega um caminho pontuado a partir da minha base (ex.:
    -- "PenSign.Board.ClickDetector"). Devolve a instancia, ou nil.
    function FeatureContext.PenPart(path)
        local instance = FeatureContext.MyPen()
        if not instance then return nil end
        for segment in tostring(path or ""):gmatch("[^.]+") do
            instance = instance:FindFirstChild(segment)
            if not instance then return nil end
        end
        return instance
    end
end

-- Instancia o Auto Steal Exu (mecanismo pronto; so roda quando o toggle ligar).
if AutoStealModule then
    State.AutoSteal = AutoStealModule.new(FeatureContext)
    State.Features.AutoSteal = State.AutoSteal
else
    warn("[DepHub] Steal An Exu autosteal unavailable: " .. tostring(autoStealError))
end

-- Auto Upgrade: duas instancias do MESMO mecanismo (o botao da base e o da
-- esteira sao o mesmo click), mudando so o caminho dentro do pen.
if AutoUpgradeModule then
    State.UpgradeBase = AutoUpgradeModule.new(FeatureContext, {
        label = "base", path = "PenSign.Board.ClickDetector",
    })
    State.UpgradeTread = AutoUpgradeModule.new(FeatureContext, {
        label = "tread", path = "TreadSign.Board.ClickDetector",
    })
    State.Features.UpgradeBase = State.UpgradeBase
    State.Features.UpgradeTread = State.UpgradeTread
else
    warn("[DepHub] Steal An Exu autoupgrade unavailable: " .. tostring(autoUpgradeError))
end

-- Auto Sell All: uma instancia da GUI de venda (o botao "Vender Todos").
if AutoSellModule then
    State.AutoSell = AutoSellModule.new(FeatureContext)
    State.Features.AutoSell = State.AutoSell
else
    warn("[DepHub] Steal An Exu autosell unavailable: " .. tostring(autoSellError))
end

State:Start()

-- ---------------------------------------------------------------------------
-- Apresentacao: categoria Farming.
--   * "Auto Steal Exu" -- o loop (toggle). Varre TODOS os Exus do Runtime.
--     Guardar na base e o proprio teleporte de volta -- sem knob separado.
--   * "Steal All" -- um botao de passada unica: todos os Exus do Runtime, com
--     wait entre cada um.
--   * "Sell All" -- um botao de passada unica: vende os Exus pela GUI do jogo
--     (PlayerGui.Menus["Vender Todos"].Button).
-- ---------------------------------------------------------------------------
do
    local Kit = env.__DEPHUB and env.__DEPHUB.UIKit
    if Kit then
        local tab = Kit.Tab("Auto Steal", "Farming")

        local feature = State.AutoSteal
        if feature then
            local section = Kit.Section(tab, "Auto Steal Exu", "Left")
            if section then
                section:CreateToggle("Auto Steal Exu", false, function(value)
                    feature:SetEnabled(value)
                end)
            end
            local allSection = Kit.Section(tab, "Steal All", "Left")
            if allSection then
                allSection:CreateButton("Steal All", function()
                    feature:StartStealAll()
                end)
            end
        end

        -- Sell All: vende todos os Exus pela GUI "Vender Todos" do jogo.
        if State.AutoSell then
            local sellSection = Kit.Section(tab, "Sell All", "Left")
            if sellSection then
                sellSection:CreateButton("Sell All Exus", function()
                    State.AutoSell:StartSell()
                end)
            end
        end

        -- Auto Upgrade: um toggle por botao (o da base e o da esteira).
        if State.UpgradeBase or State.UpgradeTread then
            local upgradeSection = Kit.Section(tab, "Auto Upgrade", "Left")
            if upgradeSection then
                if State.UpgradeBase then
                    upgradeSection:CreateToggle("Auto Upgrade Base", false, function(value)
                        State.UpgradeBase:SetEnabled(value)
                    end)
                end
                if State.UpgradeTread then
                    upgradeSection:CreateToggle("Auto Upgrade Esteira", false, function(value)
                        State.UpgradeTread:SetEnabled(value)
                    end)
                end
            end
        end
    end
end

return State
