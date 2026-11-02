local game = game
local task = task
local type = type
local pcall = pcall
local tostring = tostring
local workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Fast Attack -- o auto-hit RAPIDO do Blox Fruits, irmao da blade hit.
--
-- E o MESMO mecanismo da blade hit (src/games/features/bloxfruits/bladhits.lua):
-- dispara os remotes do proprio jogo (RE/RegisterAttack + RE/RegisterHit) direto,
-- em todos os alvos no alcance, num laco. A UNICA coisa que muda e' o INTERVALO
-- entre os golpes -- por isso ele fica num modulo proprio em vez de sobrecarregar
-- a blade hit: sao dois TOSTERS separados no painel, com velocidades diferentes.
--
--   * Blade hits  -> MinInterval = 0.05s (o auto-hit continuo de farm/mastery).
--   * Fast Attack -> MinInterval = 0.30s (o golpe ESPACADO de PvP: uma cadencia
--     menos continua, que o usuario quer pra reduzir a assinatura de "morte
--     suspeita" quando bate em player).
--
-- Bate em MOBS e em PLAYERS (Players = true): varre as pastas Enemies/Characters
-- e tambem os outros jogadores dentro do PlayerRange -- igual a blade hit, que
-- tambem liga players. O Fast Attack so nao tem tanto a aceleracao.
--
-- O hitId (4. argumento do RegisterHit) e' o token que o servidor valida: sem ele
-- um hit e' ignorado em conta nova. Le o hitId capturado pelo gancho COMPARTILHADO
-- (options.hook, a infra net-hook) -- o mesmo gancho que a blade hit e o silent
-- aim usam. Sem captura, cai no SetHitId manual; sem nada, manda sem id (o
-- servidor recusa, mas nao explode).
--
-- O LOS (line of sight, opcional) e' o MESMO freio da blade hit: antes de hitar,
-- faz um raycast ate o alvo e pula o que estiver atras de parede.
--
-- Self-contained de proposito: nada do DepHub, nada do adapter OSS. Faz o proprio
-- game:GetService e publica um modulo com new()/Enable()/Disable().

local Feature = {}
Feature.__index = Feature

-- Timing humanizado: varia cada espera pra o loop nao ser perfeitamente
-- periodico. Mesmo jitter da blade hit (25%).
local function jitter(base, spread)
    spread = spread or 0.15
    return task.wait(base * (1 + (math.random() * 2 - 1) * spread))
end

local function alive(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.Health > 0
end

-- A vara de pesca sequestra o gancho do RegisterAttack (os hits param de cair):
-- se ela estiver equipada, tira antes de atacar. Mesmo cuidado da blade hit.
local function isFishingRod(tool)
    if not tool then return false end
    local tip = tool.ToolTip
    if tip and (tostring(tip):find("Fishing") or tostring(tip):find("Rod")) then return true end
    return tool.Name:find("Rod") ~= nil
end

function Feature.new(options)
    options = options or {}
    local self = setmetatable({}, Feature)
    self.Enabled = false
    self.Thread = nil
    self.hits = 0
    -- A UNICA diferenca pra blade hit: o intervalo. 0.30s e' mais LENTO que o
    -- 0.05s da blade hit de proposito -- o golpe espacado e' a cadencia que o
    -- usuario quer pro PvP. Range 300 cobre o pack de mobs; PlayerRange 60 e' o
    -- mesmo alcance de player da blade hit.
    self.MinInterval = options.interval or 0.3
    self.AttackRange = options.range or 300
    self.PlayerRange = options.playerRange or 60
    -- Bate em MOBS e em PLAYERS, como a blade hit (options.players ~= false).
    self.Players = options.players ~= false
    self.EnemiesFolder = options.enemiesFolder ~= false
    self.CharactersFolder = options.charactersFolder ~= false
    self.LastHitId = options.hitId or nil
    -- O gancho COMPARTILHADO de __namecall (injetado por options.hook, a infra
    -- net-hook). De la vem o hitId capturado. Sem ele, a feature ainda funciona
    -- (usa SetHitId ou manda sem id).
    self.Hook = options.hook or nil
    -- O id da inscricao no gancho compartilhado (pra sair no Disable). O
    -- subscriber e' no-op: a feature assina so pra garantir a captura do hitId.
    self.HookId = nil
    -- LOS: quando ligado, nao hita alvo sem linha de visao (raycast).
    self.LosCheck = options.losCheck == true
    self.RegisterAttack = nil
    self.RegisterHit = nil
    return self
end

-- Resolve os remotes. Tenta Modules.Net (caminho atual do jogo) e cai pro Net
-- solto em ReplicatedStorage, que e' o caminho de builds mais antigas. Se o gancho
-- compartilhado ja os resolveu, usa de la (o mesmo remote que a blade hit ve).
function Feature:ResolveRemotes()
    if self.Hook and type(self.Hook.Resolve) == "function" then
        pcall(self.Hook.Resolve, self.Hook)
    end
    if self.Hook and self.Hook.RegisterHit ~= nil then
        self.RegisterAttack = self.Hook.RegisterAttack
        self.RegisterHit = self.Hook.RegisterHit
        return true
    end
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

-- O hitId pro RegisterHit. Prefere o ultimo capturado pelo gancho COMPARTILHADO;
-- cai no SetHitId manual; sem nada, devolve nil (manda sem id).
function Feature:_HitId()
    local hook = self.Hook
    if hook and hook.LastHitId ~= nil then return hook.LastHitId end
    return self.LastHitId
end

-- Tira a vara de pesca do character, se estiver equipada.
function Feature:_EnsureNotRod()
    local character = LocalPlayer and LocalPlayer.Character
    if not character then return end
    local equipped = character:FindFirstChildOfClass("Tool")
    if equipped and isFishingRod(equipped) then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then pcall(function() humanoid:UnequipTools() end) end
    end
end

-- Ha linha de visao clara do meu root ate a part do alvo? Raycast excluindo o
-- meu character e o proprio alvo. Sem params devolve true.
local function losClear(fromPosition, part, ignore)
    if not part then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character, ignore }
    local result = workspace:Raycast(fromPosition, part.Position - fromPosition, params)
    return result == nil
end

function Feature:_root()
    local character = LocalPlayer and LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

-- Junta todo alvo vivo no alcance: mobs das pastas + players (self.Players).
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
                        if not self.LosCheck or losClear(root.Position, part, enemy) then
                            list[#list + 1] = { model = enemy, part = part, distance = distance }
                        end
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
                    if not self.LosCheck or losClear(root.Position, part, character) then
                        list[#list + 1] = { model = character, part = part, distance = distance }
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.distance < b.distance end)
    return list
end

-- Dispara os remotes em todos os alvos no alcance. O combo cicla 1..4 pra as
-- chaves de animacao alternarem do jeito que o jogo espera.
function Feature:AttackNearest(range)
    if not (self.RegisterAttack and self.RegisterHit) then return false end
    self:_EnsureNotRod()
    local targets = self:CollectEnemies(range)
    if #targets == 0 then return false end
    local hitId = self:_HitId()
    self._combo = ((self._combo or 0) % 4) + 1
    pcall(function() self.RegisterAttack:FireServer(0.4, self._combo) end)
    for _, target in ipairs(targets) do
        pcall(function() self.RegisterHit:FireServer(target.part, {}, nil, hitId) end)
    end
    self.hits = self.hits + 1
    return true
end

function Feature:SetHitId(value)
    if value ~= nil then self.LastHitId = value end
end

-- Liga/desliga o LOS (nao hitar sem linha de visao).
function Feature:SetLos(on)
    self.LosCheck = on == true
    return true
end

function Feature:Enable()
    if self.Enabled then return true end
    if not self:ResolveRemotes() then return false end
    self:_SubscribeHook()
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

-- Assina o gancho compartilhado (se injetado). Assinante no-op: o trabalho de
-- captura do hitId e' do proprio gancho.
function Feature:_SubscribeHook()
    if self.HookId ~= nil then return true end
    local hook = self.Hook
    if not hook or type(hook.Add) ~= "function" then return false end
    local id = hook:Add(function() end)
    if id == nil then return false end
    self.HookId = id
    return true
end

function Feature:Disable()
    self.Enabled = false
    if self.Thread then pcall(task.cancel, self.Thread); self.Thread = nil end
    if self.HookId ~= nil and self.Hook and type(self.Hook.Remove) == "function" then
        pcall(self.Hook.Remove, self.Hook, self.HookId)
    end
    self.HookId = nil
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
    self.HookId = nil
end

return Feature
