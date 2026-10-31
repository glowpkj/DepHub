-- Behaviour checks for o backend de Blox Fruits do usuario.
--
-- O backend carrega src/games/features/bloxfruits/<nome>.lua (uma feature por
-- arquivo, cada uma independente) e monta o painel. As features que ainda nao
-- foram portadas ficam guardadas em features/bloxfruits/parked/ -- fora da
-- pasta ativa, sem carregar e sem entrar no manifest -- portanto nao aparecem
-- aqui. Nao existe flag global: o que carrega e so o que esta em FEATURE_MODULES.
local FEATURE_PREFIX = "src/games/features/bloxfruits/"
local FEATURES = {"bladhits"}

-- O backend resolve as features pelo mesmo game:HttpGet que um executor usa, e
-- a blade hit faz os proprios game:GetService, entao cada arquivo tem que ser
-- servido pelo sandbox.
local function bfContext(placeId, gameId)
    local ctx = sandbox(placeId, gameId)
    for _, name in ipairs(FEATURES) do
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
    check(instance.AttackRange == 100, "alcance padrao e 100")
    check(instance.MinInterval == 0.1, "intervalo padrao e 0.1s")
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

    -- Os knobs passam pelo backend ate o metodo do modulo.
    state:SetToggle("bladhits", true)
    check(state:SetFeatureRange("bladhits", 180), "o backend encaminha SetRange")
    check(state.Instances.bladhits.AttackRange == 180, "o alcance chega no modulo")
    check(state:SetFeatureInterval("bladhits", 0.05), "o backend encaminha SetInterval")
    check(state.Instances.bladhits.MinInterval == 0.05, "o intervalo chega no modulo")

    -- Um nome desconhecido nao explode nem liga nada.
    check(state:SetToggle("nao-existe", true) == false, "feature desconhecida e rejeitada")
    check(state:SetFeatureRange("nao-existe", 5) == false, "knob de feature desconhecida e rejeitado")

    local status = state:GetStatus()
    check(status.TogglesOn == 1, "status conta a feature ligada")

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
        check(name == "bladhits", "nenhuma feature parkeada e carregada")
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

-- O mesmo backend servido pela outra rota (PlaceId do Sea 1) tem que se
-- comportar igual.
do
    local ctx = bfContext(85211729168715, 85211729168715)
    local state = ctx:Run("src/games/bloxfruits.lua")
    check(type(state) == "table" and state.Destroyed == false, "Blox Fruits sobe tambem na rota do Sea 1")
    check(state.Features.bladhits ~= nil, "a blade hit carrega na rota do Sea 1")
    check(ctx.State.__DEPHUB.BloxFruits == state, "o contrato do loader aponta pro backend")
end
