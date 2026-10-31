local game = game
local task = task
local type = type
local pcall = pcall
local tostring = tostring
local workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Blade Hits -- o auto-hit do Blox Fruits.
--
-- Ele nao usa tool:Activate() nem input: dispara os remotes do proprio jogo
-- (RE/RegisterAttack + RE/RegisterHit) direto, que e o que faz um loop de
-- farm/mastery funcionar de verdade -- o golpe chega no inimigo mesmo quando a
-- animacao do swing nao alcancaria.
--
-- Self-contained de proposito: nada do DepHub, nada do adapter OSS. Faz o
-- proprio game:GetService e publica um modulo com new()/Enable()/Disable().
-- Assim ele pode ser colado em qualquer lugar, ou carregado por um backend
-- (o src/games/bloxfruits.lua faz isso), sem arrastar dependencia junto.

local Feature = {}
Feature.__index = Feature

-- Timing humanizado: varia cada espera pra o loop nao ser perfeitamente
-- periodico. Foi por isso que o original nao usava um wait(0.1) cravado.
local function jitter(base, spread)
    spread = spread or 0.15
    return task.wait(base * (1 + (math.random() * 2 - 1) * spread))
end

local function alive(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.Health > 0
end

function Feature.new(options)
    options = options or {}
    local self = setmetatable({}, Feature)
    self.Enabled = false
    self.Thread = nil
    self.hits = 0
    -- Rate limiting: a parte mais detectavel de um hit por remote. O piso e a
    -- cadencia com jitter sao medidos, nunca um while wait(0.1) sem teto.
    self.MinInterval = options.interval or 0.1
    self.AttackRange = options.range or 100
    self.PlayerRange = options.playerRange or 60
    self.Players = options.players or false
    self.EnemiesFolder = options.enemiesFolder ~= false
    self.CharactersFolder = options.charactersFolder ~= false
    self.LastHitId = options.hitId or nil
    self.RegisterAttack = nil
    self.RegisterHit = nil
    return self
end

-- Resolve os remotes. Tenta Modules.Net (caminho atual do jogo) e cai pro Net
-- solto em ReplicatedStorage, que e o caminho de builds mais antigas.
function Feature:ResolveRemotes()
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    local net = (modules and modules:FindFirstChild("Net")) or ReplicatedStorage:FindFirstChild("Net")
    if not net then return false end
    local attack = net:FindFirstChild("RE/RegisterAttack")
    local hit = net:FindFirstChild("RE/RegisterHit")
    if not attack or not hit then return false end
    self.RegisterAttack = attack
    self.RegisterHit = hit
    return true
end

function Feature:_root()
    local character = LocalPlayer and LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

-- Junta todo alvo vivo no alcance. Varre as pastas que o jogo usa pra mobs e
-- pra outros personagens; players sao opcionais e tem alcance proprio.
function Feature:CollectEnemies(range)
    range = range or self.AttackRange
    local root = self:_root()
    if not root then return {} end
    local list = {}
    local function scan(folder)
        if not folder then return end
        for _, enemy in ipairs(folder:GetChildren()) do
            if enemy ~= LocalPlayer.Character then
                local humanoid = enemy:FindFirstChildOfClass("Humanoid")
                local part = enemy:FindFirstChild("Head") or enemy:FindFirstChild("HumanoidRootPart")
                if humanoid and humanoid.Health > 0 and part then
                    local distance = (part.Position - root.Position).Magnitude
                    if distance <= range then
                        list[#list + 1] = {model = enemy, part = part, distance = distance}
                    end
                end
            end
        end
    end
    if self.EnemiesFolder then scan(workspace:FindFirstChild("Enemies")) end
    if self.CharactersFolder then scan(workspace:FindFirstChild("Characters")) end
    if self.Players then
        for _, player in ipairs(Players:GetPlayers()) do
            local character = player ~= LocalPlayer and player.Character
            local part = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if part and humanoid and humanoid.Health > 0 then
                local distance = (part.Position - root.Position).Magnitude
                if distance <= self.PlayerRange then
                    list[#list + 1] = {model = character, part = part, distance = distance}
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.distance < b.distance end)
    return list
end

-- Dispara os remotes em todos os alvos no alcance. O combo cicla 1..4 pra as
-- chaves de animacao alternarem do jeito que o jogo espera. O 4. argumento do
-- RegisterHit e o hitId validado no servidor: sem ele um hit forjado e ignorado
-- em conta nova, por isso ele vem de LastHitId (ver SetHitId).
function Feature:AttackNearest(range)
    if not (self.RegisterAttack and self.RegisterHit) then return false end
    local targets = self:CollectEnemies(range)
    if #targets == 0 then return false end
    self._combo = ((self._combo or 0) % 4) + 1
    pcall(function() self.RegisterAttack:FireServer(0.4, self._combo) end)
    for _, target in ipairs(targets) do
        pcall(function() self.RegisterHit:FireServer(target.part, {}, nil, self.LastHitId) end)
    end
    self.hits = self.hits + 1
    return true
end

function Feature:SetHitId(value)
    if value ~= nil then self.LastHitId = value end
end

function Feature:Enable()
    if self.Enabled then return true end
    if not self:ResolveRemotes() then return false end
    self.Enabled = true
    self.Thread = task.spawn(function()
        while self.Enabled do
            if alive(LocalPlayer.Character) then pcall(function() self:AttackNearest() end) end
            jitter(self.MinInterval, 0.25)
        end
        self.Thread = nil
    end)
    return true
end

function Feature:Disable()
    self.Enabled = false
    if self.Thread then pcall(task.cancel, self.Thread); self.Thread = nil end
    return true
end

function Feature:SetRange(value)
    value = tonumber(value)
    if not value or value <= 0 then return false end
    self.AttackRange = value
    return true
end

function Feature:SetInterval(value)
    value = tonumber(value)
    if not value or value <= 0 then return false end
    self.MinInterval = value
    return true
end

function Feature:IsEnabled() return self.Enabled end

function Feature:Destroy()
    self:Disable()
    self.RegisterAttack = nil
    self.RegisterHit = nil
end

return Feature
