-- Shared DepHub live diagnostics console.
--
-- One Debug tab, identical in every game, that behaves like a real terminal:
-- it keeps itself current instead of showing a snapshot, and it listens to
-- both the hub and the game.
--
-- Listeners (read-only; they never modify the game's own scripts):
--   * global log hooks    -- warn/print routed through a capture buffer
--   * ScriptContext.Error -- engine/script errors from the running game
--   * live metrics        -- FPS, ping, memory, uptime, entity counts
--   * structure watch     -- titans/resources entering and leaving
--   * remote sniffer      -- every GET/POST the hub sends, with arguments
--
-- API used by the loader and backends:
--   Diag:SetEnvironment(t)         -- executor/place/version snapshot
--   Diag:Module(name, ok, detail)  -- module load outcome
--   Diag:RegisterModule(name)      -- declare a module before it reports
--   Diag:Probe(label, ok, detail)  -- game-structure probe result
--   Diag:Feature(name, reader)     -- live value, polled for the console
--   Diag:Watch(label, reader)      -- watched value; changes become log lines
--   Diag:Note(text)                -- free-form line
--   Diag:Log(kind, text)           -- capture a log line
--   Diag:Command(name, handler)    -- register a console command
--   Diag:Install(ui)               -- build the live Debug console
--   Diag:Report() / Diag:Copy()    -- whole snapshot as text
--
-- Every collector is pcall-guarded: a probe, feature or hook that throws is
-- shown as an error line instead of taking the hub (or the game) down.
local Diagnostics = {}
Diagnostics.__index = Diagnostics

local MAX_LOG = 400
local REFRESH = 0.5

local function envTable()
    return type(getgenv) == "function" and getgenv() or _G
end

local function safe(...)
    return select(2, pcall(...))
end

-- Capture the environment this chunk was loaded into while we are still at
-- top level. Luau's getfenv() answers for the *calling* function, so a call
-- made later from inside a method can resolve to a different table than the
-- one the chunk actually runs in. Reading it once, here, gives us the real
-- holder for warn/print in every environment (executor globals or a host
-- that ran the chunk under setfenv).
--
-- Note: the probe runs inside its own closure on purpose. Calling getfenv
-- itself as the pcall target would answer for pcall's C frame, not the chunk.
local LOAD_ENV
do
    local ok, captured = pcall(function() return getfenv() end)
    if ok and type(captured) == "table" then LOAD_ENV = captured end
end

local function now()
    return os.clock()
end

local function clockString(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60)
end

function Diagnostics.new()
    local self = setmetatable({
        Environment = {},
        Modules = {}, ModuleOrder = {},
        Probes = {}, ProbeOrder = {},
        Features = {}, FeatureOrder = {},
        Watches = {}, WatchOrder = {}, WatchValues = {},
        Notes = {},
        Logs = {},
        LogPaused = false,
        SniffEnabled = true,
        RemoteLog = {},
        Hooks = {},
        Commands = {},
        StartedAt = now(),
        Metrics = {FPS = 0, Ping = 0, Memory = 0, Uptime = 0, Titans = 0},
        Installed = false,
        Tab = nil,
        RenderTask = nil,
        Destroyed = false
    }, Diagnostics)
    self:_registerBuiltins()
    return self
end

local function pushUnique(list, value)
    if not table.find(list, value) then list[#list + 1] = value end
end

-- ---------------------------------------------------------------------------
-- Data collection
-- ---------------------------------------------------------------------------

function Diagnostics:SetEnvironment(values)
    if type(values) ~= "table" then return end
    for key, value in pairs(values) do self.Environment[tostring(key)] = tostring(value) end
end

function Diagnostics:RegisterModule(name)
    name = tostring(name)
    pushUnique(self.ModuleOrder, name)
    if self.Modules[name] == nil then self.Modules[name] = {Ok = nil, Detail = "pendente"} end
    return name
end

function Diagnostics:Module(name, ok, detail)
    name = tostring(name)
    pushUnique(self.ModuleOrder, name)
    self.Modules[name] = {Ok = ok == true, Detail = detail ~= nil and tostring(detail) or (ok and "ok" or "sem detalhe")}
    self:_addLog("module", (ok and "[OK] " or "[FALHA] ") .. name .. ": " .. self.Modules[name].Detail)
end

function Diagnostics:Probe(label, ok, detail)
    label = tostring(label)
    pushUnique(self.ProbeOrder, label)
    self.Probes[label] = {Ok = ok == true, Detail = detail ~= nil and tostring(detail) or (ok and "ok" or "ausente")}
end

function Diagnostics:Feature(name, reader)
    name = tostring(name)
    pushUnique(self.FeatureOrder, name)
    self.Features[name] = reader
end

-- A watch polls its reader on the console loop and writes a log line whenever
-- the value changes, so structure changes (a titan spawning, a remote leaving)
-- become timestamped events instead of a value you have to stare at.
function Diagnostics:Watch(label, reader)
    label = tostring(label)
    pushUnique(self.WatchOrder, label)
    self.Watches[label] = reader
end

function Diagnostics:Note(text)
    self.Notes[#self.Notes + 1] = tostring(text)
end

function Diagnostics:Command(name, handler)
    self.Commands[tostring(name)] = handler
end

-- ---------------------------------------------------------------------------
-- Log capture + hooks
-- ---------------------------------------------------------------------------

local function stamp()
    return string.format("%6.2f", now() % 100000)
end

function Diagnostics:_addLog(kind, text)
    if self.LogPaused and kind ~= "console" then return end
    self.Logs[#self.Logs + 1] = {Kind = tostring(kind or "log"), Text = tostring(text), T = stamp()}
    while #self.Logs > MAX_LOG do table.remove(self.Logs, 1) end
end

function Diagnostics:Log(kind, text)
    self:_addLog(kind, text)
end

-- Wrap the executor's warn/print so everything the hub *and the game* prints is
-- captured. The originals are always called, so nothing is swallowed.
function Diagnostics:_installLogHooks()
    if self.Hooks.warn or self.Hooks.print then return end
    -- Candidate holders, in priority order: the table the chunk was loaded
    -- into (always correct), the shared executor globals, and the raw _G.
    local holders = {}
    local seen = {}
    local function add(table_)
        if type(table_) == "table" and not seen[table_] then
            seen[table_] = true
            holders[#holders + 1] = table_
        end
    end
    add(LOAD_ENV)
    add(envTable())
    add(_G)
    for _, name in ipairs({"warn", "print"}) do
        -- Hook every holder that currently exposes the function, so a line
        -- emitted by the hub or by the game is captured no matter which table
        -- it resolves through. The first one found is the reference the
        -- wrapper forwards to.
        local original
        for _, holder in ipairs(holders) do
            if type(holder[name]) == "function" then
                original = original or holder[name]
                break
            end
        end
        if original then
            local wrapped = function(...)
                local parts = {}
                for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
                self:_addLog(name, table.concat(parts, " "))
                return original(...)
            end
            local installed = {}
            for _, holder in ipairs(holders) do
                if type(holder[name]) == "function" then
                    pcall(function() holder[name] = wrapped end)
                    installed[#installed + 1] = holder
                end
            end
            self.Hooks[name] = {Original = original, Holders = installed, Wrapped = wrapped}
        end
    end
    -- ScriptContext.Error reports errors raised by scripts running in this
    -- client, including the game's own. We only listen.
    local ok, scriptContext = pcall(function() return game:GetService("ScriptContext") end)
    if ok and scriptContext and scriptContext.Error and not self.Hooks.ScriptContext then
        local connection = scriptContext.Error:Connect(function(message, stack)
            self:_addLog("erro", tostring(message) .. (stack and ("\n" .. tostring(stack)) or ""))
        end)
        self.Hooks.ScriptContext = connection
    end
end

function Diagnostics:_removeLogHooks()
    local env = envTable()
    local restore = env.restorefunction or _G.restorefunction
    for name, hook in pairs(self.Hooks) do
        if name == "ScriptContext" then
            pcall(function() hook:Disconnect() end)
        elseif type(hook) == "table" and hook.Holders then
            for _, holder in ipairs(hook.Holders) do
                pcall(function() holder[name] = hook.Original end)
            end
        elseif type(hook) == "table" then
            -- Remote sniffer record: undo executor hooks and field patches.
            if hook.Restores and type(restore) == "function" then
                for _, handle in ipairs(hook.Restores) do pcall(restore, handle) end
            end
            for _, patch in ipairs(hook.Fields or {}) do
                pcall(function() rawset(patch.Remote, patch.Name, patch.Original) end)
            end
        end
    end
    self.Hooks = {}
end

-- Wrap a remote so every invocation the hub makes is logged with its arguments.
-- The wrapping is transparent: the original call is forwarded untouched.
--
-- Real Roblox Instances keep their methods on a shared metatable, so a plain
-- field assignment does not override InvokeServer/FireServer. The sniffer
-- therefore prefers an executor's hooking primitive (hookfunction /
-- replaceclosure) when one is present, and only falls back to a field patch
-- for plain-function doubles that accept one.
function Diagnostics:SniffRemote(remote, label)
    if not remote then return end
    label = tostring(label)
    local key = "remote:" .. label
    if self.Hooks[key] then return end

    local env = envTable()
    local hook = env.hookfunction or _G.hookfunction
    local restore = env.restorefunction or _G.restorefunction
    local record = {Restores = {}, Fields = {}}
    self.Hooks[key] = record

    for _, name in ipairs({"InvokeServer", "FireServer"}) do
        local method = remote[name]
        if type(method) == "function" then
            local verb = name == "InvokeServer" and "GET " or "POST "
            local wrapped = function(instance, ...)
                self:_addLog("remote", verb .. label .. "(" .. self:_fmtArgs(...) .. ")")
                return method(instance, ...)
            end
            if type(hook) == "function" then
                -- Executor hooking: swap the closure and keep the handle for
                -- restorefunction on teardown.
                local handle
                local ok = pcall(function() handle = hook(method, wrapped) end)
                if ok and handle ~= nil then
                    record.Restores[#record.Restores + 1] = handle
                else
                    self:_addLog("remote", "nao foi possivel hookar " .. name .. " de " .. label)
                end
            elseif rawget(remote, name) == method then
                -- Plain-function double: patch the own field only, and only
                -- when no metatable shadows it.
                record.Fields[#record.Fields + 1] = {Remote = remote, Name = name, Original = method}
                pcall(function() rawset(remote, name, wrapped) end)
            end
        end
    end
    if type(restore) ~= "function" then record.Restores = nil end
end

function Diagnostics:_fmtArgs(...)
    local parts = {}
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        local kind = type(value)
        if kind == "string" or kind == "number" or kind == "boolean" then
            parts[i] = tostring(value)
        elseif typeof(value) == "Instance" then
            parts[i] = tostring(value.ClassName) .. ":" .. tostring(value.Name)
        elseif typeof(value) == "Vector3" then
            parts[i] = string.format("(%.1f,%.1f,%.1f)", value.X, value.Y, value.Z)
        else
            parts[i] = kind
        end
    end
    return table.concat(parts, ", ")
end

-- ---------------------------------------------------------------------------
-- Metrics
-- ---------------------------------------------------------------------------

-- Resolve a child by name without raising when the member is absent. A raw
-- index like stats.FrameStats throws on executors where the member is not
-- exposed, so every optional read goes through FindFirstChild.
local function child(object, name)
    if not object then return nil end
    local ok, found = pcall(function() return object:FindFirstChild(name) end)
    return ok and found or nil
end

function Diagnostics:_collectMetrics()
    local metrics = self.Metrics
    local okStats, stats = pcall(function() return game:GetService("Stats") end)
    if okStats and stats then
        local frame = child(stats, "FrameStats")
        if frame then
            local rate = child(frame, "FrameRate")
            local fps = rate and safe(function() return rate.Value end)
            if type(fps) == "number" then metrics.FPS = fps end
        end
        local network = child(stats, "Network")
        local serverStats = network and child(network, "ServerStatsItem")
        local pingItem = serverStats and child(serverStats, "Data Ping")
        if pingItem then
            local ping = safe(function() return pingItem:GetValue() end)
            if type(ping) == "number" then metrics.Ping = ping end
        end
        local memory = safe(function() return stats:GetTotalMemoryUsageMb() end)
        if type(memory) == "number" then metrics.Memory = memory end
    end
    metrics.Uptime = now() - self.StartedAt

    -- Entity counts come from whatever the active backend opted to watch; a
    -- generic fallback keeps the console useful before a backend reports.
    local okWorkspace, ws = pcall(function() return game:GetService("Workspace") end)
    if okWorkspace and ws then
        local titans = child(ws, "Titans")
        local count = titans and safe(function() return #titans:GetChildren() end)
        if type(count) == "number" then metrics.Titans = count end
    end
    return metrics
end

function Diagnostics:_pollWatches()
    if self.Destroyed then return end
    for _, label in ipairs(self.WatchOrder) do
        local reader = self.Watches[label]
        if type(reader) == "function" then
            local ok, value = pcall(reader)
            local text = ok and tostring(value) or ("ERRO: " .. tostring(value))
            if self.WatchValues[label] ~= text then
                if self.WatchValues[label] ~= nil then self:_addLog("watch", label .. ": " .. self.WatchValues[label] .. " -> " .. text) end
                self.WatchValues[label] = text
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Built-in console commands
-- ---------------------------------------------------------------------------

function Diagnostics:_registerBuiltins()
    self:Command("help", function() return "comandos: " .. self:_commandList() end)
    self:Command("clear", function() self.Logs = {}; return "log limpo" end)
    self:Command("pause", function() self.LogPaused = true; return "log pausado" end)
    self:Command("resume", function() self.LogPaused = false; return "log retomado" end)
    self:Command("report", function() return "relatorio completo: use o botao Copiar relatorio" end)
    self:Command("modules", function()
        local parts = {}
        for _, name in ipairs(self.ModuleOrder) do
            local record = self.Modules[name]
            parts[#parts + 1] = (record and (record.Ok == true and "ok " or record.Ok == false and "FALHA " or "? ") or "? ") .. name
        end
        return table.concat(parts, " | ")
    end)
    self:Command("probes", function()
        local parts = {}
        for _, label in ipairs(self.ProbeOrder) do
            local record = self.Probes[label]
            if record then parts[#parts + 1] = label .. "=" .. tostring(record.Ok and "ok" or "ausente") end
        end
        return table.concat(parts, " | ")
    end)
    self:Command("features", function()
        local parts = {}
        for _, name in ipairs(self.FeatureOrder) do
            local reader = self.Features[name]
            if type(reader) == "function" then
                local ok, value = pcall(reader)
                parts[#parts + 1] = name .. "=" .. (ok and tostring(value) or "ERRO")
            end
        end
        return table.concat(parts, " | ")
    end)
    self:Command("sniff", function(argument)
        if argument == "on" then self.SniffEnabled = true return "sniff de remotes ligado"
        elseif argument == "off" then self.SniffEnabled = false return "sniff de remotes desligado" end
        return "uso: sniff on|off (atual: " .. tostring(self.SniffEnabled) .. ")"
    end)
    self:Command("env", function()
        local parts = {}
        for key, value in pairs(self.Environment) do parts[#parts + 1] = key .. "=" .. tostring(value) end
        table.sort(parts)
        return table.concat(parts, " | ")
    end)
    self:Command("metrics", function()
        local metrics = self:_collectMetrics()
        return string.format("fps=%.0f ping=%.0fms memoria=%.1fMB uptime=%s titans=%d",
            metrics.FPS, metrics.Ping, metrics.Memory, clockString(metrics.Uptime), metrics.Titans)
    end)
end

function Diagnostics:_commandList()
    local names = {}
    for name in pairs(self.Commands) do names[#names + 1] = name end
    table.sort(names)
    return table.concat(names, ", ")
end

function Diagnostics:RunCommand(text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return "" end
    local name, argument = text:match("^(%S+)%s*(.*)$")
    self:_addLog("cmd", "> " .. text)
    local handler = self.Commands[name]
    if not handler then
        local message = "comando desconhecido: " .. name .. " (" .. self:_commandList() .. ")"
        self:_addLog("console", message)
        return message
    end
    local ok, result = pcall(handler, argument ~= "" and argument or nil)
    local message = ok and tostring(result or "ok") or ("erro: " .. tostring(result))
    self:_addLog("console", message)
    return message
end

-- ---------------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------------

local function statusMark(ok)
    if ok == true then return "[OK]" end
    if ok == false then return "[FALHA]" end
    return "[?]"
end

function Diagnostics:MetricsLine()
    local metrics = self:_collectMetrics()
    return string.format("FPS %3.0f | ping %3.0fms | mem %.0fMB | uptime %s | titans %d",
        metrics.FPS, metrics.Ping, metrics.Memory, clockString(metrics.Uptime), metrics.Titans)
end

function Diagnostics:Report()
    if self.Destroyed then return "diagnostico encerrado" end
    local ok, text = pcall(function() return self:_render() end)
    return ok and text or ("DepHub diagnostico: falha ao montar o relatorio: " .. tostring(text))
end

function Diagnostics:_render()
    local lines = {}
    lines[#lines + 1] = "===== DepHub console ====="
    lines[#lines + 1] = "modulo ativo: " .. tostring((envTable().__DEPHUB or {}).Mode or "?")
    lines[#lines + 1] = self:MetricsLine()
    lines[#lines + 1] = ""

    lines[#lines + 1] = "-- Ambiente --"
    local envKeys = {}
    for key in pairs(self.Environment) do envKeys[#envKeys + 1] = key end
    table.sort(envKeys)
    for _, key in ipairs(envKeys) do lines[#lines + 1] = key .. ": " .. self.Environment[key] end
    lines[#lines + 1] = ""

    lines[#lines + 1] = "-- Modulos --"
    for _, name in ipairs(self.ModuleOrder) do
        local record = self.Modules[name]
        if record then lines[#lines + 1] = statusMark(record.Ok) .. " " .. name .. ": " .. tostring(record.Detail) end
    end
    lines[#lines + 1] = ""

    lines[#lines + 1] = "-- Estrutura do jogo --"
    for _, label in ipairs(self.ProbeOrder) do
        local record = self.Probes[label]
        if record then lines[#lines + 1] = statusMark(record.Ok) .. " " .. label .. ": " .. tostring(record.Detail) end
    end
    lines[#lines + 1] = ""

    lines[#lines + 1] = "-- Estado das features (ao vivo) --"
    for _, name in ipairs(self.FeatureOrder) do
        local reader = self.Features[name]
        if type(reader) == "function" then
            local ok, value = pcall(reader)
            lines[#lines + 1] = name .. ": " .. (ok and tostring(value) or ("ERRO DE LEITURA: " .. tostring(value)))
        end
    end
    lines[#lines + 1] = ""

    if #self.WatchOrder > 0 then
        lines[#lines + 1] = "-- Observados --"
        for _, label in ipairs(self.WatchOrder) do lines[#lines + 1] = label .. ": " .. tostring(self.WatchValues[label] or "?") end
        lines[#lines + 1] = ""
    end

    if #self.Notes > 0 then
        lines[#lines + 1] = "-- Notas --"
        for _, note in ipairs(self.Notes) do lines[#lines + 1] = note end
        lines[#lines + 1] = ""
    end

    lines[#lines + 1] = "-- Log (" .. tostring(#self.Logs) .. " de " .. tostring(MAX_LOG) .. ") --"
    for _, entry in ipairs(self.Logs) do lines[#lines + 1] = "[" .. entry.T .. "][" .. entry.Kind .. "] " .. entry.Text end
    return table.concat(lines, "\n")
end

function Diagnostics:LogText()
    local lines = {}
    for _, entry in ipairs(self.Logs) do lines[#lines + 1] = "[" .. entry.T .. "][" .. entry.Kind .. "] " .. entry.Text end
    return table.concat(lines, "\n")
end

function Diagnostics:Summary()
    local okM, failM, pendM = 0, 0, 0
    for _, name in ipairs(self.ModuleOrder) do
        local record = self.Modules[name]
        if record then
            if record.Ok == true then okM = okM + 1
            elseif record.Ok == false then failM = failM + 1
            else pendM = pendM + 1 end
        end
    end
    local okP, failP = 0, 0
    for _, label in ipairs(self.ProbeOrder) do
        local record = self.Probes[label]
        if record then
            if record.Ok == true then okP = okP + 1 else failP = failP + 1 end
        end
    end
    return string.format("modulos %d ok / %d falha / %d pendente | estrutura %d ok / %d ausente | features %d | log %d",
        okM, failM, pendM, okP, failP, #self.FeatureOrder, #self.Logs)
end

function Diagnostics:Copy()
    local text = self:Report()
    local env = envTable()
    local copied = false
    for _, name in ipairs({"setclipboard", "toclipboard", "Clipboard"}) do
        local fn = (env and env[name]) or _G[name]
        if type(fn) == "function" then
            local ok = pcall(fn, text)
            if ok then copied = true break end
        end
    end
    pcall(print, text)
    return copied, text
end

-- ---------------------------------------------------------------------------
-- Live console UI
-- ---------------------------------------------------------------------------

function Diagnostics:_refreshViews()
    if self.Destroyed then return end
    if self.MetricsParagraph then pcall(function() self.MetricsParagraph:Set(nil, self:MetricsLine()) end) end
    if self.ReportParagraph then pcall(function() self.ReportParagraph:Set(nil, self:Report()) end) end
    if self.LogParagraph then pcall(function() self.LogParagraph:Set(nil, self:LogText()) end) end
end

function Diagnostics:Install(ui)
    if self.Installed or type(ui) ~= "table" or type(ui.CreateTab) ~= "function" then return false end
    local tab = ui:CreateTab("Debug", "All")
    if not tab then return false end
    self.Tab = tab
    self.UI = ui

    local live = tab:CreateSection("Ao vivo", "Left")
    if live then
        self.MetricsParagraph = live:CreateParagraph("Metricas", self:MetricsLine())
        if type(self.MetricsParagraph.Set) ~= "function" then self.MetricsParagraph = nil end
        self.ReportParagraph = live:CreateParagraph("Estado", self:Report())
        if type(self.ReportParagraph.Set) ~= "function" then self.ReportParagraph = nil end
    end

    local controls = tab:CreateSection("Controles", "Left")
    if controls then
        self.LogParagraph = controls:CreateParagraph("Log", self:LogText())
        if type(self.LogParagraph.Set) ~= "function" then self.LogParagraph = nil end
        controls:CreateToggle("Sniff de remotes", self.SniffEnabled, function(value) self.SniffEnabled = value == true end)
        controls:CreateToggle("Pausar log", false, function(value) self.LogPaused = value == true end)
        controls:CreateButton("Limpar log", function() self.Logs = {}; self:_refreshViews() end)
        controls:CreateButton("Copiar relatorio (clipboard + console)", function()
            local copied = self:Copy()
            if type(ui.Notify) == "function" then
                ui:Notify("Debug", copied and "Relatorio copiado." or "Relatorio enviado ao console (clipboard indisponivel).")
            end
            self:_refreshViews()
        end)
    end

    local terminal = tab:CreateSection("Terminal", "Right")
    if terminal then
        self.CommandInput = terminal:CreateInput("Comando", "digite e clique Executar (help)", "", function() end)
        terminal:CreateButton("Executar", function()
            local value = self.CommandInput and self.CommandInput.Value or ""
            self:RunCommand(value)
            if self.CommandInput then pcall(function() self.CommandInput.Control:Set("") end) end
            self:_refreshViews()
        end)
        terminal:CreateParagraph("Comandos", self:_commandList())
    end

    self.Installed = true
    self:_installLogHooks()
    -- A single refresh loop keeps every view current; it stops with Destroy.
    self.RenderTask = task.spawn(function()
        while not self.Destroyed do
            task.wait(REFRESH)
            if self.Destroyed then return end
            local ok, err = pcall(function()
                self:_pollWatches()
                self:_refreshViews()
            end)
            if not ok then self:_addLog("console", "loop: " .. tostring(err)) end
        end
    end)
    self:_addLog("console", "console de debug iniciado")
    return true
end

function Diagnostics:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    if self.RenderTask then pcall(task.cancel, self.RenderTask); self.RenderTask = nil end
    self:_removeLogHooks()
    self.Installed = false
    self.Tab = nil
    self.UI = nil
    self.MetricsParagraph = nil
    self.ReportParagraph = nil
    self.LogParagraph = nil
    self.CommandInput = nil
end

return Diagnostics
