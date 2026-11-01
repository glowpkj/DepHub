-- Behaviour checks for o backend de Blox Fruits do usuario.
--
-- O backend carrega src/games/features/bloxfruits/<nome>.lua (uma feature por
-- arquivo, cada uma independente) e monta o painel. As features que ainda nao
-- foram portadas ficam guardadas em features/bloxfruits/parked/ -- fora da
-- pasta ativa, sem carregar e sem entrar no manifest -- portanto nao aparecem
-- aqui. Nao existe flag global: o que carrega e so o que esta em FEATURE_MODULES.
local FEATURE_PREFIX = "src/games/features/bloxfruits/"
local FEATURES = {"bladhits", "fruit", "islands"}
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
    check(type(state.Errors) == "table" and #state.Errors == 0, "as features carregam sem erro")

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
        check(name == "bladhits" or name == "teleport" or name == "fruit" or name == "islands", "nenhuma feature parkeada e carregada")
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
