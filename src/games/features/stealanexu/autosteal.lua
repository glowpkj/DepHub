-- Auto Steal Exu -- rouba os Exu por teleporte instantaneo, com noclip e o
-- personagem parado no ar (ancorado) pra nao bugar dentro do cenario.
--
-- O JOGO (o que este modulo assume):
--
--   * workspace.Runtime -- os MODELOS dos Exu, um por Exu no servidor. O prompt
--     vive em cada modelo: Model.Root.ProximityPrompt. E a VARREDURA e' aqui:
--     percorre os filhos do Runtime e rouba um por um -- e' assim que se pega
--     VARIOS Exus (os Nests podem apontar pro mesmo Exu por proximidade).
--   * workspace.Map.Terreiros.TerreiroN -- as fases, N = 1..9, com .Nests
--     Nest1..8. Sao so referencia visual do jogo; o roubo nao depende delas.
--   * workspace.Map.Pens.PenX -- as bases, uma por jogador. Cada base tem o
--     atributo "Owner" (o UserId do dono) e um BadgeAnchor (o ponto onde o
--     jogador "guarda" o Exu). A NUMERACAO Pen1/Pen2 muda por servidor, entao a
--     base certa so se acha pelo atributo Owner == LocalPlayer.UserId.
--
-- O CICLO de cada roubo (script de referencia do usuario, que funciona):
--   1) teleporta pro modelo do Exu (GetPivot().Position + Vector3.new(0,3,0));
--   2) task.wait(0.1);
--   3) dispara o prompt (HoldDuration=0 + InputHoldBegin/End) e volta pra base;
--   4) proximo Exu.
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

-- TEMPOS (iguais ao script de referencia que funciona):
--   SETTLE_WAIT -- task.wait(0.1) DEPOIS do teleporte, antes de disparar.
--   POST_WAIT   -- task.wait(0.1) DEPOIS de disparar, antes de voltar pra base.
local SETTLE_WAIT = 0.1
local POST_WAIT = 0.1

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

function AutoSteal.new(context, options)
    local self = setmetatable({}, AutoSteal)
    options = options or {}
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

-- Rouba o Exu. MECANISMO (o script de referencia do usuario, que funciona):
--
--     prompt.HoldDuration = 0        -- <- a peca-chave
--     prompt:InputHoldBegin()
--     prompt:InputHoldEnd()
--
-- Com o HoldDuration zerado o hold completa NA HORA e o servidor aceita. O
-- HoldDuration original e' restaurado logo depois (sem residuo no prompt).
-- Se a versao do jogo/executor nao tiver InputHold*, cai no fireproximityprompt.
local function stealPrompt(prompt)
    if not prompt then return false end

    if type(prompt.InputHoldBegin) == "function" then
        local original = prompt.HoldDuration
        pcall(function() prompt.HoldDuration = 0 end)
        pcall(function() prompt:InputHoldBegin() end)
        if type(prompt.InputHoldEnd) == "function" then
            pcall(function() prompt:InputHoldEnd() end)
        end
        pcall(function() prompt.HoldDuration = original end)
        return true
    end

    -- Fallback (executor/jogo sem InputHold*): o fire instantaneo.
    local fire = fireproximityprompt
    if type(fire) == "function" then
        return pcall(fire, prompt)
    end
    return false
end

-- --- O passo de roubo -----------------------------------------------------

-- Um roubo, EXATAMENTE o script de referencia do usuario:
--
--     local pos = t.model:GetPivot().Position
--     hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
--     task.wait(0.1)
--     t.prompt.HoldDuration = 0
--     t.prompt:InputHoldBegin()
--     t.prompt:InputHoldEnd()
--     hrp.CFrame = originalPos
--     task.wait(0.1)
--
-- Sem skip, sem releitura, sem verificacao. Teleporta pro modelo, dispara, volta.
function AutoSteal:_stealAt(target)
    local model = target and target.model
    local prompt = target and target.prompt
    if not model or not prompt then return false end

    local anchor = self:PenAnchor()
    if not anchor then
        self.LastError = "base nao encontrada (Owner)"
        debugLog(self, "ABORTA: base nao encontrada (Owner)")
        return false
    end

    -- Teleporta (o script de referencia).
    local pos = model:GetPivot().Position
    self:TeleportTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
    debugLog(self, "teleportou pro Exu (", model.Name, ")")

    -- task.wait(0.1)
    task.wait(SETTLE_WAIT)

    -- Ativa (o script de referencia).
    stealPrompt(prompt)
    debugLog(self, "disparou o prompt")

    -- Volta (o script de referencia).
    self:TeleportTo(anchor)
    task.wait(POST_WAIT)

    return true
end

-- --- Auto Steal Exu (toggle) / Steal All (botao) --------------------------

-- O script de referencia, dentro do ciclo. Coleta a lista UMA vez, cicla por ela
-- (i = i % #targets + 1) e rouba um por um -- exatamente como o script que
-- funciona.
--
-- `once = true`: uma passada (passa por cada alvo uma vez e para).
-- `once = false`: ciclo infinito (como o script); `stop()` decide quando parar.
function AutoSteal:_runCycle(options)
    options = options or {}
    local once = options.once == true
    local stop = options.stop

    local runtime = Workspace:FindFirstChild("Runtime")
    if not runtime then
        self.LastError = "workspace.Runtime nao encontrado"
        debugLog(self, "ABORTA: workspace.Runtime nao encontrado")
        return 0
    end

    -- Coleta todos os modelos com Root.ProximityPrompt (UMA vez, como o script).
    local targets = {}
    for _, child in ipairs(runtime:GetChildren()) do
        local root = child:FindFirstChild("Root")
        local prompt = root and root:FindFirstChild("ProximityPrompt")
        if prompt then
            targets[#targets + 1] = {model = child, prompt = prompt}
        end
    end

    if #targets == 0 then
        self.LastError = "Nenhum ProximityPrompt encontrado em Runtime"
        self.LastStatus = "no targets"
        debugLog(self, "Nenhum ProximityPrompt encontrado em Runtime")
        return 0
    end

    self.LastStatus = "stealing"
    debugLog(self, "=== ciclo Auto Steal Exu (", tostring(#targets), " Exus) ===")

    local stole = 0
    local i = 1
    while true do
        -- `reverse`: do ultimo pro primeiro (volta pra tras). Senao, do 1o pro
        -- ultimo -- como o script de referencia.
        local index
        if options.reverse then
            index = #targets - ((i - 1) % #targets)
        else
            index = ((i - 1) % #targets) + 1
        end
        local t = targets[index]

        -- Teleporta / Ativa / Volta (o script de referencia).
        self:_stealAt(t)
        stole = stole + 1
        if once and stole >= #targets then break end
        if stop and stop() then break end

        -- Proximo (cicla de volta ao 1o quando acaba).
        i = i + 1
        if stop and stop() then break end
    end

    debugLog(self, "=== fim do ciclo: passou por", stole, "Exus ===")
    return stole
end

-- Uma passada completa pelos Exus do Runtime (usada pelo toggle e pelo teste).
function AutoSteal:StealOnce()
    if not self:_root() then self.LastError = "sem personagem"; return false, 0 end
    local stole = self:_runCycle({once = true})
    if stole == 0 then return false, 0 end
    return true, stole
end

-- --- Steal All (botao) ----------------------------------------------------

-- A passada do botao: uma volta por TODOS os Exus do Runtime, do ultimo pro
-- primeiro (como o script, so que parando depois de uma passada). No fim volta
-- pro CFrame de origem.
function AutoSteal:StealAll()
    if not self:_root() then self.LastError = "sem personagem"; return false, 0 end

    local origin = self:PenAnchor()
    self.LastStatus = "stealing all"
    self.LastError = nil

    debugLog(self, "=== Steal All ===")
    local stole = self:_runCycle({once = true, reverse = true})

    if origin then self:TeleportTo(origin) end

    debugLog(self, "=== fim do Steal All: passou por", stole, "Exus ===")
    self.LastStatus = "idle"
    self.LastCounts = {stole = stole}
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
    debugLog(self, "loop Auto Steal Exu iniciado")
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

function AutoSteal:Destroy()
    self.Destroyed = true
    self.Enabled = false
    if self.Thread then pcall(task.cancel, self.Thread); self.Thread = nil end
    if self.AllThread then pcall(task.cancel, self.AllThread); self.AllThread = nil end
    self:_leaveStealState()
end

return AutoSteal
