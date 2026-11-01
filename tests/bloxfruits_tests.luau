-- Behaviour checks for o backend de Blox Fruits do usuario.
--
-- O backend carrega src/games/features/bloxfruits/<nome>.lua (uma feature por
-- arquivo, cada uma independente) e monta o painel. As features que ainda nao
-- foram portadas ficam guardadas em features/bloxfruits/parked/ -- fora da
-- pasta ativa, sem carregar e sem entrar no manifest -- portanto nao aparecem
-- aqui. Nao existe flag global: o que carrega e so o que esta em FEATURE_MODULES.
local FEATURE_PREFIX = "src/games/features/bloxfruits/"
local FEATURES = {"bladhits", "silentaim", "fruit", "islands", "player"}
-- Infraestrutura: carrega sozinha (sem toggle) e fica em State.Infra.
local INFRA = {"teleport"}

-- O backend resolve as features pelo mesmo game:HttpGet que um executor usa, e
-- a blade hit faz os proprios game:GetService, entao cada arquivo tem que ser
-- servido pelo sandbox.
local function bfContext(placeId, gameId)
    local ctx = sandbox(placeId, gameId)
    for _, name in ipairs(FEATURES) do
        local path = FEATURE_PREFIX .. name .. ".lua"
        ctx.Responses[path] = sources[path]
    end
    for _, name in ipairs(INFRA) do
        local path = FEATURE_PREFIX .. name .. ".lua"
        ctx.Responses[path] = sources[path]
    end
    -- Os remotes que a blade hit resolve, para o Enable passar de verdade.
    local rstorage = ctx.Services.ReplicatedStorage
    local modules = Instance.new("Folder"); modules.Name = "Modules"; modules.Parent = rstorage
    local netFolder = Instance.new("Folder"); netFolder.Name = "Net"; netFolder.Parent = modules
    local attack = Instance.new("RemoteEvent"); attack.Name = "RE/RegisterAttack"; attack.Parent = netFolder
    local hit = Instance.new("RemoteEvent"); hit.Name = "RE/RegisterHit"; hit.Parent = netFolder
    -- O jogo diz o mar em ReplicatedStorage.Util.Realm (getCurrentSeaAsync). Aqui
    -- ele responde Sea 2 por padrao; um teste pode trocar ctx.RealmSea antes de
    -- carregar o backend para exercitar outro mar.
    local util = Instance.new("Folder"); util.Name = "Util"; util.Parent = rstorage
    local realm = Instance.new("ModuleScript"); realm.Name = "Realm"; realm.Parent = util
    ctx.RealmSea = 2
    -- Nao substituir realm._props: ele guarda ClassName/Name/Parent. So adicionar
    -- o slot Module (o payload que o require do harness chama).
    realm._props.Module = function()
        return { getCurrentSeaAsync = function() return ctx.RealmSea end }
    end
    return ctx, modules
end

-- A blade hit e auto-contida de proposito: nada de DepHub, nada de adapter.
-- Ela tem que carregar e rodar sozinha, com os proprios services.
do
    local Factory = sources[FEATURE_PREFIX .. "bladhits.lua"]
    local ctx = bfContext(994732206, 994732206)
    local feature = ctx.Env.loadstring(Factory)()
    check(type(feature) == "table" and type(feature.new) == "function", "a blade hit carrega sozinha e publica new()")

    local instance = feature.new()
    check(type(instance) == "table", "blade hit instancia sem argumento")
    check(instance:IsEnabled() == false, "blade hit comeca desligada")
    -- Sem UI de knob: os valores padrao sao fixos no melhor que funciona.
    check(instance.AttackRange == 300, "alcance padrao e o maximo que funciona (300)")
    check(instance.MinInterval == 0.05, "intervalo padrao e o piso seguro (0.05s)")
    check(instance.hits == 0, "contador de hits comeca em zero")

    -- Os setters validam, como o seu original.
    check(instance:SetRange(250) and instance.AttackRange == 250, "SetRange aplica um alcance valido")
    check(instance:SetRange(0) == false and instance.AttackRange == 250, "SetRange rejeita zero e nao muda o valor")
    check(instance:SetRange(-5) == false, "SetRange rejeita negativo")
    check(instance:SetRange("abc") == false, "SetRange rejeita nao-numerico")
    check(instance:SetInterval(0.25) and instance.MinInterval == 0.25, "SetInterval aplica um intervalo valido")
    check(instance:SetInterval(-1) == false, "SetInterval rejeita negativo")

    instance:SetHitId(4242)
    check(instance.LastHitId == 4242, "SetHitId guarda o id pro proximo hit")
    instance:SetHitId(nil)
    check(instance.LastHitId == 4242, "SetHitId ignora nil e nao apaga o id")
end

-- O caminho ativo: a blade hit carrega, instancia pelo toggle e sai no Destroy.
-- Este e o contrato que importa para o script do usuario.
do
    local ctx = bfContext(994732206, 994732206)
    local state = ctx:Run("src/games/bloxfruits.lua")
    check(type(state) == "table" and state.Destroyed == false, "o backend de Blox Fruits sobe")

    local factory = state.Features.bladhits
    check(type(factory) == "table" and type(factory.new) == "function", "a blade hit e carregada pelo backend")
    check(state.Features.fruit ~= nil, "a feature de fruta e carregada pelo backend")
    check(state.Features.raid == nil, "a raid parkeada nao e carregada pelo backend")
    check(type(state.Errors) == "table" and #state.Errors == 0, "as features carregam sem erro: " .. table.concat(state.Errors, "; "))

    -- Nada liga sozinho: o painel abre sem instanciar a feature.
    check(state.Instances.bladhits == nil, "a blade hit nao instancia so pelo load")
    check(state:GetToggle("bladhits") == false, "a blade hit comeca desligada")

    -- O toggle instancia e liga. Com os remotes no lugar o Enable passa.
    local ok = state:SetToggle("bladhits", true)
    check(ok == true, "ligar o toggle liga a blade hit com os remotes no lugar")
    check(state.Instances.bladhits ~= nil, "ligar o toggle instancia a blade hit")
    check(state:GetToggle("bladhits") == ok, "o estado do toggle acompanha o resultado do Enable")
    check(state.Instances.bladhits:IsEnabled() == true, "com remotes a blade hit liga")

    -- Desligar sempre funciona e nao explode.
    check(state:SetToggle("bladhits", false), "desligar a blade hit sempre funciona")
    check(state:GetToggle("bladhits") == false, "depois de desligar o toggle le falso")
    check(state.Instances.bladhits:IsEnabled() == false, "depois de desligar a feature esta parada")

    -- Os knobs continuam no modulo (sem UI): quem quiser mexe pelo console.
    state:SetToggle("bladhits", true)
    check(state:SetFeatureRange("bladhits", 180), "o backend ainda encaminha SetRange")
    check(state.Instances.bladhits.AttackRange == 180, "o alcance chega no modulo")
    check(state:SetFeatureInterval("bladhits", 0.05), "o backend ainda encaminha SetInterval")
    check(state.Instances.bladhits.MinInterval == 0.05, "o intervalo chega no modulo")

    -- Um nome desconhecido nao explode nem liga nada. O teleporte e infra, nao
    -- feature: tambem e rejeitado como nome de toggle.
    check(state:SetToggle("nao-existe", true) == false, "feature desconhecida e rejeitada")
    check(state:SetFeatureRange("nao-existe", 5) == false, "knob de feature desconhecida e rejeitado")
    check(state:SetToggle("teleport", true) == false, "o teleporte nao vira toggle")

    -- A feature de fruta instancia pelo proprio toggle e recebe o motor de
    -- teleporte (a injecao e o contrato que a faz voar ate a fruta).
    check(state.Instances.fruit == nil, "a fruta nao instancia so pelo load")
    check(state:SetToggle("fruit", true), "ligar o toggle instancia a fruta")
    check(state.Instances.fruit.Teleport ~= nil, "a fruta recebeu o motor de teleporte na criacao")
    check(state.Instances.fruit.Teleport == state.Infra.teleport, "o motor e o mesmo objeto da infra")
    state:SetToggle("fruit", false)

    -- A raid esta PARKEADA (o usuario vai refazer por completo): nao instancia,
    -- nao carrega e o toggle e recusado. O arquivo foi pra parked/raid.lua.
    check(state.Instances.raid == nil, "a raid parkeada nao instancia pelo load")
    check(state:SetToggle("raid", true) == false, "a raid parkeada nao pode ser ligada")

    local status = state:GetStatus()
    check(status.TogglesOn == 1, "status conta so a blade hit ligada")
    check(status.Infra.teleport ~= nil, "status lista o teleporte na infra, fora da contagem")

    state:Destroy()
    check(state.Destroyed and next(state.Instances) == nil, "destroy derruba as instancias")
    check(ctx.State.__DEPHUB.BloxFruits == nil, "destroy limpa o global do backend")
    check(state:SetToggle("bladhits", true) == false, "backend destruido rejeita toggles")
end

-- Sem os remotes, ligar nao explode: o modulo instancia, o Enable devolve false
-- e o toggle fica desligado. O jogador ve a notificacao, nao um erro.
do
    local ctx, modules = bfContext(994732206, 994732206)
    modules.Parent = nil
    local state = ctx:Run("src/games/bloxfruits.lua")
    check(state:SetToggle("bladhits", true) == false, "sem remotes ligar devolve false")
    check(state.Instances.bladhits ~= nil, "mesmo assim o modulo foi instanciado")
    check(state:GetToggle("bladhits") == false, "sem remotes o toggle fica desligado")
    check(state.Instances.bladhits:IsEnabled() == false, "sem remotes a feature nao liga")
    state:Destroy()
end

-- As features parkeadas ficam fora da pasta ativa: o backend nao as resolve e
-- o manifest nao as lista (nada apagado -- so nao carregam).
do
    local ctx = bfContext(994732206, 994732206)
    ctx.Responses[FEATURE_PREFIX .. "parked/farm.lua"] = "error('parked feature must not be fetched')"
    local state = ctx:Run("src/games/bloxfruits.lua")
    check(type(state) == "table" and state.Destroyed == false, "o backend sobe com o parked/ ao lado")
    check(next(state.Features) ~= nil, "so as features ativas carregam")
    for name in pairs(state.Features) do
        check(name == "bladhits" or name == "silentaim" or name == "teleport" or name == "fruit" or name == "islands" or name == "player", "nenhuma feature parkeada e carregada")
    end
    check(state.Instances["farm"] == nil, "uma feature parkeada nao instancia")
    check(state:SetToggle("farm", true) == false, "uma feature parkeada nao pode ser ligada")
    state:Destroy()
end

-- Com uma janela montada, o backend constroi o painel e o toggle do painel
-- dirige o mesmo caminho do backend.
do
    local ctx = bfContext(994732206, 994732206)
    local ui = ctx:MountUI()
    local state = ctx:Run("src/games/bloxfruits.lua")
    check(type(state) == "table", "o backend constroi contra uma janela montada")
    check(state.UIFrontend == ui, "o backend publica o frontend montado")

    local names = {}
    for _, tab in ipairs(ui.Library._Tabs) do names[tab.Name] = true end
    check(names["Combat"] == true, "a aba Combat e criada para a blade hit")
    check(names["Farm"] == true, "a aba Farm e criada para a fruta")

    -- O tamanho compacto (600x420) foi APLICADO na criacao da janela: a shell
    -- escreve o UDim2 em Library.Default.UISize, que e o que o RedzLib le.
    local applied = ui.Library.Default and ui.Library.Default.UISize
    check(applied and applied.X.Offset == 600 and applied.Y.Offset == 420, "o painel abre em 600x420 de verdade")

    -- A aba de fruta NAO tem mais os sliders de distancia nem campos de texto:
    -- as listas agora sao dropdowns de selecao multipla.
    local labels = {}
    for _, control in ipairs(ui.Library._Controls) do
        labels[control.Kind .. ":" .. tostring(control.Label)] = control
    end
    check(labels["slider:ESP max distance"] == nil, "o slider ESP max distance saiu")
    check(labels["slider:Grab max distance"] == nil, "o slider Grab max distance saiu")
    check(labels["textbox:Skip list"] == nil, "a Skip list nao e mais um campo de texto")
    check(labels["textbox:Store keep list"] == nil, "a Store keep list nao e mais um campo de texto")

    local skipDropdown = labels["dropdown:Skip list"]
    local keepDropdown = labels["dropdown:Store keep list"]
    check(skipDropdown ~= nil and skipDropdown.MultiSelect == true, "a Skip list e um dropdown de selecao multipla")
    check(keepDropdown ~= nil and keepDropdown.MultiSelect == true, "a Store keep list e um dropdown de selecao multipla")
    check(skipDropdown.Options and #skipDropdown.Options > 40, "o dropdown lista as frutas reais (fonte do sistema)")
    check(skipDropdown.Options[1] == "Barrier", "os nomes de fruta vem da lista canonica (primeiro = Barrier)")
    check(table.find(skipDropdown.Options, "Dragon") ~= nil and table.find(skipDropdown.Options, "Kitsune") ~= nil, "nomes reais como Dragon e Kitsune estao na lista")

    -- Escolher uma fruta no dropdown de Skip list chega na feature como o
    -- conjunto de prefixos que ela ja usava -- o caminho do painel ate a logica.
    state:SetFeature("fruit", true)
    local fruit = state.Instances.fruit
    check(fruit ~= nil, "a feature de fruta instancia ao ligar")
    skipDropdown.Handle:Select("Dragon", true)
    check(fruit.Skip["dragon"] == true, "escolher Dragon no dropdown entra na skip list")
    keepDropdown.Handle:Select("Leopard", true)
    check(fruit.Keep["leopard"] == true, "escolher Leopard no dropdown entra na store keep list")
    state:SetFeature("fruit", false)

    -- Silent aim: um toggle, um dropdown de teclas de excecao (Z X C V F) e um
    -- slider de alcance (500 a 1000). O toggle dirige o mesmo caminho do backend.
    local aimToggle = labels["toggle:Silent aim"]
    local exceptionDown = labels["dropdown:Exception keys"]
    local rangeSlider = labels["slider:Range"]
    check(aimToggle ~= nil, "o painel registra o toggle Silent aim")
    check(exceptionDown ~= nil and exceptionDown.MultiSelect == true, "as teclas de excecao sao um dropdown de selecao multipla")
    check(#exceptionDown.Options == 5, "o dropdown lista as 5 teclas")
    check(exceptionDown.Options[1] == "Z" and exceptionDown.Options[5] == "F", "as teclas sao Z X C V F")
    check(rangeSlider ~= nil, "o painel registra o slider Range")
    check(rangeSlider.Min == 500 and rangeSlider.Max == 1000, "o slider vai de 500 a 1000")
    check(rangeSlider.Value == 500, "o padrao do slider e 500")
    check(labels["toggle:Debug logs"] ~= nil, "o painel registra o toggle Debug logs")

    -- O toggle do painel liga a feature pelo mesmo caminho do backend.
    aimToggle.Handle:SetValue(true)
    check(state:GetToggle("silentaim") == true, "o toggle do painel liga o silent aim")
    check(state.Instances.silentaim ~= nil and state.Instances.silentaim:IsEnabled() == true, "a feature liga pelo toggle")
    -- A feature nasce com F marcada (o padrao) e o alcance de 500 do painel.
    check(state.Instances.silentaim.MaxRange == 500, "a feature nasce com o alcance padrao do slider (500)")
    aimToggle.Handle:SetValue(false)
    check(state:GetToggle("silentaim") == false, "o toggle do painel desliga o silent aim")
    check(state.Instances.silentaim:IsEnabled() == false, "a feature desliga pelo toggle")
end

-- Config do painel: o bloco CONFIG (sem feature) sempre monta, com os botoes de
-- salvar/carregar. As escolhas ficam em State.Config a cada mexida de controle;
-- o Save grava pro arquivo do executor e o Load devolve -- reaplicando o estado
-- e a UI. Aqui, com o filesystem em memoria do harness.
do
    local ctx = bfContext(994732206, 994732206)
    local ui = ctx:MountUI()
    local state = ctx:Run("src/games/bloxfruits.lua")
    check(type(state) == "table", "o backend sobe para o teste de config")

    local labels, buttons = {}, {}
    for _, control in ipairs(ui.Library._Controls) do
        labels[control.Kind .. ":" .. tostring(control.Label)] = control
        if control.Kind == "button" then buttons[tostring(control.Label)] = control end
    end
    check(buttons["Save config"] ~= nil and type(buttons["Save config"].Callback) == "function", "o bloco CONFIG monta o botao Save config")
    check(buttons["Load config"] ~= nil and type(buttons["Load config"].Callback) == "function", "o bloco CONFIG monta o botao Load config")

    -- Sem nada salvo, o Load nao inventa valores.
    check(state:LoadConfig() == 0, "Load sem arquivo nao aplica nada")

    -- Mexe em controles de features variadas: silent aim (alcance + debug). O
    -- callback de cada controle ja grava no Config. (O slider do harness nao tem
    -- SetValue: o valor e o callback sao do proprio registro do controle.)
    local rangeControl = labels["slider:Range"]
    rangeControl.Value = 777
    rangeControl.Callback(777)
    check(state.Config.range == 777, "mexer no Range grava no Config")
    labels["toggle:Debug logs"].Handle:SetValue(true)
    check(state.Config.debug == true, "mexer no Debug logs grava no Config")

    -- O botao Save grava o arquivo do executor (filesystem em memoria).
    buttons["Save config"].Callback()
    local file = ctx.Files["DepHub_BloxFruits_config.json"]
    check(type(file) == "string" and file:find('"range":777', 1, true) ~= nil, "o Save grava o arquivo com o range escolhido")

    -- Zera a escolha viva (como numa sessao nova, controles no padrao) e carrega.
    state.Config.range = nil
    state.PendingSilentAimRange = nil
    local applied = state:LoadConfig()
    check(applied > 0, "o Load aplica as chaves salvas")
    check(state.Config.range == 777, "o Load devolve o range salvo")
    check(state.PendingSilentAimRange == 777, "o Load re-aplica o range no estado da feature (Pending)")

    -- O valor chega na instancia viva: liga a feature e confere que o Load
    -- seguinte empurra o alcance pra ela.
    state:SetFeature("silentaim", true)
    state.Config.range = nil
    state:LoadConfig()
    check(state.Instances.silentaim ~= nil and state.Instances.silentaim.MaxRange == 777, "o Load aplica o range na feature instanciada")
end

-- Auto-load: com uma config ja no disco, o painel abre com ela aplicada ("so
-- salvar e gg" -- o usuario nao clica em Load toda sessao).
do
    local ctx = bfContext(994732206, 994732206)
    local ui = ctx:MountUI()
    -- Pre-existe um arquivo (como se a sessao anterior tivesse salvo).
    ctx.Files["DepHub_BloxFruits_config.json"] = '{"debug":true,"range":640,"speed":4}'
    local state = ctx:Run("src/games/bloxfruits.lua")
    check(state.Config.range == 640, "o painel abre com o range salvo aplicado")
    check(state.Config.debug == true, "o painel abre com o debug salvo aplicado")
    check(state.Config.speed == 4, "o painel abre com a velocidade salva aplicada")
    check(state.PendingSilentAimRange == 640, "o valor salvo tambem alimenta o Pending da feature")

    -- A tela nasce refletindo o salvo: o controle do Debug logs ja abre ligado.
    local debugControl = nil
    for _, control in ipairs(ui.Library._Controls) do
        if control.Kind == "toggle" and control.Label == "Debug logs" then debugControl = control end
    end
    check(debugControl ~= nil and debugControl.Handle.Value == true, "o toggle Debug logs abre no valor salvo (a tela reflete o Load)")
end

-- Fallback em memoria: sem writefile/readfile/isfile, o Save nao quebra -- so
-- fica na sessao. O Load devolve o que ficou guardado.
do
    local ctx = bfContext(994732206, 994732206)
    local ui = ctx:MountUI()
    local state = ctx:Run("src/games/bloxfruits.lua")

    ctx.Env.writefile = nil
    ctx.Env.readfile = nil
    ctx.Env.isfile = nil

    check(state:CanPersist() == false, "sem a API de arquivo CanPersist e false")
    state.Config.range = 640
    check(state:SaveConfig() == false, "sem arquivo o Save so guarda em memoria")
    state.Config.range = nil
    check(state:LoadConfig() == 1 and state.Config.range == 640, "o Load devolve a config em memoria")
end

-- Encode/decode do codec JSON minimo: escalares, booleanos e arrays de string.
do
    local ctx = bfContext(994732206, 994732206)
    local _ = ctx:MountUI()
    local state = ctx:Run("src/games/bloxfruits.lua")
    state.Config = {
        range = 500,
        debug = true,
        silentaim = false,
        island = "Cafe",
        fruitSkip = { "Dragon", "Leopard" },
    }
    local json = state:EncodeConfig()
    check(json:find('"range":500', 1, true) ~= nil, "encode: numero sem aspas")
    check(json:find('"debug":true', 1, true) ~= nil, "encode: booleano true")
    check(json:find('"silentaim":false', 1, true) ~= nil, "encode: booleano false")
    check(json:find('"island":"Cafe"', 1, true) ~= nil, "encode: string com aspas")
    check(json:find('"fruitSkip":["Dragon","Leopard"]', 1, true) ~= nil, "encode: array de string")

    -- Grava e le de volta pelo arquivo: o round-trip tem que preservar tudo.
    ctx.Env.writefile("DepHub_BloxFruits_config.json", json)
    local parsed = state:ReadConfig()
    check(parsed.range == 500 and parsed.debug == true and parsed.silentaim == false, "decode: escalares voltam")
    check(parsed.island == "Cafe", "decode: string volta")
    check(#parsed.fruitSkip == 2 and parsed.fruitSkip[1] == "Dragon" and parsed.fruitSkip[2] == "Leopard", "decode: array volta inteiro")
end

-- Chegada desliga o toggle SOZINHO, pelo caminho do backend: ligar o toggle do
-- painel voa, encostar no destino desliga o mesmo controle (SetValue(false)),
-- que por sua vez chama SetEnabled(false). Nada mais e tocado.
do
    local ctx = bfContext(994732206, 994732206)
    local ui = ctx:MountUI()
    local state = ctx:Run("src/games/bloxfruits.lua")
    check(type(state) == "table", "o backend sobe com o painel montado")

    -- Personagem + mapa com Snow Mountain (o destino do voo).
    local char = Instance.new("Model"); char.Name, char.Parent = "Character", ctx.Player
    ctx.Player.Character = char
    local root = Instance.new("Part"); root.Name, root.Position, root.Parent = "HumanoidRootPart", Vector3.new(0, 0, 0), char
    local humanoid = Instance.new("Humanoid"); humanoid.Parent = char
    local map = Instance.new("Folder"); map.Name, map.Parent = "Map", ctx.Services.Workspace
    local snow = Instance.new("Model"); snow.Name, snow.Parent = "SnowMountain", map
    local floor = Instance.new("Part"); floor.Name, floor.Position, floor.Parent = "Floor", Vector3.new(0, 50, 0), snow

    -- Acha o toggle "Island teleport" que o backend registrou.
    local islandToggle = nil
    for _, control in ipairs(ui.Library._Controls) do
        if control.Kind == "toggle" and control.Label == "Island teleport" then islandToggle = control.Handle end
    end
    check(islandToggle ~= nil, "o painel registra o toggle Island teleport")

    -- Ligar pelo metodo real do controle (SetValue flips e dispara o callback),
    -- exatamente como o clique faz na lib real.
    islandToggle:SetValue(true)
    check(islandToggle.Value == true, "ligar o toggle arma o voo")
    check(state.Instances.islands ~= nil and state.Instances.islands.ToggleOn == true, "o backend arma a feature")

    -- Perto do destino: a chegada desliga o toggle sozinho.
    root.Position = Vector3.new(0, 50, 0)
    ctx.Services.RunService.Heartbeat:Fire()
    check(islandToggle.Value == false, "chegar na ilha desliga o toggle do painel")
    check(state.Instances.islands.ToggleOn == false, "o backend tambem desarma ao chegar")

    state:Destroy()
end

-- A feature de fruta e auto-contida e usa o motor de teleporte por INJECAO:
-- ela nao tem teleporte proprio. Sem motor ainda funciona para ESP/store; so o
-- grab recusa. Este bloco carrega ela sozinha e exercita a API publica.
do
    local ctx = bfContext(994732206, 994732206)
    local Fruit = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "fruit.lua"])()
    check(type(Fruit) == "table" and type(Fruit.new) == "function", "a fruta carrega sozinha e publica new()")

    -- Sem motor: a feature sobe, aceita knobs, e o grab recusa.
    local bare = Fruit.new()
    check(bare:Enable() == true, "a fruta liga sem motor de teleporte")
    check(bare.Teleport == nil, "sem motor injetado Teleport e nil")
    check(bare:CollectNearestOnce() == false, "sem motor o grab recusa (nao ha como voar)")

    -- Com o motor injetado.
    local motor = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "teleport.lua"])().new()
    bare:SetTeleport(motor)
    check(bare.Teleport == motor, "SetTeleport injeta o motor")

    -- Alcance ILIMITADO: os sliders de distancia sairam, entao nao ha mais
    -- SetRange/SetEspRange nem campos Range/EspRange na feature.
    check(bare.SetRange == nil and bare.SetEspRange == nil, "os knobs de distancia sairam (alcance ilimitado)")
    check(bare.Range == nil and bare.EspRange == nil, "nao ha mais campos de limite de distancia")

    -- Listas de skip/keep. A UI manda um ARRAY de nomes (do dropdown de selecao
    -- multipla); a feature guarda como conjunto de prefixos em minusculo.
    bare:SetSkip({ "Dragon", "Rocket" })
    check(bare.Skip["dragon"] == true and bare.Skip["rocket"] == true, "SetSkip aceita o array do dropdown")
    bare:SetKeep({ "Leopard" })
    check(bare.Keep["leopard"] == true, "SetKeep aceita o array do dropdown")
    -- O formato antigo (string separada por virgula) continua aceito.
    bare:SetSkip("Dragon, Rocket")
    check(bare.Skip["dragon"] == true and bare.Skip["rocket"] == true, "SetSkip ainda aceita a string")

    -- Os tres sub-toggles ligam e desligam sem explodir.
    check(bare:SetGrab(true) and bare.GrabEnabled == true, "SetGrab liga o grab")
    check(bare:SetGrab(false) and bare.GrabEnabled == false, "SetGrab desliga o grab")
    check(bare:Enable() and bare:Disable() and bare:IsEnabled() == false, "Enable/Disable ciclam")
    bare:Destroy()
end

-- A fruta no chao, de verdade: um Tool com OriginalName e Handle e achado; um
-- Tool qualquer nao. E o NearestGroundFruit respeita range e skip.
do
    local ctx = bfContext(994732206, 994732206)
    local Fruit = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "fruit.lua"])()
    local fruit = Fruit.new()

    local character = Instance.new("Model"); character.Name, character.Parent = "Character", ctx.Player
    ctx.Player.Character = character
    local root = Instance.new("Part"); root.Name, root.Position, root.Parent = "HumanoidRootPart", Vector3.new(0, 0, 0), character
    local humanoid = Instance.new("Humanoid"); humanoid.Parent = character

    -- Uma fruta no chao.
    local ground = Instance.new("Tool"); ground.Name = "Dragon-Dragon Fruit"; ground.Parent = ctx.Services.Workspace
    ground:SetAttribute("OriginalName", "Dragon-Dragon Fruit")
    local handle = Instance.new("Part"); handle.Name, handle.Position, handle.Parent = "Handle", Vector3.new(0, 0, 30), ground

    -- Um Tool qualquer (uma espada) nao conta como fruta.
    local sword = Instance.new("Tool"); sword.Name = "Sword"; sword.Parent = ctx.Services.Workspace
    local blade = Instance.new("Part"); blade.Name, blade.Parent = "Handle", sword

    local found = fruit:GroundFruits()
    check(#found == 1 and found[1] == ground, "acha a fruta no chao e nao a espada")

    local nearest, part = fruit:NearestGroundFruit()
    check(nearest == ground and part == handle, "NearestGroundFruit acha a fruta e a Handle")

    -- Sem limite de distancia: a fruta a 30 studs (e qualquer outra, mais longe
    -- ainda) continua sendo achada -- nao ha corte por range.
    local far = Instance.new("Tool"); far.Name, far.Parent = "Leopard-Leopard Fruit", ctx.Services.Workspace
    far:SetAttribute("OriginalName", "Leopard-Leopard Fruit")
    local farHandle = Instance.new("Part"); farHandle.Name, farHandle.Position, farHandle.Parent = "Handle", Vector3.new(0, 0, 5000), far
    check(fruit:NearestGroundFruit() == ground, "a fruta mais proxima ganha mesmo com uma fruta muito longe no mundo")

    -- Na skip list, nao entra.
    fruit:SetSkip("dragon")
    check(fruit:NearestGroundFruit() == far, "a skip list esconde so a fruta do prefixo; a proxima assume")
    fruit:SetSkip("")

    fruit:Destroy()
end

-- A fruta SPAWNADA pelo jogo: um Model chamado "Fruit"/"fruit" em Workspace, SEM
-- Handle (o Handle/prompt so nasce quando o jogador encosta). Era o caso que a
-- deteccao antiga jogava fora -- so aceitava Tool -- e por isso nao aparecia ESP
-- nem ia o grab. Agora as duas formas contam.
do
    local ctx = bfContext(994732206, 994732206)
    local Fruit = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "fruit.lua"])()
    local fruit = Fruit.new()

    local character = Instance.new("Model"); character.Name, character.Parent = "Character", ctx.Player
    ctx.Player.Character = character
    local root = Instance.new("Part"); root.Name, root.Position, root.Parent = "HumanoidRootPart", Vector3.new(0, 0, 0), character
    local humanoid = Instance.new("Humanoid"); humanoid.Parent = character

    -- A fruta spawnada: Model "Fruit" com uma parte dentro, SEM Handle e SEM
    -- OriginalName (e o que o jogo entrega antes do toque).
    local spawned = Instance.new("Model"); spawned.Name, spawned.Parent = "Fruit", ctx.Services.Workspace
    local body = Instance.new("Part"); body.Name, body.Position, body.Parent = "FruitPart", Vector3.new(0, 0, 40), spawned

    -- Um Model qualquer do mapa (outra geometria) NAO conta -- so nome Fruit.
    local prop = Instance.new("Model"); prop.Name, prop.Parent = "Rock", ctx.Services.Workspace
    Instance.new("Part").Parent = prop

    local found = fruit:GroundFruits()
    check(#found == 1 and found[1] == spawned, "acha a fruta spawnada (Model Fruit) e nao um Model qualquer")
    check(fruit:NearestGroundFruit() == spawned, "NearestGroundFruit acha a fruta spawnada")

    -- A parte fisica vem de dentro do Model (nao ha Handle).
    local nearest, part = fruit:NearestGroundFruit()
    check(nearest == spawned and part == body, "a parte da fruta spawnada vem de dentro do Model")

    -- Minusculo tambem conta ("fruit").
    spawned.Name = "fruit"
    check(#fruit:GroundFruits() == 1, "aceita 'fruit' minusculo tambem")

    -- O grab nao recusa por falta de prompt: ele voa ate a fruta (o encosto faz
    -- o jogo virar em Tool). O motor injetado prova o voo.
    local motor = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "teleport.lua"])().new()
    fruit:SetTeleport(motor)
    check(fruit:CollectNearestOnce() == true, "o grab aceita a fruta spawnada sem prompt")
    check(motor:IsFlying() == true, "o grab voa ate a fruta spawnada")
    motor:Cancel()

    motor:Destroy()
    fruit:Destroy()
end

-- Island Teleport: o usuario escolhe no dropdown, mas so voa com o toggle LIGADO
-- (o gate que ele pediu). O destino e a instancia real workspace.Map.<Nome>; se
-- ela nao estiver no mapa, ele avisa em vez de voar pro vazio.
do
    local ctx = bfContext(994732206, 994732206)
    local Islands = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "islands.lua"])()
    local motor = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "teleport.lua"])().new()

    local char = Instance.new("Model"); char.Name, char.Parent = "Character", ctx.Player
    ctx.Player.Character = char
    local root = Instance.new("Part"); root.Name, root.Position, root.Parent = "HumanoidRootPart", Vector3.new(0, 0, 0), char
    local humanoid = Instance.new("Humanoid"); humanoid.Parent = char

    -- A lista publica de destinos e POR MAR. O Sea 2 (mar padrao) tem as 12
    -- ilhas por instancia mais o Cafe por posicao fixa; o Sea 3 tem o Castle on
    -- Sea por posicao fixa.
    local sea2 = Islands:IslandLabels("Sea2")
    check(type(sea2) == "table" and #sea2 == 13, "o Sea 2 tem as 12 ilhas + o Cafe")
    check(sea2[1] == "Snow Mountain", "a primeira ilha do Sea 2 e Snow Mountain")
    check(sea2[13] == "Cafe", "o Cafe e o ultimo destino do Sea 2")

    local sea3 = Islands:IslandLabels("Sea3")
    check(type(sea3) == "table" and #sea3 == 1 and sea3[1] == "Castle on Sea", "o Sea 3 tem o Castle on Sea")

    local islands = Islands.new({ teleport = motor, sea = 2 })
    check(islands.ToggleOn == false, "o toggle comeca desligado")
    check(islands.CurrentSea == "Sea2", "a feature comeca no mar passado (Sea 2)")
    check(islands.Selected == "Snow Mountain", "a selecao comeca na primeira ilha do mar")

    -- A pasta do mapa e a ilha real.
    local map = Instance.new("Folder"); map.Name, map.Parent = "Map", ctx.Services.Workspace
    local snow = Instance.new("Model"); snow.Name, snow.Parent = "SnowMountain", map
    local floor = Instance.new("Part"); floor.Name, floor.Position, floor.Parent = "Floor", Vector3.new(0, 0, 500), snow

    -- GATE: com o toggle desligado, selecionar NAO teleporta (so memoriza).
    check(islands:Select("Ice Castle") == true, "selecionar uma ilha e aceito")
    check(islands.Selected == "Ice Castle", "a selecao foi memorizada")
    check(motor:IsFlying() == false, "com o toggle desligado, selecionar NAO voa")

    -- LIGAR o toggle vai pra ilha ja selecionada. Ice Castle ainda nao esta no
    -- mapa -> ele avisa em vez de voar.
    check(islands:SetEnabled(true) == true, "ligar o toggle e aceito")
    check(islands.ToggleOn == true and motor:IsFlying() == false, "ilha fora do mapa nao voa e reporta")
    check(islands.LastStatus:find("not in map"), "reporta que a ilha nao esta no mapa")

    -- Escolher Snow Mountain (que ESTA no mapa) com o toggle ligado voa.
    check(islands:Select("Snow Mountain") == true, "escolher uma ilha que existe e aceito")
    check(motor:IsFlying() == true, "com o toggle ligado, escolher a ilha voa pra ela")
    motor:Cancel()

    -- Desligar o toggle para de agir.
    islands:SetEnabled(false)
    check(islands.ToggleOn == false, "desligar o toggle desarma")
    check(islands:Select("Snow Mountain") == true, "com o toggle desligado, selecionar de novo e aceito")
    check(motor:IsFlying() == false, "com o toggle desligado, de novo NAO voa")

    -- Rotulo desconhecido nao entra.
    check(islands:Select("Nao Existe") == false, "ilha desconhecida e recusada")

    -- Cafe: destino por POSICAO fixa. Nao ha instancia no mapa chamada Cafe, mas
    -- ele voa mesmo assim -- porque o destino e um Vector3, nao uma instancia.
    local cafePosition = Vector3.new(-379.38089, 73.6452713, 303.899628)
    check(islands:Select("Cafe") == true, "Cafe e um destino aceito")
    check(islands.Selected == "Cafe", "a selecao do Cafe foi memorizada")
    check(islands:SetEnabled(true) == true, "armar o voo pro Cafe e aceito")
    check(motor:IsFlying() == true, "o Cafe voa mesmo sem instancia no mapa (destino por posicao)")
    check(islands.LastStatus:find("Cafe"), "reporta que esta voando pro Cafe")
    -- A vigia de chegada mirou a POSICAO do Cafe (nao uma instancia): mover o
    -- personagem pra la dispara a chegada.
    local cafeRoot = ctx.Player.Character:FindFirstChild("HumanoidRootPart")
    cafeRoot.Position = cafePosition
    ctx.Services.RunService.Heartbeat:Fire()
    check(islands.LastStatus:find("arrived at Cafe"), "a chegada ao Cafe e detectada pela posicao")
    islands:SetEnabled(false)
    motor:Cancel()

    -- POR MAR: trocar o mar troca a lista. No Sea 3 so existe o Castle on Sea,
    -- um destino por POSICAO fixa (nao ha instancia no mapa com esse nome). A
    -- selecao do mar antigo nao vale no mar novo.
    local castlePosition = Vector3.new(-5436.60986, 500, -3000)
    local sea3Labels = islands:SetSea(3)
    check(islands.CurrentSea == "Sea3", "SetSea troca o mar corrente")
    check(#sea3Labels == 1 and sea3Labels[1] == "Castle on Sea", "o Sea 3 lista so o Castle on Sea")
    check(islands.Selected == "Castle on Sea", "a selecao cai na primeira entrada do mar novo")
    check(islands:Select("Snow Mountain") == false, "ilha do Sea 2 nao existe no Sea 3")
    check(islands:Select("Castle on Sea") == true, "Castle on Sea e aceito no Sea 3")
    check(islands:SetEnabled(true) == true, "armar o voo pro Castle on Sea e aceito")
    check(motor:IsFlying() == true, "o Castle on Sea voa mesmo sem instancia no mapa (destino por posicao)")
    check(islands.LastStatus:find("Castle on Sea"), "reporta que esta voando pro Castle on Sea")
    local castleRoot = ctx.Player.Character:FindFirstChild("HumanoidRootPart")
    castleRoot.Position = castlePosition
    ctx.Services.RunService.Heartbeat:Fire()
    check(islands.LastStatus:find("arrived at Castle on Sea"), "a chegada ao Castle on Sea e detectada pela posicao")
    islands:SetEnabled(false)
    motor:Cancel()
    islands:SetSea(2)
    check(islands.CurrentSea == "Sea2", "voltar pro Sea 2 restaura a lista do Sea 2")

    -- Sem motor de teleporte, ligar recusa.
    local bare = Islands.new()
    check(bare:SetEnabled(true) == false and bare.ToggleOn == false, "sem teleporte o toggle recusa")

    bare:Destroy()
    islands:Destroy()
    motor:Destroy()
end

-- Chegada: quando o personagem fica perto do destino daquele voo, a feature
-- avisa UMA vez (OnArrive) com o rotulo da ilha e para de vigiar. Nao dispara
-- longe do alvo, nem re-dispara depois de chegar mesmo mexendo um pouco.
do
    local ctx = bfContext(994732206, 994732206)
    local Islands = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "islands.lua"])()
    local motor = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "teleport.lua"])().new()

    local char = Instance.new("Model"); char.Name, char.Parent = "Character", ctx.Player
    ctx.Player.Character = char
    local root = Instance.new("Part"); root.Name, root.Position, root.Parent = "HumanoidRootPart", Vector3.new(0, 0, 0), char
    local humanoid = Instance.new("Humanoid"); humanoid.Parent = char

    local map = Instance.new("Folder"); map.Name, map.Parent = "Map", ctx.Services.Workspace
    local snow = Instance.new("Model"); snow.Name, snow.Parent = "SnowMountain", map
    local floor = Instance.new("Part"); floor.Name, floor.Position, floor.Parent = "Floor", Vector3.new(0, 50, 0), snow

    local islands = Islands.new({ teleport = motor })
    local arrivals = {}
    islands.OnArrive = function(_, arrived) arrivals[#arrivals + 1] = arrived end

    -- Voa pra Snow Mountain.
    check(islands:SetEnabled(true) == true, "o toggle arma com o motor")
    check(motor:IsFlying() == true, "armar com a ilha no mapa voa")

    -- Longe do destino (o alvo do voo e o pivot do model, ~(0,50,0); o HRP esta
    -- em (0,0,0) -> 50 studs): nao conta como chegada.
    ctx.Services.RunService.Heartbeat:Fire()
    check(#arrivals == 0, "longe do destino ainda nao conta como chegada")

    -- Encosta no destino: dispara UMA vez, com o rotulo certo.
    root.Position = Vector3.new(0, 50, 0)
    ctx.Services.RunService.Heartbeat:Fire()
    check(#arrivals == 1, "perto do destino a chegada dispara uma vez")
    check(arrivals[1] == "Snow Mountain", "a chegada reporta a ilha do voo")
    check(islands.LastStatus:find("arrived"), "o status passa a arrived")

    -- Mexer de leve depois de chegar NAO re-dispara (a vigia ja parou).
    root.Position = Vector3.new(0, 55, 0)
    ctx.Services.RunService.Heartbeat:Fire()
    root.Position = Vector3.new(0, 50, 0)
    ctx.Services.RunService.Heartbeat:Fire()
    check(#arrivals == 1, "mexer depois de chegar nao re-dispara a chegada")

    islands:Destroy()
    motor:Destroy()
end

-- RBXScriptSignal de VERDADE: no Roblox Heartbeat/RenderStepped/InputBegan sao
-- RBXScriptSignal (typeof == "RBXScriptSignal"), NAO tabelas Lua. A checagem
-- antiga `type(RunService.Heartbeat) == "table"` era FALSA no Roblox e a vigia
-- de chegada nunca conectava. Este bloco troca o Heartbeat do sandbox por um
-- objeto que se comporta como o sinal real (Connect presente, typeof correto,
-- nao e tabela) e prova que a chegada ainda dispara.
do
    local ctx = bfContext(994732206, 994732206)
    local Islands = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "islands.lua"])()
    local motor = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "teleport.lua"])().new()

    local char = Instance.new("Model"); char.Name, char.Parent = "Character", ctx.Player
    ctx.Player.Character = char
    local root = Instance.new("Part"); root.Name, root.Position, root.Parent = "HumanoidRootPart", Vector3.new(0, 0, 0), char
    local humanoid = Instance.new("Humanoid"); humanoid.Parent = char

    local map = Instance.new("Folder"); map.Name, map.Parent = "Map", ctx.Services.Workspace
    local snow = Instance.new("Model"); snow.Name, snow.Parent = "SnowMountain", map
    local floor = Instance.new("Part"); floor.Name, floor.Position, floor.Parent = "Floor", Vector3.new(0, 50, 0), snow

    -- Um sinal estrito: um USERDATA com metatable (como o RBXScriptSignal real,
    -- que NAO e uma tabela Lua). Com type(heartbeat) == "userdata" a checagem
    -- invalida antiga (type(...) == "table") retorna FALSO -- exatamente como no
    -- Roblox -- enquanto o Connect protegido continua funcionando.
    local listeners = {}
    local strictHeartbeat = newproxy(true)
    getmetatable(strictHeartbeat).__index = function(_, key)
        if key == "Connect" then
            return function(_, fn)
                listeners[#listeners + 1] = fn
                return {Disconnect = function() end, Connected = true}
            end
        end
        return nil
    end
    check(type(strictHeartbeat) ~= "table", "o sinal estrito nao e uma tabela Lua (como o RBXScriptSignal real)")
    ctx.Services.RunService.Heartbeat = strictHeartbeat

    local islands = Islands.new({ teleport = motor })
    local arrivals = {}
    islands.OnArrive = function(_, arrived) arrivals[#arrivals + 1] = arrived end

    check(islands:SetEnabled(true) == true, "arma o voo com o sinal estrito")
    check(motor:IsFlying() == true, "voa pra ilha no mapa")
    root.Position = Vector3.new(0, 50, 0)
    for _, fn in ipairs(listeners) do fn() end
    check(#arrivals == 1, "a chegada dispara com um Heartbeat RBXScriptSignal de verdade")
    check(arrivals[1] == "Snow Mountain", "a chegada reporta a ilha certa")

    islands:Destroy()
    motor:Destroy()
end

-- Silent aim: escolhe o jogador mais proximo e reescreve a POSICAO (arg 2) de
-- todo remote de saida pelo gancho de __namecall (o mecanismo do script do
-- usuario). Segurar uma tecla de excecao larga o aim; soltar conta um grace. O
-- Disable PRECISA devolver o __namecall original -- sem isso o game ficaria com
-- o gancho pendurado.
do
    local ctx = bfContext(994732206, 994732206)
    local SilentAim = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "silentaim.lua"])()

    -- O dono: um character com HumanoidRootPart na origem.
    local char = Instance.new("Model"); char.Name, char.Parent = "Character", ctx.Player
    ctx.Player.Character = char
    local myRoot = Instance.new("Part"); myRoot.Name, myRoot.Position, myRoot.Parent = "HumanoidRootPart", Vector3.new(0, 0, 0), char
    local myHumanoid = Instance.new("Humanoid"); myHumanoid.Parent = char

    -- Um remote de verdade, para o gancho interceptar e o teste ler o que saiu.
    local remotes = ctx.Services.ReplicatedStorage
    local attack = Instance.new("RemoteEvent"); attack.Name, attack.Parent = "RE/RegisterAttack", remotes

    -- As teclas de excecao e os limites de alcance que o usuario pediu.
    check(#SilentAim.exceptionKeys == 5, "as 5 teclas de excecao estao publicadas")
    check(SilentAim.exceptionKeys[1] == "Z" and SilentAim.exceptionKeys[5] == "F", "as teclas sao Z X C V F, nessa ordem")
    check(SilentAim.MIN_RANGE == 500 and SilentAim.DEFAULT_RANGE == 500 and SilentAim.MAX_RANGE == 1000, "o alcance e 500 (min e padrao) a 1000 (max)")

    -- O alcance e preso a [500, 1000], mesmo se pedirem fora.
    local feature = SilentAim.new({ range = 99999 })
    check(feature.MaxRange == 1000, "o alcance acima do maximo e preso em 1000")
    feature:SetRange(10)
    check(feature.MaxRange == 500, "o alcance abaixo do minimo e preso em 500")
    feature:SetRange(750)
    check(feature.MaxRange == 750, "o alcance no meio e aceito")

    -- Sem getrawmetatable/newcclosure o Enable recusa (nao liga um no-op). O
    -- harness expoe as duas, entao aqui ele LIGA -- e o gancho e de verdade.
    check(feature:Enable() == true, "o Enable instala o gancho de __namecall")

    -- Dois alvos: um a 100 studs, outro a 300. O mais proximo vence.
    local near = ctx:AddPlayer("NearTarget", Vector3.new(100, 0, 0))
    local far = ctx:AddPlayer("FarTarget", Vector3.new(300, 0, 0))

    -- Um passo da selecao escolhe o alvo (normalmente no Heartbeat; aqui,
    -- chamando o passo direto para o teste nao depender de clock).
    feature:_SelectStep()
    check(feature.TargetName == "NearTarget", "escolhe o jogador mais proximo")

    -- COM alvo: o remote sai com a posicao do alvo no slot 2, em vez da que o
    -- jogo mandou. E o coracao do silent aim -- comportamento IDENTICO ao script
    -- original v3.4: reescreve qualquer slot 2 que nao seja booleano enquanto ha
    -- alvo e o aim nao esta em excecao.
    local skillPosition = Vector3.new(5, 0, 5)
    ctx:FireRemote(attack, "FireServer", skillPosition)
    check(tostring(attack) == "RemoteEvent", "tostring de um remote devolve o nome da classe")
    check(attack.Fired ~= nil and #attack.Fired == 1, "o remote registrou um disparo")
    check(attack.Fired[1][1] == near.Character:FindFirstChild("HumanoidRootPart").Position, "a posicao enviada foi trocada pela do alvo")

    -- Sem alvo NAO reescreve: a chamada sai intacta (o original so troca quando
    -- Playersaimbot/TargetPosition existe). Um booleano no slot 2 tambem passa.
    local noTargetPosition = Vector3.new(7, 7, 7)
    feature.TargetPosition = nil
    ctx:FireRemote(attack, "FireServer", noTargetPosition)
    check(attack.Fired[#attack.Fired][1] == noTargetPosition, "sem alvo a posicao sai intacta")
    feature:_SelectStep()

    -- O alvo se move: o proximo passo le a posicao nova.
    near.Character:FindFirstChild("HumanoidRootPart").Position = Vector3.new(120, 5, 0)
    feature:_SelectStep()
    check(feature.TargetPosition == Vector3.new(120, 5, 0), "a posicao do alvo e relida a cada passo")

    -- O BEAM: existe enquanto ligado, ligado a tua HRP e a do alvo, e VISIVEL
    -- quando ha alvo e o aim nao esta em excecao -- e o que mostra em quem o aim
    -- esta travado.
    check(feature.Beam ~= nil and feature.Beam.Name == "TargetBeam", "o beam existe enquanto o aim esta ligado")
    check(feature.Beam.Parent ~= nil, "o beam esta no workspace")
    feature:_UpdateBeam()
    check(feature.Beam.Enabled == true, "com alvo o beam aparece")
    check(feature.Beam.Attachment0 == feature.LocalAttachment and feature.Beam.Attachment1 == feature.TargetAttachment, "o beam liga as duas attachments")
    check(feature.LocalAttachment.Parent ~= nil and feature.TargetAttachment.Parent ~= nil, "as attachments estao penduradas nos HumanoidRootParts")

    -- Segurar a tecla de excecao (F) larga o aim: mesmo com uma POSICAO no slot
    -- 2 (que normalmente seria reescrita), ela passa intacta.
    ctx.Services.UserInputService.InputBegan:Fire({KeyCode = Enum.KeyCode.F})
    check(feature:IsExceptionActive() == true, "segurar a tecla de excecao ativa a supressao")
    feature:_UpdateBeam()
    check(feature.Beam.Enabled == false, "com a excecao ativa o beam se esconde")
    local exceptionPosition = Vector3.new(9, 9, 9)
    ctx:FireRemote(attack, "FireServer", exceptionPosition)
    check(attack.Fired[#attack.Fired][1] == exceptionPosition, "com a excecao ativa o remote sai intacto")

    -- Soltar conta o grace: ainda largado por um instante.
    ctx.Services.UserInputService.InputEnded:Fire({KeyCode = Enum.KeyCode.F})
    check(feature:IsExceptionActive() == true, "logo apos soltar, o grace ainda mantem a supressao")

    -- Uma tecla que NAO esta na lista de excecao nao suprime.
    feature:SetExceptions({ "Z", "X", "C", "V", "F" })
    ctx.Services.UserInputService.InputBegan:Fire({KeyCode = Enum.KeyCode.G})
    check(feature.ExceptionHeld == false, "uma tecla fora da lista nao suprime o aim")

    -- Um remote com booleano no slot 2 nao e tocado (reescrever quebraria).
    feature.ExceptionTime = -100
    feature:_SelectStep()
    ctx:FireRemote(attack, "FireServer", true)
    check(attack.Fired[#attack.Fired][1] == true, "um remote com booleano no slot 2 fica intacto")

    -- BLINDAGEM: o hook NUNCA pode quebrar a chamada do jogo. Sem alvo, um remote
    -- ainda sai normal (o hook nao trava quando nao ha alvo).
    ctx:RemovePlayers()
    feature:_SelectStep()
    -- Com o grude forte, o alvo e segurado por um instante (o grace) antes de
    -- soltar. Passado o grace, o alvo sai de verdade.
    check(feature.TargetName == nil or feature.TargetLostAt ~= nil, "sem jogadores o alvo e segurado so pelo grace")
    feature.TargetLostAt = os.clock() - 100
    feature:_SelectStep()
    check(feature.TargetName == nil, "sem jogadores e passado o grace nao ha alvo")
    ctx:FireRemote(attack, "FireServer", "sem-alvo")
    check(attack.Fired[#attack.Fired][1] == "sem-alvo", "sem alvo o remote sai intacto (hook nao trava a skill)")

    -- E um metodo que NAO e Fire/Invoke passa direto, sem tocar em nada.
    ctx:FireRemote(remotes, "GetChildren")
    check(true, "um metodo que nao e Fire/Invoke passa pelo hook sem erro")

    -- Disable devolve o __namecall original: o game nao fica com o gancho.
    check(feature:Disable() == true, "o Disable desliga")
    check(feature.Hooked == false, "o gancho foi removido")
    -- O beam tambem morre no Disable: nada fica pendurado no workspace.
    check(feature.Beam == nil, "o Disable destroi o beam")
    ctx:FireRemote(attack, "FireServer", "depois-do-disable")
    check(attack.Fired[#attack.Fired][1] == "depois-do-disable", "depois do Disable o remote sai normal de novo")

    feature:Destroy()
    ctx:RemovePlayers()
end

-- Silent aim grude FORTE: uma vez travado, a mira NAO pisca entre players. O
-- que o usuario pediu no PvP ("nao pode parar de ficar no player").
do
    local ctx = bfContext(994732206, 994732206)
    local sources2 = sources
    local feature = ctx.Env.loadstring(sources2[FEATURE_PREFIX .. "silentaim.lua"])().new({ range = 1000 })
    -- O meu character (a origem).
    local myChar = Instance.new("Model"); myChar.Name, myChar.Parent = "Character", ctx.Player
    local myHrp = Instance.new("Part"); myHrp.Name, myHrp.Parent = "HumanoidRootPart", myChar
    myHrp.Position = Vector3.new(0, 0, 0)
    ctx.Player.Character = myChar
    feature:Enable()

    -- Alvo A a 100, alvo B a 120 (bem perto de A). Escolhe A.
    local a = ctx:AddPlayer("TargetA", Vector3.new(100, 0, 0))
    local b = ctx:AddPlayer("TargetB", Vector3.new(120, 0, 0))
    feature:_SelectStep()
    check(feature.TargetName == "TargetA", "escolhe o mais proximo (A)")

    -- B chega bem mais perto, mas NAO o suficiente pra arrancar A (grude forte).
    b.Character:FindFirstChild("HumanoidRootPart").Position = Vector3.new(80, 0, 0)
    feature:_SelectStep()
    check(feature.TargetName == "TargetA", "um alvo um pouco mais perto NAO arranca o alvo travado")

    -- B fica MUITO mais perto (dentro da margem de lock): ai sim troca.
    b.Character:FindFirstChild("HumanoidRootPart").Position = Vector3.new(10, 0, 0)
    feature:_SelectStep()
    check(feature.TargetName == "TargetB", "so troca quando o novo fica muito mais perto")

    -- O character do alvo some por um frame (morte/respawn/dash): a mira SEGURA
    -- o alvo por um instante em vez de soltar na hora.
    local bChar = b.Character
    b.Character = nil
    feature:_SelectStep()
    check(feature.TargetName == "TargetB", "um frame sem character nao solta o alvo (grace)")

    -- O character volta: a mira nunca saiu dele.
    b.Character = bChar
    feature:_SelectStep()
    check(feature.TargetName == "TargetB", "o alvo volta intacto depois do frame perdido")

    -- O alvo sumiu DE VEZ (grace estourado) e nao ha outro: solta.
    b.Character = nil
    feature.TargetLostAt = os.clock() - 100
    feature:_SelectStep()
    check(feature.TargetName == nil or feature.TargetName ~= "TargetB", "passado o grace, um alvo que sumiu de vez e solto")

    feature:Disable()
    feature:Destroy()
    ctx:RemovePlayers()
end

-- Silent aim no CLIQUE (M1/ar): o RegisterHit do BF manda a PART do alvo no slot
-- 1 -- (part, {}, nil, hitId). O aim troca essa part pela HumanoidRootPart do
-- alvo travado, sem tocar nos outros slots (o hitId do slot 4 continua o do jogo).
do
    local ctx = bfContext(994732206, 994732206)
    local feature = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "silentaim.lua"])().new({ range = 1000 })
    local myChar = Instance.new("Model"); myChar.Name, myChar.Parent = "Character", ctx.Player
    local myHrp = Instance.new("Part"); myHrp.Name, myHrp.Parent = "HumanoidRootPart", myChar
    myHrp.Position = Vector3.new(0, 0, 0)
    ctx.Player.Character = myChar

    check(feature:Enable() == true, "o Enable resolve o RegisterHit do clique")
    check(feature.RegisterHit ~= nil, "o RegisterHit do clique foi encontrado")

    local target = ctx:AddPlayer("ClickTarget", Vector3.new(50, 0, 0))
    feature:_SelectStep()
    check(feature.TargetName == "ClickTarget", "o clique tem um alvo travado")

    -- O clique do jogo: RegisterHit:FireServer(minhaPart, {}, nil, hitId). Aqui
    -- disparamos PELO hook (__namecall) pra ele interceptar como no jogo.
    local mineRoot = Instance.new("Part"); mineRoot.Name = "Sword"
    ctx:FireRemote(feature.RegisterHit, "FireServer", mineRoot, {}, nil, "hit-id-123")

    local fired = feature.RegisterHit.Fired[#feature.RegisterHit.Fired]
    check(fired[1] == target.Character:FindFirstChild("HumanoidRootPart"), "o clique foi redirecionado pra HRP do alvo (slot 1)")
    check(type(fired[2]) == "table" and next(fired[2]) == nil, "o slot 2 do clique continua a tabela vazia (intacto)")
    check(fired[4] == "hit-id-123", "o hitId do clique (slot 4) nao foi tocado")

    -- Sem alvo travado: o clique sai intacto (o aim nao inventa alvo).
    feature.TargetLostAt = os.clock() - 100
    feature.TargetName = nil
    feature.TargetPosition = nil
    local somePart = Instance.new("Part"); somePart.Name = "SomePart"
    ctx:FireRemote(feature.RegisterHit, "FireServer", somePart, {}, nil, "hit-id-9")
    local fired2 = feature.RegisterHit.Fired[#feature.RegisterHit.Fired]
    check(fired2[1] == somePart, "sem alvo o clique sai com a part original")

    -- O DEBUG nao pode quebrar o hook: ligar, disparar um ataque, e a chamada
    -- continua chegando (o print e so observacao).
    check(feature:SetDebug(true) == true, "o modo debug liga")
    local debugPart = Instance.new("Part"); debugPart.Name = "DebugPart"
    ctx:FireRemote(feature.RegisterHit, "FireServer", debugPart, {}, nil, "dbg")
    check(feature.RegisterHit.Fired[#feature.RegisterHit.Fired][4] == "dbg", "com debug ligado o ataque continua chegando")
    feature:SetDebug(false)

    feature:Disable()
    feature:Destroy()
    ctx:RemovePlayers()
end

-- Silent aim no GOLPE: quando RegisterAttack abre o golpe, o aim dispara um
-- RegisterHit no HumanoidRootPart do alvo travado -- o caminho que de fato
-- registra dano no BF (o mesmo da blade hit). A POSICAO reescrita nos outros
-- remotes sozinha nao garante o acerto em PvP; o RegisterHit garante.
do
    local ctx = bfContext(994732206, 994732206)
    local feature = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "silentaim.lua"])().new({ range = 1000 })
    local myChar = Instance.new("Model"); myChar.Name, myChar.Parent = "Character", ctx.Player
    local myHrp = Instance.new("Part"); myHrp.Name, myHrp.Parent = "HumanoidRootPart", myChar
    myHrp.Position = Vector3.new(0, 0, 0)
    ctx.Player.Character = myChar

    check(feature:Enable() == true, "o Enable resolve os remotes do golpe")
    check(feature.RegisterAttack ~= nil, "o RegisterAttack foi encontrado")

    local target = ctx:AddPlayer("HitTarget", Vector3.new(40, 0, 0))
    feature:_SelectStep()
    check(feature.TargetName == "HitTarget", "o golpe tem alvo travado")

    -- O jogo abre o golpe: RegisterAttack:FireServer(0.4, combo). Pelo hook.
    -- `Fired` so nasce no primeiro FireServer, entao le com fallback.
    local function hitCount()
        return #(feature.RegisterHit.Fired or {})
    end
    local before = hitCount()
    ctx:FireRemote(feature.RegisterAttack, "FireServer", 0.4, 1)
    -- O RegisterHit forjado sai via task.spawn: o harness registra o corpo e o
    -- teste decide quando rodar (FlushSpawned).
    ctx:FlushSpawned()

    local forged = nil
    for index = before + 1, hitCount() do
        forged = feature.RegisterHit.Fired[index]
    end
    check(forged ~= nil, "o golpe disparou um RegisterHit no alvo")
    if forged then
        check(forged[1] == target.Character:FindFirstChild("HumanoidRootPart"), "o RegisterHit forjado aponta pro HRP do alvo")
        check(forged[4] ~= nil and tostring(forged[4]) ~= "", "o RegisterHit forjado leva um hitId (nao vazio)")
    end

    -- Com a excecao ativa (tecla F segurada), o golpe NAO forja hit.
    feature.ExceptionHeld = true
    feature.ExceptionTime = os.clock()
    local before2 = hitCount()
    ctx:FireRemote(feature.RegisterAttack, "FireServer", 0.4, 2)
    ctx:FlushSpawned()
    check(hitCount() == before2, "com a excecao ativa o golpe nao forja RegisterHit")

    feature:Disable()
    feature:Destroy()
    ctx:RemovePlayers()
end


do
    local ctx = bfContext(994732206, 994732206)
    -- Um env sem os primitivos: o __index esconde getrawmetatable/newcclosure
    -- (devolve nil), e todo o resto cai no env real.
    local hide = {getrawmetatable = true, newcclosure = true, setreadonly = true, getnamecallmethod = true}
    local bare = setmetatable({}, {__index = function(_, key)
        if hide[key] then return nil end
        return ctx.Env[key]
    end})
    local chunk = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "silentaim.lua"])
    setfenv(chunk, bare)
    local feature = chunk().new({})
    check(feature:Enable() == false, "sem getrawmetatable o Enable recusa")
    check(feature:IsEnabled() == false, "a feature fica desligada quando recusa")
end

-- Player: a aba SO do local player. Os atributos do character (SpeedMultiplier,
-- UnbreakableAll, WaterWalking, FlashstepCooldown) e o Stun (NumberValue filho)
-- mantido em 0. Nao mexe nos cooldowns de skill do jogo.
do
    local ctx = bfContext(994732206, 994732206)
    local Player = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "player.lua"])()

    -- O character do local player, com o Stun NumberValue (como no jogo).
    local char = Instance.new("Model"); char.Name, char.Parent = "Character", ctx.Player
    ctx.Player.Character = char
    local stun = Instance.new("NumberValue"); stun.Name, stun.Parent = "Stun", char
    stun.Value = 0

    check(Player.DEFAULT_SPEED == 2.3, "o padrao do multiplicador de velocidade e 2.3 (do jogo)")
    check(Player.DEFAULT_FLASHSTEP == 0, "o padrao do flashstep e 0 (pronto)")

    local feature = Player.new({ speed = 3 })
    check(feature.Speed == 3, "a feature nasce com a velocidade passada")
    check(feature:Enable() == true, "a aba Player liga com o character no lugar")

    -- Speed multiplier: escreve o atributo e prende ao [min,max].
    feature:SetSpeed(5)
    check(char:GetAttribute("SpeedMultiplier") == 5, "SetSpeed escreve o atributo SpeedMultiplier")
    feature:SetSpeed(9999)
    check(char:GetAttribute("SpeedMultiplier") == Player.MAX_SPEED, "a velocidade acima do maximo e presa")
    feature:SetSpeed(-5)
    check(char:GetAttribute("SpeedMultiplier") == 0, "a velocidade abaixo do minimo e presa em 0")

    -- UnbreakableAll: seta true e MANTEM true -- se o jogo tentar voltar pra
    -- false, a feature re-aplica.
    feature:SetUnbreakable(true)
    check(char:GetAttribute("UnbreakableAll") == true, "Unbreakable liga o atributo")
    char:SetAttribute("UnbreakableAll", false)
    check(char:GetAttribute("UnbreakableAll") == true, "o Unbreakable se re-aplica quando o jogo tenta desligar")

    -- WaterWalking: igual.
    feature:SetWaterWalking(true)
    check(char:GetAttribute("WaterWalking") == true, "Water walk liga o atributo")
    char:SetAttribute("WaterWalking", false)
    check(char:GetAttribute("WaterWalking") == true, "o Water walk se re-aplica quando o jogo tenta desligar")

    -- FlashstepCooldown: 0 = pronto.
    feature:SetFlashstep(1)
    check(char:GetAttribute("FlashstepCooldown") == 1, "o Flashstep cooldown vai pra 1 (com cooldown)")
    feature:SetFlashstep(0)
    check(char:GetAttribute("FlashstepCooldown") == 0, "o Flashstep cooldown volta pra 0 (pronto)")

    -- Stun: o NumberValue fica SEMPRE em 0. Se o jogo escrever 1, a feature
    -- devolve pra 0 (o "1" e o que te deixa stunado).
    check(stun.Value == 0, "o Stun comeca em 0")
    stun.Value = 1
    check(stun.Value == 0, "o Stun volta pra 0 quando o jogo tenta stunar")

    -- Respawn: um character novo ganha os atributos de novo (re-bind).
    local char2 = Instance.new("Model"); char2.Name, char2.Parent = "Character2", ctx.Player
    ctx.Player.Character = char2
    local stun2 = Instance.new("NumberValue"); stun2.Name, stun2.Parent = "Stun", char2
    stun2.Value = 0
    ctx.Player.CharacterAdded:Fire(char2)
    check(char2:GetAttribute("SpeedMultiplier") ~= nil, "no respawn os atributos sao re-aplicados no character novo")
    stun2.Value = 1
    check(stun2.Value == 0, "o Stun do character novo tambem fica em 0")

    -- Disable devolve o character ao neutro: o que a feature ligou e limpo.
    feature:Disable()
    check(char2:GetAttribute("UnbreakableAll") ~= true and char2:GetAttribute("WaterWalking") ~= true, "o Disable limpa o que a feature ligou")
    check(char2:GetAttribute("SpeedMultiplier") == Player.DEFAULT_SPEED, "o Disable devolve a velocidade ao padrao do jogo")
    check(char2:GetAttribute("FlashstepCooldown") == Player.DEFAULT_FLASHSTEP, "o Disable devolve o flashstep ao padrao (pronto)")

    feature:Destroy()
end

-- O motor de teleporte e infraestrutura: carrega e instancia sozinho (sem
-- toggle), expoe Go/GoToIsland/GoToInstance, e recusa destino invalido sem
-- explodir. Um teleporte so, que toda feature usa.
do
    local Factory = sources[FEATURE_PREFIX .. "teleport.lua"]
    local ctx = bfContext(994732206, 994732206)
    local Teleport = ctx.Env.loadstring(Factory)()
    check(type(Teleport) == "table" and type(Teleport.new) == "function", "o teleporte carrega sozinho e publica new()")

    local tp = Teleport.new()
    check(tp:Enable() == true and tp:IsEnabled() == true, "o motor de teleporte liga o loop de voo")
    check(tp:IsFlying() == false, "comeca sem voo em andamento")
    check(tp.Speed == 200, "velocidade padrao e a do original (200)")

    -- As tabelas de destino vieram inteiras do script antigo.
    check(#Teleport.islands > 0 and #Teleport.islands2 > 0 and #Teleport.islands3 > 0, "as ilhas das 3 mares estao no modulo")
    check(#Teleport.bosses > 0 and #Teleport.bosses2 > 0 and #Teleport.bosses3 > 0, "os bosses das 3 mares estao no modulo")
    check(type(Teleport:Find(Teleport.islands, "Jungle")) == "table", "Find acha uma ilha pelo nome")
    check(Teleport:Find(Teleport.islands, "NaoExiste") == nil, "Find devolve nil para nome desconhecido")
    check(type(Teleport:Find(Teleport.islands, "jungle")) == "table", "Find ignora maiuscula")

    -- Sem character nao ha voo, e nada explode.
    check(tp:Go(Vector3.new(1, 2, 3)) == nil, "Go sem character devolve nil em vez de explodir")
    check(tp:GoToIsland("Jungle") == nil, "GoToIsland sem character devolve nil")
    check(tp:GoToInstance(nil) == nil, "GoToInstance sem instance devolve nil")

    -- Com um character montado, o voo cria um tween e vira IsFlying.
    local character = Instance.new("Model"); character.Name, character.Parent = "Character", ctx.Player
    ctx.Player.Character = character
    local root = Instance.new("Part"); root.Name, root.Position, root.Parent = "HumanoidRootPart", Vector3.new(0, 0, 0), character
    local humanoid = Instance.new("Humanoid"); humanoid.Parent = character

    local tween = tp:Go(Vector3.new(0, 0, 100))
    check(tween ~= nil, "com character o Go dispara um voo")
    check(tp:IsFlying() == true, "durante o voo IsFlying e verdadeiro")
    check(tp:Cancel() == true, "Cancel aborta o voo")
    check(tp:IsFlying() == false, "depois de Cancel nao ha mais voo")

    -- O offset padrao soma 5 studs no Y (sair 5 acima evita spawnar no chao).
    local off = tp.ArrivalOffset
    check(off.Y == 5, "o offset de chegada padrao sobe 5 studs")

    check(tp:SetSpeed(150) and tp.Speed == 150, "SetSpeed aplica uma velocidade valida")
    check(tp:SetSpeed(0) == false, "SetSpeed rejeita zero")
    check(tp:SetSpeed(-1) == false, "SetSpeed rejeita negativo")

    -- GoToInstance aceita um BasePart do mundo: o contrato que a feature de
    -- fruta vai usar (achar a fruta no workspace e teleportar ate ela).
    local part = Instance.new("Part"); part.Position = Vector3.new(10, 20, 30)
    check(type(tp:GoToInstance(part)) == "table", "GoToInstance aceita um BasePart")

    tp:Disable()
    check(tp:IsEnabled() == false, "Disable desliga o loop e para o voo")
    tp:Destroy()
end

-- O backend publica o mesmo motor de teleporte para as features: State:Teleport()
-- devolve a instancia viva, ja ligada, sem toggle nenhum.
do
    local ctx = bfContext(994732206, 994732206)
    local state = ctx:Run("src/games/bloxfruits.lua")
    local tp = state:Teleport()
    check(type(tp) == "table", "o backend expoe o motor de teleporte")
    check(tp:IsEnabled() == true, "o motor ja vem ligado (infra, sem toggle)")
    check(type(tp.Go) == "function" and type(tp.GoToIsland) == "function", "o motor expoe Go e GoToIsland")
    check(state:GetStatus().Infra.teleport == tp, "o status lista o teleporte na infra")
    -- Infra nao e feature de painel: nao entra em Toggles e nao aparece como knob.
    check(state.Instances.teleport == nil, "o teleporte nao vira instancia de feature")
    check(state.Toggles.teleport == nil, "o teleporte nao publica toggle")
    check(state:SetToggle("teleport", true) == false, "o teleporte nao pode ser ligado por toggle")

    state:Destroy()
    check(next(state.Infra) == nil, "destroy derruba a infra junto")
end

-- A lista de ilhas do Travel e POR MAR: quando o jogo diz que o jogador esta no
-- Sea 3, o dropdown monta com os destinos do Sea 3 (Castle on Sea), nao com as
-- ilhas do Sea 2.
do
    local ctx = bfContext(994732206, 994732206)
    ctx.RealmSea = 3
    local state = ctx:Run("src/games/bloxfruits.lua")

    -- Instancia a feature com o mar que o backend detectou.
    check(state.Sea == 3 or state.Sea == "3" or state.Sea == "Sea3", "o backend detecta o Sea 3 (veio: " .. tostring(state.Sea) .. ")")
    check(state:SetFeature("islands", true), "a feature de ilhas sobe no Sea 3")
    local feature = state:GetFeature("islands")
    check(feature ~= nil and feature.CurrentSea == "Sea3", "a feature fica no mar detectado (Sea 3)")
    check(feature.Selected == "Castle on Sea", "a selecao cai no Castle on Sea do Sea 3")

    state:Destroy()
end

-- O mesmo backend servido pela outra rota (PlaceId do Sea 1) tem que se
-- comportar igual.
do
    local ctx = bfContext(85211729168715, 85211729168715)
    local state = ctx:Run("src/games/bloxfruits.lua")
    check(type(state) == "table" and state.Destroyed == false, "Blox Fruits sobe tambem na rota do Sea 1")
    check(state.Features.bladhits ~= nil, "a blade hit carrega na rota do Sea 1")
    check(state.Infra.teleport ~= nil, "o motor de teleporte carrega na rota do Sea 1")
    check(ctx.State.__DEPHUB.BloxFruits == state, "o contrato do loader aponta pro backend")
end
