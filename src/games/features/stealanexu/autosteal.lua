-- Auto Steal Exu -- rouba os Exu de um Terreiro em loop, por teleporte
-- instantaneo.
--
-- O JOGO (como o usuario descreveu, e o que este modulo assume):
--
--   * workspace.Map.Terreiros.TerreiroN -- as fases, N = 1..9. Cada uma tem uma
--     pasta .Nests com Nest1..Nest8: o LUGAR onde um Exu esta (a POSICAO).
--   * workspace.Runtime -- os MODELOS dos Exu, um por Exu do mapa. O prompt
--     vive em cada modelo: Model.Root.ProximityPrompt. E de la que se PEGA o
--     prompt; o Nest so da a posicao.
--   * workspace.Map.Pens.PenX -- as bases, uma por jogador. Cada base tem o
--     atributo "Owner" (o UserId do dono) e um BadgeAnchor (o ponto onde o
--     jogador "guarda" o Exu). A NUMERACAO Pen1/Pen2 muda por servidor, entao a
--     base certa so se acha pelo atributo Owner == LocalPlayer.UserId.

local game = game
local task = task
local type = type
local pcall = pcall
local tostring = tostring
local math = math

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local AutoSteal = {}
AutoSteal.__index = AutoSteal

-- Quanto esperar depois de voltar pra base (pedido do usuario: 0.5s), e quanto
-- esperar apos disparar o prompt antes de considerar o passo terminado.
local BASE_WAIT = 0.5
local PROMPT_WAIT = 0.15

-- Steal All (botao unico): o wait entre um Exu e outro, e a ordem dos terreiros
-- (do 9 pro 1 -- o usuario pediu "comeca do 9 ate o 1"). Aumentamos a
-- MaxActivationDistance do prompt na hora de disparar pra tentar pegar de longe,
-- e devolvemos o valor original depois (nada de residuo).
local ALL_WAIT = 0.25
local ALL_TERREIRO_FROM = 9
local ALL_TERREIRO_TO = 1

-- O numero de terreiros e de nests por terreiro. O jogo usa Terreiro1..9 e
-- Nest1..8; mantemos como constantes para o dropdown e a varredura sairem daqui.
AutoSteal.TERREIRO_COUNT = 9
AutoSteal.NEST_COUNT = 8

-- Os rotulos do dropdown de terreiro (Terreiro1..Terreiro9).
function AutoSteal.terreiros()
    local list = {}
    for index = 1, AutoSteal.TERREIRO_COUNT do
        list[#list + 1] = "Terreiro" .. index
    end
    return list
end

function AutoSteal.new(options)
    options = options or {}
    local self = setmetatable({}, AutoSteal)
    self.Enabled = false
    self.Thread = nil
    self.Terreiro = options.terreiro or "Terreiro1"
    self.LastError = nil
    self.LastStatus = "idle"
    self.Destroyed = false
    -- Steal All: uma passada unica (botao). AllThread guarda a thread viva pra
    -- nao deixar duas passadas rodarem juntas.
    self.AllThread = nil
    -- Teleporte instantaneo: o jogo nao tem anti-cheat de posicao, entao o
    -- destino e escrito direto no HumanoidRootPart.CFrame (sem tween, sem voo).
    self.Instant = true
    return self
end

-- --- Helpers de mundo -----------------------------------------------------

local function mapFolder()
    local map = Workspace:FindFirstChild("Map")
    return map
end

-- A minha base: varre Pens e compara o atributo Owner com o MEU UserId. Nao usa
-- Pen1/Pen2 fixo -- a numeracao muda por servidor -- e funciona para quem
-- receber o script (UserId de cada um), nao so para mim.
function AutoSteal:MyPen()
    local map = mapFolder()
    if not map then return nil end
    local pens = map:FindFirstChild("Pens")
    if not pens then return nil end
    local myUserId = LocalPlayer and LocalPlayer.UserId
    if not myUserId then return nil end
    -- Owner pode vir como number ou string dependendo do jogo; compara como
    -- string para nao escapar por tipo.
    local wanted = tostring(myUserId)
    for _, pen in ipairs(pens:GetChildren()) do
        local owner = pen:GetAttribute("Owner")
        if owner ~= nil and tostring(owner) == wanted then return pen end
    end
    return nil
end

-- O ponto de guardar da minha base (BadgeAnchor). Devolve a CFrame, ou nil.
function AutoSteal:PenAnchor()
    local pen = self:MyPen()
    if not pen then return nil end
    local anchor = pen:FindFirstChild("BadgeAnchor")
    if not anchor then return nil end
    if anchor:IsA("BasePart") then return anchor.CFrame end
    if anchor:IsA("Model") and anchor.PrimaryPart then return anchor.PrimaryPart.CFrame end
    return nil
end

-- A pasta de Nests do terreiro pedido (workspace.Map.Terreiros.<terreiro>.Nests).
function AutoSteal:TerreiroNests(name)
    local map = mapFolder()
    if not map then return nil end
    local terreiros = map:FindFirstChild("Terreiros")
    if not terreiros then return nil end
    local terreiro = terreiros:FindFirstChild(self.Terreiro or name or "")
    if not terreiro then return nil end
    return terreiro:FindFirstChild("Nests")
end

-- Onde roubar: a posicao do Nest. Nest e um Model ou uma Part; devolve a CFrame.
local function nestPosition(nest)
    if not nest then return nil end
    if nest:IsA("BasePart") then return nest.CFrame end
    if nest:IsA("Model") then
        if nest.PrimaryPart then return nest.PrimaryPart.CFrame end
        local ok, pivot = pcall(function() return nest:GetPivot() end)
        if ok and pivot then return pivot end
    end
    return nil
end

-- O Exu do Runtime mais perto de uma posicao. Os modelos no Runtime sao todos
-- iguais (mesmo nome), entao a associacao Nest -> Exu e por PROXIMIDADE: chega
-- perto, pega o do Runtime que esta ali.
local function nearestRuntimeExu(position)
    local runtime = Workspace:FindFirstChild("Runtime")
    if not runtime then return nil, nil end
    local best, bestPart, bestDistance = nil, nil, math.huge
    for _, model in ipairs(runtime:GetChildren()) do
        -- O prompt vive em Model.Root. Sem Root/Prompt nao e um Exu roubavel.
        local root = model:FindFirstChild("Root")
        local prompt = root and root:FindFirstChild("ProximityPrompt")
        if prompt then
            local origin
            if root:IsA("BasePart") then origin = root.Position
            elseif model:IsA("Model") and model.PrimaryPart then origin = model.PrimaryPart.Position
            elseif model:IsA("BasePart") then origin = model.Position end
            if origin then
                local distance = (origin - position).Magnitude
                if distance < bestDistance then
                    best, bestPart, bestDistance = model, prompt, distance
                end
            end
        end
    end
    return best, bestPart
end

-- --- Teleporte instantaneo ------------------------------------------------

function AutoSteal:_root()
    local character = LocalPlayer and LocalPlayer.Character
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart")
end

-- Teleporte DIRETO: escreve a CFrame no HumanoidRootPart na hora. Zera as
-- velocidades para o personagem nao seguir escorregando do voo anterior.
function AutoSteal:TeleportTo(cframe)
    if not cframe then return false end
    local root = self:_root()
    if not root then return false end
    pcall(function()
        root.CFrame = cframe
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
    return true
end

-- --- O passo de roubo -----------------------------------------------------

-- Um passo: teleporta pro Nest, acha o Exu do Runtime ali, dispara o prompt,
-- espera, e volta pra base. Devolve true se chegou a disparar o prompt.
function AutoSteal:StealOnce()
    local root = self:_root()
    if not root then self.LastError = "sem personagem"; return false end

    local anchor = self:PenAnchor()
    if not anchor then self.LastError = "base nao encontrada (Owner)"; return false end

    local nests = self:TerreiroNests()
    if not nests then self.LastError = "terreiro nao encontrado: " .. tostring(self.Terreiro); return false end

    -- Varre os Nests do terreiro, na ordem, e rouba o primeiro que tiver um Exu.
    -- Desligar o toggle cancela a thread inteira (SetEnabled), entao este passo
    -- nao precisa se vigiar: ele so faz uma passada completa.
    local fired = false
    for index = 1, AutoSteal.NEST_COUNT do
        local nest = nests:FindFirstChild("Nest" .. index)
        local target = nest and nestPosition(nest)
        if target then
            -- 1) Teleporta instantaneo ate o Nest.
            self:TeleportTo(target)
            task.wait()
            -- 2) O Exu que esta ali (o mais proximo no Runtime) -> o prompt dele.
            local _, prompt = nearestRuntimeExu(target.Position)
            if prompt then
                local fire = fireproximityprompt
                if type(fire) == "function" then
                    pcall(fire, prompt)
                    fired = true
                end
            end
            task.wait(PROMPT_WAIT)
        end
    end

    -- 3) Volta pra base e guarda. Sempre volta, mesmo se nenhum prompt disparou,
    -- para o loop nao ficar parado longe da base. O 0.5s do ciclo fica no _loop.
    self:TeleportTo(anchor)

    self.LastStatus = fired and "stealing" or "no targets"
    return fired
end

-- Dispara um ProximityPrompt o mais "de longe" possivel: sobe a
-- MaxActivationDistance na hora (o jogo valida 6.5 studs por padrao) e devolve o
-- valor original em seguida -- sem residuo. Nao garante que o servidor aceite
-- (isso so o jogo diz), por isso quem chama tambem pisca-o-teleporte ate o Exu.
local function firePromptWide(prompt)
    local fire = fireproximityprompt
    if type(fire) ~= "function" then return false end
    local original = prompt.MaxActivationDistance
    pcall(function() prompt.MaxActivationDistance = 1e9 end)
    local ok = pcall(fire, prompt)
    pcall(function() prompt.MaxActivationDistance = original end)
    return ok
end

-- --- Steal All (botao) ----------------------------------------------------

-- Uma passada por TODOS os Exus: Terreiro9 -> Terreiro1 (o usuario pediu essa
-- ordem), e em cada Terreiro os Nest1..Nest8. Para cada Exu: tenta disparar de
-- longe e, pra garantir contra a validacao de distancia do servidor, pisca o
-- teleporte ate o Nest, dispara, e segue. No fim volta pro CFrame de origem (a
-- sua base, de onde voce clicou).
function AutoSteal:StealAll()
    local root = self:_root()
    if not root then self.LastError = "sem personagem"; return false end

    -- CFrame de origem: e pra onde voltamos no fim (a base, no caso).
    local okOrigin, origin = pcall(function() return root.CFrame end)
    if not okOrigin or not origin then origin = nil end

    local map = mapFolder()
    local terreiros = map and map:FindFirstChild("Terreiros")
    if not terreiros then self.LastError = "Terreiros nao encontrados"; return false end

    self.LastStatus = "stealing all"
    self.AllError = nil
    local fired, skipped = 0, 0

    for terreiroIndex = ALL_TERREIRO_FROM, ALL_TERREIRO_TO, -1 do
        local terreiro = terreiros:FindFirstChild("Terreiro" .. terreiroIndex)
        local nests = terreiro and terreiro:FindFirstChild("Nests")
        if nests then
            for nestIndex = 1, AutoSteal.NEST_COUNT do
                local nest = nests:FindFirstChild("Nest" .. nestIndex)
                local target = nest and nestPosition(nest)
                if target then
                    -- O Exu do Runtime nesse Nest -> o prompt dele.
                    local _, prompt = nearestRuntimeExu(target.Position)
                    if prompt then
                        -- 1) tenta de longe; 2) pisca ate o Nest e dispara de novo
                        --    (cobre o jogo que revalida a distancia no servidor).
                        firePromptWide(prompt)
                        self:TeleportTo(target)
                        task.wait()
                        firePromptWide(prompt)
                        fired = fired + 1
                    else
                        skipped = skipped + 1
                    end
                    task.wait(ALL_WAIT)
                end
            end
        end
    end

    -- Volta pra origem (a base). Sem isso o personagem fica no ultimo Nest.
    if origin then self:TeleportTo(origin) end

    self.LastStatus = "idle"
    self.LastError = nil
    self.LastCounts = {fired = fired, skipped = skipped}
    return fired > 0, fired
end

-- O botao chama isto: sobe a passada numa thread propria pra nao travar o
-- clique. Uma passada por vez -- se ja tem uma rodando, ignora o clique.
function AutoSteal:StartStealAll()
    if self.Destroyed or self.AllThread then return false end
    self.AllThread = task.spawn(function()
        local ok, err = pcall(function() return self:StealAll() end)
        if not ok then self.LastError = tostring(err) end
        self.AllThread = nil
    end)
    return true
end

-- --- Ciclo de vida --------------------------------------------------------

function AutoSteal:_loop()
    while self.Enabled do
        local done, result = pcall(function() return self:StealOnce() end)
        if not done then self.LastError = tostring(result) end
        -- Um unico 0.5s por ciclo, tenha o passo roubado ou falhado: sem isso, um
        -- passo que sai cedo (sem base, sem personagem) giraria em falso.
        task.wait(BASE_WAIT)
    end
    self.Thread = nil
end

function AutoSteal:SetEnabled(on)
    self.Enabled = on == true
    if not self.Enabled then
        if self.Thread then pcall(task.cancel, self.Thread); self.Thread = nil end
        self.LastStatus = "idle"
        return true
    end
    -- Sobe o loop so uma vez. Se ja esta rodando (toggle re-ligado), nao duplica.
    if not self.Thread then
        self.LastError = nil
        self.Thread = task.spawn(function() self:_loop() end)
    end
    return true
end

function AutoSteal:IsEnabled()
    return self.Enabled == true
end

function AutoSteal:SetTerreiro(name)
    self.Terreiro = tostring(name or "Terreiro1")
    return true
end

function AutoSteal:Destroy()
    self.Destroyed = true
    self:SetEnabled(false)
    if self.AllThread then pcall(task.cancel, self.AllThread); self.AllThread = nil end
end

return AutoSteal
