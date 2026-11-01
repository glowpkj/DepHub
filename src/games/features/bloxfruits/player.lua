local game = game
local pcall = pcall
local tonumber = tonumber

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Player -- a aba so do LOCAL PLAYER. Nada de ESP de outros, nada de mexer no
-- mundo: sao os atributos do proprio character que o jogador controla.
--
-- Tudo aqui vive em ATRIBUTOS do character (o jogo guarda assim):
--   * SpeedMultiplier -- o multiplicador de velocidade (padrao do jogo: 2.3).
--   * UnbreakableAll -- o toggle que fica ligado (o jogo pode tentar voltar pra
--     false; a feature re-aplica, como o flashstep fazia).
--   * WaterWalking   -- andar sobre a agua.
--   * FlashstepCooldown -- 0 = o flashstep esta pronto; 1 = com cooldown.
-- E o Stun nao e atributo: e um NumberValue filho do character. O jogador quer
-- ele SEMPRE em 0 -- no 1 ele fica stunado. A feature re-escreve pra 0 quando o
-- jogo mexer (Changed), e re-cria se o character novo vier sem.
--
-- NAO mexe nos cooldowns de skill do jogo (MeleeZ/Sword/SwordV/X/Z) -- o usuario
-- deixou claro que aquilo e padrao do jogo e nao deve ser tocado.
--
-- Gate de verdade: cada controle liga/desliga o proprio efeito, e o Disable
-- devolve o character ao estado neutro (attributos que a feature setou sao
-- limpos). O SpeedMultiplier e o FlashstepCooldown sao SLIDERS: o valor vale
-- sempre que o slider mexer, e o delete limpa.
--
-- Self-contained: faz os proprios game:GetService e publica new()/Enable()/
-- Disable()/Destroy(). Sem UI: quem monta o painel e o backend.

local Feature = {}
Feature.__index = Feature

-- Os limites dos sliders, como o usuario pediu.
--   * SpeedMultiplier: padrao do jogo 2.3. O slider vai de 0 a 10 (o jogo aceita
--     fracionario; 2.3 e o normal, 1.0 seria o passo base).
--   * FlashstepCooldown: 0 = pronto (sem cooldown), 1 = com cooldown. So esses
--     dois estados importam, entao o slider e 0..1.
Feature.MIN_SPEED = 0
Feature.MAX_SPEED = 10
Feature.DEFAULT_SPEED = 2.3
Feature.MIN_FLASHSTEP = 0
Feature.MAX_FLASHSTEP = 1
Feature.DEFAULT_FLASHSTEP = 0

-- O nome do NumberValue do stun, filho do character.
local STUN_NAME = "Stun"

function Feature.new(options)
    options = options or {}
    local self = setmetatable({}, Feature)
    self.Enabled = false
    -- O que cada controle quer. Desligado, o valor nao e tocado (o jogo decide).
    self.SpeedOn = false
    self.Speed = tonumber(options.speed) or Feature.DEFAULT_SPEED
    self.UnbreakableOn = false
    self.WaterWalkingOn = false
    -- O FlashstepCooldown so e aplicado quando o usuario mexe no slider; ate la
    -- fica desligado e nao toca em nada (nao zera o do jogo so por abrir o painel).
    self.FlashstepOn = false
    self.FlashstepCooldown = tonumber(options.flashstep) or Feature.DEFAULT_FLASHSTEP
    -- O stun sempre 0: enquanto ligado, a feature re-escreve o NumberValue.
    self.StunOn = true
    -- Levantado enquanto a PROPRIE feature escreve um atributo/value: os vigias
    -- de "manter ligado" so re-aplicam quando o JOGO tenta desfazer a escolha.
    self._SelfWrite = false
    -- O Stun cujo Changed ja esta conectado (estado fora da instance).
    self._StunWatched = nil
    -- O character atual + as conexoes dele (re-bind no respawn).
    self.Character = nil
    self.Connections = {}
    self.RespawnConnection = nil
    self.LastStatus = "idle"
    return self
end

-- O character vivo do local player, ou nil.
local function myCharacter()
    return LocalPlayer and LocalPlayer.Character
end

-- --- Aplicacao dos valores no character -------------------------------------

-- Escreve os atributos no character conforme o estado dos controles. O que esta
-- desligado NAO e tocado -- o valor do jogo fica como esta.
function Feature:_Apply(character)
    if not character or not character.Parent then return end
    -- Guarda levantado durante toda a escrita: os vigias de manter-ligado (e o
    -- do Stun) nao devem re-agir as escritas da propria feature, so as do jogo.
    self._SelfWrite = true
    pcall(function()
        if self.SpeedOn then
            character:SetAttribute("SpeedMultiplier", self.Speed)
        end
        if self.UnbreakableOn then
            character:SetAttribute("UnbreakableAll", true)
        end
        if self.WaterWalkingOn then
            character:SetAttribute("WaterWalking", true)
        end
        if self.FlashstepOn then
            character:SetAttribute("FlashstepCooldown", self.FlashstepCooldown)
        end
    end)
    self:_ApplyStun(character)
    self._SelfWrite = false
end

-- O Stun e um NumberValue filho do character: mantem em 0. Se o character veio
-- sem o Value (ou o jogo o removeu), cria um.
function Feature:_ApplyStun(character)
    if not self.StunOn or not character then return end
    local stun = character:FindFirstChild(STUN_NAME)
    if not stun then
        local ok, created = pcall(function()
            local value = Instance.new("NumberValue")
            value.Name = STUN_NAME
            value.Value = 0
            value.Parent = character
            return value
        end)
        if ok and created then self:_WatchStun(created) end
        return
    end
    if stun:IsA("NumberValue") and stun.Value ~= 0 then
        pcall(function() stun.Value = 0 end)
    end
    self:_WatchStun(stun)
end

-- Reconecta o Changed do Stun uma vez por instance. O estado fica num campo do
-- proprio objeto (nao na instance: escrever campo numa Instance real levanta
-- "StunWatched is not a valid member of NumberValue").
function Feature:_WatchStun(stun)
    if self._StunWatched == stun then return end
    self._StunWatched = stun
    self.Connections[#self.Connections + 1] = stun.Changed:Connect(function()
        -- O guarda corta o eco da propria escrita (que dispara Changed de novo);
        -- so a escrita do jogo (que nao vem com o guarda) e corrigida pra 0.
        if self._SelfWrite then return end
        if self.StunOn and stun.Parent and stun.Value ~= 0 then
            self._SelfWrite = true
            pcall(function() stun.Value = 0 end)
            self._SelfWrite = false
        end
    end)
end

-- Remove o que a feature setou, devolvendo o character ao estado do jogo. So
-- limpa o que ESTA feature ligou (nao mexe no que o usuario/jogo tinha).
-- Escreve com o guarda levantado: o vigia de "manter ligado" nao pode re-agir a
-- escrita de limpeza da propria feature, senao ela desfaz o desligamento.
function Feature:_Clear(character)
    if not character then return end
    self._SelfWrite = true
    pcall(function()
        if self.SpeedOn then character:SetAttribute("SpeedMultiplier", Feature.DEFAULT_SPEED) end
        if self.FlashstepOn then character:SetAttribute("FlashstepCooldown", Feature.DEFAULT_FLASHSTEP) end
        if self.UnbreakableOn then character:SetAttribute("UnbreakableAll", false) end
        if self.WaterWalkingOn then character:SetAttribute("WaterWalking", false) end
    end)
    self._SelfWrite = false
end

-- --- Re-bind no respawn -----------------------------------------------------

function Feature:_Bind(character)
    self:_Unbind()
    self.Character = character
    if not character then return end
    -- Re-aplica assim que o character novo aparece. Espera o Humanoid existir
    -- nao e necessario: os atributos e o Stun podem ser setados de imediato.
    self:_Apply(character)
    self.Connections[#self.Connections + 1] = character:GetAttributeChangedSignal("UnbreakableAll"):Connect(function()
        if self._SelfWrite then return end
        if self.UnbreakableOn and character:GetAttribute("UnbreakableAll") ~= true then
            pcall(function() character:SetAttribute("UnbreakableAll", true) end)
        end
    end)
    self.Connections[#self.Connections + 1] = character:GetAttributeChangedSignal("WaterWalking"):Connect(function()
        if self._SelfWrite then return end
        if self.WaterWalkingOn and character:GetAttribute("WaterWalking") ~= true then
            pcall(function() character:SetAttribute("WaterWalking", true) end)
        end
    end)
end

function Feature:_Unbind()
    for _, connection in ipairs(self.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    self.Connections = {}
    self.Character = nil
    self._StunWatched = nil
end

-- --- Controles (chamados pelo backend) --------------------------------------

function Feature:SetSpeed(value)
    value = tonumber(value)
    if not value then return false end
    self.Speed = math.clamp(value, Feature.MIN_SPEED, Feature.MAX_SPEED)
    self.SpeedOn = true
    self:_Apply(self.Character or myCharacter())
    return true
end

function Feature:SetUnbreakable(on)
    self.UnbreakableOn = on == true
    local character = self.Character or myCharacter()
    if not character then return true end
    -- Guarda levantado: se for pra DESLIGAR, a escrita nao pode ser vista pelo
    -- vigia de manter-ligado e re-aplicada.
    self._SelfWrite = true
    pcall(function() character:SetAttribute("UnbreakableAll", self.UnbreakableOn) end)
    self._SelfWrite = false
    return true
end

function Feature:SetWaterWalking(on)
    self.WaterWalkingOn = on == true
    local character = self.Character or myCharacter()
    if not character then return true end
    self._SelfWrite = true
    pcall(function() character:SetAttribute("WaterWalking", self.WaterWalkingOn) end)
    self._SelfWrite = false
    return true
end

function Feature:SetFlashstep(value)
    value = tonumber(value)
    if not value then return false end
    self.FlashstepCooldown = math.clamp(value, Feature.MIN_FLASHSTEP, Feature.MAX_FLASHSTEP)
    self.FlashstepOn = true
    self:_Apply(self.Character or myCharacter())
    return true
end

-- --- Ciclo de vida ----------------------------------------------------------

function Feature:Enable()
    if self.Enabled then return true end
    self.Enabled = true
    self.LastStatus = "idle"

    self:_Bind(myCharacter())

    -- Re-bind no respawn: o character novo nao tem os atributos da sessao antiga.
    self.RespawnConnection = LocalPlayer.CharacterAdded:Connect(function(character)
        if self.Enabled then self:_Bind(character) end
    end)

    return true
end

function Feature:Disable()
    self.Enabled = false
    self:_Clear(self.Character or myCharacter())
    self:_Unbind()
    if self.RespawnConnection then
        pcall(function() self.RespawnConnection:Disconnect() end)
        self.RespawnConnection = nil
    end
    return true
end

function Feature:IsEnabled()
    return self.Enabled == true
end

function Feature:Destroy()
    self:Disable()
end

return Feature
