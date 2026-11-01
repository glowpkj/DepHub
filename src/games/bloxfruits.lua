local game = game
local type = type
local tostring = tostring

local env = type(getgenv) == "function" and getgenv() or _G
local report = (env.__DEPHUB and type(env.__DEPHUB.Log) == "function") and env.__DEPHUB.Log or function() end

-- Backend for o script de Blox Fruits do usuario.
--
-- As features ficam em src/games/features/bloxfruits/<nome>.lua, uma por
-- arquivo, cada uma independente (sem DepHub, sem adapter OSS): elas fazem os
-- proprios game:GetService e se publicam como um modulo com new()/Enable()/
-- Disable(). Este backend so faz tres coisas -- baixa a arvore, monta o painel
-- e liga/desliga cada feature pelo toggle.
--
-- As features que ainda nao foram portadas ficam guardadas em
-- src/games/features/bloxfruits/parked/ (nada foi apagado): elas saem da pasta
-- ativa, nao carregam e nao entram no manifest, mas seguem no disco prontas
-- para serem trazidas pro molde proprio uma a uma. Por isso o backend so varre
-- FEATURE_MODULES -- nao existe flag global que ligue/desligue tudo.

local FEATURE_PATH = "src/games/features/bloxfruits/"
local VERSION = "1.0.0"

-- As features deste backend, na ordem em que carregam. Cada entrada: o arquivo,
-- a aba/secao em que aparece e o rotulo do toggle. O resto (range, intervalo…)
-- sai do proprio modulo, para o backend nao virar uma lista de knobs paralela.
--
-- Só a blade hit tem UI. O teleporte e INFRAESTRUTURA: um motor que outras
-- features usam (pegar fruta, farm), nao um toggle -- por isso entra em
-- INFRA_MODULES e nao aparece no painel.
local FEATURE_MODULES = {
    {name = "bladhits", page = "Combat", section = "BLADE HITS", toggle = "Blade hits"},
    {name = "fruit", page = "Farm", section = "FRUIT", toggle = "Grab fruit"},
    {name = "islands", page = "Travel", section = "ISLAND TELEPORT", toggle = "Island teleport"},
}
local INFRA_MODULES = {
    {name = "teleport"},
}

local previous = type(env.__DEPHUB_BLOXFRUITS) == "table" and env.__DEPHUB_BLOXFRUITS or nil
if previous and type(previous.Destroy) == "function" then pcall(previous.Destroy, previous) end

local sourceBase = (env.__DEPHUB or {}).SourceBaseURL or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"

-- Prefer the bundle's resolver published on the shared environment. It is only
-- present in a bundled build; a source checkout resolves through the loader's
-- own fetch path, so fall back to the executor primitives in that order.
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

local function loadFactory(path)
    local okFetch, source = fetch(path)
    if not okFetch then return false, "fetch: " .. tostring(source) end
    local chunk, chunkError = loadstring(source)
    if not chunk then return false, "compile: " .. tostring(chunkError) end
    local okRun, factory = pcall(chunk)
    if not okRun or type(factory) ~= "table" then return false, "run: " .. tostring(factory) end
    return true, factory
end

local LocalPlayer = game:GetService("Players").LocalPlayer
if not LocalPlayer then
    report("BloxFruits: LocalPlayer ausente")
    return false
end

local State = {
    Destroyed = false,
    Version = VERSION,
    Features = {},
    Instances = {},
    Infra = {},
    Errors = {},
    Toggles = {},
    ToggleLabels = {},
    LastError = nil,
}

-- Carrega cada feature e guarda a fabrica. Nenhum init ainda: o modulo so
-- instancia quando o toggle liga, para o painel abrir sem ligar nada sozinho.
for _, entry in ipairs(FEATURE_MODULES) do
    local ok, factory = loadFactory(FEATURE_PATH .. entry.name .. ".lua")
    if ok then
        State.Features[entry.name] = factory
    else
        State.Errors[#State.Errors + 1] = entry.name .. ": " .. tostring(factory)
        report("BloxFruits: feature " .. entry.name .. " falhou: " .. tostring(factory))
    end
end

-- Infraestrutura: carrega e INSTANCIA sempre, porque nao ha toggle pra ligar.
-- O motor de teleporte fica disponivel em State.Infra para qualquer feature
-- (ou para o console) chamar. Sem character ou sem remotes ele nao explode --
-- so nao faz nada -- entao instanciar no load e seguro.
for _, entry in ipairs(INFRA_MODULES) do
    local ok, factory = loadFactory(FEATURE_PATH .. entry.name .. ".lua")
    if ok and type(factory) == "table" and type(factory.new) == "function" then
        local created, instance = pcall(factory.new, {})
        if created and type(instance) == "table" then
            if type(instance.Enable) == "function" then pcall(instance.Enable, instance) end
            State.Infra[entry.name] = instance
            State.Features[entry.name] = factory
        else
            State.Errors[#State.Errors + 1] = entry.name .. ": " .. tostring(instance)
        end
    else
        State.Errors[#State.Errors + 1] = entry.name .. ": " .. tostring(factory)
        report("BloxFruits: infra " .. entry.name .. " falhou: " .. tostring(factory))
    end
end

-- O motor de teleporte publico: as features chamam State:Teleport() para se
-- mover. Ele e o mesmo objeto para todo mundo -- um teleporte so, testado.
function State:Teleport()
    return self.Infra.teleport
end

-- A antiga lista de elementos de raid (State.RaidElements) saiu junto com a raid
-- parkeada -- so ela usava. Quando a raid voltar, a lista volta com ela.

function State:GetFeature(name)
    return self.Instances[name]
end

function State:SetFeature(name, enabled)
    if self.Destroyed then return false end
    local entry
    for _, candidate in ipairs(FEATURE_MODULES) do
        if candidate.name == name then entry = candidate break end
    end
    local factory = self.Features[name]
    if not entry or type(factory) ~= "table" then return false end
    if enabled then
        local instance = self.Instances[name]
        if not instance then
            -- Toda feature recebe um contexto com as pecas que podem ser
            -- COMPARTILHADAS -- e a feature decide se usa cada uma. Hoje:
            --   * teleport: o motor de voo (infra). A fruta usa no grab.
            --   * combat: a blade hit, quando ja instanciada. Reservado pra uma
            --     feature que ataque em vez de ter um ataque proprio (um motor
            --     de ataque no script, nao dois). Ninguem consome hoje -- a raid,
            --     que era a consumidora, esta parkeada.
            local context = {
                teleport = self.Infra.teleport,
                combat = self.Instances.bladhits,
                state = self,
            }
            local ok, created = pcall(factory.new, context)
            if not ok or type(created) ~= "table" then
                self.LastError = "new " .. name .. ": " .. tostring(created)
                report("BloxFruits: " .. self.LastError)
                return false
            end
            instance = created
            self.Instances[name] = instance
        end
        local ok = pcall(instance.Enable, instance)
        if not ok then self.LastError = "enable " .. name; return false end
        self.Toggles[name] = instance:IsEnabled() == true
        return self.Toggles[name]
    end
    local instance = self.Instances[name]
    if instance then pcall(instance.Disable, instance) end
    self.Toggles[name] = false
    return true
end

function State:SetToggle(key, enabled)
    return self:SetFeature(key, enabled == true)
end

function State:GetToggle(key)
    local instance = self.Instances[key]
    if instance then return instance:IsEnabled() == true end
    return self.Toggles[key] == true
end

-- A feature expoe os proprios knobs (range, intervalo…) por metodos, nao por
-- um config paralelo aqui. O backend so encaminha.
function State:SetFeatureRange(key, value)
    local instance = self.Instances[key]
    if not instance then return false end
    if type(instance.SetRange) ~= "function" then return false end
    return pcall(instance.SetRange, instance, value)
end

function State:SetFeatureInterval(key, value)
    local instance = self.Instances[key]
    if not instance then return false end
    if type(instance.SetInterval) ~= "function" then return false end
    return pcall(instance.SetInterval, instance, value)
end

function State:GetStatus()
    local on = 0
    for _, value in pairs(self.Toggles) do if value then on = on + 1 end end
    return {
        Version = self.Version,
        Features = self.Instances,
        Infra = self.Infra,
        Loaded = self.Features,
        TogglesOn = on,
        Errors = self.Errors,
    }
end

function State:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    for name, instance in pairs(self.Instances) do
        if type(instance.Destroy) == "function" then pcall(instance.Destroy, instance) end
        self.Instances[name] = nil
    end
    for name, instance in pairs(self.Infra) do
        if type(instance.Destroy) == "function" then pcall(instance.Destroy, instance) end
        self.Infra[name] = nil
    end
    if env.__DEPHUB_BLOXFRUITS == self then env.__DEPHUB_BLOXFRUITS = nil end
    if env.__DEPHUB and env.__DEPHUB.BloxFruits == self then env.__DEPHUB.BloxFruits = nil end
    if env.__DEPHUB and env.__DEPHUB.BloxFruitsOwn == self then env.__DEPHUB.BloxFruitsOwn = nil end
end

env.__DEPHUB_BLOXFRUITS = State
env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.BloxFruits = State
env.__DEPHUB.BloxFruitsOwn = State

-- Painel: a UI e construida pelo proprio backend, com a shell compartilhada,
-- para o script nao depender do adapter nem de um frontend externo.
--
-- Cada feature traz o proprio bloco de UI. O backend so posiciona (categoria,
-- aba, secao) e cria os controles que a feature declarou -- sem o backend
-- conhecer knob por knob. A categoria e sempre finalidade (Combat, Fruit), nao
-- nome de jogo, como manda a convencao.
local PANELS = {
    bladhits = {
        page = "Combat",
        section = "BLADE HITS",
        category = "Combat",
        icon = "swords",
        build = function(section, instance)
            section:CreateToggle("Blade hits", false, function(value)
                if value and not instance.Backend:SetFeature("bladhits", true) then
                    instance.Notify("Blade hits", "Remotes nao encontrados (Modules.Net).")
                end
                if not value then instance.Backend:SetFeature("bladhits", false) end
            end)
            section:CreateParagraph("Blade hits", "Auto-swing at every enemy in range using the game's attack remotes.")
        end,
    },
    fruit = {
        page = "Farm",
        section = "FRUIT",
        category = "Farm",
        icon = "cherry",
        build = function(section, instance)
            section:CreateToggle("Fruit ESP", false, function(value)
                while State.Instances.fruit == nil do task.wait() end
                State.Instances.fruit:SetEsp(value)
            end)
            section:CreateSlider("ESP max distance", 0, 2000, 0, function(value)
                if State.Instances.fruit then State.Instances.fruit:SetEspRange(value) end
            end)
            section:CreateToggle("Grab fruit", false, function(value)
                if value and not State:SetFeature("fruit", true) then
                    instance.Notify("Grab fruit", "Teleport motor ausente.")
                    return
                end
                if not value then State:SetFeature("fruit", false) end
                if State.Instances.fruit then State.Instances.fruit:SetGrab(value) end
            end)
            section:CreateSlider("Grab max distance", 0, 2000, 0, function(value)
                if State.Instances.fruit then State.Instances.fruit:SetRange(value) end
            end)
            section:CreateToggle("Auto store fruit", false, function(value)
                if State.Instances.fruit then State.Instances.fruit:SetStore(value) end
            end)
            section:CreateInput("Skip list", "Dragon, Rocket", "", function(text)
                if State.Instances.fruit then State.Instances.fruit:SetSkip(text) end
            end)
            section:CreateInput("Store keep list", "never store these", "", function(text)
                if State.Instances.fruit then State.Instances.fruit:SetKeep(text) end
            end)
        end,
    },
    islands = {
        page = "Travel",
        section = "ISLAND TELEPORT",
        category = "Travel",
        icon = "map",
        build = function(section, instance)
            -- O dropdown lista as ilhas do Sea 2 (confirmadas pelo usuario). A
            -- selecao NAO teleporta sozinha: e gate do toggle. Trocar a ilha com
            -- o toggle ligado voa de novo.
            local islands = {}
            local factory = State.Features.islands
            if factory and type(factory.islands) == "table" then
                islands = factory.islands
            end
            local selected = islands[1] or "Snow Mountain"
            section:CreateToggle("Island teleport", false, function(value)
                if value then
                    if not State:SetFeature("islands", true) then
                        instance.Notify("Island teleport", "Teleport motor ausente.")
                        return
                    end
                    if State.Instances.islands then
                        if not State.Instances.islands:SetEnabled(true) then
                            instance.Notify("Island teleport", State.Instances.islands.LastStatus or "falhou.")
                        end
                    end
                    return
                end
                if State.Instances.islands then State.Instances.islands:SetEnabled(false) end
                State:SetFeature("islands", false)
            end)
            section:CreateDropdown("Island", islands, selected, function(choice)
                selected = choice
                if State.Instances.islands then
                    local ok = State.Instances.islands:Select(choice)
                    if State.Instances.islands.ToggleOn and not ok then
                        instance.Notify("Island teleport", State.Instances.islands.LastStatus or "ilha fora do mapa.")
                    end
                end
            end)
            section:CreateParagraph("Island teleport", "Pick an island and fly there. Only travels while the toggle is on.")
        end,
    },
    -- RAID: parked. O Auto raid e o Auto complete nao estavam do jeito que o
    -- usuario quer, entao a feature inteira saiu da lista ativa e foi para
    -- features/bloxfruits/parked/raid.lua -- nada foi apagado. Para trazer de
    -- volta, e so re-adicionar {name = "raid", page = "Farm", section = "RAID",
    -- toggle = "Auto raid"} em FEATURE_MODULES e recriar o raid no PANELS.
}

local visual = env.__DEPHUB and env.__DEPHUB.UI or nil
if type(visual) == "table" and type(visual.CreateTab) == "function" then
    local tabs = {}
    local categories = {}
    local helper = {
        Backend = State,
        Notify = function(title, body) visual:Notify(title, body) end,
    }
    for _, entry in ipairs(FEATURE_MODULES) do
        local panel = PANELS[entry.name]
        if panel and State.Features[entry.name] then
            if not categories[panel.category] then
                categories[panel.category] = true
                visual:CreateCategory(panel.category, panel.icon)
            end
            local tab = tabs[panel.page]
            if tab == nil then
                tab = visual:CreateTab(panel.page, panel.category, nil) or false
                tabs[panel.page] = tab
            end
            if tab then
                local section = tab:CreateSection(panel.section)
                if section then panel.build(section, helper) end
            end
        end
    end
    State.UIFrontend = visual
end

do
    local Diag = env.__DEPHUB and env.__DEPHUB.Diagnostics
    if Diag and type(Diag.RegisterModule) == "function" then
        local function register(entry)
            local path = "features/bloxfruits/" .. entry.name .. ".lua"
            Diag:RegisterModule(path)
            local loaded = type(State.Features[entry.name]) == "table"
            local detail = loaded and "loaded" or "absent"
            if not loaded and type(State.Errors) == "table" then
                for _, err in ipairs(State.Errors) do
                    if tostring(err):find(entry.name, 1, true) then detail = tostring(err) break end
                end
            end
            Diag:Module(path, loaded, detail)
        end
        for _, entry in ipairs(FEATURE_MODULES) do register(entry) end
        for _, entry in ipairs(INFRA_MODULES) do register(entry) end
        Diag:Feature("BloxFruits.Toggles on", function() return tostring(State:GetStatus().TogglesOn) end)
        Diag:Feature("BloxFruits.Teleport", function() return State.Infra.teleport and "ready" or "absent" end)
        Diag:Feature("BloxFruits.LastError", function() return tostring(State.LastError or "none") end)
    end
end

return State
