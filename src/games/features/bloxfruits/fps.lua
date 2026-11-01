local game = game
local type = type
local pcall = pcall
local ipairs = ipairs
local pairs = pairs

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Terrain = Workspace and Workspace:FindFirstChildOfClass("Terrain")

-- Performance -- aliviar o que o JOGO renderiza, sem mexer nas features.
--
-- O que come FPS no Blox Fruits e o render do mapa: sombras dinamicas, luzes,
-- efeitos de pos-processamento (bloom/raio de sol/desfoque), particulas, beams,
-- a agua com reflexo. Isso e o custo dominante -- muito mais do que o proprio
-- script, cujos loops sao poucos e leves.
--
-- Cada alavanca aqui e REVERSIVEL: guarda o valor original e devolve no
-- desligamento. Nada e destruido -- so desativado -- entao ligar e desligar nao
-- deixa o mapa mutilado.
--
-- Um objeto que nasce DEPOIS e pego por evento (Workspace/Lighting
-- .DescendantAdded), nao por varredura periodica: a varredura completa roda UMA
-- vez, no ligar; daqui pra frente o jogo avisa o que apareceu. Assim nao ha
-- caminhada do mapa inteiro repetida (que num mapa de Blox Fruits custaria
-- justamente os quadros que o boost tenta devolver) nem custo por frame.
--
-- Nao toca em nada que a jogabilidade use: nao remove parts do mapa, nao mexe em
-- NPC, nao mexe em remote, nao muda a fisica. So o que e puramente visual.

local Feature = {}
Feature.__index = Feature

-- As classes de EFEITO DECORATIVO escondidas. Sao coisas que so desenham (nao
-- tem colisao, nao carregam logica de jogo) e todas expoem `Enabled`, entao
-- esconder so devolve FPS.
local EFFECT_CLASSES = {
    "ParticleEmitter", "Trail", "Beam", "Smoke", "Fire", "Sparkles",
    "PointLight", "SpotLight", "SurfaceLight",
}

-- As classes de efeito por classe -- um Set para a checagem por instance ser
-- O(1) em vez de varrer a lista a cada objeto do mapa.
local EFFECT_SET = {}
for _, className in ipairs(EFFECT_CLASSES) do EFFECT_SET[className] = true end

-- Os efeitos de pos-processamento da Lighting: cada um custa um passe na GPU.
-- Desativar devolve quadro.
local POST_FX_CLASSES = {
    "BlurEffect", "SunRaysEffect", "BloomEffect", "DepthOfFieldEffect",
    "ColorCorrectionEffect",
}

local POST_FX_SET = {}
for _, className in ipairs(POST_FX_CLASSES) do POST_FX_SET[className] = true end

-- Guarda um valor original so UMA vez por instance (idempotente: rodar de novo
-- sobre o mesmo alvo nao empilha).
local function remember(map, instance, value)
    if map[instance] == nil then map[instance] = value end
end

-- Um objeto nasceu (ou a Lighting mudou): se ele for de uma classe que a feature
-- desliga, aplica agora. Este e o caminho que pega efeitos NOVOS sem varrer o
-- mapa inteiro de tempos em tempos -- a varredura completa roda uma vez so, no
-- ligar, e daqui pra frente o jogo avisa o que nasceu.
function Feature:_OnDescendantAdded(item)
    if not self.BoostOn then return end
    if type(item) ~= "table" and type(item) ~= "userdata" then return end
    local ok, className = pcall(function() return item.ClassName end)
    if not ok then return end
    if EFFECT_SET[className] then
        self:_DisableEffect(item)
    elseif POST_FX_SET[className] then
        self:_DisablePostFx(item)
    else
        -- Part nova: tira a sombra dela tambem (o sol nao projeta mais). IsA
        -- cobre toda subclasse de BasePart de uma vez (Wedge, Truss, Mesh...).
        local okPart, isPart = pcall(function() return item:IsA("BasePart") end)
        if okPart and isPart and item.CastShadow then
            remember(self.SavedShadowParts, item, item.CastShadow)
            pcall(function() item.CastShadow = false end)
        end
    end
end

-- Desliga UM efeito decorativo (Enabled = false), guardando o original. Usado
-- pela varredura inicial e pelo DescendantAdded.
function Feature:_DisableEffect(item)
    if item.Enabled == nil then return end
    remember(self.SavedEffects, item, item.Enabled)
    pcall(function() item.Enabled = false end)
end

-- Desliga UM efeito de pos-processamento da Lighting.
function Feature:_DisablePostFx(item)
    remember(self.SavedPostFx, item, item.Enabled)
    pcall(function() item.Enabled = false end)
end

function Feature.new(options)
    options = options or {}
    local self = setmetatable({}, Feature)
    self.Enabled = false
    -- As conexoes do DescendantAdded (Workspace e Lighting) enquanto o boost
    -- esta ligado. Sao poucas e de vida curta: nascem no SetBoost(true) e morrem
    -- no SetBoost(false) -- nao ha nada escutando com o boost desligado.
    self.Connections = {}
    -- O estado que a feature mexeu, pra devolver exatamente como estava. Os
    -- mapas guardam instance -> valor original; restauram no disable.
    self.SavedShadowParts = {}   -- BasePart -> CastShadow original
    self.SavedEffects = {}       -- efeito -> Enabled original
    self.SavedPostFx = {}        -- efeito de Lighting -> Enabled original
    self.SavedLighting = {}      -- propriedades soltas (GlobalShadows, agua)
    -- O que esta ligado (a unica alavanca).
    self.BoostOn = false
    return self
end

-- --- Alavancas -------------------------------------------------------------
-- Cada uma e idempotente: chamar de novo com o mesmo alvo nao empilha (o valor
-- original so e guardado na primeira vez).

-- 1) Sombras dinamicas: o maior custo isolado do render. Lighting.GlobalShadows
--    desliga as sombras globais; o CastShadow por part desliga as sombras que o
--    sol projeta daquela peca.
function Feature:_ApplyShadows()
    if type(Lighting.GlobalShadows) == "boolean" then
        remember(self.SavedLighting, "GlobalShadows", Lighting.GlobalShadows)
        pcall(function() Lighting.GlobalShadows = false end)
    end
    local ok, descendants = pcall(function() return Workspace:GetDescendants() end)
    if not ok or type(descendants) ~= "table" then return end
    for _, item in ipairs(descendants) do
        if item:IsA("BasePart") and item.CastShadow then
            remember(self.SavedShadowParts, item, item.CastShadow)
            pcall(function() item.CastShadow = false end)
        end
    end
end

-- 2) Efeitos decorativos (particulas, beams, fogo, fumaca, luzes). Esconder
--    devolve o custo de desenho deles sem tocar em nada de logica.
function Feature:_ApplyEffects()
    local ok, descendants = pcall(function() return Workspace:GetDescendants() end)
    if not ok or type(descendants) ~= "table" then return end
    for _, item in ipairs(descendants) do
        if type(item) == "table" or type(item) == "userdata" then
            local okClass, className = pcall(function() return item.ClassName end)
            if okClass and EFFECT_SET[className] then self:_DisableEffect(item) end
        end
    end
end

-- 3) Pos-processamento da Lighting (bloom, raio de sol, desfoque...). Cada um e
--    um passe de tela cheia na GPU.
function Feature:_ApplyPostFx()
    local ok, children = pcall(function() return Lighting:GetChildren() end)
    if not ok or type(children) ~= "table" then return end
    for _, child in ipairs(children) do
        if type(child) == "table" or type(child) == "userdata" then
            local okClass, className = pcall(function() return child.ClassName end)
            if okClass and POST_FX_SET[className] then self:_DisablePostFx(child) end
        end
    end
end

-- 4) Terreno: a agua com reflexo e a decoracao sao caras. Reduz o que da sem
--    remover a agua (que a jogabilidade usa pra nadar).
function Feature:_ApplyTerrain()
    if not Terrain then return end
    pcall(function()
        if type(Terrain.WaterReflectance) == "number" then
            remember(self.SavedLighting, "WaterReflectance", Terrain.WaterReflectance)
            Terrain.WaterReflectance = 0
        end
        if type(Terrain.WaterWaveSize) == "number" then
            remember(self.SavedLighting, "WaterWaveSize", Terrain.WaterWaveSize)
            Terrain.WaterWaveSize = 0
        end
        if type(Terrain.Decoration) == "boolean" then
            remember(self.SavedLighting, "TerrainDecoration", Terrain.Decoration)
            Terrain.Decoration = false
        end
    end)
end

function Feature:_ApplyAll()
    self:_ApplyShadows()
    self:_ApplyEffects()
    self:_ApplyPostFx()
    self:_ApplyTerrain()
end

-- --- Reversao --------------------------------------------------------------

-- Devolve tudo que foi mexido e zera os mapas. So reescreve em quem ainda esta
-- vivo (Parent); quem morreu no meio do caminho nao precisa (e nao da) voltar.
function Feature:_RestoreAll()
    for item, value in pairs(self.SavedShadowParts) do
        if item.Parent then pcall(function() item.CastShadow = value end) end
    end
    for item, value in pairs(self.SavedEffects) do
        if item.Parent then pcall(function() item.Enabled = value end) end
    end
    for item, value in pairs(self.SavedPostFx) do
        if item.Parent then pcall(function() item.Enabled = value end) end
    end
    pcall(function()
        if self.SavedLighting.GlobalShadows ~= nil then Lighting.GlobalShadows = self.SavedLighting.GlobalShadows end
        if self.SavedLighting.WaterReflectance ~= nil and Terrain then Terrain.WaterReflectance = self.SavedLighting.WaterReflectance end
        if self.SavedLighting.WaterWaveSize ~= nil and Terrain then Terrain.WaterWaveSize = self.SavedLighting.WaterWaveSize end
        if self.SavedLighting.TerrainDecoration ~= nil and Terrain then Terrain.Decoration = self.SavedLighting.TerrainDecoration end
    end)
    self.SavedShadowParts = {}
    self.SavedEffects = {}
    self.SavedPostFx = {}
    self.SavedLighting = {}
end

-- --- Controles -------------------------------------------------------------

-- Escuta o que nasce no Workspace e na Lighting enquanto o boost esta ligado. E
-- o que substitui a varredura periodica: o jogo avisa o objeto novo e a feature
-- desliga na hora, sem caminhar o mapa inteiro de novo.
function Feature:_Listen()
    if self.Connections[1] then return end
    local okWs, wsConn = pcall(function()
        return Workspace.DescendantAdded:Connect(function(item) self:_OnDescendantAdded(item) end)
    end)
    if okWs then self.Connections[#self.Connections + 1] = wsConn end
    local okLight, lightConn = pcall(function()
        return Lighting.DescendantAdded:Connect(function(item) self:_OnDescendantAdded(item) end)
    end)
    if okLight then self.Connections[#self.Connections + 1] = lightConn end
end

function Feature:_Unlisten()
    for _, connection in ipairs(self.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    self.Connections = {}
end

-- O toggle do FPS boost. Ligado: aplica tudo uma vez e passa a escutar o que
-- nasce depois. Desligado: para de escutar e devolve o mapa ao estado original.
function Feature:SetBoost(on)
    on = on == true
    if on == self.BoostOn then return true end
    self.BoostOn = on
    if not on then
        self:_Unlisten()
        self:_RestoreAll()
        return true
    end
    self:_ApplyAll()
    self:_Listen()
    return true
end

-- --- Ciclo de vida ---------------------------------------------------------

function Feature:Enable()
    if self.Enabled then return true end
    self.Enabled = true
    return true
end

function Feature:Disable()
    self.Enabled = false
    self:SetBoost(false)
    return true
end

function Feature:IsEnabled()
    return self.Enabled == true
end

function Feature:Destroy()
    self:SetBoost(false)
    self.Enabled = false
    self:_Unlisten()
end

return Feature
