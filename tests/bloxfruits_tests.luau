-- Behaviour checks for o backend de Blox Fruits do usuario.
--
-- O backend carrega src/games/features/bloxfruits/<nome>.lua (uma feature por
-- arquivo, cada uma independente) e monta o painel. As features que ainda nao
-- foram portadas ficam guardadas em features/bloxfruits/parked/ -- fora da
-- pasta ativa, sem carregar e sem entrar no manifest -- portanto nao aparecem
-- aqui. Nao existe flag global: o que carrega e so o que esta em FEATURE_MODULES.
local FEATURE_PREFIX = "src/games/features/bloxfruits/"
local FEATURES = {"bladhits", "fruit", "raid"}
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
    check(state.Features.raid ~= nil, "a feature de raid e carregada pelo backend")
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

    -- A raid instancia pelo proprio toggle e recebe TANTO o motor de teleporte
    -- quanto a blade hit (o ataque e injetado, nao reimplementado). Sem a blade
    -- hit instanciada antes, o raid nasce sem motor de ataque.
    check(state.Instances.raid == nil, "a raid nao instancia so pelo load")
    check(state:SetToggle("raid", true), "ligar o toggle instancia a raid")
    check(state.Instances.raid.Teleport == state.Infra.teleport, "a raid recebeu o motor de teleporte")
    check(state.Instances.raid.Combat == state.Instances.bladhits, "a raid recebeu a blade hit como motor de ataque")
    state:SetToggle("raid", false)

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
        check(name == "bladhits" or name == "teleport" or name == "fruit" or name == "raid", "nenhuma feature parkeada e carregada")
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
    check(names["Farm"] == true, "a aba Farm e criada para fruta e raid")
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

-- O auto complete e o SEGUNDO toggle da raid, e faz uma coisa so: terminar uma
-- raid que ja esta rolando. Nao compra chip, nao cria raid, nao aperta botao --
-- acha as ilhas em workspace.Map.RaidMap, vai na mais perto e recalcula.
do
    local ctx = bfContext(994732206, 994732206)
    local Raid = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "raid.lua"])()
    local motor = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "teleport.lua"])().new()

    -- Personagem posicionado na origem.
    local char = Instance.new("Model"); char.Name, char.Parent = "Character", ctx.Player
    ctx.Player.Character = char
    local root = Instance.new("Part"); root.Name, root.Position, root.Parent = "HumanoidRootPart", Vector3.new(0, 0, 0), char
    local humanoid = Instance.new("Humanoid"); humanoid.Parent = char

    local raid = Raid.new({ teleport = motor })
    check(raid.AutoComplete == false, "o auto complete comeca desligado")
    check(raid.IslandNumber == 1, "o auto complete comeca apontando pra ilha 1")

    -- Sem RaidMap no workspace: nao ha ilha nenhuma, e ele reporta isso.
    check(raid:RaidMap() == nil, "sem raid rolando nao ha RaidMap")
    check(raid:IslandByNumber(1) == nil, "sem RaidMap nao ha ilha 1")
    check(raid:HighestIslandNumber() == 0, "sem RaidMap nao ha ilha nenhuma")
    check(raid:CompleteStep() == false, "sem RaidMap o passo de completar recusa")

    -- A raid comeca: workspace.Map.RaidMap aparece com as ilhas.
    local map = Instance.new("Folder"); map.Name, map.Parent = "Map", ctx.Services.Workspace
    local raidMap = Instance.new("Folder"); raidMap.Name, raidMap.Parent = "RaidMap", map
    check(raid:RaidMap() == raidMap, "acha o RaidMap em workspace.Map")

    -- Tres ilhas, nomeadas por numero -- a ORDEM e o nome, nao a distancia.
    -- Propositalmente a 3 esta mais perto que a 2, pra provar que a sequencia e
    -- por numero e nao por proximidade.
    local i1 = Instance.new("Model"); i1.Name, i1.Parent = "RaidIsland1", raidMap
    local i1p = Instance.new("Part"); i1p.Name, i1p.Position, i1p.Parent = "Floor", Vector3.new(0, 0, 50), i1
    local i2 = Instance.new("Model"); i2.Name, i2.Parent = "RaidIsland2", raidMap
    local i2p = Instance.new("Part"); i2p.Name, i2p.Position, i2p.Parent = "Floor", Vector3.new(0, 0, 500), i2
    local i3 = Instance.new("Model"); i3.Name, i3.Parent = "RaidIsland3", raidMap
    local i3p = Instance.new("Part"); i3p.Name, i3p.Position, i3p.Parent = "Floor", Vector3.new(0, 0, 200), i3

    check(raid:IslandByNumber(1) == i1, "a ilha 1 e RaidIsland1")
    check(raid:IslandByNumber(2) == i2, "a ilha 2 e RaidIsland2")
    check(raid:IslandByNumber(3) == i3, "a ilha 3 e RaidIsland3")
    check(raid:IslandByNumber(4) == nil, "nao existe ilha 4")
    check(raid:HighestIslandNumber() == 3, "a ultima ilha e a 3")

    -- A sequencia comeca na 1, mesmo com a 3 estando mais perto.
    local island, number = raid:CurrentIsland()
    check(island == i1 and number == 1, "a ilha atual comeca na 1, nao na mais perto")

    -- O passo de completar acha a ilha 1 e voa pra la (o jogador esta na origem,
    -- ilha 1 a 50 studs -- acima do limite de 40, entao voa). Sem mob nenhum no
    -- workspace, a ilha ja conta como limpa -- mas ele so avanca no proximo
    -- passo; aqui ele ainda registra onde estava.
    check(raid:CompleteStep() == true, "com RaidMap o passo de completar acha a ilha")
    check(motor:IsFlying() == true, "o passo de completar voa ate a ilha")
    check(raid.RoundOver == false, "ha proxima ilha: a rodada nao acabou")
    motor:Cancel()

    -- Perto da ilha (menos de 40 studs) ele NAO reinicia o voo -- so fica
    -- batendo. Reiniciar de perto travaria o personagem vibrando no lugar.
    -- (Com mob vivo ele fica na ilha; o mob prova o caso "perto".)
    root.Position = Vector3.new(0, 0, 20)
    raid.IslandNumber = 1
    motor:Cancel()
    local enemies = Instance.new("Folder"); enemies.Name, enemies.Parent = "Enemies", ctx.Services.Workspace
    local mob = Instance.new("Model"); mob.Name, mob.Parent = "Bandit", enemies
    local mobHumanoid = Instance.new("Humanoid"); mobHumanoid.Health = 100; mobHumanoid.Parent = mob
    check(raid:CompleteStep() == true, "perto da ilha o passo de completar ainda roda")
    check(raid.IslandNumber == 1, "com mob vivo ele fica na ilha 1")
    check(motor:IsFlying() == false, "perto da ilha nao reinicia o voo")

    -- A ilha 1 limpa (sem mob vivo -- o mob morreu): ele AVANCA pro proximo
    -- numero, nao pra mais perto.
    root.Position = Vector3.new(0, 0, 0)
    motor:Cancel()
    mobHumanoid.Health = 0
    check(raid:CompleteStep() == true, "ilha limpa: o passo de completar roda")
    check(raid.IslandNumber == 2, "ilha 1 limpa -> avanca pra ilha 2 (numero, nao distancia)")
    check(motor:IsFlying() == true, "avancou e voou pra ilha 2")

    -- Ilha 3 tambem limpa: agora e a ultima -- sem proxima e sem mob = acabou.
    motor:Cancel()
    raid.IslandNumber = 3
    check(raid:CompleteStep() == true, "ilha 3 limpa: o passo de completar roda")
    check(raid.RoundOver == true, "sem proxima ilha e sem mob a rodada acaba")
    check(motor:IsFlying() == false, "rodada acabou: ele nao voa mais pra lugar nenhum")

    -- Auto complete sem motor de teleporte recusa.
    local bare = Raid.new()
    check(bare:SetAutoComplete(true) == false and bare.AutoComplete == false, "sem teleporte o auto complete recusa")

    -- O toggle liga, reinicia a sequencia na ilha 1, e desliga sem explodir.
    raid.IslandNumber = 5
    raid.RoundOver = true
    check(raid:SetAutoComplete(true) == true, "com teleporte o auto complete liga")
    check(raid.IslandNumber == 1 and raid.RoundOver == false, "ligar reinicia a sequencia na ilha 1")
    check(raid:SetAutoComplete(false) == true, "o auto complete desliga")
    check(raid.AutoComplete == false, "depois de desligar nao esta mais ativo")

    raid:Destroy()
    bare:Destroy()
end

-- O auto complete LIGA a blade hit quando ela existe, e DESLIGA ela ao desligar
-- o toggle -- mas so se foi o proprio complete que a ligou (nao mexe na blade
-- hit que o jogador ligou por fora).
do
    local ctx = bfContext(994732206, 994732206)
    local motor = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "teleport.lua"])().new()
    local Raid = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "raid.lua"])()

    local char = Instance.new("Model"); char.Name, char.Parent = "Character", ctx.Player
    ctx.Player.Character = char
    local root = Instance.new("Part"); root.Name, root.Position, root.Parent = "HumanoidRootPart", Vector3.new(0, 0, 0), char
    local humanoid = Instance.new("Humanoid"); humanoid.Parent = char
    local map = Instance.new("Folder"); map.Name, map.Parent = "Map", ctx.Services.Workspace
    local raidMap = Instance.new("Folder"); raidMap.Name, raidMap.Parent = "RaidMap", map
    local island = Instance.new("Model"); island.Name, island.Parent = "RaidIsland1", raidMap
    local floor = Instance.new("Part"); floor.Name, floor.Position, floor.Parent = "Floor", Vector3.new(0, 0, 300), island

    -- Uma blade hit de verdade, com os remotes resolvidos.
    local BladeHit = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "bladhits.lua"])()
    local blade = BladeHit.new()
    check(blade:ResolveRemotes(), "a blade hit resolve os remotes pra o complete dirigir")

    local raid = Raid.new({ teleport = motor, combat = blade })
    check(blade:IsEnabled() == false, "a blade hit comeca desligada")
    check(raid:CompleteStep() == true, "o passo de completar acha a ilha")
    check(blade:IsEnabled() == true, "o auto complete liga a blade hit")
    check(raid.AttackEnabled == true, "o complete marca que foi ELE que ligou o ataque")

    -- Desligar o auto complete derruba o ataque que ele ligou.
    raid:SetAutoComplete(false)
    check(blade:IsEnabled() == false, "desligar o auto complete desliga a blade hit que ele ligou")
    check(raid.AttackEnabled == false, "a marca de ataque ligado some")

    -- Se a blade hit ja estava ligada por fora, o complete nao a derruba.
    check(blade:Enable() == true, "a blade hit e ligada por fora")
    raid:CompleteStep()
    check(raid.AttackEnabled == false, "o complete nao reivindica um ataque que ja estava ligado")
    raid:SetAutoComplete(false)
    check(blade:IsEnabled() == true, "a blade hit do jogador continua ligada")

    blade:Destroy()
    raid:Destroy()
end

-- A raid e auto-contida e reusa DUAS pecas por injecao: o teleporte (pra ir ao-- tubo) e a blade hit (pra limpar as waves). Sem cada uma ela degrada de um jeito
-- especifico -- sem teleporte recusa; sem blade hit entra mas nao ataca. Este
-- bloco carrega ela sozinha e exercita a API publica.
do
    local ctx = bfContext(994732206, 994732206)
    local Raid = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "raid.lua"])()
    check(type(Raid) == "table" and type(Raid.new) == "function", "a raid carrega sozinha e publica new()")
    check(#Raid.elements == 20 and Raid.elements[1] == "Flame", "a lista de elementos veio do original")

    -- Sem motor de teleporte o Enable recusa: nao ha como ir ao tubo.
    local bare = Raid.new()
    check(bare.Teleport == nil and bare.Combat == nil, "sem injecao as duas pecas sao nil")
    check(bare:Enable() == false, "a raid recusa sem motor de teleporte")

    -- Com o teleporte (mas sem blade hit): liga, mas nao limpa wave.
    local motor = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "teleport.lua"])().new()
    bare:SetSea("Sea2")
    bare.Teleport = motor
    check(bare:Enable() == true, "com teleporte a raid liga")
    check(bare:ClearStep() == false, "sem blade hit injetada a raid nao limpa wave")
    bare:Disable()

    -- O elemento e trocavel, e trocar invalida o chip comprado.
    check(bare:SetElement("Dough") and bare.Element == "Dough", "SetElement troca o elemento")
    check(bare:SetElement("") == false, "SetElement rejeita vazio")
    bare.ChipBought, bare.ChipElement = true, "Flame"
    bare:SetElement("Ice")
    check(bare.ChipBought == false, "trocar de elemento invalida o chip comprado")

    check(bare:SetStartWait(3) and bare.StartWait == 3, "SetStartWait aplica um valor valido")
    check(bare:SetStartWait(-1) == false, "SetStartWait rejeita negativo")
    check(bare:SetChipWait(2) and bare.ChipWait == 2, "SetChipWait aplica um valor valido")

    -- O mar decide o tubo; sem informacao de jogo, cai no Sea 2.
    local sea2 = bare:Location()
    check(type(sea2) == "table" and sea2.tube ~= nil and sea2.button ~= nil, "Location devolve tubo e botao")
    check(sea2.tube.Z == -4767.7, "sem informacao de mar o tubo e o do Sea 2")
    bare:SetSea("Sea3")
    check(bare:Location().tube.Z == -2816.5, "SetSea troca o tubo pro do Sea 3")

    -- Enable/Disable ciclam e limpam o estado.
    check(bare:Disable() and bare:IsEnabled() == false, "Enable/Disable ciclam")
    check(bare.InRaid == false, "Disable sai do estado de raid")
    bare:Destroy()
end

-- A raid contra um mundo com o NPC, o botao e a blade hit: o chip e achado e
-- equipado, o botao e disparado, e a blade hit vira o motor de ataque. E o ciclo
-- que importa -- sem remotes reais, mas com as instancias que o jogo entrega.
do
    local ctx = bfContext(994732206, 994732206)
    local Raid = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "raid.lua"])()
    local motor = ctx.Env.loadstring(sources[FEATURE_PREFIX .. "teleport.lua"])().new()

    -- Remotes do NPC de raid e do evento de raid.
    local rstorage = ctx.Services.ReplicatedStorage
    local remotes = Instance.new("Folder"); remotes.Name = "Remotes"; remotes.Parent = rstorage
    local comm = Instance.new("RemoteFunction"); comm.Name = "CommF_"; comm.Parent = remotes
    local raids = Instance.new("RemoteEvent"); raids.Name = "Raids"; raids.Parent = remotes

    -- Personagem com Humanoid (pra equipar o chip).
    local char = Instance.new("Model"); char.Name, char.Parent = "Character", ctx.Player
    ctx.Player.Character = char
    local root = Instance.new("Part"); root.Name, root.Position, root.Parent = "HumanoidRootPart", Vector3.new(0, 0, 0), char
    local humanoid = Instance.new("Humanoid"); humanoid.Parent = char

    -- O chip esta na mochila.
    local backpack = Instance.new("Backpack"); backpack.Name, backpack.Parent = "Backpack", ctx.Player
    local chip = Instance.new("Tool"); chip.Name, chip.Parent = "Microchip", backpack

    local raid = Raid.new({ teleport = motor })
    check(raid:ChipTool() == chip, "a raid acha o Microchip na mochila")
    check(raid:ChipEquipped() == false, "o chip ainda nao esta equipado")
    check(raid:EquipChip() == true, "a raid equipa o Microchip")
    check(raid:ChipEquipped() == true, "depois de EquipChip o chip esta na mao")

    -- O evento de raid controla o estado "dentro da raid". O servidor entrega
    -- StartTimer/Finished pelo OnClientEvent (o cliente so escuta).
    check(raid:ConnectRaidEvent() == true, "a raid se conecta ao evento Raids")
    raids.OnClientEvent:Fire("StartTimer")
    check(raid.InRaid == true, "StartTimer poe a raid em estado de limpeza")
    raids.OnClientEvent:Fire("Finished")
    check(raid.InRaid == false, "Finished tira a raid do estado de limpeza")
    raid:DisconnectRaidEvent()
    check(raid.RaidConnection == nil, "Disconnect limpa a conexao do evento")

    -- O botao: um ProximityPrompt no tubo e disparado pelo TriggerNear.
    local fired = 0
    ctx.Env.fireproximityprompt = function() fired = fired + 1 end
    local loc = raid:Location()
    local button = Instance.new("Part"); button.Name, button.Position, button.Parent = "RaidButton", loc.button, ctx.Services.Workspace
    local prompt = Instance.new("ProximityPrompt"); prompt.Parent = button
    check(raid:TriggerNear(loc.button) >= 1, "TriggerNear acha e dispara o prompt do botao")
    check(fired >= 1, "fireproximityprompt foi chamado no botao")
    ctx.Env.fireproximityprompt = nil

    -- Sem blade hit injetada, o ClearStep recusa em vez de atacar sozinho.
    check(raid:ClearStep() == false, "a raid nao ataca sem motor de ataque")
    check(raid.LastStatus == "no attack motor injected", "a raid reporta que falta o motor de ataque")

    raid:Destroy()
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
