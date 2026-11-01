local game = game
local type = type
local tostring = tostring

-- A API de arquivo do executor vive agora no store compartilhado
-- (src/core/config-store.lua): ele resolve writefile/readfile/isfile pelos
-- nomes livres e cai pro getgenv()/_G. Nao ha mais copia aqui.
local env = type(getgenv) == "function" and getgenv() or _G
local report = (env.__DEPHUB and type(env.__DEPHUB.Log) == "function") and env.__DEPHUB.Log or function() end

-- O queue_on_teleport do executor. Como a API de arquivo, ele pode estar no
-- nome livre OU so no getgenv()/_G. Resolver a cada chamada (nao no load): alguns
-- executores so publicam o nome quando a primeira chamada acontece -- cachear no
-- load deixaria o Auto execute "sem API" e o toggle nao faria nada, o
-- "autoexecute nao funciona" do usuario.
local function resolveQueueOnTeleport()
    if type(queue_on_teleport) == "function" then return queue_on_teleport end
    if type(env.queue_on_teleport) == "function" then return env.queue_on_teleport end
    local genv = type(getgenv) == "function" and getgenv() or nil
    if type(genv) == "table" and type(genv.queue_on_teleport) == "function" then return genv.queue_on_teleport end
    if _G ~= env and type(_G.queue_on_teleport) == "function" then return _G.queue_on_teleport end
    return nil
end

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

-- O motor de persistencia COMPARTILHADO do hub (src/core/config-store.lua). Aqui
-- e o unico consumidor hoje, mas o mecanismo (achar a API de arquivo do executor,
-- JSON raso, gravar + reler, cair pra memoria, reaplicar re-disparando os
-- callbacks) mora la -- os outros jogos adotam o MESMO modulo sem copiar codigo.
local CONFIG_FILE = "DepHub_BloxFruits_config.json"
-- O gameId entra no arquivo (schema v2) pra uma config de outro jogo guardada no
-- mesmo arquivo nao ser aplicada aqui. `game` e o mesmo objeto que o backend ja
-- usa em todo lugar.
local CONFIG_GAME_ID = tostring(game.GameId or "")
local okStore, ConfigStore = loadFactory("src/core/config-store.lua")
local configStore = (okStore and type(ConfigStore) == "table" and type(ConfigStore.new) == "function")
    and ConfigStore.new({ file = CONFIG_FILE, gameId = CONFIG_GAME_ID }) or nil
if not configStore then report("BloxFruits: config-store nao carregou (" .. tostring(ConfigStore) .. ")") end

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
    -- A persistencia mora no core (State.Store). Aqui so os aliases publicos que
    -- o painel ja usa: State.Config aponta pra mesma tabela de valores do store
    -- (entao `State.Config.x = v` grava no store sem mudar uma linha do painel),
    -- e State.Store fica exposto pra debug/teste.
    Store = configStore,
    Config = configStore and configStore.Values or {},
    -- O motivo da ultima falha do Save (sem API, writefile recusou, arquivo nao
    -- voltou). Delegado ao store, mantido aqui pra nao quebrar quem le daqui.
    LastConfigError = nil,
}

-- A persistencia em si mora no core (src/core/config-store.lua). Estes metodos
-- so delegam, mantendo a superficie que o painel e os testes ja usam. Se o core
-- nao carregou (bundle velho), eles degradam: Save devolve false e nomeia o
-- motivo, Load nao aplica nada -- nunca fingem sucesso.
--
-- `sync()` re-aponta o store pra tabela visivel em State.Config antes de agir.
-- No caso normal sao a MESMA tabela (State.Config = Store.Values), mas um
-- chamador pode ter trocado State.Config por outra (os testes fazem
-- `state.Config = {...}`); sem re-apontar, o store gravaria a tabela antiga.
function State:syncStore()
    if self.Store then self.Store.Values = self.Config end
    return self.Store
end

function State:FileApi()
    return self.Store and self.Store:FileApi() or nil
end

function State:CanPersist()
    return self.Store ~= nil and self.Store:CanPersist()
end

function State:EncodeConfig()
    if not self.Store then return "{}" end
    -- Re-aponta o store pra tabela visivel em State.Config antes de codificar,
    -- pra o que sai no JSON ser o que o painel escreveu.
    self:syncStore()
    return self.Store:Encode()
end

-- Grava as configs atuais. Devolve true se gravou em disco, false se so deu pra
-- guardar em memoria (executor sem writefile). O LastConfigError reflete o motivo
-- que o store deu.
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

-- Le as configs do disco (ou da memoria) e devolve a tabela, sem aplicar nada.
function State:ReadConfig()
    if not self.Store then return nil end
    self:syncStore()
    return self.Store:Read()
end

-- Aplica uma config (a que veio do ReadConfig) ao estado e a UI: percorre a
-- lista que o painel registrou e chama a mesma operacao de cada callback.
-- Devolve o NUMERO de chaves realmente aplicadas (compativel com os chamadores
-- antigos); o detalhe (quais foram e quais falharam) fica em self.LastApplyResult.
function State:ApplyConfig(config)
    if not self.Store then return 0 end
    self:syncStore()
    local result = self.Store:Apply(config)
    self.LastApplyResult = result
    return result.count
end

-- Le do disco e aplica num passo: e o que o botao Load chamou.
function State:LoadConfig()
    local config = self:ReadConfig()
    return self:ApplyConfig(config)
end

-- Le do disco so pra preencher State.Config, sem aplicar (o Apply precisa dos
-- handles, que so existem depois do painel montar).
function State:PrimeConfig()
    if not self.Store then return nil end
    self:syncStore()
    return self.Store:Prime()
end

-- Registra como a chave volta ao vivo: a funcao de aplicar (o mesmo corpo do
-- callback) e, opcionalmente, o handle do controle -- para o Load tambem mexer
-- no que esta na tela, nao so o estado. Chamado pelo painel no build.
function State:RegisterConfig(key, apply, handle)
    if self.Store then return self.Store:Register(key, apply, handle) end
    return apply
end

-- A linha que RELIGA este script. O executor a re-executa quando convem (o
-- queue_on_teleport), entao o DepHub sobe de novo sozinho. Usa o mesmo
-- source ref do run atual (via env.__DEPHUB.SourceRef/SourceBaseURL), pra
-- religar a mesma build que o usuario esta rodando.
--
-- SEGURANCA: essa string vira codigo Lua (`loadstring(...)`), e ref/base vem de
-- estado COMPARTILHADO do ambiente do executor -- qualquer script no mesmo
-- ambiente pode ter escrito ali. Interpolar direto deixava aspas/barra/quebra de
-- linha virarem sintaxe no chunk enfileirado. Por isso ref e base passam por
-- validacao ANTES: ref com formato de commit/tag/branch (sem aspas, barra,
-- controle, espaco ou `..`), base HTTPS de host permitido. Reprovar nao monta
-- codigo nenhum -- cai no default seguro.
local SOURCE_HOSTS = {
    ["raw.githubusercontent.com"] = true,
    ["github.com"] = true,
    ["cdn.jsdelivr.net"] = true,
}

-- Uma ref segura: SHA completo, tag, ou branch de segmentos simples
-- (letra/numero/`_`/`-`/`.`/`/`), sem `..`, sem comecar/terminar com barra.
local function safeRef(ref)
    if type(ref) ~= "string" or ref == "" or #ref > 200 then return nil end
    if ref:find("%.%.") or ref:find("^[/]") or ref:find("[/]$") then return nil end
    if not ref:match("^[%w_%./-]+$") then return nil end
    return ref
end

-- Uma base segura: HTTPS, host na allowlist. Devolve a base sem barra final ou
-- nil se nao passar.
local function safeBase(base)
    if type(base) ~= "string" or #base > 300 then return nil end
    local scheme, host = base:match("^(https)://([^/]+)/")
    if not scheme or not host or not SOURCE_HOSTS[host] then return nil end
    if base:find('"') or base:find("\\") or base:find("[\r\n]") then return nil end
    return base
end

function State:SelfExecLine()
    local shared = env.__DEPHUB
    local loaderState = env.__DEPHUB_LOADER_STATE
    -- Sem `or` preservando valor antigo: a ref da sessao atual, validada.
    local ref = safeRef(shared and shared.SourceRef)
        or safeRef(type(loaderState) == "table" and loaderState.SourceRef)
        or "main"
    local base = safeBase(shared and shared.SourceBaseURL)
        or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
    if not base:match("/$") then base = base .. "/" end
    return ('loadstring(game:HttpGet("%sDepHub.lua"))("%s")'):format(base, ref)
end

-- Liga/desliga o auto-execute. Ligado, enfileira a re-execucao no executor
-- (queue_on_teleport), que re-sobe o DepHub depois do proximo teleporte. Sem o
-- executor expor queue_on_teleport, avisa em vez de fingir que ligou.
--
-- Devolve true se o auto-execute ficou ativo de fato.
function State:SetAutoExec(on)
    on = on == true
    local queue = resolveQueueOnTeleport()
    if not on then
        if queue then pcall(queue, "") end
        return true
    end
    if not queue then
        self.LastError = "executor sem queue_on_teleport"
        return false
    end
    local ok = pcall(queue, self:SelfExecLine())
    if not ok then self.LastError = "queue_on_teleport recusou" end
    return ok
end

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
        local createdHere = false
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
            createdHere = true
        end
        local ok = pcall(instance.Enable, instance)
        if not ok then
            -- Um Enable que falhou nao pode deixar a feature meio ligada no
            -- registry: a proxima vez ela seria reusada nesse estado. Desliga
            -- (best-effort) e, se esta chamada CRIOU a instancia, remove do
            -- registry -- se a instancia ja existia, so desligamos (nao
            -- apagamos o registro de outra sessao de toggle).
            self.LastError = "enable " .. name
            pcall(instance.Disable, instance)
            if createdHere then self.Instances[name] = nil end
            self.Toggles[name] = false
            return false
        end
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
            -- Blade hits: o auto-swing. Tem que SALVAR e reativar como qualquer
            -- outro toggle -- por isso o estado de ligado/desligado vai pro
            -- Config (bladhits) e a funcao de aplicar (applyBlade) e registrada:
            -- o auto-load reusa o mesmo caminho que o clique do usuario.
            local function applyBlade(value)
                if value and not State:SetFeature("bladhits", true) then
                    instance.Notify("Blade hits", "Remotes nao encontrados (Modules.Net).")
                    return
                end
                if not value then State:SetFeature("bladhits", false) end
            end
            local bladeToggle = section:CreateToggle("Blade hits", State.Config.bladhits == true, function(value)
                applyBlade(value)
                State.Config.bladhits = value == true
            end)
            State:RegisterConfig("bladhits", applyBlade, bladeToggle)
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
            local function applyAim(value)
                if value and not State:SetFeature("silentaim", true) then
                    instance.Notify("Silent aim", "Unsupported executor (needs getrawmetatable).")
                end
                if not value then State:SetFeature("silentaim", false) end
            end
            local aimToggle = section:CreateToggle("Silent aim", State.Config.silentaim == true, function(value)
                applyAim(value)
                State.Config.silentaim = value == true
            end)
            State:RegisterConfig("silentaim", applyAim, aimToggle)

            -- As teclas que SUPRIMEM o aim: segurar qualquer uma delas larga o
            -- alvo. Multi-dropdown (marca/desmarca), comecando em F (o padrao).
            local function applyExceptions(selected)
                if State.Instances.silentaim then
                    State.Instances.silentaim:SetExceptions(selected)
                else
                    -- Ainda nao instanciada: guarda a escolha pra quando ligar.
                    State.PendingSilentAimExceptions = selected
                end
            end
            local keysHandle = section:CreateMultiDropdown("Exception keys", keys, State.Config.exceptionKeys or { "F" }, function(selected)
                applyExceptions(selected)
                State.Config.exceptionKeys = selected
            end)
            State:RegisterConfig("exceptionKeys", applyExceptions, keysHandle)

            -- Range: minimo 500, padrao 500, maximo 1000.
            local function applyRange(value)
                if State.Instances.silentaim then State.Instances.silentaim:SetRange(value) end
                State.PendingSilentAimRange = value
            end
            local rangeHandle = section:CreateSlider("Range", minRange, maxRange, State.Config.range or defaultRange, function(value)
                applyRange(value)
                State.Config.range = value
            end)
            State:RegisterConfig("range", applyRange, rangeHandle)

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
            -- A feature de fruta so nasce no primeiro SetFeature(..., true).
            -- Quem liga um knob de fruta sobe a feature aqui; e o que dispensa o
            -- spin (while Instances.fruit == nil do task.wait() end) que travava a
            -- thread quando a fruta nunca era instanciada.
            local function ensureFruit()
                if State.Instances.fruit == nil then State:SetFeature("fruit", true) end
                return State.Instances.fruit
            end

            -- Fruit ESP: sem slider de distancia -- o alcance e ilimitado.
            local function applyEsp(value)
                local feature = State.Instances.fruit
                if value then feature = ensureFruit() end
                if feature then feature:SetEsp(value) end
            end
            local espToggle = section:CreateToggle("Fruit ESP", State.Config.fruitEsp == true, function(value)
                applyEsp(value)
                State.Config.fruitEsp = value == true
            end)
            State:RegisterConfig("fruitEsp", applyEsp, espToggle)

            -- Fruit tracer: as linhas ligando o character a cada fruta. Toggle a
            -- PARTE (o highlight e a distancia continuam vindo com o Fruit ESP);
            -- sem o ESP ligado, so guarda a escolha pro proximo ciclo.
            local function applyTrace(value)
                local feature = State.Instances.fruit
                if value then feature = ensureFruit() end
                if feature then feature:SetTrace(value) end
            end
            local traceToggle = section:CreateToggle("Fruit tracer", State.Config.fruitTrace == true, function(value)
                applyTrace(value)
                State.Config.fruitTrace = value == true
            end)
            State:RegisterConfig("fruitTrace", applyTrace, traceToggle)

            -- Grab: sem slider de distancia -- pega a fruta mais proxima de
            -- qualquer distancia.
            local function applyGrab(value)
                if value and not State:SetFeature("fruit", true) then
                    instance.Notify("Grab fruit", "Teleport motor ausente.")
                    return
                end
                if not value then State:SetFeature("fruit", false) end
                if State.Instances.fruit then State.Instances.fruit:SetGrab(value) end
            end
            local grabToggle = section:CreateToggle("Grab fruit", State.Config.fruitGrab == true, function(value)
                applyGrab(value)
                State.Config.fruitGrab = value == true
            end)
            State:RegisterConfig("fruitGrab", applyGrab, grabToggle)

            local function applyStore(value)
                local feature = State.Instances.fruit
                if value then feature = ensureFruit() end
                if feature then feature:SetStore(value) end
            end
            local storeToggle = section:CreateToggle("Auto store fruit", State.Config.fruitStore == true, function(value)
                applyStore(value)
                State.Config.fruitStore = value == true
            end)
            State:RegisterConfig("fruitStore", applyStore, storeToggle)

            -- Skip list / Store keep list: seletores de fruta por DROPDOWN de
            -- selecao multipla (nada de digitar o nome). Usam a mesma fonte de
            -- nomes de fruta do sistema (State: FruitNames()). A lista escolhida
            -- vira o conjunto de prefixos que a feature ja usava.
            local fruits = State:FruitNames()
            local function applySkip(selected)
                if #selected > 0 then ensureFruit() end
                if State.Instances.fruit then State.Instances.fruit:SetSkip(selected) end
            end
            local skipHandle = section:CreateMultiDropdown("Skip list", fruits, State.Config.fruitSkip or {}, function(selected)
                applySkip(selected)
                State.Config.fruitSkip = selected
            end)
            State:RegisterConfig("fruitSkip", applySkip, skipHandle)

            local function applyKeep(selected)
                if #selected > 0 then ensureFruit() end
                if State.Instances.fruit then State.Instances.fruit:SetKeep(selected) end
            end
            local keepHandle = section:CreateMultiDropdown("Store keep list", fruits, State.Config.fruitKeep or {}, function(selected)
                applyKeep(selected)
                State.Config.fruitKeep = selected
            end)
            State:RegisterConfig("fruitKeep", applyKeep, keepHandle)
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
            -- A ilha inicial: a salva, se ainda existir na lista do mar atual
            -- (a config e escrita noutro mar pode citar uma ilha que nao existe
            -- aqui); senao, a primeira da lista.
            local selected = islands[1]
            if State.Config.island ~= nil then
                for _, name in ipairs(islands) do
                    if name == State.Config.island then selected = name break end
                end
            end
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
            -- Liga/desliga o teleporte de ilha. E o MESMO caminho pro clique do
            -- usuario e pro auto-load: o config (islandOn) reusa esta funcao, e a
            -- chegada desliga pelo SetValue do toggle, que cai aqui tambem.
            local function applyIslandOn(value)
                if value then
                    if not State:SetFeature("islands", true) then
                        instance.Notify("Island teleport", "Teleport motor ausente.")
                        return
                    end
                    wireArrivalHook()
                    if State.Instances.islands then
                        -- Garante que a feature voe pro destino JA escolhido (o
                        -- salvo, no auto-load, ou o que o dropdown mostra). Na
                        -- primeira ligada a instancia nasce na UMA ilha padrao
                        -- (o contexto nao carrega a escolha), entao sem isto ela
                        -- voaria pra padrao mesmo com o dropdown no salvo.
                        if selected then State.Instances.islands:Select(selected) end
                        if not State.Instances.islands:SetEnabled(true) then
                            instance.Notify("Island teleport", State.Instances.islands.LastStatus or "falhou.")
                        end
                    end
                    return
                end
                if State.Instances.islands then State.Instances.islands:SetEnabled(false) end
                State:SetFeature("islands", false)
            end
            islandToggle = section:CreateToggle("Island teleport", State.Config.islandOn == true, function(value)
                applyIslandOn(value)
                State.Config.islandOn = value == true
            end)
            -- A instancia pode ja existir (toggle reaberto nesta sessao): liga o
            -- hook de imediato tambem.
            wireArrivalHook()
            -- Aplica uma escolha de ilha: guarda como o atual e, se a feature ja
            -- existe, seleciona (com o toggle ligado, isso ja voa).
            local function applyIsland(choice)
                selected = choice
                if State.Instances.islands then
                    local ok = State.Instances.islands:Select(choice)
                    if State.Instances.islands.ToggleOn and not ok then
                        instance.Notify("Island teleport", State.Instances.islands.LastStatus or "ilha fora do mapa.")
                    end
                end
            end
            local islandDown = section:CreateDropdown("Island", islands, selected, function(choice)
                applyIsland(choice)
                State.Config.island = choice
            end)
            -- Ordem de registro = ordem do auto-load. A ILHA e registrada antes do
            -- toggle: no load o destino salvo e escolhido primeiro, e so entao o
            -- toggle liga e voa direto pra ele -- sem voar pra ilha padrao e
            -- re-voar. O clique do usuario nao depende da ordem (cada controle
            -- chama seu proprio apply).
            State:RegisterConfig("island", applyIsland, islandDown)
            State:RegisterConfig("islandOn", applyIslandOn, islandToggle)
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
            local function applySpeed(value)
                State:SetFeature("player", true)
                if State.Instances.player then State.Instances.player:SetSpeed(value) end
                State.PendingPlayerSpeed = value
            end
            local speedHandle = section:CreateSlider("Speed multiplier", minSpeed, maxSpeed, State.Config.speed or defaultSpeed, function(value)
                applySpeed(value)
                State.Config.speed = value
            end)
            State:RegisterConfig("speed", applySpeed, speedHandle)

            -- UnbreakableAll: toggle que seta true e MANTEM true (re-aplica se o
            -- jogo tentar voltar). Ligar ja sobe a feature.
            local function applyUnbreakable(value)
                State:SetFeature("player", true)
                if State.Instances.player then State.Instances.player:SetUnbreakable(value) end
            end
            local unbreakableToggle = section:CreateToggle("Unbreakable", State.Config.unbreakable == true, function(value)
                applyUnbreakable(value)
                State.Config.unbreakable = value == true
            end)
            State:RegisterConfig("unbreakable", applyUnbreakable, unbreakableToggle)

            -- WaterWalking: o atributo de andar sobre a agua.
            local function applyWater(value)
                State:SetFeature("player", true)
                if State.Instances.player then State.Instances.player:SetWaterWalking(value) end
            end
            local waterToggle = section:CreateToggle("Water walk", State.Config.waterwalk == true, function(value)
                applyWater(value)
                State.Config.waterwalk = value == true
            end)
            State:RegisterConfig("waterwalk", applyWater, waterToggle)

            -- FlashstepCooldown: 0 = pronto (sem cooldown), 1 = com cooldown.
            local function applyFlashstep(value)
                State:SetFeature("player", true)
                if State.Instances.player then State.Instances.player:SetFlashstep(value) end
            end
            local flashHandle = section:CreateSlider("Flashstep cooldown", 0, 1, State.Config.flashstep or 0, function(value)
                applyFlashstep(value)
                State.Config.flashstep = value
            end)
            State:RegisterConfig("flashstep", applyFlashstep, flashHandle)

            section:CreateParagraph("Player", "Local player only: speed multiplier (game default 2.3), Unbreakable, water walk, and Flashstep cooldown (0 = ready). Stun is kept at 0.")
        end,
    },
    -- CONFIG: os botoes de salvar/carregar. Nao e uma feature (nao tem toggle
    -- nem modulo por tras): e o unico lugar que grava e devolve todas as
    -- escolhas do painel. Por isso `alwaysShow` -- o loop de UI o constroi
    -- mesmo sem um modulo em FEATURE_MODULES.
    config = {
        page = "Player",
        section = "CONFIG",
        category = "Player",
        icon = "save",
        tabIcon = "user",
        alwaysShow = true,
        build = function(section, instance)
            -- Auto execute: ligado, o DepHub se re-executa sozinho (via
            -- queue_on_teleport) depois do proximo teleporte -- o script volta a
            -- subir sem o usuario colar de novo. Persiste como os outros knobs.
            local function applyAutoExec(value)
                local ok = State:SetAutoExec(value)
                if value and not ok then
                    instance.Notify("Auto execute", State.LastError or "This executor has no queue_on_teleport.")
                end
            end
            local autoToggle = section:CreateToggle("Auto execute", State.Config.autoexec == true, function(value)
                applyAutoExec(value)
                State.Config.autoexec = value == true
            end)
            State:RegisterConfig("autoexec", applyAutoExec, autoToggle)

            section:CreateButton("Save config", function()
                local ok = State:SaveConfig()
                if ok then
                    instance.Notify("Config", "Saved.")
                else
                    -- Reporta o MOTIVO real (sem API de arquivo, writefile
                    -- recusou, ou o arquivo nao voltou): "so na memoria" sozinho
                    -- nao dizia o que deu errado.
                    instance.Notify("Config", State.LastConfigError or "Saved for this session only.")
                end
            end)
            section:CreateButton("Load config", function()
                local applied = State:LoadConfig()
                local failed = State.LastApplyResult and #State.LastApplyResult.failed or 0
                if applied > 0 and failed == 0 then
                    instance.Notify("Config", ("Loaded %d settings."):format(applied))
                elseif applied > 0 then
                    -- Aplicou parte: diz quantas entraram e quantas nao -- antes o
                    -- painel dizia "Loaded N" mesmo com feature recusando a config.
                    instance.Notify("Config", ("Loaded %d, %d failed."):format(applied, failed))
                elseif failed > 0 then
                    instance.Notify("Config", ("Load failed (%d)."):format(failed))
                else
                    instance.Notify("Config", "Nothing saved yet.")
                end
            end)
            section:CreateParagraph("Config", "Save your panel settings to a file and load them back on any session. Auto execute re-runs the script by itself after a teleport.")
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
    -- Constroi um bloco de UI. Cria a categoria e a aba na primeira vez; a
    -- partir dai so adiciona a secao. Vale tanto para as features quanto para o
    -- bloco de config (que nao tem modulo).
    local function buildPanel(panel)
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

    -- Auto-load, parte 1: le o arquivo pra State.Config ANTES de montar, pra
    -- cada controle ja nascer no valor salvo (sem piscar em default). Sem
    -- arquivo, State.Config fica vazio e os controles usam o padrao.
    local saved = nil
    pcall(function() saved = State:PrimeConfig() end)

    for _, entry in ipairs(FEATURE_MODULES) do
        local panel = PANELS[entry.name]
        if panel and State.Features[entry.name] then buildPanel(panel) end
    end
    -- Blocos sem feature (o CONFIG): sempre construidos.
    for _, panel in pairs(PANELS) do
        if panel.alwaysShow == true then buildPanel(panel) end
    end
    State.UIFrontend = visual

    -- Auto-load, parte 2: empurra os valores lidos pros estados das features
    -- (Pending do silent aim, alcance, etc.). Os handles ja existem, entao o
    -- ApplyConfig tambem confere a posicao dos controles. "Salvar e gg": o
    -- usuario nao clica em Load toda sessao.
    if type(saved) == "table" then
        pcall(function() State:ApplyConfig(saved) end)
    end
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
