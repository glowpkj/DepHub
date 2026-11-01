-- Behaviour checks for o backend de Blox Fruits do usuario.
--
-- O backend carrega src/games/features/bloxfruits/<nome>.lua (uma feature por
-- arquivo, cada uma independente) e monta o painel. As features que ainda nao
-- foram portadas ficam guardadas em features/bloxfruits/parked/ -- fora da
-- pasta ativa, sem carregar e sem entrar no manifest -- portanto nao aparecem
-- aqui. Nao existe flag global: o que carrega e so o que esta em FEATURE_MODULES.
local FEATURE_PREFIX = "src/games/features/bloxfruits/"
local FEATURES = {"bladhits"}
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
    check(type(state.Errors) == "table" and #state.Errors == 0, "a blade hit carrega sem erro")

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
        check(name == "bladhits" or name == "teleport", "nenhuma feature parkeada e carregada")
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
