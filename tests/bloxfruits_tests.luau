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
    -- A gacha de fruta (Auto random fruit) chama o RemoteFunction RF/GachaNetworkRF
    -- no mesmo Modules.Net. O retorno padrao e nil; um teste pode dar SetMethod
    -- pra devolver um cooldown e provar que a feature o respeita.
    local gacha = Instance.new("RemoteFunction"); gacha.Name = "RF/GachaNetworkRF"; gacha.Parent = netFolder
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

-- Um Enable que falha nao pode deixar a feature meio-ligada no registry: a
-- proxima vez ela seria reusada nesse estado. Agora o backend desliga e, se a
-- instancia foi CRIADA nesta chamada, remove do registry.
do
    local ctx = bfContext(994732206, 994732206)
    local state = ctx:Run("src/games/bloxfruits.lua")

    -- "bladhits" e um nome real de FEATURE_MODULES (o SetFeature so chega no
    -- Enable se o nome estiver na lista) -- trocamos a fabrica por uma que falha.
    local disabled = false
    local stub = {
        Enable=function() error("enable boom") end,
        Disable=function() disabled = true end,
        IsEnabled=function() return false end,
    }
    state.Features.bladhits = { new=function() return stub end }

    check(state:SetFeature("bladhits", true) == false, "um Enable que falha devolve false")
    check(disabled == true, "a feature foi desligada (rollback) apos a falha do Enable")
    check(state.Instances.bladhits == nil, "uma instancia criada e falha sai do registry (nao fica meio-ligada)")
    check(state.Toggles.bladhits == false, "o toggle fica desligado apos a falha")

    -- Uma instancia que JA existia nao e apagada do registry por uma re-tentativa
    -- que falha -- so e desligada.
    local existing = { Enable=function() error("still boom") end, Disable=function() end, IsEnabled=function() return false end }
    state.Instances.bladhits = existing
    state.Features.bladhits = { new=function() return existing end }
    check(state:SetFeature("bladhits", true) == false, "re-tentar uma instancia existente que falha devolve false")
    check(state.Instances.bladhits == existing, "uma instancia que ja existia NAO sai do registry por uma falha")

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

    -- Auto random fruit: o toggle + o slider de cooldown existem na aba de fruta.
    check(labels["toggle:Auto random fruit"] ~= nil, "o toggle Auto random fruit existe no painel")
    check(labels["slider:Gacha cooldown"] ~= nil, "o slider Gacha cooldown existe no painel")

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

    -- O tracer e um toggle SEPARADO do Fruit ESP: os dois existem e dirigem a
    -- mesma feature por caminhos independentes (o ESP liga o realce/distancia; o
    -- tracer so as linhas).
    local espToggle = labels["toggle:Fruit ESP"]
    local traceToggle = labels["toggle:Fruit tracer"]
    check(espToggle ~= nil, "o painel registra o toggle Fruit ESP")
    check(traceToggle ~= nil, "o painel registra o toggle Fruit tracer (a parte)")
    traceToggle.Handle:SetValue(true)
    check(state.Instances.fruit ~= nil and state.Instances.fruit.TraceEnabled == true, "ligar o Fruit tracer liga as linhas na feature")
    check(state.Instances.fruit.EspEnabled ~= true, "ligar o tracer NAO liga o realce (sao toggles separados)")
    traceToggle.Handle:SetValue(false)
    check(state.Instances.fruit.TraceEnabled == false, "desligar o Fruit tracer desliga as linhas")
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
    check(labels["toggle:Debug logs"] == nil, "o toggle Debug logs saiu do painel")

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

    -- Mexe em controles de features variadas: silent aim (alcance + tracer da
    -- fruta). O callback de cada controle ja grava no Config. (O slider do
    -- harness nao tem SetValue: o valor e o callback sao do proprio registro do
    -- controle.)
    local rangeControl = labels["slider:Range"]
    rangeControl.Value = 777
    rangeControl.Callback(777)
    check(state.Config.range == 777, "mexer no Range grava no Config")
    labels["toggle:Fruit tracer"].Handle:SetValue(true)
    check(state.Config.fruitTrace == true, "mexer no Fruit tracer grava no Config")

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
    -- O detalhe estruturado do Apply fica disponivel para o botao Load reportar
    -- falhas parciais em vez de um "Loaded N" que esconde recusa.
    check(type(state.LastApplyResult) == "table" and state.LastApplyResult.count == applied, "ApplyConfig guarda o resultado estruturado (LastApplyResult)")
    check(#state.LastApplyResult.failed == 0, "o Load limpo nao tem chaves falhadas")

    -- O valor chega na instancia viva: liga a feature e confere que o Load
    -- seguinte empurra o alcance pra ela.
    state:SetFeature("silentaim", true)
    state.Config.range = nil
    state:LoadConfig()
    check(state.Instances.silentaim ~= nil and state.Instances.silentaim.MaxRange == 777, "o Load aplica o range na feature instanciada")
end

-- Round-trip COMPLETO: a config real tem escalares, booleanos E listas de
-- string (exceptionKeys, fruitSkip, fruitKeep). O teste de cima so exercita
-- escalares; aqui passa a config inteira pelo arquivo, como o Save real grava,
-- e le de volta numa sessao NOVA (filesystem em memoria compartilhado).
do
    local ctx = bfContext(994732206, 994732206)
    local ui = ctx:MountUI()
    local state = ctx:Run("src/games/bloxfruits.lua")

    -- Uma config realista, com todas as formas de valor que o painel grava.
    state.Config = {
        range = 640,
        speed = 4,
        silentaim = true,
        fruitEsp = true,
        fruitTrace = true,
        unbreakable = true,
        island = "Snow Mountain",
        exceptionKeys = { "Z", "F" },
        fruitSkip = { "Dragon", "Leopard" },
        fruitKeep = { "Kitsune" },
    }
    ctx.Env.writefile("DepHub_BloxFruits_config.json", state:EncodeConfig())

    -- Le de volta pelo parser: TODA forma de valor tem que voltar.
    local parsed = state:ReadConfig()
    check(parsed.range == 640, "round-trip: numero volta")
    check(parsed.speed == 4, "round-trip: segundo numero volta")
    check(parsed.silentaim == true, "round-trip: booleano true volta")
    check(parsed.unbreakable == true, "round-trip: outro booleano volta")
    check(parsed.island == "Snow Mountain", "round-trip: string com espaco volta")
    check(type(parsed.exceptionKeys) == "table" and #parsed.exceptionKeys == 2, "round-trip: lista de 2 itens volta")
    check(parsed.exceptionKeys[1] == "Z" and parsed.exceptionKeys[2] == "F", "round-trip: ordem da lista preservada")
    check(type(parsed.fruitSkip) == "table" and #parsed.fruitSkip == 2, "round-trip: segunda lista volta")
    check(type(parsed.fruitKeep) == "table" and #parsed.fruitKeep == 1 and parsed.fruitKeep[1] == "Kitsune", "round-trip: lista de 1 item volta")
end

-- Auto execute: um toggle que faz o DepHub se re-executar sozinho depois do
-- proximo teleporte (queue_on_teleport). Ligado, entrega a linha de reload ao
-- executor; desligado, limpa. Sem o executor expor a API, recusa honestamente.
do
    local ctx = bfContext(994732206, 994732206)
    local ui = ctx:MountUI()
    local state = ctx:Run("src/games/bloxfruits.lua")

    local autoControl = nil
    for _, control in ipairs(ui.Library._Controls) do
        if control.Kind == "toggle" and control.Label == "Auto execute" then autoControl = control end
    end
    check(autoControl ~= nil, "o bloco CONFIG monta o toggle Auto execute")

    -- Ligar entrega uma linha de reload ao queue_on_teleport.
    autoControl.Handle:SetValue(true)
    check(type(ctx.QueuedTeleportScript) == "string" and #ctx.QueuedTeleportScript > 0, "ligar o auto execute enfileira o reload")
    check(ctx.QueuedTeleportScript:find("DepHub.lua", 1, true) ~= nil, "a linha enfileirada carrega o DepHub.lua")
    check(state.Config.autoexec == true, "o auto execute grava no Config")

    -- Desligar limpa o que estava enfileirado.
    autoControl.Handle:SetValue(false)
    check(ctx.QueuedTeleportScript == "", "desligar o auto execute limpa o reload enfileirado")

    -- Sem queue_on_teleport (executor sem a API), ligar recusa.
    ctx.Env.queue_on_teleport = nil
    check(state:SetAutoExec(true) == false, "sem queue_on_teleport o auto execute recusa")
end

-- Auto execute persiste: salvo ligado, o painel volta a enfileirar o reload
-- sozinho no proximo start.
do
    local ctx = bfContext(994732206, 994732206)
    local ui = ctx:MountUI()
    ctx.Files["DepHub_BloxFruits_config.json"] = '{"autoexec":true}'
    local state = ctx:Run("src/games/bloxfruits.lua")
    check(state.Config.autoexec == true, "o auto execute salvo volta no Config")
    check(type(ctx.QueuedTeleportScript) == "string" and ctx.QueuedTeleportScript:find("DepHub.lua", 1, true) ~= nil, "com auto execute salvo, o start ja enfileira o reload")
end

-- SourceRef: a linha de re-execucao usa a ref da SESSAO ATUAL (nao uma ref
-- antiga que ficou em estado compartilhado) e valida ref/base antes de montar
-- codigo Lua. O ambiente do executor e compartilhado; a linha vira loadstring.
do
    local ctx = bfContext(994732206, 994732206)
    local _ = ctx:MountUI()
    local state = ctx:Run("src/games/bloxfruits.lua")

    -- Ref valida (branch simples): entra na linha.
    ctx.State.__DEPHUB = ctx.State.__DEPHUB or {}
    ctx.State.__DEPHUB.SourceRef = "main"
    ctx.State.__DEPHUB.SourceBaseURL = "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
    local line = state:SelfExecLine()
    check(line:find('loadstring(game:HttpGet("https://raw.githubusercontent.com/glowpkj/DepHub/main/DepHub.lua"))("main")', 1, true) ~= nil, "a linha usa a base e a ref validas")

    -- Ref com aspas/barra/quebra de linha NAO entra: cai no default "main".
    ctx.State.__DEPHUB.SourceRef = 'main" ) ; game:HttpGet("evil'
    local hostile = state:SelfExecLine()
    check(hostile:find('"main")', 1, true) ~= nil, "ref hostil cai no default seguro (main)")
    check(hostile:find("evil", 1, true) == nil, "ref hostil nao e interpolada na linha")

    -- Base fora da allowlist (host desconhecido) cai no default.
    ctx.State.__DEPHUB.SourceRef = "main"
    ctx.State.__DEPHUB.SourceBaseURL = "http://evil.example.com/"
    local badBase = state:SelfExecLine()
    check(badBase:find("evil.example.com", 1, true) == nil, "host fora da allowlist nao entra na linha")
    check(badBase:find("raw.githubusercontent.com", 1, true) ~= nil, "base invalida cai no default do GitHub")

    -- Base HTTPS de host permitido mas com aspas/controle tambem e recusada: cai
    -- no default (nao monta codigo com o conteudo hostil).
    ctx.State.__DEPHUB.SourceBaseURL = 'https://raw.githubusercontent.com/glowpkj/DepHub/main/"\n'
    local badBase2 = state:SelfExecLine()
    check(badBase2 == 'loadstring(game:HttpGet("https://raw.githubusercontent.com/glowpkj/DepHub/main/DepHub.lua"))("main")', "base com aspas/quebra de linha cai no default seguro")
end

-- Auto-load: com uma config ja no disco, o painel abre com ela aplicada ("so
-- salvar e gg" -- o usuario nao clica em Load toda sessao).
do
    local ctx = bfContext(994732206, 994732206)
    local ui = ctx:MountUI()
    -- Pre-existe um arquivo (como se a sessao anterior tivesse salvo).
    ctx.Files["DepHub_BloxFruits_config.json"] = '{"fruitTrace":true,"range":640,"speed":4}'
    local state = ctx:Run("src/games/bloxfruits.lua")
    check(state.Config.range == 640, "o painel abre com o range salvo aplicado")
    check(state.Config.fruitTrace == true, "o painel abre com o tracer salvo aplicado")
    check(state.Config.speed == 4, "o painel abre com a velocidade salva aplicada")
    check(state.PendingSilentAimRange == 640, "o valor salvo tambem alimenta o Pending da feature")

    -- A tela nasce refletindo o salvo: o controle do Fruit tracer ja abre ligado.
    local traceControl = nil
    for _, control in ipairs(ui.Library._Controls) do
        if control.Kind == "toggle" and control.Label == "Fruit tracer" then traceControl = control end
    end
    check(traceControl ~= nil and traceControl.Handle.Value == true, "o toggle Fruit tracer abre no valor salvo (a tela reflete o Load)")
end

-- Fallback em memoria: sem writefile/readfile/isfile, o Save nao quebra -- so
-- fica na sessao. O Load devolve o que ficou guardado. A API e removida ANTES
-- do load, como um executor que de fato nao a tem (o backend a captura no load;
-- nil depois nao muda o que ja foi capturado).
do
    local ctx = bfContext(994732206, 994732206)
    local ui = ctx:MountUI()

    ctx.Env.writefile = nil
    ctx.Env.readfile = nil
    ctx.Env.isfile = nil

    local state = ctx:Run("src/games/bloxfruits.lua")
    check(state:CanPersist() == false, "sem a API de arquivo CanPersist e false")
    state.Config.range = 640
    check(state:SaveConfig() == false, "sem arquivo o Save so guarda em memoria")
    check(type(state.LastConfigError) == "string", "o Save sem API explica o motivo")
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
        fruitTrace = true,
        silentaim = false,
        island = "Cafe",
        fruitSkip = { "Dragon", "Leopard" },
    }
    local json = state:EncodeConfig()
    check(json:find('"range":500', 1, true) ~= nil, "encode: numero sem aspas")
    check(json:find('"fruitTrace":true', 1, true) ~= nil, "encode: booleano true")
    check(json:find('"silentaim":false', 1, true) ~= nil, "encode: booleano false")
    check(json:find('"island":"Cafe"', 1, true) ~= nil, "encode: string com aspas")
    check(json:find('"fruitSkip":["Dragon","Leopard"]', 1, true) ~= nil, "encode: array de string")

    -- Grava e le de volta pelo arquivo: o round-trip tem que preservar tudo.
    ctx.Env.writefile("DepHub_BloxFruits_config.json", json)
    local parsed = state:ReadConfig()
    check(parsed.range == 500 and parsed.fruitTrace == true and parsed.silentaim == false, "decode: escalares voltam")
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

    -- Personagem. O destino do voo e a POSICAO da ilha selecionada por padrao no
    -- Sea 2 (a primeira: Kingdom of Rose).
    local char = Instance.new("Model"); char.Name, char.Parent = "Character", ctx.Player
    ctx.Player.Character = char
    local root = Instance.new("Part"); root.Name, root.Position, root.Parent = "HumanoidRootPart", Vector3.new(0, 0, 0), char
    local humanoid = Instance.new("Humanoid"); humanoid.Parent = char
    local rosePos = Vector3.new(-195.1, 155.3, 279.9)

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
    root.Position = rosePos
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

-- Tracer da fruta: um toggle a PARTE que liga/desliga so as linhas (o highlight
-- e a distancia continuam vindo com o Fruit ESP). Sem o ESP ligado, o tracer so
-- guarda a escolha. Precisa de uma fruta no chao pra montar a entrada do ESP.
do
    local ctx = bfContext(994732206, 994732206)
    local Fruit = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "fruit.lua"])()
    local feature = Fruit.new()

    -- Personagem com HRP (o tracer liga a minha HRP na fruta) + uma fruta
    -- spawnada pelo jogo: Model "Fruit" com uma BasePart dentro.
    local char = Instance.new("Model"); char.Name, char.Parent = "Character", ctx.Player
    ctx.Player.Character = char
    local root = Instance.new("Part"); root.Name, root.Position, root.Parent = "HumanoidRootPart", Vector3.new(0, 0, 0), char
    local fruit = Instance.new("Model"); fruit.Name, fruit.Parent = "Fruit", ctx.Services.Workspace
    local fruitPart = Instance.new("Part"); fruitPart.Name, fruitPart.Position, fruitPart.Parent = "Handle", Vector3.new(30, 0, 0), fruit

    -- O tracer e um toggle a parte: comeca desligado e ha um setter dedicado.
    check(feature.TraceEnabled == false, "o tracer comeca desligado")
    check(type(feature.SetTrace) == "function", "a feature expoe SetTrace")
    check(feature:SetTrace(true) and feature.TraceEnabled == true, "SetTrace liga o tracer")
    -- Sem o ESP ligado, ligar o tracer so guarda a escolha (nada pra desenhar).
    check(next(feature.EspMap) == nil, "sem o ESP ligado o tracer so guarda a escolha")

    -- Liga o ESP: a entrada nasce com Highlight, Billboard E beam de tracer. O
    -- ciclo do ESP e um while com task.wait; o harness guarda o corpo no spawn em
    -- vez de rodar. Aqui o task.wait da UMA passada do loop (desliga o while no
    -- fim) e o spawn roda sincrono -- e o unico jeito de observar um frame.
    local function espStep()
        ctx.Env.task.wait = function() feature.EspEnabled = false end
        ctx:FlushSpawned()
    end
    feature:SetEsp(true)
    espStep()
    local entry = feature.EspMap[fruit]
    check(entry ~= nil, "o ESP monta a entrada da fruta")
    check(entry.highlight ~= nil and entry.billboard ~= nil, "a entrada tem highlight e billboard (ESP)")
    check(entry.beam ~= nil, "a entrada tem um beam de tracer")
    check(entry.beam.Enabled == true, "com o tracer ligado o beam fica visivel")
    check(entry.localAttachment.Parent == root, "o attachment local aponta pra minha HRP")
    check(entry.beam.Attachment1 == entry.fruitAttachment, "o outro lado do beam aponta pra fruta")

    -- O rotulo carrega a distancia (o outro pedaco do ESP que ativa junto).
    check(entry.label.Text:find("m", 1, true) ~= nil, "o rotulo mostra a distancia")

    -- Desligar o tracer esconde o beam sem derrubar o highlight/billboard: o
    -- proximo ciclo passa com o TraceEnabled ja em false.
    feature:SetTrace(false)
    local beamRef = entry.beam
    feature:SetEsp(true)
    espStep()
    check(beamRef.Enabled == false, "desligar o tracer esconde o beam")
    check(entry.highlight.Enabled == true and entry.billboard.Enabled == true, "o highlight/billboard do ESP continuam")

    -- Desligar o ESP limpa tudo, beam incluso.
    feature:SetEsp(false)
    check(next(feature.EspMap) == nil, "desligar o ESP limpa o mapa de entradas")
    feature:Destroy()
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

-- Auto random fruit: rola a gacha (Zioles) pelo RemoteFunction RF/GachaNetworkRF
-- no mesmo Modules.Net. O payload e {Context="Purchase", BoxName="ZiolesGacha"};
-- o retorno com um numero (o cooldown) e respeitado; desligar para o thread.
do
    local ctx, modules = bfContext(994732206, 994732206)
    local Fruit = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "fruit.lua"])()
    local fruit = Fruit.new({ randomCooldown = 90 })

    -- O RemoteFunction da gacha, resolvido pelo caminho real (Modules.Net).
    local net = modules:FindFirstChild("Net")
    local gacha = net:FindFirstChild("RF/GachaNetworkRF")
    check(gacha ~= nil, "a gacha RF/GachaNetworkRF existe no Modules.Net")
    -- O servidor responde com o cooldown real (45s): a feature tem que devolver.
    -- O override tambem grava o payload pra conferir o que foi mandado.
    local sent
    ctx:SetMethod(gacha, "InvokeServer", function(_, payload) sent = payload return 45 end)

    local ok, cooldown = fruit:RollGacha()
    check(ok == true, "RollGacha invoca a gacha")
    check(cooldown == 45, "RollGacha devolve o cooldown que o servidor mandou")
    check(type(sent) == "table" and sent.Context == "Purchase" and sent.BoxName == "ZiolesGacha", "o payload e Purchase/ZiolesGacha")

    -- Cooldown fora da faixa e preso a [30, 300].
    ctx:SetMethod(gacha, "InvokeServer", function() return 9999 end)
    check(select(2, fruit:RollGacha()) == 300, "cooldown acima do maximo e preso em 300")
    ctx:SetMethod(gacha, "InvokeServer", function() return 1 end)
    check(select(2, fruit:RollGacha()) == nil, "um numero <= 3 nao conta como cooldown (usa o default)")

    -- Sem o remote, RollGacha falha com motivo (nao explode).
    local bare, bareModules = bfContext(994732206, 994732206)
    bareModules:FindFirstChild("Net"):FindFirstChild("RF/GachaNetworkRF"):Destroy()
    local fruit2 = bare.Env.loadstring(sources[FEATURE_PREFIX .. "fruit.lua"])().new()
    local ok2 = fruit2:RollGacha()
    check(ok2 == false and fruit2.LastError == "gacha remote ausente", "sem o remote a gacha recusa com motivo")

    -- SetRandom liga o flag e agenda o thread; desligar derruba.
    check(fruit:SetRandom(true) == true, "SetRandom liga")
    check(fruit.RandomEnabled == true, "o flag RandomEnabled fica ligado")
    check(fruit.Threads.random ~= nil, "SetRandom agenda o thread do loop")
    fruit:SetRandom(false)
    check(fruit.RandomEnabled == false, "SetRandom(false) desliga")
    check(fruit.Threads.random == nil, "desligar cancela o thread")

    -- SetRandomInterval ajusta o cooldown default (o slider do painel).
    fruit:SetRandomInterval(120)
    check(fruit.RandomCooldown == 120, "SetRandomInterval muda o cooldown default")
    fruit:SetRandomInterval(0)
    check(fruit.RandomCooldown == 1, "um cooldown abaixo de 1 e preso em 1")

    -- Disable derruba o random junto com o resto.
    fruit:SetRandom(true)
    fruit:Disable()
    check(fruit.RandomEnabled == false and fruit.Threads.random == nil, "Disable desliga e cancela a gacha")

    fruit:Destroy()
    fruit2:Destroy()
end

-- (o gate que ele pediu). O destino e uma POSICAO fixa (Vector3) da lista do
-- OpenSource; o voo vai direto pro ponto, sem lookup de instancia no mapa.
do
    local ctx = bfContext(994732206, 994732206)
    local Islands = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "islands.lua"])()
    local motor = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "teleport.lua"])().new()

    local char = Instance.new("Model"); char.Name, char.Parent = "Character", ctx.Player
    ctx.Player.Character = char
    local root = Instance.new("Part"); root.Name, root.Position, root.Parent = "HumanoidRootPart", Vector3.new(0, 0, 0), char
    local humanoid = Instance.new("Humanoid"); humanoid.Parent = char

    -- A lista publica de destinos e POR MAR, e toda por POSICAO (as coordenadas
    -- do OpenSource). Sea 1: 16 ilhas; Sea 2: 14; Sea 3: 15. Sem bosses.
    local sea1 = Islands:IslandLabels("Sea1")
    check(type(sea1) == "table" and #sea1 == 16, "o Sea 1 tem as 16 ilhas do OpenSource")
    check(sea1[1] == "Middle Town" and sea1[16] == "Water 7", "o Sea 1 vai de Middle Town a Water 7")

    local sea2 = Islands:IslandLabels("Sea2")
    check(type(sea2) == "table" and #sea2 == 14, "o Sea 2 tem as 14 ilhas do OpenSource")
    check(sea2[1] == "Kingdom of Rose", "a primeira ilha do Sea 2 e Kingdom of Rose")
    check(table.find(sea2, "Cafe") ~= nil and table.find(sea2, "Ice Castle") ~= nil, "o Cafe e o Ice Castle estao no Sea 2")

    local sea3 = Islands:IslandLabels("Sea3")
    check(type(sea3) == "table" and #sea3 == 15, "o Sea 3 tem as 15 ilhas do OpenSource")
    check(table.find(sea3, "Castle on the Sea") ~= nil and table.find(sea3, "Hell Dimension") ~= nil, "Castle on the Sea e Hell Dimension estao no Sea 3")

    local islands = Islands.new({ teleport = motor, sea = 2 })
    check(islands.ToggleOn == false, "o toggle comeca desligado")
    check(islands.CurrentSea == "Sea2", "a feature comeca no mar passado (Sea 2)")
    check(islands.Selected == "Kingdom of Rose", "a selecao comeca na primeira ilha do mar")

    -- GATE: com o toggle desligado, selecionar NAO teleporta (so memoriza).
    check(islands:Select("Ice Castle") == true, "selecionar uma ilha e aceito")
    check(islands.Selected == "Ice Castle", "a selecao foi memorizada")
    check(motor:IsFlying() == false, "com o toggle desligado, selecionar NAO voa")

    -- LIGAR o toggle vai pra ilha ja selecionada (por posicao, sem instancia).
    check(islands:SetEnabled(true) == true, "ligar o toggle e aceito")
    check(motor:IsFlying() == true, "com o toggle ligado, ligar voa pra ilha selecionada")
    check(islands.LastStatus:find("Ice Castle"), "reporta que esta voando pro Ice Castle")
    motor:Cancel()

    -- A vigia de chegada mira a POSICAO da ilha: mover o character pra la dispara.
    local icePos = Vector3.new(6062.3, 155.3, -6880.9)
    root.Position = icePos
    ctx.Services.RunService.Heartbeat:Fire()
    check(islands.LastStatus:find("arrived at Ice Castle"), "a chegada ao Ice Castle e detectada pela posicao")

    -- Desligar o toggle para de agir.
    islands:SetEnabled(false)
    check(islands.ToggleOn == false, "desligar o toggle desarma")
    root.Position = Vector3.new(0, 0, 0)
    check(islands:Select("Kingdom of Rose") == true, "com o toggle desligado, selecionar de novo e aceito")
    check(motor:IsFlying() == false, "com o toggle desligado, de novo NAO voa")

    -- O pedido do usuario: desligar o toggle no MEIO de um voo tem que PARAR o
    -- teleporte na hora -- nao so impedir voos novos. O motor para de arrastar
    -- (Cancel zera o tween) e a vigia de chegada e desarmada.
    check(islands:SetEnabled(true) == true, "religa o toggle")
    check(motor:IsFlying() == true, "com o toggle ligado ha voo em andamento")
    check(islands._arrivalConnection ~= nil, "a vigia de chegada esta armada durante o voo")
    islands:SetEnabled(false)
    check(motor:IsFlying() == false, "desligar o toggle CANCELA o voo em andamento (para de teleportar)")
    check(islands._arrivalConnection == nil, "desligar o toggle desarma a vigia de chegada")

    -- Rotulo desconhecido nao entra.
    check(islands:Select("Nao Existe") == false, "ilha desconhecida e recusada")

    -- Cafe: destino por POSICAO (o ponto do OpenSource). Voa direto pro ponto.
    local cafePosition = Vector3.new(-380.4, 72.8, 303.2)
    check(islands:Select("Cafe") == true, "Cafe e um destino aceito")
    check(islands.Selected == "Cafe", "a selecao do Cafe foi memorizada")
    check(islands:SetEnabled(true) == true, "armar o voo pro Cafe e aceito")
    check(motor:IsFlying() == true, "o Cafe voa direto pro ponto")
    check(islands.LastStatus:find("Cafe"), "reporta que esta voando pro Cafe")
    local cafeRoot = ctx.Player.Character:FindFirstChild("HumanoidRootPart")
    cafeRoot.Position = cafePosition
    ctx.Services.RunService.Heartbeat:Fire()
    check(islands.LastStatus:find("arrived at Cafe"), "a chegada ao Cafe e detectada pela posicao")
    islands:SetEnabled(false)
    motor:Cancel()

    -- POR MAR: trocar o mar troca a lista. No Sea 3 a primeira e o Port Town (por
    -- posicao). A selecao do mar antigo nao vale no mar novo.
    local portTownPos = Vector3.new(-610.4, 57.8, 6436.3)
    local sea3Labels = islands:SetSea(3)
    check(islands.CurrentSea == "Sea3", "SetSea troca o mar corrente")
    check(#sea3Labels == 15 and sea3Labels[1] == "Port Town", "o Sea 3 lista as 15 ilhas do OpenSource")
    check(islands.Selected == "Port Town", "a selecao cai na primeira entrada do mar novo")
    check(islands:Select("Kingdom of Rose") == false, "ilha do Sea 2 nao existe no Sea 3")
    check(islands:Select("Port Town") == true, "Port Town e aceito no Sea 3")
    check(islands:SetEnabled(true) == true, "armar o voo pro Port Town e aceito")
    check(motor:IsFlying() == true, "o Port Town voa direto pro ponto")
    check(islands.LastStatus:find("Port Town"), "reporta que esta voando pro Port Town")
    local ptRoot = ctx.Player.Character:FindFirstChild("HumanoidRootPart")
    ptRoot.Position = portTownPos
    ctx.Services.RunService.Heartbeat:Fire()
    check(islands.LastStatus:find("arrived at Port Town"), "a chegada ao Port Town e detectada pela posicao")
    islands:SetEnabled(false)
    motor:Cancel()
    islands:SetSea(2)
    check(islands.CurrentSea == "Sea2", "voltar pro Sea 2 restaura a lista do Sea 2")

    -- Por mar: escolher troca a lista; ilha do Sea 1 nao existe no Sea 2.
    local sea1Labels = islands:SetSea(1)
    check(islands.CurrentSea == "Sea1" and #sea1Labels == 16, "SetSea(1) mostra as 16 ilhas do Sea 1")
    check(islands:Select("Middle Town") == true, "Middle Town (Sea 1) e aceito no Sea 1")
    check(islands:Select("Port Town") == false, "Port Town (Sea 3) nao existe no Sea 1")
    islands:SetSea(2)

    -- Sem motor de teleporte, ligar recusa.
    local bare = Islands.new()
    check(bare:SetEnabled(true) == false and bare.ToggleOn == false, "sem teleporte o toggle recusa")

    -- Bug: pcall bem-sucedido != voo iniciado. O motor devolve nil sem lancar
    -- quando nao ha HumanoidRootPart. Antes a feature so olhava o booleano do
    -- pcall, dizia "flying" e armava a vigia sem voo nenhum. Agora o retorno real
    -- do motor e checado e SetEnabled propaga a falha.
    local noRootChar = Instance.new("Model"); noRootChar.Name, noRootChar.Parent = "Character", ctx.Player
    ctx.Player.Character = noRootChar
    local body = Instance.new("Part"); body.Name, body.Parent = "Torso", noRootChar
    -- Sem HumanoidRootPart: o motor devolve nil (nao lanca).
    check(islands:Select("Snow Mountain") == true, "escolher Snow Mountain e aceito")
    islands:SetEnabled(false)
    local armed = islands:SetEnabled(true)
    check(armed == false, "SetEnabled propaga a falha quando o motor nao iniciou o voo")
    check(islands.ToggleOn == false, "sem character pronto o toggle NAO fica armado")
    check(islands.LastStatus == "character not ready", "reporta 'character not ready' em vez de 'flying'")
    check(islands._arrivalConnection == nil, "nao arma a vigia de chegada quando o voo nao iniciou")

    -- Restabelece o character com root para o fim do bloco.
    local restored = Instance.new("Model"); restored.Name, restored.Parent = "Character", ctx.Player
    local rRoot = Instance.new("Part"); rRoot.Name, rRoot.Parent = "HumanoidRootPart", restored
    ctx.Player.Character = restored

    bare:Destroy()
    islands:Destroy()
    motor:Destroy()
end

-- Chegada: quando o personagem fica perto do destino daquele voo, a feature
-- avisa UMA vez (OnArrive) com o rotulo da ilha e para de vigiar. Nao dispara
-- longe do alvo, nem re-dispara depois de chegar mesmo mexendo um pouco. O
-- destino e a POSICAO do Snow Mountain na lista (por posicao, sem instancia).
do
    local ctx = bfContext(994732206, 994732206)
    local Islands = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "islands.lua"])()
    local motor = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "teleport.lua"])().new()

    local char = Instance.new("Model"); char.Name, char.Parent = "Character", ctx.Player
    ctx.Player.Character = char
    local root = Instance.new("Part"); root.Name, root.Position, root.Parent = "HumanoidRootPart", Vector3.new(0, 0, 0), char
    local humanoid = Instance.new("Humanoid"); humanoid.Parent = char

    -- A posicao do Snow Mountain no Sea 2 (a coordenada do OpenSource).
    local snowPos = Vector3.new(856.2, 50.3, -5278.3)

    local islands = Islands.new({ teleport = motor })
    local arrivals = {}
    islands.OnArrive = function(_, arrived) arrivals[#arrivals + 1] = arrived end

    -- Escolhe Snow Mountain e voa pra ela (com o toggle desarmado, Select so
    -- memoriza; armar depois e que voa).
    check(islands:Select("Snow Mountain") == true, "escolher Snow Mountain e aceito")
    check(islands:SetEnabled(true) == true, "o toggle arma com o motor")
    check(motor:IsFlying() == true, "armar com a ilha selecionada voa")

    -- Longe do destino (HRP em (0,0,0), alvo em (856.2,50.3,-5278.3)): nao conta.
    ctx.Services.RunService.Heartbeat:Fire()
    check(#arrivals == 0, "longe do destino ainda nao conta como chegada")

    -- Encosta no destino: dispara UMA vez, com o rotulo certo.
    root.Position = snowPos
    ctx.Services.RunService.Heartbeat:Fire()
    check(#arrivals == 1, "perto do destino a chegada dispara uma vez")
    check(arrivals[1] == "Snow Mountain", "a chegada reporta a ilha do voo")
    check(islands.LastStatus:find("arrived"), "o status passa a arrived")

    -- Mexer de leve depois de chegar NAO re-dispara (a vigia ja parou).
    root.Position = snowPos + Vector3.new(0, 5, 0)
    ctx.Services.RunService.Heartbeat:Fire()
    root.Position = snowPos
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

    -- A posicao do Snow Mountain no Sea 2 (a coordenada do OpenSource).
    local snowPos = Vector3.new(856.2, 50.3, -5278.3)

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

    check(islands:Select("Snow Mountain") == true, "escolher Snow Mountain e aceito")
    check(islands:SetEnabled(true) == true, "arma o voo com o sinal estrito")
    check(motor:IsFlying() == true, "voa pra ilha selecionada")
    root.Position = snowPos
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

-- Cleanup do gancho do silent aim: o Disable so devolve o __namecall se o valor
-- atual ainda for o NOSSO gancho. Se outro script instalou uma camada depois, a
-- dele fica -- apagar aqui destruiria a de outro.
do
    local ctx = bfContext(994732206, 994732206)
    local SilentAim = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "silentaim.lua"])()
    local char = Instance.new("Model"); char.Name, char.Parent = "Character", ctx.Player
    ctx.Player.Character = char
    local myRoot = Instance.new("Part"); myRoot.Name, myRoot.Position, myRoot.Parent = "HumanoidRootPart", Vector3.new(0, 0, 0), char

    local mt = ctx.Env.getrawmetatable(ctx.State.__DEPHUB_OSS_RUNTIME.game)
    local baseNamecall = mt.__namecall

    -- Caso normal: instala e desliga -> volta ao __namecall original.
    local feature = SilentAim.new({ range = 1000 })
    check(feature:Enable() == true, "o Enable instala o gancho (cleanup)")
    local installed = feature.InstalledNamecall
    check(type(installed) == "function" and installed ~= baseNamecall, "o gancho instalado e guardado em InstalledNamecall")
    check(mt.__namecall == installed, "o __namecall da metatable e o nosso gancho instalado")
    feature:Disable()
    check(mt.__namecall == baseNamecall, "com o valor ainda nosso, o Disable devolve o __namecall original")

    -- Caso de conflito: instala, OUTRO script sobrescreve, depois desliga.
    local feature2 = SilentAim.new({ range = 1000 })
    check(feature2:Enable() == true, "o Enable instala o gancho de novo")
    local ours = feature2.InstalledNamecall
    local foreign = function() return "foreign" end
    mt.__namecall = foreign  -- simula outra camada assumindo o __namecall
    feature2:Disable()
    check(mt.__namecall == foreign, "nao sobrescreve a camada de outro script (deixa o foreign)")
    check(ours ~= foreign, "sanity: a camada alheia nao e a nossa")

    -- Restaura o estado da metatable pro resto da suite.
    mt.__namecall = baseNamecall
    feature:Destroy()
    feature2:Destroy()
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

    -- O clique sai intacto mesmo sem alvo travado -- sem debug pendurado no meio
    -- do gancho (o modo debug saiu).
    feature.TargetLostAt = os.clock() - 100
    feature.TargetName = nil
    feature.TargetPosition = nil
    local somePart = Instance.new("Part"); somePart.Name = "SomePart"
    ctx:FireRemote(feature.RegisterHit, "FireServer", somePart, {}, nil, "hit-id-9")
    local fired2 = feature.RegisterHit.Fired[#feature.RegisterHit.Fired]
    check(fired2[1] == somePart, "sem alvo o clique sai com a part original")

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

    -- Disable devolve o character ao estado ORIGINAL (nao a um default): o que a
    -- feature ligou e limpo, e um atributo que NAO existia antes e REMOVIDO -- o
    -- baseline nunca foi um numero padrao presumido.
    feature:Disable()
    check(char2:GetAttribute("UnbreakableAll") == nil, "o Disable REMOVE o Unbreakable (nao existia antes da feature)")
    check(char2:GetAttribute("WaterWalking") == nil, "o Disable REMOVE o Water walk (nao existia antes)")
    check(char2:GetAttribute("SpeedMultiplier") == nil, "o Disable REMOVE a velocidade (nao existia antes da feature)")
    check(char2:GetAttribute("FlashstepCooldown") == nil, "o Disable REMOVE o flashstep (nao existia antes)")

    -- O Stun que a FEATURE criou e destruido no cleanup (se o jogo ja tinha um,
    -- nao e nosso). Aqui o char2 tem o Stun do PROPRIO teste (stun2), entao ele
    -- permanece -- so o que a feature cria e que sai.
    check(char2:FindFirstChild("Stun") ~= nil, "o Stun do jogo (stun2) nao e destruido pelo Disable")

    feature:Destroy()
end

-- Autoken / Autobuso (haki): mantem o Observation (Ken) e o Armament (Buso)
-- ligados pelo MESMO mecanismo do OpenSource -- ve os atributos KenActive /
-- BusoEnabled e so manda o remote de ligar quando estao desligados. Ken usa
-- CommE:FireServer("Ken", true/false); Buso usa CommF_:InvokeServer("Buso").
do
    local ctx = bfContext(994732206, 994732206)
    local Player = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "player.lua"])()

    -- Os remotes da haki em ReplicatedStorage.Remotes (o caminho do jogo).
    local rstorage = ctx.Services.ReplicatedStorage
    local remotes = Instance.new("Folder"); remotes.Name, remotes.Parent = "Remotes", rstorage
    local commE = Instance.new("RemoteEvent"); commE.Name, commE.Parent = "CommE", remotes
    local commF = Instance.new("RemoteFunction"); commF.Name, commF.Parent = "CommF_", remotes

    local char = Instance.new("Model"); char.Name, char.Parent = "Character", ctx.Player
    ctx.Player.Character = char

    local feature = Player.new({})
    feature:Enable()
    -- Zera os variados remotes antes de cada passo (o loop e testado por passo).
    local function resetFired() commE.Fired = {} commF.Invoked = {} end

    -- Ken desligado no jogo: HakiStep manda ligar (Ken, true).
    resetFired()
    feature.KenOn = true
    feature:HakiStep()
    check(commE.Fired[#commE.Fired] ~= nil and commE.Fired[#commE.Fired][1] == "Ken" and commE.Fired[#commE.Fired][2] == true, "Ken desligado -> o passo manda Ken=true")

    -- Ken JA ativo (o jogo marcou o atributo): nao re-manda (nada de spam).
    resetFired()
    char:SetAttribute("KenActive", true)
    feature:HakiStep()
    check(#commE.Fired == 0, "Ken ja ativo -> o passo nao re-manda (gate do atributo)")

    -- Buso desligado: o passo invoca o remote Buso.
    resetFired()
    feature.KenOn = false
    feature.BusoOn = true
    feature:HakiStep()
    check(commF.Invoked[#commF.Invoked] ~= nil and commF.Invoked[#commF.Invoked][1] == "Buso", "Buso desligado -> o passo invoca Buso")

    -- Buso ja ativo: nao re-invoca.
    resetFired()
    char:SetAttribute("BusoEnabled", true)
    feature:HakiStep()
    check(#commF.Invoked == 0, "Buso ja ativo -> o passo nao re-invoca (gate do atributo)")

    -- Desligar o Ken com ele ATIVO manda Ken=false; com ele inativo, nao manda.
    resetFired()
    feature.KenOn = true
    feature:SetKen(false)
    check(commE.Fired[#commE.Fired][2] == false, "desligar o Ken ativo manda Ken=false")
    resetFired()
    char:SetAttribute("KenActive", false)
    feature.KenOn = true
    feature:SetKen(false)
    check(#commE.Fired == 0, "desligar o Ken inativo nao manda nada")

    -- Desligar o Buso com ele ATIVO manda o toggle Buso de volta.
    resetFired()
    char:SetAttribute("BusoEnabled", true)
    feature.BusoOn = true
    feature:SetBuso(false)
    check(commF.Invoked[#commF.Invoked] ~= nil and commF.Invoked[#commF.Invoked][1] == "Buso", "desligar o Buso ativo manda o toggle Buso")

    -- O loop compartilhado: ligar o Ken agenda UM thread; ligar o Buso nao
    -- duplica; desligar os dois cancela.
    resetFired()
    feature:SetKen(true)
    check(feature.KenOn == true and feature.Threads.haki ~= nil, "SetKen liga e agenda o loop da haki")
    local firstThread = feature.Threads.haki
    feature:SetBuso(true)
    check(feature.BusoOn == true and feature.Threads.haki == firstThread, "SetBuso nao duplica o loop (um so)")
    feature:SetKen(false)
    check(feature.Threads.haki == firstThread, "com o Buso ainda ligado o loop continua")
    feature:SetBuso(false)
    check(feature.Threads.haki == nil, "desligar os dois cancela o loop da haki")

    -- Disable derruba o loop e zera os pedidos.
    feature:SetKen(true)
    feature:SetBuso(true)
    feature:Disable()
    check(feature.KenOn == false and feature.BusoOn == false, "Disable zera os pedidos de haki")
    check(feature.Threads.haki == nil, "Disable cancela o loop da haki")

    feature:Destroy()
end

-- Player cleanup: estado ORIGINAL restaurado (nao defaults) e o Stun que a
-- FEATURE criou destruido. Um character que ja tinha valores do jogo volta com
-- eles; um que nao tinha Stun nao pode sair com um Stun orfao.
do
    local ctx = bfContext(994732206, 994732206)
    local Player = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "player.lua"])()

    -- Character SEM Stun e com atributos PRE-EXISTENTES do jogo (valores que a
    -- feature nao pode sobrescrever no fim).
    local char = Instance.new("Model"); char.Name, char.Parent = "Character", ctx.Player
    ctx.Player.Character = char
    char:SetAttribute("SpeedMultiplier", 8)
    char:SetAttribute("UnbreakableAll", true)
    char:SetAttribute("WaterWalking", false)

    local feature = Player.new({ speed = 4 })
    -- Liga primeiro (bind no character + re-bind no respawn); os setters vem
    -- depois, como no painel real.
    feature:Enable()
    check(feature.Character == char, "Enable liga a feature ao character do local player")
    feature:SetSpeed(4)
    feature:SetUnbreakable(true)
    feature:SetWaterWalking(true)

    -- A feature criou um Stun (o character nao tinha nenhum).
    check(char:FindFirstChild("Stun") ~= nil, "a feature cria o Stun quando o character nao tem")

    -- Desliga: o Stun CRIADO pela feature sai, e os atributos voltam ao que o
    -- jogo tinha ANTES (8, true, false) -- nao a defaults.
    feature:Disable()
    check(char:FindFirstChild("Stun") == nil, "o Disable DESTROI o Stun que a FEATURE criou")
    check(char:GetAttribute("SpeedMultiplier") == 8, "a velocidade volta ao valor ORIGINAL do jogo (8)")
    check(char:GetAttribute("UnbreakableAll") == true, "o Unbreakable volta ao valor original (true)")
    check(char:GetAttribute("WaterWalking") == false, "o Water walk volta ao valor original (false)")

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

    -- Durante o voo: o Heartbeat zera a velocidade e tira o noclip (CanCollide
    -- false). O cache e montado uma vez (ao ver o character) e reusado -- nao
    -- varre GetDescendants por frame.
    check(tp:IsEnabled() == true, "o motor esta ligado (loop do Heartbeat ativo)")
    root.CanCollide = true
    local tween2 = tp:Go(Vector3.new(0, 0, 100))
    check(tween2 ~= nil, "novo voo criado para testar o Heartbeat")
    ctx.Services.RunService.Heartbeat:Fire()
    check(tp._noclipParts ~= nil and #tp._noclipParts >= 1, "o Heartbeat monta o cache de noclip uma vez")
    check(root.CanCollide == false, "durante o voo o Heartbeat tira a colisao (noclip)")
    local cachedCount = #tp._noclipParts
    ctx.Services.RunService.Heartbeat:Fire()
    check(#tp._noclipParts == cachedCount, "o cache nao e reconstruido por frame (so quando o character muda)")

    -- Cancelar (o que o desligar do toggle faz) devolve a colisao: o personagem
    -- nao fica atravessando o chao depois.
    check(tp:Cancel() == true, "Cancel no meio do voo")
    check(root.CanCollide == true, "Cancel devolve a colisao (o personagem volta a pisar)")

    -- Bug: _RestoreCollision setava CanCollide=true CEGO. Uma parte que ja era
    -- nao-colidivel (acessorio, decoracao) tem que voltar nao-colidivel -- nao
    -- ganhar colisao. Aqui uma parte nasce CanCollide=false e tem que continuar
    -- false depois do voo.
    local accessory = Instance.new("Part"); accessory.Name, accessory.Parent = "Accessory", character
    accessory.CanCollide = false
    root.CanCollide = true
    local tween3 = tp:Go(Vector3.new(0, 0, 100))
    check(tween3 ~= nil, "novo voo para testar a colisao original")
    ctx.Services.RunService.Heartbeat:Fire()
    check(accessory.CanCollide == false, "durante o voo a parte nao-colidivel continua false")
    check(root.CanCollide == false, "durante o voo a parte colidivel vira false")
    check(tp:Cancel() == true, "Cancel devolve o estado de cada parte")
    check(root.CanCollide == true, "a parte que era colidivel volta colidivel")
    check(accessory.CanCollide == false, "a parte que ja era nao-colidivel volta nao-colidivel (nao vira true)")

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
-- Sea 3, o dropdown monta com os destinos do Sea 3 (a primeira e Port Town), nao
-- com as ilhas do Sea 2.
do
    local ctx = bfContext(994732206, 994732206)
    ctx.RealmSea = 3
    local state = ctx:Run("src/games/bloxfruits.lua")

    -- Instancia a feature com o mar que o backend detectou.
    check(state.Sea == 3 or state.Sea == "3" or state.Sea == "Sea3", "o backend detecta o Sea 3 (veio: " .. tostring(state.Sea) .. ")")
    check(state:SetFeature("islands", true), "a feature de ilhas sobe no Sea 3")
    local feature = state:GetFeature("islands")
    check(feature ~= nil and feature.CurrentSea == "Sea3", "a feature fica no mar detectado (Sea 3)")
    check(feature.Selected == "Port Town", "a selecao cai na primeira ilha do Sea 3 (Port Town)")

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


-- O bug real do usuario: um toggle salvo LIGADO abre ligado no painel, mas a
-- FEATURE nao esta rodando (o "ESP ta ativo mas nao aparece"). Aqui ele e o foco:
-- com fruitEsp salvo, o painel abre, o toggle abre ligado E a feature tem que
-- estar de fato habilitada com o loop de ESP no ar -- nao so a carinha do toggle.
do
    local ctx = bfContext(994732206, 994732206)
    local ui = ctx:MountUI()
    ctx.Files["DepHub_BloxFruits_config.json"] = '{"fruitEsp":true,"fruitTrace":true,"fruitGrab":true,"silentaim":true}'
    local state = ctx:Run("src/games/bloxfruits.lua")

    -- A fruta precisa existir COMO INSTANCIA e estar habilitada.
    check(state.Instances.fruit ~= nil, "o fruitEsp salvo instancia a feature de fruta no load")
    check(state.Instances.fruit:IsEnabled() == true, "a feature de fruta fica habilitada pelo config salvo")
    check(state.Instances.fruit.EspEnabled == true, "o loop de ESP fica ligado pelo config salvo")
    check(state.Instances.fruit.Threads.esp ~= nil, "o loop de ESP esta REALMENTE rodando (nao so o toggle)")

    -- As outras features salvas tambem tem que estar rodando, nao so marcadas.
    check(state.Instances.silentaim ~= nil and state.Instances.silentaim:IsEnabled() == true, "o silent aim salvo liga de verdade")

    state:Destroy()
end

-- Mesma coisa pelos TOGGLES DA TELA: o valor salvo tem que cair no callback que
-- liga a feature, nao apenas pintar o controle. Sem isso o usuario ve o toggle
-- ligado e nada acontece.
do
    local ctx = bfContext(994732206, 994732206)
    local ui = ctx:MountUI()
    ctx.Files["DepHub_BloxFruits_config.json"] = '{"fruitEsp":true,"waterwalk":true}'
    local state = ctx:Run("src/games/bloxfruits.lua")

    local espControl, waterControl
    for _, control in ipairs(ui.Library._Controls) do
        if control.Kind == "toggle" and control.Label == "Fruit ESP" then espControl = control end
        if control.Kind == "toggle" and control.Label == "Water walk" then waterControl = control end
    end
    check(espControl ~= nil and espControl.Handle.Value == true, "o toggle Fruit ESP abre ligado")
    check(state.Instances.fruit ~= nil and state.Instances.fruit.EspEnabled == true, "e o ESP liga de verdade no load")
    check(waterControl ~= nil and waterControl.Handle.Value == true, "o toggle Water walk abre ligado")
    check(state.Instances.player ~= nil, "e a feature do player sobe no load")

    state:Destroy()
end

-- "Salva TUDO": TODO controle configuravel do painel (toggle, slider, dropdown)
-- tem que estar registrado no store -- quem registra e quem faz o auto-load
-- re-disparar o setter. Um controle que nasce com literal false e nunca chama
-- RegisterConfig salva nada e nunca reativa: era o caso do Blade hits e do
-- Island teleport. Aqui enumeramos os controles e conferimos o registro.
do
    local ctx = bfContext(994732206, 994732206)
    local ui = ctx:MountUI()
    local state = ctx:Run("src/games/bloxfruits.lua")

    -- Os handles registrados (toggle/dropdown tem Handle; slider guarda Value).
    local registeredHandles = {}
    local registeredKeys = {}
    for _, entry in ipairs(state.Store.Entries) do
        registeredKeys[entry.key] = true
        if entry.handle ~= nil then registeredHandles[entry.handle] = true end
    end

    -- As chaves que o painel precisa salvar. Se um controle novo nascer sem
    -- registro, este conjunto fica menor do que a tela e o teste acusa.
    local expectedKeys = {
        bladhits = true, silentaim = true, exceptionKeys = true, range = true,
        fruitEsp = true, fruitTrace = true, fruitGrab = true, fruitStore = true,
        fruitSkip = true, fruitKeep = true, island = true, islandOn = true,
        speed = true, unbreakable = true, waterwalk = true, flashstep = true,
        autoken = true, autobuso = true,
        autoexec = true,
    }
    for key in pairs(expectedKeys) do
        check(registeredKeys[key] == true, "o controle '" .. key .. "' esta registrado no store (salva e reativa)")
    end

    -- E todo controle com Handle na tela foi registrado -- nenhum ficou de fora.
    local unregistered = {}
    for _, control in ipairs(ui.Library._Controls) do
        if (control.Kind == "toggle" or control.Kind == "dropdown") and control.Handle ~= nil then
            if not registeredHandles[control.Handle] then
                unregistered[#unregistered + 1] = control.Kind .. ":" .. tostring(control.Label)
            end
        end
    end
    check(#unregistered == 0, "nenhum controle com handle ficou sem registro: " .. table.concat(unregistered, ", "))

    state:Destroy()
end

-- Blade hits + Island teleport: os dois que nasciam com literal false e nunca
-- salvavam. Aqui: (1) mexer neles grava no Config e no arquivo; (2) um arquivo
-- com eles ligados REATIVA a feature no start (nao so pinta o toggle).
do
    local ctx = bfContext(994732206, 994732206)
    local ui = ctx:MountUI()
    local state = ctx:Run("src/games/bloxfruits.lua")

    local blade, island
    for _, control in ipairs(ui.Library._Controls) do
        if control.Kind == "toggle" and control.Label == "Blade hits" then blade = control end
        if control.Kind == "toggle" and control.Label == "Island teleport" then island = control end
    end
    check(blade ~= nil and island ~= nil, "o painel monta os toggles Blade hits e Island teleport")

    blade.Handle:SetValue(true)
    check(state.Config.bladhits == true, "ligar Blade hits grava no Config (antes nao salvava)")
    island.Handle:SetValue(true)
    check(state.Config.islandOn == true, "ligar Island teleport grava no Config (antes nao salvava)")

    ctx.Env.writefile("DepHub_BloxFruits_config.json", state:EncodeConfig())

    state:Destroy()
end

do
    local ctx = bfContext(994732206, 994732206)
    local ui = ctx:MountUI()
    ctx.Files["DepHub_BloxFruits_config.json"] = '{"bladhits":true,"islandOn":true}'
    local state = ctx:Run("src/games/bloxfruits.lua")

    -- Blade hits salvo ligado: a feature existe e esta habilitada de verdade.
    check(state.Instances.bladhits ~= nil and state.Instances.bladhits:IsEnabled() == true, "Blade hits salvo reativa a feature no load")
    -- Island teleport salvo ligado: a feature existe e o toggle da tela esta ligado.
    check(state.Instances.islands ~= nil, "Island teleport salvo instancia a feature no load")
    local islandControl
    for _, control in ipairs(ui.Library._Controls) do
        if control.Kind == "toggle" and control.Label == "Island teleport" then islandControl = control end
    end
    check(islandControl ~= nil and islandControl.Handle.Value == true, "o toggle Island teleport abre ligado pelo salvo")

    state:Destroy()
end

-- Auto-load de ILHA: o destino salvo (dropdown) tem que ser aplicado ANTES do
-- toggle ligar (a ordem de registro), pra o voo sair direto pra ilha certa e nao
-- voar pra padrao e re-voar. Aqui o dropdown abre no valor salvo e a feature
-- desponta com a mesma selecao.
do
    local ctx = bfContext(994732206, 994732206)
    local ui = ctx:MountUI()
    ctx.Files["DepHub_BloxFruits_config.json"] = '{"island":"Ice Castle","islandOn":true}'
    local state = ctx:Run("src/games/bloxfruits.lua")

    local islandDown
    for _, control in ipairs(ui.Library._Controls) do
        if control.Kind == "dropdown" and control.Label == "Island" then islandDown = control end
    end
    check(islandDown ~= nil and islandDown.Handle.Value == "Ice Castle", "o dropdown Island abre no destino salvo")
    check(state.Instances.islands ~= nil and state.Instances.islands.Selected == "Ice Castle", "a feature seleciona o destino salvo (nao a ilha padrao)")

    state:Destroy()
end

-- Auto execute robusto: a API pode estar SO no getgenv() (executor que nao
-- publica o nome livre). Antes a resolucao lia so o global solto e o toggle nao
-- fazia nada nesse caso -- o "autoexecute nao funciona" do usuario.
do
    local ctx = bfContext(994732206, 994732206)
    local ui = ctx:MountUI()
    local state = ctx:Run("src/games/bloxfruits.lua")

    -- Tira do global solto e publica SO no getgenv() (ex.: context.State).
    ctx.Env.queue_on_teleport = nil
    local captured = nil
    ctx.State.queue_on_teleport = function(script) captured = script end

    check(state:SetAutoExec(true) == true, "com a API so no getgenv() o auto execute liga")
    check(type(captured) == "string" and captured:find("DepHub.lua", 1, true) ~= nil, "o reload foi enfileirado mesmo assim")

    state:Destroy()
end