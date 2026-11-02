-- Auto Steal Exu -- rouba os Exu por teleporte instantaneo, com noclip e o
-- personagem parado no ar (ancorado) pra nao bugar dentro do cenario.
--
-- O JOGO (o que este modulo assume):
--
--   * workspace.Map.Terreiros.TerreiroN -- as fases, N = 1..9. Cada uma tem uma
--     pasta .Nests com Nest1..Nest8: o LUGAR onde um Exu esta (a POSICAO).
--   * workspace.Runtime -- os MODELOS dos Exu. O prompt vive em cada modelo:
--     Model.Root.ProximityPrompt. E de la que se PEGA o prompt; o Nest so da a
--     posicao.
--   * workspace.Map.Pens.PenX -- as bases, uma por jogador. Cada base tem o
--     atributo "Owner" (o UserId do dono) e um BadgeAnchor (o ponto onde o
--     jogador "guarda" o Exu). A NUMERACAO Pen1/Pen2 muda por servidor, entao a
--     base certa so se acha pelo atributo Owner == LocalPlayer.UserId.
--
-- O CICLO de cada roubo (pedido do usuario):
--   1) teleporta pro Exu;
--   2) espera o prompt ficar ativo (no alcance);
--   3) dispara o prompt; se "ativou", teleporta pra base;
--   4) espera VALIDATE_WAIT na base (o jogo confirmar o guardar);
--   5) proximo Exu.
--
-- Enquanto roda, o personagem fica ANCORADO no ar e SEM colisao (noclip): sem
-- gravidade, sem colisao, sem fisica brigando com o teleporte. Ao parar, tudo e
-- restaurado (colisao e ancoragem originais).

local game = game
local task = task
local type = type
local pcall = pcall
local tostring = tostring
local math = math
local table = table
local select = select

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local AutoSteal = {}
AutoSteal.__index = AutoSteal

-- TEMPOS (calibraveis). O usuario reclamou que "nao pega os exu, acho que ta mto
-- rapido", entao tudo aqui esta folgado de proposito -- da pra ir apertando
-- conforme o jogo responder.
--
-- Auto Steal Exu (toggle):
--   VALIDATE_WAIT   -- quanto esperar na base depois de disparar (o jogo confirmar
--                      o guardar) antes de ir pro proximo Exu.
--   SETTLE_WAIT     -- quanto esperar parado em cima do Exu depois do teleporte,
--                      pro prompt assentar antes de disparar.
--   PROMPT_TIMEOUT  -- quanto esperar o Triggered do prompt ("ativou").
local VALIDATE_WAIT = 1.5
local SETTLE_WAIT = 0.25
local PROMPT_TIMEOUT = 1.0

-- Steal All (botao): mesma logica, so que mais apertada que o toggle (o usuario
-- quer o botao "um pouco mais forte e rapido"). Ainda assim, folgada o bastante
-- pra o servidor processar.
local ALL_VALIDATE_WAIT = 0.8
local ALL_SETTLE_WAIT = 0.2
local ALL_PROMPT_TIMEOUT = 1.0
-- Um respiro entre um Exu e o proximo, pra nao metralhar o servidor.
local ALL_STEP_GAP = 0.15
local ALL_TERREIRO_FROM = 9
local ALL_TERREIRO_TO = 1

-- O numero de terreiros e de nests por terreiro. O jogo usa Terreiro1..9 e
-- Nest1..8; mantemos como constantes para o dropdown e a varredura sairem daqui.
AutoSteal.TERREIRO_COUNT = 9
AutoSteal.NEST_COUNT = 8

-- --- Debug ----------------------------------------------------------------
-- Log de diagnostico por etapa. Vai pro console (print) e fica guardado em
-- self.DebugLog pra inspecao. Desligavel com AutoSteal.DebugEnabled = false.
AutoSteal.DebugEnabled = true
local DEBUG_TAG = "[StealAnExu]"

-- O env do hub (getgenv/_G), pra publicar o log no Debug do painel quando existir.
local env = type(getgenv) == "function" and getgenv() or _G

local function debugLog(self, ...)
    local parts = {}
    for index = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(index, ...))
    end
    local message = DEBUG_TAG .. " " .. table.concat(parts, " ")
    self.DebugLog = self.DebugLog or {}
    self.DebugLog[#self.DebugLog + 1] = message
    -- Mantem a lista curta (ultimas 200 linhas).
    if #self.DebugLog > 200 then table.remove(self.DebugLog, 1) end
    if AutoSteal.DebugEnabled then
        print(message)
        -- Tambem manda uma nota pro Debug do painel (se o modulo estiver la).
        local diag = env.__DEPHUB and env.__DEPHUB.Diagnostics
        if type(diag) == "table" and type(diag.Note) == "function" then
            pcall(diag.Note, diag, message)
        end
    end
end

-- Os rotulos do dropdown de terreiro (Terreiro1..Terreiro9).
function AutoSteal.terreiros()
    local list = {}
    for index = 1, AutoSteal.TERREIRO_COUNT do
        list[#list + 1] = "Terreiro" .. index
    end
    return list
end

function AutoSteal.new(context, options)
    options = options or {}
    local self = setmetatable({}, AutoSteal)
    -- Contexto compartilhado do backend (helpers de mundo). Se vier um options
    -- no lugar (compatibilidade), aceita.
    if type(context) == "table" and context.MyPen then
        self.Ctx = context
    else
        self.Ctx = options
        options = type(context) == "table" and context or options
    end
    self.Enabled = false
    self.Thread = nil
    self.Terreiro = options.terreiro or "Terreiro1"
    self.LastError = nil
    self.LastStatus = "idle"
    self.Destroyed = false
    -- Steal All: uma passada unica (botao). AllThread guarda a thread viva pra
    -- nao deixar duas passadas rodarem juntas.
    self.AllThread = nil
    -- Noclip/ancoragem: guardam o estado original pra restaurar ao parar.
    self.Frozen = false
    self.OriginalAnchored = nil
    self.OriginalCollide = nil
    -- Debug: historico de log desta sessao.
    self.DebugLog = {}
    return self
end

-- O historico de debug (ultimas linhas). Util pra puxar do painel/console.
function AutoSteal:Logs()
    return self.DebugLog or {}
end

-- --- Helpers de mundo -----------------------------------------------------

local function mapFolder()
    return Workspace:FindFirstChild("Map")
end

-- A minha base: varre Pens e compara o atributo Owner com o MEU UserId. Nao usa
-- Pen1/Pen2 fixo -- a numeracao muda por servidor -- e funciona para quem
-- receber o script (UserId de cada um), nao so para mim.
function AutoSteal:MyPen()
    -- Se o backend passou o helper compartilhado, usa ele (uma logica so de
    -- Owner no repo). Senao, cai no fallback local.
    if self.Ctx and type(self.Ctx.MyPen) == "function" then
        return self.Ctx.MyPen()
    end
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
-- perto, pega o do Runtime que esta ali. Devolve (model, prompt, rootPart), onde
-- rootPart e a BasePart que carrega o prompt -- e pra ONDE se teleporta.
local function nearestRuntimeExu(position)
    local runtime = Workspace:FindFirstChild("Runtime")
    if not runtime then return nil, nil, nil end
    local best, bestPrompt, bestRoot, bestDistance = nil, nil, nil, math.huge
    for _, model in ipairs(runtime:GetChildren()) do
        local root = model:FindFirstChild("Root")
        local prompt = root and root:FindFirstChild("ProximityPrompt")
        if prompt then
            -- O ponto de referencia do Exu: o proprio Root se for BasePart, senao
            -- o PrimaryPart do modelo.
            local rootPart, origin
            if root and root:IsA("BasePart") then rootPart, origin = root, root.Position
            elseif model:IsA("Model") and model.PrimaryPart then rootPart, origin = model.PrimaryPart, model.PrimaryPart.Position
            elseif model:IsA("BasePart") then rootPart, origin = model, model.Position end
            if origin then
                local distance = (origin - position).Magnitude
                if distance < bestDistance then
                    best, bestPrompt, bestRoot, bestDistance = model, prompt, rootPart, distance
                end
            end
        end
    end
    return best, bestPrompt, bestRoot
end

-- --- Personagem: root, noclip e ancoragem ---------------------------------

function AutoSteal:_root()
    local character = LocalPlayer and LocalPlayer.Character
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart")
end

function AutoSteal:_character()
    return LocalPlayer and LocalPlayer.Character
end

-- Noclip: desliga a colisao de toda BasePart do personagem (e guarda o valor
-- original pra devolver no fim). Sem isso o corpo colide com o cenario e trava.
function AutoSteal:_noclip(on)
    local character = self:_character()
    if not character then return end
    self.OriginalCollide = self.OriginalCollide or {}
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            if on then
                if self.OriginalCollide[part] == nil then self.OriginalCollide[part] = part.CanCollide end
                part.CanCollide = false
            else
                local original = self.OriginalCollide[part]
                if original ~= nil then
                    pcall(function() part.CanCollide = original end)
                else
                    pcall(function() part.CanCollide = true end)
                end
            end
        end
    end
    if not on then self.OriginalCollide = {} end
end

-- Congela o personagem no ar: ancora o HumanoidRootPart e zera as velocidades.
-- Ancorado, ele nao cai, nao escorrega e nao briga com o teleporte. Guarda a
-- ancoragem original do Root pra restaurar.
function AutoSteal:_freeze(on)
    local root = self:_root()
    if not root then return end
    if on then
        if self.OriginalAnchored == nil then self.OriginalAnchored = root.Anchored end
        pcall(function()
            root.Anchored = true
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    else
        local original = self.OriginalAnchored
        pcall(function()
            root.Anchored = original == true
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
        self.OriginalAnchored = nil
    end
    self.Frozen = on == true
end

-- Liga noclip + congelamento. Idempotente.
function AutoSteal:_enterStealState()
    debugLog(self, "estado steal ON: noclip + ancorado (parado no ar)")
    self:_noclip(true)
    self:_freeze(true)
end

-- Restaura tudo: colisao e ancoragem originais. Idempotente.
function AutoSteal:_leaveStealState()
    debugLog(self, "estado steal OFF: colisao e ancoragem restauradas")
    self:_freeze(false)
    self:_noclip(false)
end

-- --- Teleporte instantaneo ------------------------------------------------

-- Teleporte DIRETO: escreve a CFrame no HumanoidRootPart na hora. Zera as
-- velocidades para o personagem nao seguir escorregando do teleporte anterior.
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

-- --- Disparo do prompt ----------------------------------------------------

-- O prompt esta no alcance? (Enabled e a distancia dentro do MaxActivationDistance)
local function promptInRange(prompt, rootPosition)
    if not prompt then return false end
    if prompt.Enabled == false then return false end
    local part = prompt.Parent
    if part and part:IsA("BasePart") and rootPosition then
        local range = prompt.MaxActivationDistance or 10
        return (part.Position - rootPosition).Magnitude <= range
    end
    return true
end

-- Escuta o Triggered do prompt (conectando ANTES do disparo, senao um trigger
-- sincrono passaria batido) e espera o sinal. Devolve uma funcao de espera e a
-- de limpeza. Sem Triggered pra escutar, assume OK (nao trava o loop).
local function armPromptTrigger(prompt)
    if not prompt then return function() return false end, function() end end
    local triggered = false
    local connection
    local ok = pcall(function()
        connection = prompt.Triggered:Connect(function() triggered = true end)
    end)
    if not ok then
        return function() return true end, function() end
    end
    local function wait(timeout)
        local deadline = os.clock() + timeout
        while not triggered and os.clock() < deadline do
            task.wait(0.05)
        end
        return triggered
    end
    local function cleanup()
        pcall(function() if connection then connection:Disconnect() end end)
    end
    return wait, cleanup
end

-- Tenta disparar o prompt de longe: sobe a MaxActivationDistance na hora do
-- disparo e devolve o valor original em seguida (sem residuo).
local function firePromptWide(prompt)
    local fire = fireproximityprompt
    if type(fire) ~= "function" or not prompt then return false end
    local original = prompt.MaxActivationDistance
    pcall(function() prompt.MaxActivationDistance = 1e9 end)
    local ok = pcall(fire, prompt)
    pcall(function() prompt.MaxActivationDistance = original end)
    return ok
end

-- --- O passo de roubo -----------------------------------------------------

-- Um roubo. A CORRECAO do bug "nao pega": o Nest NAO fica sempre em cima do Exu
-- (o log mostrou dist de 14 a 24 studs em alguns Nests, com range 6.5). Entao a
-- ordem certa e:
--   1) acha o Exu do Runtime perto do Nest -> pega a POSICAO REAL do Root dele;
--   2) teleporta pra CIMA do Root (dentro dos 6.5), nao pro Nest;
--   3) espera o prompt entrar no alcance, dispara, espera o "ativou";
--   4) volta pra base pra validar.
-- options.validateWait / settleWait / promptTimeout / label: como antes.
-- options.wide: tenta tambem o disparo de longe (o toggle ja nao precisa).
function AutoSteal:_stealAt(nestTarget, rootPosition, options)
    options = options or {}
    local label = options.label or "?"
    local anchor = self:PenAnchor()
    if not anchor then
        self.LastError = "base nao encontrada (Owner)"
        debugLog(self, label, "ABORTA: base nao encontrada (Owner)")
        return false
    end

    local position = rootPosition or nestTarget.Position

    -- 1) Acha o Exu do Runtime perto do Nest e a posicao REAL do Root dele.
    local model, prompt, rootPart = nearestRuntimeExu(position)
    if not prompt or not rootPart then
        debugLog(self, label, "1) sem Exu no Runtime perto do Nest")
        self:TeleportTo(anchor)
        task.wait(options.validateWait or VALIDATE_WAIT)
        return false
    end

    -- 2) Teleporta pra CIMA do Root do Exu (nao pro Nest) -- e o que faz o prompt
    --    valer de verdade no servidor.
    self:TeleportTo(rootPart.CFrame)
    debugLog(self, label, "2) teleportou pro Root do Exu (",
        rootPart:GetFullName(), ")")
    task.wait()

    local root = self:_root()
    local rootPos = root and root.Position or rootPart.Position
    local distance = (rootPart.Position - rootPos).Magnitude
    local range = prompt.MaxActivationDistance or 10
    debugLog(self, label, "3) dist ate o prompt=", string.format("%.1f", distance),
        "range=", tostring(prompt.MaxActivationDistance), "enabled=", tostring(prompt.Enabled))

    -- Deixa o prompt assentar (corpo parado no ar em cima do Exu).
    task.wait(options.settleWait or SETTLE_WAIT)

    if not promptInRange(prompt, rootPos) then
        debugLog(self, label, "AVISO: ainda fora do alcance (dist=",
            string.format("%.1f", distance), "range=", tostring(range), ")")
    end

    -- Escuta o Triggered ANTES de disparar (o trigger pode ser sincrono).
    local waitTriggered, cleanup = armPromptTrigger(prompt)

    -- 4a) Mais forte (Steal All): tenta de longe tambem.
    if options.wide then
        local wideOk = firePromptWide(prompt)
        debugLog(self, label, "4a) disparo de longe ->", tostring(wideOk))
    end

    -- 4b) Dispara normal, com o personagem em cima do Exu.
    local fire = fireproximityprompt
    if type(fire) == "function" then
        local firedOk = pcall(fire, prompt)
        debugLog(self, label, "4b) fireproximityprompt ->", tostring(firedOk))
    else
        debugLog(self, label, "4b) fireproximityprompt INDISPONIVEL (executor sem essa funcao?)")
    end

    local didFire = waitTriggered(options.promptTimeout or PROMPT_TIMEOUT)
    cleanup()
    debugLog(self, label, "5) Triggered (ativou) ->", tostring(didFire))

    -- 5) Volta pra base e espera pra o jogo confirmar o guardar.
    self:TeleportTo(anchor)
    debugLog(self, label, "6) voltou pra base; validando por",
        tostring(options.validateWait or VALIDATE_WAIT), "s")
    task.wait(options.validateWait or VALIDATE_WAIT)

    return didFire
end

-- Um ciclo do Auto Steal Exu: varre os Nests do Terreiro escolhido, roubando um
-- por um (cada um com sua ida-e-volta pra base).
function AutoSteal:StealOnce()
    if not self:_root() then self.LastError = "sem personagem"; return false, 0 end
    local nests = self:TerreiroNests()
    if not nests then
        self.LastError = "terreiro nao encontrado: " .. tostring(self.Terreiro)
        debugLog(self, "ABORTA: Terreiro nao encontrado (", tostring(self.Terreiro), ")")
        return false, 0
    end

    debugLog(self, "=== ciclo Auto Steal Exu (", tostring(self.Terreiro), ") ===")
    local stole = 0
    for index = 1, AutoSteal.NEST_COUNT do
        local nest = nests:FindFirstChild("Nest" .. index)
        local target = nest and nestPosition(nest)
        if target then
            local ok = self:_stealAt(target, target.Position, {
                label = "Nest" .. index,
                validateWait = VALIDATE_WAIT,
                settleWait = SETTLE_WAIT,
                promptTimeout = PROMPT_TIMEOUT,
            })
            if ok then stole = stole + 1 end
        else
            debugLog(self, "Nest" .. index, "ausente")
        end
    end

    debugLog(self, "=== fim do ciclo: roubou", stole, "de", tostring(AutoSteal.NEST_COUNT), "===")
    self.LastStatus = stole > 0 and "stealing" or "no targets"
    return stole > 0, stole
end

-- --- Steal All (botao) ----------------------------------------------------

-- Uma passada por TODOS os Exus: Terreiro9 -> Terreiro1 (ordem pedida pelo
-- usuario), Nest1..8 em cada. Mesmo ciclo do toggle, so que mais rapido e com o
-- disparo de longe antes de piscar. No fim volta pro CFrame de origem.
function AutoSteal:StealAll()
    if not self:_root() then self.LastError = "sem personagem"; return false, 0 end

    local map = mapFolder()
    local terreiros = map and map:FindFirstChild("Terreiros")
    if not terreiros then
        self.LastError = "Terreiros nao encontrados"
        debugLog(self, "ABORTA: workspace.Map.Terreiros ausente")
        return false, 0
    end

    local origin = self:PenAnchor()
    self.LastStatus = "stealing all"
    self.LastError = nil
    local stole, skipped = 0, 0

    debugLog(self, "=== Steal All: Terreiro" .. ALL_TERREIRO_FROM .. " -> Terreiro" .. ALL_TERREIRO_TO, "===")

    for terreiroIndex = ALL_TERREIRO_FROM, ALL_TERREIRO_TO, -1 do
        local terreiro = terreiros:FindFirstChild("Terreiro" .. terreiroIndex)
        local nests = terreiro and terreiro:FindFirstChild("Nests")
        if not nests then
            debugLog(self, "Terreiro" .. terreiroIndex, "sem .Nests (pulado)")
        else
            for nestIndex = 1, AutoSteal.NEST_COUNT do
                local nest = nests:FindFirstChild("Nest" .. nestIndex)
                local target = nest and nestPosition(nest)
                if target then
                    local ok = self:_stealAt(target, target.Position, {
                        label = "T" .. terreiroIndex .. ".Nest" .. nestIndex,
                        validateWait = ALL_VALIDATE_WAIT,
                        settleWait = ALL_SETTLE_WAIT,
                        promptTimeout = ALL_PROMPT_TIMEOUT,
                        wide = true,
                    })
                    if ok then stole = stole + 1 else skipped = skipped + 1 end
                    task.wait(ALL_STEP_GAP)
                end
            end
        end
    end

    -- Volta pra base no fim (tambem e onde o ultimo passo ja parou).
    if origin then self:TeleportTo(origin) end

    debugLog(self, "=== fim do Steal All: roubou", stole, "pulou", skipped, "===")
    self.LastStatus = "idle"
    self.LastCounts = {stole = stole, skipped = skipped}
    return stole > 0, stole
end

-- O botao chama isto: sobe a passada numa thread propria pra nao travar o
-- clique, com noclip+congelamento ligados. Uma passada por vez.
function AutoSteal:StartStealAll()
    if self.Destroyed then
        debugLog(self, "Steal All ignorado: feature destruida")
        return false
    end
    if self.AllThread then
        debugLog(self, "Steal All ignorado: ja tem uma passada rodando")
        return false
    end
    debugLog(self, "Steal All iniciado (botao)")
    self:_enterStealState()
    self.AllThread = task.spawn(function()
        local ok, err = pcall(function() return self:StealAll() end)
        if not ok then
            self.LastError = tostring(err)
            debugLog(self, "Steal All ERRO:", tostring(err))
        end
        -- So sai do estado de steal se o toggle do loop tambem nao estiver ligado.
        if not self.Enabled then self:_leaveStealState() end
        self.AllThread = nil
        debugLog(self, "Steal All terminado")
    end)
    return true
end

-- --- Ciclo de vida --------------------------------------------------------

function AutoSteal:_loop()
    debugLog(self, "loop Auto Steal Exu iniciado (", tostring(self.Terreiro), ")")
    self:_enterStealState()
    while self.Enabled do
        local done, result = pcall(function() return self:StealOnce() end)
        if not done then
            self.LastError = tostring(result)
            debugLog(self, "ciclo ERRO:", tostring(result))
        end
    end
    -- Saiu do loop: se o botao nao estiver rodando, restaura tudo.
    if not self.AllThread then self:_leaveStealState() end
    self.Thread = nil
    debugLog(self, "loop Auto Steal Exu parado")
end

function AutoSteal:SetEnabled(on)
    self.Enabled = on == true
    if not self.Enabled then
        if self.Thread then pcall(task.cancel, self.Thread); self.Thread = nil end
        self.LastStatus = "idle"
        if not self.AllThread then self:_leaveStealState() end
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
    self.Enabled = false
    if self.Thread then pcall(task.cancel, self.Thread); self.Thread = nil end
    if self.AllThread then pcall(task.cancel, self.AllThread); self.AllThread = nil end
    self:_leaveStealState()
end

return AutoSteal
