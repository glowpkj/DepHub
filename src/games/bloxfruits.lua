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

-- A fonte CONFIÁVEL dos nomes de fruta do Blox Fruits. A lista abaixo e a mesma
-- que o sistema de frutas ja usava (parked/fruits.lua, M.FRUITS): manter uma so
-- evita duas listas divergindo. O dropdown de Skip list / Store keep list monta
-- suas opcoes daqui, para o usuario escolher a fruta pelo nome certo sem digitar.
local FRUIT_NAMES = {
    "Barrier", "Blade", "Blizzard", "Bomb", "Buddha", "Chop", "Control", "Creation", "Dark",
    "Diamond", "Door", "Dough", "Dragon", "Eagle", "Falcon", "Flame", "Gas", "Ghost", "Gravity",
    "Ice", "Kilo", "Kitsune", "Leopard", "Light", "Lightning", "Love", "Magma", "Mammoth",
    "Mochi", "Pain", "Paw", "Phoenix", "Portal", "Quake", "Revive", "Rocket", "Rubber", "Rumble",
    "Sand", "Shadow", "Smoke", "Sound", "Spider", "Spike", "Spin", "Spirit", "Spring", "String",
    "T-Rex", "Venom", "Yeti",
}

-- As features deste backend, na ordem em que carregam. Cada entrada: o arquivo,
-- a aba/secao em que aparece e o rotulo do toggle. O resto (range, intervalo…)
-- sai do proprio modulo, para o backend nao virar uma lista de knobs paralela.
--
-- Só a blade hit tem UI. O teleporte e INFRAESTRUTURA: um motor que outras
-- features usam (pegar fruta, farm), nao um toggle -- por isso entra em
-- INFRA_MODULES e nao aparece no painel.
local FEATURE_MODULES = {
    {name = "bladhits", page = "Combat", section = "BLADE HITS", toggle = "Blade hits"},
    {name = "silentaim", page = "Combat", section = "SILENT AIM", toggle = "Silent aim"},
    {name = "fruit", page = "Farm", section = "FRUIT", toggle = "Grab fruit"},
    {name = "islands", page = "Travel", section = "ISLAND TELEPORT", toggle = "Island teleport"},
    {name = "player", page = "Player", section = "PLAYER", toggle = "Speed multiplier"},
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

-- Em qual mar o jogador esta. O jogo expoe isso em ReplicatedStorage.Util.Realm
-- (getCurrentSeaAsync), o MESMO caminho que o script antigo usava para escolher o
-- tubo da raid. E por mar que a lista de ilhas do Travel e escolhida: Sea 1, 2 e 3
-- tem mapas diferentes. Se o jogo nao disser, cai em Sea 2 (o padrao historico).
-- Resolvido uma vez no load (o mar nao muda durante a sessao sem rejoin).
local function detectSea()
    local ok, sea = pcall(function()
        local replicated = game:GetService("ReplicatedStorage")
        local util = replicated and replicated:FindFirstChild("Util")
        local realm = util and util:FindFirstChild("Realm")
        if not realm then return nil end
        local module = require(realm)
        if type(module) ~= "table" then return nil end
        local getter = module.getCurrentSeaAsync
        if type(getter) ~= "function" then return nil end
        return getter(module)
    end)
    if not ok or sea == nil then return nil end
    return sea
end

local CURRENT_SEA = detectSea()

local State = {
    Destroyed = false,
    Version = VERSION,
    Sea = CURRENT_SEA,
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

-- Os nomes de fruta para os dropdowns de Skip list / Store keep list. Devolve
-- uma COPIA da lista canonica, para um chamador nao mexer na fonte por engano.
function State:FruitNames()
    local out = {}
    for index, name in ipairs(FRUIT_NAMES) do out[index] = name end
    return out
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
                -- O mar atual: a feature de ilhas escolhe a lista de destinos
                -- daqui (Sea 1 / 2 / 3 tem ilhas e pontos fixos diferentes).
                sea = CURRENT_SEA,
                -- O silent aim nasce com o alvo/alcance que o painel ja marcou
                -- antes de ligar (o usuario pode ajustar o slider e as teclas com
                -- o toggle ainda desligado; a escolha nao se perde).
                range = self.PendingSilentAimRange,
                exceptions = self.PendingSilentAimExceptions,
                -- A aba Player nasce com o multiplicador de velocidade que o
                -- painel ja marcou (o slider aplica mesmo sem reabrir o painel).
                speed = self.PendingPlayerSpeed,
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
    -- A escolha do painel guardada antes de ligar nao sobrevive ao unload.
    self.PendingSilentAimRange = nil
    self.PendingSilentAimExceptions = nil
    self.PendingPlayerSpeed = nil
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
        tabIcon = "swords",
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
    silentaim = {
        page = "Combat",
        section = "SILENT AIM",
        category = "Combat",
        icon = "crosshair",
        tabIcon = "crosshair",
        build = function(section, instance)
            local factory = State.Features.silentaim
            local keys = (factory and type(factory.exceptionKeys) == "table") and factory.exceptionKeys or { "Z", "X", "C", "V", "F" }
            local minRange = (factory and factory.MIN_RANGE) or 500
            local maxRange = (factory and factory.MAX_RANGE) or 1000
            local defaultRange = (factory and factory.DEFAULT_RANGE) or 500

            -- Silent aim: liga/desliga. Se o executor nao expoe o gancho de
            -- metatable, o Enable recusa -- avisa em vez de ligar um no-op.
            section:CreateToggle("Silent aim", false, function(value)
                if value and not State:SetFeature("silentaim", true) then
                    instance.Notify("Silent aim", "Unsupported executor (needs getrawmetatable).")
                end
                if not value then State:SetFeature("silentaim", false) end
            end)

            -- As teclas que SUPRIMEM o aim: segurar qualquer uma delas larga o
            -- alvo. Multi-dropdown (marca/desmarca), comecando em F (o padrao).
            section:CreateMultiDropdown("Exception keys", keys, { "F" }, function(selected)
                if State.Instances.silentaim then
                    State.Instances.silentaim:SetExceptions(selected)
                else
                    -- Ainda nao instanciada: guarda a escolha pra quando ligar.
                    State.PendingSilentAimExceptions = selected
                end
            end)

            -- Range: minimo 500, padrao 500, maximo 1000.
            section:CreateSlider("Range", minRange, maxRange, defaultRange, function(value)
                if State.Instances.silentaim then State.Instances.silentaim:SetRange(value) end
                State.PendingSilentAimRange = value
            end)

            section:CreateParagraph("Silent aim", "Redirects your attack position to the nearest player. Hold an exception key to release the aim.")
        end,
    },
    fruit = {
        page = "Farm",
        section = "FRUIT",
        category = "Farm",
        icon = "apple",
        tabIcon = "apple",
        build = function(section, instance)
            -- Fruit ESP: sem slider de distancia -- o alcance e ilimitado.
            section:CreateToggle("Fruit ESP", false, function(value)
                while State.Instances.fruit == nil do task.wait() end
                State.Instances.fruit:SetEsp(value)
            end)
            -- Grab: sem slider de distancia -- pega a fruta mais proxima de
            -- qualquer distancia.
            section:CreateToggle("Grab fruit", false, function(value)
                if value and not State:SetFeature("fruit", true) then
                    instance.Notify("Grab fruit", "Teleport motor ausente.")
                    return
                end
                if not value then State:SetFeature("fruit", false) end
                if State.Instances.fruit then State.Instances.fruit:SetGrab(value) end
            end)
            section:CreateToggle("Auto store fruit", false, function(value)
                if State.Instances.fruit then State.Instances.fruit:SetStore(value) end
            end)
            -- Skip list / Store keep list: seletores de fruta por DROPDOWN de
            -- selecao multipla (nada de digitar o nome). Usam a mesma fonte de
            -- nomes de fruta do sistema (State: FruitNames()). A lista escolhida
            -- vira o conjunto de prefixos que a feature ja usava.
            local fruits = State:FruitNames()
            section:CreateMultiDropdown("Skip list", fruits, {}, function(selected)
                if State.Instances.fruit then State.Instances.fruit:SetSkip(selected) end
            end)
            section:CreateMultiDropdown("Store keep list", fruits, {}, function(selected)
                if State.Instances.fruit then State.Instances.fruit:SetKeep(selected) end
            end)
        end,
    },
    islands = {
        page = "Travel",
        section = "ISLAND TELEPORT",
        category = "Travel",
        icon = "rocket",
        tabIcon = "rocket",
        build = function(section, instance)
            -- O dropdown lista as ilhas DO MAR ATUAL (Sea 1 / 2 / 3 tem mapas
            -- diferentes). A selecao NAO teleporta sozinha: e gate do toggle.
            -- Trocar a ilha com o toggle ligado voa de novo.
            --
            -- A lista vem da FABRICA (Feature:IslandLabels), que sabe o mar. Se a
            -- feature ja foi instanciada, ela manda (CurrentSea); senao, monta do
            -- mar detectado no load.
            local factory = State.Features.islands
            local islands = {}
            if factory and type(factory.IslandLabels) == "function" then
                islands = factory:IslandLabels((State.Instances.islands and State.Instances.islands.CurrentSea) or CURRENT_SEA)
            elseif factory and type(factory.islands) == "table" then
                islands = factory.islands
            end
            local selected = islands[1]
            -- O handle do toggle: a chegada precisa desligar ESTE controle
            -- (programaticamente), nao so a flag interna. SetValue dispara o
            -- callback, que por sua vez chama SetEnabled(false) -- um unico
            -- caminho de desligamento.
            local islandToggle = nil
            -- Ao CHEGAR na ilha, o toggle se desliga sozinho. So este toggle e
            -- mexido (a feature tem um so); nada mais e tocado. O hook e
            -- (re)ligado toda vez que o toggle e armado, porque a instancia da
            -- feature so nasce no primeiro SetFeature(..., true).
            local function wireArrivalHook()
                local feature = State.Instances.islands
                if not feature then return end
                feature.OnArrive = function(_, arrived)
                    if islandToggle and type(islandToggle.SetValue) == "function" then
                        islandToggle:SetValue(false)
                    elseif islandToggle and islandToggle.Value ~= nil then
                        islandToggle.Value = false
                    end
                    if arrived then
                        instance.Notify("Island teleport", ("Arrived at %s."):format(tostring(arrived)))
                    end
                end
            end
            islandToggle = section:CreateToggle("Island teleport", false, function(value)
                if value then
                    if not State:SetFeature("islands", true) then
                        instance.Notify("Island teleport", "Teleport motor ausente.")
                        return
                    end
                    wireArrivalHook()
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
            -- A instancia pode ja existir (toggle reaberto nesta sessao): liga o
            -- hook de imediato tambem.
            wireArrivalHook()
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
    player = {
        page = "Player",
        section = "PLAYER",
        category = "Player",
        icon = "user",
        tabIcon = "user",
        -- Aba local player: so o proprio character. O toggle da feature (Speed
        -- multiplier) e um slider, nao um on/off -- por isso o bloco monta os
        -- controles direto e usa SetFeature para instanciar a feature.
        build = function(section, instance)
            local factory = State.Features.player
            local minSpeed = (factory and factory.MIN_SPEED) or 0
            local maxSpeed = (factory and factory.MAX_SPEED) or 10
            local defaultSpeed = (factory and factory.DEFAULT_SPEED) or 2.3

            -- O Speed multiplier: o atributo SpeedMultiplier do character. O
            -- padrao do jogo e 2.3 -- mexer no slider ja aplica (a feature sobe
            -- sozinha) e o valor vale sempre que o slider mexer.
            section:CreateSlider("Speed multiplier", minSpeed, maxSpeed, defaultSpeed, function(value)
                State:SetFeature("player", true)
                if State.Instances.player then State.Instances.player:SetSpeed(value) end
                State.PendingPlayerSpeed = value
            end)

            -- UnbreakableAll: toggle que seta true e MANTEM true (re-aplica se o
            -- jogo tentar voltar). Ligar ja sobe a feature.
            section:CreateToggle("Unbreakable", false, function(value)
                State:SetFeature("player", true)
                if State.Instances.player then State.Instances.player:SetUnbreakable(value) end
            end)

            -- WaterWalking: o atributo de andar sobre a agua.
            section:CreateToggle("Water walk", false, function(value)
                State:SetFeature("player", true)
                if State.Instances.player then State.Instances.player:SetWaterWalking(value) end
            end)

            -- FlashstepCooldown: 0 = pronto (sem cooldown), 1 = com cooldown.
            section:CreateSlider("Flashstep cooldown", 0, 1, 0, function(value)
                State:SetFeature("player", true)
                if State.Instances.player then State.Instances.player:SetFlashstep(value) end
            end)

            section:CreateParagraph("Player", "Local player only: speed multiplier (game default 2.3), Unbreakable, water walk, and Flashstep cooldown (0 = ready). Stun is kept at 0.")
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
                tab = visual:CreateTab(panel.page, panel.category, panel.tabIcon or panel.icon) or false
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
