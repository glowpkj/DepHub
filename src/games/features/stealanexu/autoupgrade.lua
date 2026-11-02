-- Steal An Exu -- Auto Upgrade (dois toggles: base e esteira).
--
-- A ideia e' a mesma dos dois: o jogo sobe o nivel quando o jogador clica no
-- ClickDetector do quadro do proprio pen. Entao, ligado, a gente martela esse
-- ClickDetector.
--
--   base   -> workspace.Map.Pens.<MeuPen>.PenSign.Board.ClickDetector
--   esteira-> workspace.Map.Pens.<MeuPen>.TreadSign.Board.ClickDetector
--
-- "A base muda": NUNCA usa Pen1/Pen2 fixo -- o pen e' sempre o MEU, achado pelo
-- atributo Owner (mesma logica do autosteal, vinda do contexto do backend).
--
-- Os dois quadros sao o MESMO mecanismo mudando so o caminho dentro do pen, entao
-- este modulo e' uma fabrica: o backend instancia duas vezes (base e esteira),
-- cada uma com seu toggle.
--
-- API: AutoUpgrade.new(ctx, opts) -> obj com SetEnabled(on) / IsEnabled() /
--      Destroy() e o campo Enabled.

local game = game
local task = task
local type = type
local pcall = pcall
local tostring = tostring
local table = table
local select = select

-- De quanto em quanto tempo clicar. O upgrade tem custo/animacao; martelar mais
-- rapido que isso so desperdica chamada (o servidor ignora as repetidas).
local CLICK_INTERVAL = 0.3

local AutoUpgrade = {}
AutoUpgrade.__index = AutoUpgrade

-- --- Debug ----------------------------------------------------------------

AutoUpgrade.DebugEnabled = true
local DEBUG_TAG = "[StealAnExu]"
local env = type(getgenv) == "function" and getgenv() or _G

local function debugLog(self, ...)
    local parts = {}
    for index = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(index, ...))
    end
    local message = DEBUG_TAG .. " " .. self.Label .. ": " .. table.concat(parts, " ")
    self.DebugLog = self.DebugLog or {}
    self.DebugLog[#self.DebugLog + 1] = message
    if #self.DebugLog > 200 then table.remove(self.DebugLog, 1) end
    if AutoUpgrade.DebugEnabled then
        print(message)
        local diag = env.__DEPHUB and env.__DEPHUB.Diagnostics
        if type(diag) == "table" and type(diag.Note) == "function" then
            pcall(diag.Note, diag, message)
        end
    end
end

-- --- Construtor -----------------------------------------------------------

-- ctx: contexto compartilhado do backend (ctx.MyPen / ctx.PenPart).
-- opts.label: prefixo do log ("base" / "tread").
-- opts.path:  caminho pontuado dentro do pen ate o ClickDetector.
function AutoUpgrade.new(ctx, opts)
    opts = opts or {}
    local self = setmetatable({}, AutoUpgrade)
    self.Ctx = ctx or {}
    self.Label = opts.label or "upgrade"
    self.Path = opts.path
    self.Enabled = false
    self.Thread = nil
    self.LastError = nil
    self.Destroyed = false
    self.DebugLog = {}
    return self
end

function AutoUpgrade:Logs()
    return self.DebugLog or {}
end

function AutoUpgrade:IsEnabled()
    return self.Enabled == true
end

-- --- O alvo ---------------------------------------------------------------

-- O ClickDetector da minha base pra este upgrade. Se o objeto no fim do caminho
-- nao for um ClickDetector (o jogo as vezes troca por outro "botao"), ainda
-- aceita qualquer coisa com :Click().
function AutoUpgrade:Detector()
    local ctx = self.Ctx
    if type(ctx.PenPart) ~= "function" then
        return nil, "sem helper de mundo (ctx.PenPart ausente)"
    end
    local instance = ctx.PenPart(self.Path)
    if not instance then
        return nil, "caminho nao encontrado no meu pen: " .. tostring(self.Path)
    end
    if instance:IsA("ClickDetector") then return instance end
    -- Alguns jogos poem um filho ClickDetector dentro do "Board"; aceita.
    local child = instance:FindFirstChildOfClass("ClickDetector")
    if child then return child end
    -- Ultimo caso: um objeto com :Click() (funciona igual no client).
    if type(instance.Click) == "function" then return instance end
    return nil, "nao e um ClickDetector: " .. instance:GetFullName()
end

-- Um clique. Prefere o fireclickdetector do executor (e o que atravessa o
-- filtro do client sem depender de toque); cai no :Click() se nao houver.
function AutoUpgrade:Click(detector)
    if not detector then return false end
    local fire = fireclickdetector
    if type(fire) == "function" then
        local ok = pcall(fire, detector)
        if ok then return true end
    end
    if type(detector.Click) == "function" then
        local ok = pcall(function() detector:Click() end)
        if ok then return true end
    end
    return false
end

-- --- O loop ---------------------------------------------------------------

function AutoUpgrade:_loop()
    debugLog(self, "loop de upgrade iniciado (", tostring(self.Path), ")")
    local misses = 0
    while self.Enabled do
        local detector, reason = self:Detector()
        if detector then
            misses = 0
            local ok = self:Click(detector)
            if not ok then
                self.LastError = "falha ao clicar"
                debugLog(self, "clique falhou em", detector:GetFullName())
            end
        else
            -- Base/path ausente e' normal enquanto o pen ainda esta carregando;
            -- so loga de vez em quando pra nao inundar o console.
            misses = misses + 1
            self.LastError = reason
            if misses == 1 or misses % 20 == 0 then
                debugLog(self, "sem alvo (", tostring(reason), ") tentativa", misses)
            end
        end
        task.wait(CLICK_INTERVAL)
    end
    self.Thread = nil
    debugLog(self, "loop de upgrade parado")
end

-- --- Ligar / desligar -----------------------------------------------------

-- Idempotente: ligar duas vezes nao abre dois loops, desligar duas vezes nao
-- quebra. Nao deixa residuo: ao desligar, a thread sai no proximo tick.
function AutoUpgrade:SetEnabled(on)
    on = on == true
    if self.Destroyed then
        debugLog(self, "SetEnabled ignorado: feature destruida")
        return false
    end
    if on == self.Enabled then return true end
    self.Enabled = on
    if on then
        debugLog(self, "ON")
        self.Thread = task.spawn(function()
            local ok, err = pcall(function() return self:_loop() end)
            if not ok then
                self.LastError = tostring(err)
                debugLog(self, "ERRO no loop:", tostring(err))
            end
        end)
    else
        debugLog(self, "OFF")
    end
    return true
end

function AutoUpgrade:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self.Enabled = false
    if self.Thread then
        pcall(task.cancel, self.Thread)
        self.Thread = nil
    end
    self.DebugLog = {}
end

-- Devolve a fabrica.
return AutoUpgrade
