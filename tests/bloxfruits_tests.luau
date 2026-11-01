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
    check(bare:SetRange(0) and bare.Range == 0, "SetRange aceita 0 (qualquer distancia)")
    check(bare:SetRange(-1) == false, "SetRange rejeita negativo")
    check(bare:SetEspRange(500) and bare.EspRange == 500, "SetEspRange aplica um alcance valido")

    -- Listas de skip/keep por prefixo, case-insensitive.
    bare:SetSkip("Dragon, Rocket")
    check(bare.Skip["dragon"] == true and bare.Skip["rocket"] == true, "SetSkip parseia a lista")
    bare:SetKeep("leopard")
    check(bare.Keep["leopard"] == true, "SetKeep parseia a lista")

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

    -- Fora do range nao entra.
    fruit:SetRange(10)
    check(fruit:NearestGroundFruit() == nil, "range curto esconde a fruta distante")
    fruit:SetRange(0)

    -- Na skip list, nao entra.
    fruit:SetSkip("dragon")
    check(fruit:NearestGroundFruit() == nil, "a skip list esconde a fruta pelo prefixo")
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

    -- A lista publica das ilhas (o backend monta o dropdown dela).
    check(type(Islands.islands) == "table" and #Islands.islands == 12, "a feature publica as 12 ilhas do Sea 2")
    check(Islands.islands[1] == "Snow Mountain", "a primeira ilha da lista e Snow Mountain")

    local islands = Islands.new({ teleport = motor })
    check(islands.ToggleOn == false, "o toggle comeca desligado")
    check(islands.Selected == "Snow Mountain", "a selecao comeca na primeira ilha")

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

    -- Sem motor de teleporte, ligar recusa.
    local bare = Islands.new()
    check(bare:SetEnabled(true) == false and bare.ToggleOn == false, "sem teleporte o toggle recusa")

    bare:Destroy()
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
