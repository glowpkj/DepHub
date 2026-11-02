-- Steal An Exu - backend.
--
-- Features: Auto Steal Exu (o loop de roubo pelo prompt), Auto Upgrade (os botoes
-- da base e da esteira) e Auto Sell All (a GUI "Vender Todos"). O backend sobe,
-- carrega os modulos do repositorio, registra em State.Features e monta a UI
-- (categoria Farming). A logica mora nas features.

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

local ConfigStoreModule, configStoreError = loadFeature("src/core/config-store.lua", function(module)
    return type(module.new) == "function"
end)

local configStore = nil
if ConfigStoreModule then
    local ok, store = pcall(ConfigStoreModule.new, {
        file = "DepHub_StealAnExu_config.json",
        gameId = tostring(game.GameId or game.PlaceId or ""),
    })
    if ok then
        configStore = store
    else
        configStoreError = tostring(store)
    end
end

local State = {
    Version = "0.1.64",
    Destroyed = false,
    Started = false,
    Features = {},
    Store = configStore,
    Config = configStore and configStore.Values or {},
    LastConfigError = not configStore and tostring(configStoreError or "config-store indisponivel") or nil,
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

function State:syncStore()
    if self.Store then self.Store.Values = self.Config end
    return self.Store
end

function State:SaveConfig()
    if not self.Store then
        self.LastConfigError = "config-store nao carregou"
        return false
    end
    self:syncStore()
    local ok = self.Store:Save()
    self.LastConfigError = self.Store.LastError
    return ok
end

function State:PersistIfAutoExec()
    return self:SaveConfig()
end

function State:ReadConfig()
    if not self.Store then return nil end
    self:syncStore()
    return self.Store:Read()
end

function State:ApplyConfig(config)
    if not self.Store then return {applied = {}, failed = {}, count = 0} end
    self:syncStore()
    local result = self.Store:Apply(config)
    self.LastApplyResult = result
    return result
end

function State:LoadConfig()
    local config = self:ReadConfig()
    return self:ApplyConfig(config)
end

function State:PrimeConfig()
    if not self.Store then return nil end
    self:syncStore()
    return self.Store:Prime()
end

function State:RegisterConfig(key, apply, handle)
    if self.Store then return self.Store:Register(key, apply, handle) end
    return apply
end

local function resolveQueueOnTeleport()
    if type(queue_on_teleport) == "function" then return queue_on_teleport end
    if type(env.queue_on_teleport) == "function" then return env.queue_on_teleport end
    local genv = type(getgenv) == "function" and getgenv() or nil
    if type(genv) == "table" and type(genv.queue_on_teleport) == "function" then
        return genv.queue_on_teleport
    end
    if _G ~= env and type(_G.queue_on_teleport) == "function" then return _G.queue_on_teleport end
    return nil
end

local SOURCE_HOSTS = {
    ["raw.githubusercontent.com"] = true,
    ["github.com"] = true,
    ["cdn.jsdelivr.net"] = true,
}

local function safeRef(ref)
    if type(ref) ~= "string" or ref == "" or #ref > 200 then return nil end
    if ref:find("%.%.") or ref:find("^[/]") or ref:find("[/]$") then return nil end
    if not ref:match("^[%w_%./-]+$") then return nil end
    return ref
end

local function safeBase(base)
    if type(base) ~= "string" or #base > 300 then return nil end
    local scheme, host = base:match("^(https)://([^/]+)/")
    if not scheme or not host or not SOURCE_HOSTS[host] then return nil end
    if base:find('"') or base:find("\\") or base:find("[\\r\\n]") then return nil end
    return base
end

function State:SelfExecLine()
    local shared = env.__DEPHUB
    local loaderState = env.__DEPHUB_LOADER_STATE
    local ref = safeRef(shared and shared.SourceRef)
        or safeRef(type(loaderState) == "table" and loaderState.SourceRef)
        or "main"
    local base = safeBase(shared and shared.SourceBaseURL)
        or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
    if not base:match("/$") then base = base .. "/" end
    local command = ('loadstring(game:HttpGet("%sDepHub.lua"))("%s")'):format(base, ref)

    if not self.Store or not self.Store:CanPersist() or not self.Store.file then
        return command
    end

    local guard = ([[
local __ok = pcall(function()
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return end
    if isfile(%q) ~= true then return end
    local __text = tostring(readfile(%q))
    if not __text:find('"autoexec":true', 1, true) then error("autoexec off") end
end)
if not __ok then return end
]]):format(tostring(self.Store.file), tostring(self.Store.file))
    return guard .. command
end

function State:SetAutoExec(enabled)
    enabled = enabled == true
    local queue = resolveQueueOnTeleport()

    if not enabled then
        if queue then pcall(queue, "") end
        return true
    end

    if not queue then
        self.LastError = "executor sem queue_on_teleport"
        return false
    end

    local ok, err = pcall(queue, self:SelfExecLine())
    if not ok then self.LastError = "queue_on_teleport recusou: " .. tostring(err) end
    return ok
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

local AutoStealModule, autoStealError = loadFeature("src/games/features/stealanexu/autosteal.lua", function(module)
    return type(module.new) == "function"
end)

local AutoUpgradeModule, autoUpgradeError = loadFeature("src/games/features/stealanexu/autoupgrade.lua", function(module)
    return type(module.new) == "function"
end)

local AutoSellModule, autoSellError = loadFeature("src/games/features/stealanexu/autosell.lua", function(module)
    return type(module.new) == "function"
end)

local AutoRebirthModule, autoRebirthError = loadFeature("src/games/features/stealanexu/autorebirth.lua", function(module)
    return type(module.new) == "function"
end)

local AutoHopModule, autoHopError = loadFeature("src/games/features/stealanexu/autohop.lua", function(module)
    return type(module.new) == "function"
end)

local AutoPlaceModule, autoPlaceError = loadFeature("src/games/features/stealanexu/autoplace.lua", function(module)
    return type(module.new) == "function"
end)

-- Contexto COMPARTILHADO das features: os helpers de mundo que as duas usam
-- (achar a MINHA base pelo Owner, e navegar um caminho dentro dela). Fica aqui,
-- num lugar so, pra nao duplicar a logica de Owner em cada feature.
local FeatureContext = {}
do
    -- Um unico bloqueio de movimento para impedir que Auto Steal e Auto Sell
    -- teleportem o personagem ao mesmo tempo.
    local movementOwner = nil

    function FeatureContext.AcquireMovement(owner)
        if movementOwner ~= nil and movementOwner ~= owner then return false end
        movementOwner = owner
        return true
    end

    function FeatureContext.ReleaseMovement(owner)
        if movementOwner ~= owner then return false end
        movementOwner = nil
        return true
    end

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
        local penName = LocalPlayer and LocalPlayer:GetAttribute("PenName")
        if penName then
            local namedPen = pens:FindFirstChild(tostring(penName))
            if namedPen then return namedPen end
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

    local function partCFrame(part)
        if not part then return nil end
        local ok, frame = pcall(function()
            return CFrame.new(part.Position + Vector3.new(0, part.Size.Y / 2 + 3, 0))
        end)
        return ok and frame or nil
    end

    function FeatureContext.BaseCFrame()
        local pen = FeatureContext.MyPen()
        if not pen then return nil, "base do jogador nao encontrada" end
        local anchor = pen:FindFirstChild("BadgeAnchor", true)
        if anchor and anchor:IsA("BasePart") then
            return CFrame.new(anchor.Position + Vector3.new(0, 3, 0))
        end
        local ok, pivot = pcall(function() return pen:GetPivot() end)
        if ok and pivot then return CFrame.new(pivot.Position + Vector3.new(0, 5, 0)) end
        return nil, "ponto de retorno da base nao encontrado"
    end

    function FeatureContext.PlazaCFrame()
        local map = Workspace:FindFirstChild("Map")
        local plaza = map and map:FindFirstChild("Plaza")
        local part = plaza and plaza:FindFirstChild("Part")
        if not part or not part:IsA("BasePart") then
            return nil, "workspace.Map.Plaza.Part nao encontrado"
        end
        return partCFrame(part)
    end

    function FeatureContext.StealReturnCFrame()
        if State.AutoSell and State.AutoSell:IsEnabled() then
            local sellFrame = FeatureContext.PlazaCFrame()
            if sellFrame then return sellFrame end
        end
        return FeatureContext.BaseCFrame()
    end

    local function characterRoot()
        local character = LocalPlayer and LocalPlayer.Character
        return character and character:FindFirstChild("HumanoidRootPart") or nil
    end

    local function manualTeleport(owner, resolver)
        if not FeatureContext.AcquireMovement(owner) then
            return false, "outro recurso esta usando o teleporte"
        end
        local root = characterRoot()
        local destination, reason = resolver()
        local ok, err = pcall(function()
            if not root then error("HumanoidRootPart nao encontrado") end
            if not destination then error(reason or "destino indisponivel") end
            root.CFrame = destination
        end)
        FeatureContext.ReleaseMovement(owner)
        if not ok then return false, tostring(err) end
        return true
    end

    function FeatureContext.TeleportToBase(owner)
        return manualTeleport(owner or State, FeatureContext.BaseCFrame)
    end

    function FeatureContext.TeleportToSell(owner)
        return manualTeleport(owner or State, FeatureContext.PlazaCFrame)
    end

    function FeatureContext.Terreiros()
        return AutoStealModule and AutoStealModule.terreiros() or {}
    end

    local function inventoryExuIds()
        local ids = {}
        local seen = {}
        local backpack = LocalPlayer and (LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack"))
        local character = LocalPlayer and LocalPlayer.Character
        local function collect(container)
            if not container then return end
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("Tool") then
                    local id = child:GetAttribute("ExuId")
                    if id ~= nil then
                        local key = tostring(id)
                        if not seen[key] then seen[key] = true; ids[#ids + 1] = key end
                    end
                end
            end
        end
        collect(backpack)
        collect(character)
        return ids
    end

    function FeatureContext.InventoryExuIds()
        return inventoryExuIds()
    end

    function FeatureContext.TrackExuSource(id, terreiroName)
        if id == nil or type(terreiroName) ~= "string" then return end
        local sourceMap = env.__DEPHUB_STEALANEXU_EXU_SOURCES
        if type(sourceMap) ~= "table" then
            sourceMap = {}
            env.__DEPHUB_STEALANEXU_EXU_SOURCES = sourceMap
        end
        sourceMap[tostring(id)] = terreiroName
    end

    function FeatureContext.TrackNewExuSources(before, after, terreiroName)
        local known = {}
        for _, id in ipairs(type(before) == "table" and before or {}) do known[tostring(id)] = true end
        for _, id in ipairs(type(after) == "table" and after or {}) do
            if not known[tostring(id)] then FeatureContext.TrackExuSource(id, terreiroName) end
        end
    end
end

function State:TeleportToBase()
    return FeatureContext.TeleportToBase(self)
end

function State:TeleportToSell()
    return FeatureContext.TeleportToSell(self)
end

-- A unica rotina de roubo e a selecao multipla de terreiros.
if AutoStealModule then
    local availableTerreiros = AutoStealModule.terreiros()
    local selectedTerreiros = State.Config.selectedTerreiros
    if type(selectedTerreiros) ~= "table" or #selectedTerreiros == 0 then
        selectedTerreiros = {availableTerreiros[1]}
    end

    State.AutoStealSelection = AutoStealModule.new(FeatureContext, {
        selectedOnly = true,
        terreiros = selectedTerreiros,
    })
    State.Features.AutoStealSelection = State.AutoStealSelection
else
    warn("[DepHub] Steal An Exu autosteal unavailable: " .. tostring(autoStealError))
end

-- Instancia o Auto Upgrade. Duas instancias do MESMO mecanismo (o botao da base e
-- o da esteira sao o mesmo click), mudando so o caminho dentro do pen.
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

-- Auto Rebirth: verifica Cash/Rebirths e executa o remote quando atingir o custo.
if AutoRebirthModule then
    State.AutoRebirth = AutoRebirthModule.new()
    State.Features.AutoRebirth = State.AutoRebirth
else
    warn("[DepHub] Steal An Exu autorebirth unavailable: " .. tostring(autoRebirthError))
end

-- Auto Hop usa exatamente a mesma selecao de Exus do Auto Steal Selection.
if AutoHopModule then
    State.AutoHop = AutoHopModule.new({
        placeId = game.PlaceId,
        targetProvider = function()
            if not State.AutoStealSelection then return nil, "Auto Steal Selection indisponivel" end
            return State.AutoStealSelection:_targets()
        end,
        scopeProvider = function()
            return State.AutoStealSelection and State.AutoStealSelection:SelectionKey() or ""
        end,
        pendingProvider = function()
            if State.AutoSell and State.AutoSell:IsEnabled() then
                return #FeatureContext.InventoryExuIds()
            end
            return 0
        end,
    })
    State.Features.AutoHop = State.AutoHop
else
    warn("[DepHub] Steal An Exu autohop unavailable: " .. tostring(autoHopError))
end

if AutoPlaceModule then
    local placeTerreiros = State.Config.placeTerreiros
    if type(placeTerreiros) ~= "table" then placeTerreiros = {} end
    State.AutoPlace = AutoPlaceModule.new(FeatureContext, {terreiros = placeTerreiros})
    State.Features.AutoPlace = State.AutoPlace
else
    warn("[DepHub] Steal An Exu autoplace unavailable: " .. tostring(autoPlaceError))
end
State:Start()


-- ---------------------------------------------------------------------------
-- Farming: roubo multi-Terreiro, Auto Place, Auto Sell, Auto Hop e config.
-- ---------------------------------------------------------------------------
do
    local savedConfig = nil
    pcall(function() savedConfig = State:PrimeConfig() end)

    local Kit = env.__DEPHUB and env.__DEPHUB.UIKit
    if Kit then
        local tab = Kit.Tab("Auto Steal", "Farming")
        local availableTerreiros = AutoStealModule and AutoStealModule.terreiros() or {}
        local defaultStealTerreiros = State.Config.selectedTerreiros
        if type(defaultStealTerreiros) ~= "table" or #defaultStealTerreiros == 0 then
            defaultStealTerreiros = {availableTerreiros[1]}
        end
        if State.AutoStealSelection then
            State.AutoStealSelection:SetTerreiros(defaultStealTerreiros)
        end

        if State.AutoStealSelection then
            local stealSection = Kit.Section(tab, "Steal Exu Selection", "Left")
            if stealSection then
                local function applyStealTerreiros(names)
                    State.Config.selectedTerreiros = table.clone(names)
                    local ok = State.AutoStealSelection:SetTerreiros(names)
                    State:PersistIfAutoExec()
                    return ok
                end
                local handle = stealSection:CreateMultiDropdown(
                    "Steal Terreiros",
                    availableTerreiros,
                    defaultStealTerreiros,
                    applyStealTerreiros
                )
                State:RegisterConfig("selectedTerreiros", applyStealTerreiros, handle)

                local function applySelectedSteal(value)
                    State.Config.autoStealSelection = value == true
                    local ok = State.AutoStealSelection:SetEnabled(value)
                    State:PersistIfAutoExec()
                    return ok
                end
                local stealHandle = stealSection:CreateToggle(
                    "Steal Exu Selection",
                    State.Config.autoStealSelection == true,
                    applySelectedSteal
                )
                State:RegisterConfig("autoStealSelection", applySelectedSteal, stealHandle)

                local function applyHop(value)
                    State.Config.autoHopSelected = value == true
                    local ok = State.AutoHop and State.AutoHop:SetEnabled(value) or false
                    State:PersistIfAutoExec()
                    return ok
                end
                local hopHandle = stealSection:CreateToggle(
                    "Auto Hop When Empty",
                    State.Config.autoHopSelected == true,
                    applyHop
                )
                State:RegisterConfig("autoHopSelected", applyHop, hopHandle)
                stealSection:CreateParagraph(
                    "Selected farming",
                    "Rouba somente os terreiros marcados. O Auto Hop espera os Exus desses mesmos terreiros acabarem antes de trocar de servidor."
                )
            end
        end

        if State.AutoPlace then
            local placeSection = Kit.Section(tab, "Auto Place Exu", "Left")
            if placeSection then
                local defaultPlaceTerreiros = State.Config.placeTerreiros
                if type(defaultPlaceTerreiros) ~= "table" or #defaultPlaceTerreiros == 0 then
                    defaultPlaceTerreiros = table.clone(defaultStealTerreiros)
                end
                State.AutoPlace:SetTerreiros(defaultPlaceTerreiros)

                local function applyPlaceTerreiros(names)
                    State.Config.placeTerreiros = table.clone(names)
                    local ok = State.AutoPlace:SetTerreiros(names)
                    State:PersistIfAutoExec()
                    return ok
                end
                local placeDropdown = placeSection:CreateMultiDropdown(
                    "Place Terreiros",
                    availableTerreiros,
                    defaultPlaceTerreiros,
                    applyPlaceTerreiros
                )
                State:RegisterConfig("placeTerreiros", applyPlaceTerreiros, placeDropdown)

                local function applyAutoPlace(value)
                    State.Config.autoPlace = value == true
                    local ok = State.AutoPlace:SetEnabled(value)
                    State:PersistIfAutoExec()
                    return ok
                end
                local placeToggle = placeSection:CreateToggle(
                    "Auto Place Exu",
                    State.Config.autoPlace == true,
                    applyAutoPlace
                )
                State:RegisterConfig("autoPlace", applyAutoPlace, placeToggle)
                placeSection:CreateParagraph(
                    "Auto Place",
                    "Coloca Tools com ExuId cuja origem foi mapeada para os terreiros selecionados. Exus sem origem identificada sao ignorados para evitar colocar no grupo errado."
                )
            end
        end

        if State.AutoSell then
            local sellSection = Kit.Section(tab, "Sell All", "Left")
            if sellSection then
                local function applyAutoSell(value)
                    State.Config.autoSell = value == true
                    local ok = State.AutoSell:SetEnabled(value)
                    State:PersistIfAutoExec()
                    return ok
                end
                local handle = sellSection:CreateToggle("Auto Sell Exus", State.Config.autoSell == true, applyAutoSell)
                State:RegisterConfig("autoSell", applyAutoSell, handle)
                sellSection:CreateParagraph(
                    "Sell priority",
                    "Com Steal e Sell ligados, cada Exu roubado retorna diretamente para a Plaza. O Sell so clica quando voce esta dentro da area."
                )
            end
        end

        if State.AutoRebirth then
            local rebirthSection = Kit.Section(tab, "Auto Rebirth", "Left")
            if rebirthSection then
                local function applyAutoRebirth(value)
                    State.Config.autoRebirth = value == true
                    local ok = State.AutoRebirth:SetEnabled(value)
                    State:PersistIfAutoExec()
                    return ok
                end
                local handle = rebirthSection:CreateToggle("Auto Rebirth", State.Config.autoRebirth == true, applyAutoRebirth)
                State:RegisterConfig("autoRebirth", applyAutoRebirth, handle)
            end
        end

        if State.UpgradeBase or State.UpgradeTread then
            local upgradeSection = Kit.Section(tab, "Auto Upgrade", "Left")
            if upgradeSection then
                if State.UpgradeBase then
                    local function applyUpgradeBase(value)
                        State.Config.upgradeBase = value == true
                        local ok = State.UpgradeBase:SetEnabled(value)
                        State:PersistIfAutoExec()
                        return ok
                    end
                    local handle = upgradeSection:CreateToggle("Auto Upgrade Base", State.Config.upgradeBase == true, applyUpgradeBase)
                    State:RegisterConfig("upgradeBase", applyUpgradeBase, handle)
                end
                if State.UpgradeTread then
                    local function applyUpgradeTread(value)
                        State.Config.upgradeTread = value == true
                        local ok = State.UpgradeTread:SetEnabled(value)
                        State:PersistIfAutoExec()
                        return ok
                    end
                    local handle = upgradeSection:CreateToggle("Auto Upgrade Esteira", State.Config.upgradeTread == true, applyUpgradeTread)
                    State:RegisterConfig("upgradeTread", applyUpgradeTread, handle)
                end
            end
        end

        local hopSection = Kit.Section(tab, "Server Hop", "Right")
        if hopSection then
            hopSection:CreateParagraph(
                "Auto Hop",
                "A troca usa somente os terreiros marcados em Steal Terreiros. Exige que pelo menos um Exu selecionado tenha aparecido no servidor e que a selecao fique vazia por 15 segundos."
            )
        end

        local teleportSection = Kit.Section(tab, "Manual Teleport", "Right")
        if teleportSection then
            teleportSection:CreateButton("Teleport to Base", function()
                local ok, reason = FeatureContext.TeleportToBase(State)
                local ui = env.__DEPHUB and env.__DEPHUB.UI
                if ui and type(ui.Notify) == "function" then
                    ui:Notify("Teleport to Base", ok and "Teleportado para sua base." or tostring(reason))
                end
            end)
            teleportSection:CreateButton("Teleport to Sell Area", function()
                local ok, reason = FeatureContext.TeleportToSell(State)
                local ui = env.__DEPHUB and env.__DEPHUB.UI
                if ui and type(ui.Notify) == "function" then
                    ui:Notify("Teleport to Sell Area", ok and "Teleportado para a Plaza." or tostring(reason))
                end
            end)
        end

        local configSection = Kit.Section(tab, "Config", "Right")
        if configSection then
            local function applyAutoExec(value)
                State.Config.autoexec = value == true
                local saved = State:SaveConfig()
                local ok = State:SetAutoExec(value)
                if value and not ok then
                    local ui = env.__DEPHUB and env.__DEPHUB.UI
                    if ui and type(ui.Notify) == "function" then
                        ui:Notify("Auto Execute", State.LastError or "Executor sem queue_on_teleport.")
                    end
                elseif value and not saved then
                    local ui = env.__DEPHUB and env.__DEPHUB.UI
                    if ui and type(ui.Notify) == "function" then
                        ui:Notify("Auto Execute", State.LastConfigError or "Config nao foi salva em disco.")
                    end
                end
                return ok
            end

            local autoExecHandle = configSection:CreateToggle("Auto Execute", State.Config.autoexec == true, applyAutoExec)
            State:RegisterConfig("autoexec", applyAutoExec, autoExecHandle)

            configSection:CreateButton("Save Config", function()
                local ok = State:SaveConfig()
                local ui = env.__DEPHUB and env.__DEPHUB.UI
                if ui and type(ui.Notify) == "function" then
                    ui:Notify("Config", ok and "Todas as configuracoes foram salvas." or (State.LastConfigError or "Nao foi possivel salvar em disco."))
                end
            end)

            configSection:CreateButton("Load Config", function()
                local result = State:LoadConfig()
                local ui = env.__DEPHUB and env.__DEPHUB.UI
                if ui and type(ui.Notify) == "function" then
                    local failed = result and #result.failed or 0
                    ui:Notify("Config", ("Aplicadas: %d | Falhas: %d"):format(result and result.count or 0, failed))
                end
            end)
            configSection:CreateParagraph(
                "Config",
                "Todas as selecoes multiplas, toggles e Auto Execute sao salvos automaticamente ao mudar, e tambem pelo botao Save Config."
            )
        end
    end

    if type(savedConfig) == "table" then
        local result = State:ApplyConfig(savedConfig)
        if result and #result.failed > 0 then
            State.LastConfigError = ("falha ao aplicar %d opcoes salvas"):format(#result.failed)
        end
    end

    if State.Config.autoexec ~= true then
        pcall(function() State:SetAutoExec(false) end)
    end
end

return State
