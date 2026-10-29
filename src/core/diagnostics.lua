-- Shared DepHub diagnostics.
--
-- One place every game (and the loader) can hand information to, and one place
-- the player reads it from: a "Debug" tab present in every game, identical
-- everywhere, that answers "what is broken and why".
--
-- The module never inspects game internals on its own. It only renders what the
-- loader and the active backend report through the small API below, so a game
-- stays free to describe its own structure without the shell knowing about it:
--
--   Diag.SetEnvironment(env)          -- executor/place/version snapshot (loader)
--   Diag.Module(name, ok, detail)     -- "did this module load, and if not why"
--   Diag.RegisterModule(name)         -- declares a module so a missing report shows up
--   Diag.Probe(label, value, detail)  -- game-structure probe result
--   Diag.Feature(name, stateFn)       -- live feature state, read only when shown
--   Diag.Note(text)                   -- free-form line in the report
--   Diag.Log(kind, text)              -- captured hub log line
--   Diag.Report()                     -- whole snapshot as plain text
--   Diag.Install(ui)                  -- build the Debug tab on the shared UI
--
-- Every collector is pcall-guarded: a probe that throws must never take the
-- diagnostic (or the hub) down with it.
local Diagnostics = {}
Diagnostics.__index = Diagnostics

local function envTable()
    return type(getgenv) == "function" and getgenv() or _G
end

local function safe(call, ...)
    local ok, result = pcall(call, ...)
    if ok then return true, result end
    return false, tostring(result)
end

local MAX_LOG = 120

function Diagnostics.new()
    local self = setmetatable({
        Environment = {},
        Modules = {},
        ModuleOrder = {},
        Probes = {},
        ProbeOrder = {},
        Features = {},
        FeatureOrder = {},
        Notes = {},
        Logs = {},
        Installed = false,
        Tab = nil,
        StartedAt = os.clock()
    }, Diagnostics)
    return self
end

local function pushUnique(list, value)
    if not table.find(list, value) then list[#list + 1] = value end
end

-- Environment: a flat key/value snapshot the loader fills at startup.
function Diagnostics:SetEnvironment(values)
    if type(values) ~= "table" then return end
    for key, value in pairs(values) do
        self.Environment[tostring(key)] = tostring(value)
    end
end

-- A module is declared first (so it is visible even if it never reports), then
-- reported. Declaring twice keeps the latest detail string.
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
end

-- A structure probe: "does Workspace.Titans.Hitboxes.Hit.Nape exist". The value
-- is any human detail; ok decides the marker. Same probe label overwrites.
function Diagnostics:Probe(label, ok, detail)
    label = tostring(label)
    pushUnique(self.ProbeOrder, label)
    self.Probes[label] = {Ok = ok == true, Detail = detail ~= nil and tostring(detail) or (ok and "ok" or "ausente")}
end

-- A live feature: the function is called each time the report is rendered, so
-- the value shown is current, and a throwing reader is reported as an error.
function Diagnostics:Feature(name, reader)
    name = tostring(name)
    pushUnique(self.FeatureOrder, name)
    self.Features[name] = reader
end

function Diagnostics:Note(text)
    self.Notes[#self.Notes + 1] = tostring(text)
end

function Diagnostics:Log(kind, text)
    self.Logs[#self.Logs + 1] = {Kind = tostring(kind or "log"), Text = tostring(text)}
    if #self.Logs > MAX_LOG then table.remove(self.Logs, 1) end
    self:_refreshLogView()
end

-- ---------------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------------

local function statusMark(ok)
    if ok == true then return "[OK]" end
    if ok == false then return "[FALHA]" end
    return "[?]"
end

function Diagnostics:Render()
    local lines = {}
    lines[#lines + 1] = "===== DepHub diagnostico ====="
    lines[#lines + 1] = "modulo ativo: " .. tostring((envTable().__DEPHUB or {}).Mode or "?")
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

    lines[#lines + 1] = "-- Estado das features --"
    for _, name in ipairs(self.FeatureOrder) do
        local reader = self.Features[name]
        if type(reader) == "function" then
            local ok, value = safe(reader)
            lines[#lines + 1] = name .. ": " .. (ok and tostring(value) or ("ERRO DE LEITURA: " .. tostring(value)))
        end
    end
    lines[#lines + 1] = ""

    if #self.Notes > 0 then
        lines[#lines + 1] = "-- Notas --"
        for _, note in ipairs(self.Notes) do lines[#lines + 1] = note end
        lines[#lines + 1] = ""
    end

    lines[#lines + 1] = "-- Log (" .. tostring(#self.Logs) .. " ultimas) --"
    for _, entry in ipairs(self.Logs) do lines[#lines + 1] = "[" .. entry.Kind .. "] " .. entry.Text end

    return table.concat(lines, "\n")
end

function Diagnostics:Report()
    local ok, text = safe(function() return self:Render() end)
    if ok then return text end
    return "DepHub diagnostico: falha ao montar o relatorio: " .. tostring(text)
end

function Diagnostics:Copy()
    local text = self:Report()
    local env = envTable()
    local copied = false
    for _, name in ipairs({"setclipboard", "toclipboard", "Clipboard"}) do
        local fn = (env and env[name]) or _G[name]
        if type(fn) == "function" then
            local ok = safe(fn, text)
            if ok then copied = true break end
        end
    end
    local okPrint = safe(print, text)
    return copied, text, okPrint
end

local function countByStatus(order, records)
    local okCount, failCount, pending = 0, 0, 0
    for _, name in ipairs(order) do
        local record = records[name]
        if record then
            if record.Ok == true then okCount = okCount + 1
            elseif record.Ok == false then failCount = failCount + 1
            else pending = pending + 1 end
        end
    end
    return okCount, failCount, pending
end

function Diagnostics:Summary()
    local okM, failM, pendM = countByStatus(self.ModuleOrder, self.Modules)
    local okP, failP = countByStatus(self.ProbeOrder, self.Probes)
    return string.format("modulos: %d ok / %d falha / %d pendente | estrutura: %d ok / %d ausente | features: %d | log: %d",
        okM, failM, pendM, okP, failP, #self.FeatureOrder, #self.Logs)
end

function Diagnostics:_refreshLogView()
    if self.LogParagraph and type(self.LogParagraph.Set) == "function" then
        pcall(function() self.LogParagraph:Set(nil, self:Report()) end)
    end
end

-- ---------------------------------------------------------------------------
-- UI
-- ---------------------------------------------------------------------------

-- Builds the shared "Debug" tab. Called by the loader once the window exists,
-- so every game gets the same diagnostics surface with no per-game code.
function Diagnostics:Install(ui)
    if self.Installed or type(ui) ~= "table" or type(ui.CreateTab) ~= "function" then return false end
    local tab = ui:CreateTab("Debug", "All")
    if not tab then return false end
    self.Tab = tab

    local overview = tab:CreateSection("Resumo", "Left")
    if overview then
        self.SummaryParagraph = overview:CreateParagraph("Diagnostico", self:Summary())
        if type(self.SummaryParagraph.Set) ~= "function" then self.SummaryParagraph = nil end
        self.LogParagraph = overview:CreateParagraph("Relatorio", self:Report())
        if type(self.LogParagraph.Set) ~= "function" then self.LogParagraph = nil end
        overview:CreateButton("Copiar relatorio", function()
            local copied, text = self:Copy()
            if type(ui.Notify) == "function" then
                ui:Notify("Debug", copied and "Relatorio copiado para a area de transferencia." or "Relatorio enviado ao console (clipboard indisponivel).")
            end
            if self.LogParagraph then pcall(function() self.LogParagraph:Set(nil, text) end) end
        end)
        overview:CreateButton("Atualizar resumo", function()
            if self.SummaryParagraph then pcall(function() self.SummaryParagraph:Set(nil, self:Summary()) end) end
            if self.LogParagraph then pcall(function() self.LogParagraph:Set(nil, self:Report()) end) end
        end)
    end

    self.Installed = true
    return true
end

function Diagnostics:Destroy()
    self.Installed = false
    self.Tab = nil
    self.SummaryParagraph = nil
    self.LogParagraph = nil
end

return Diagnostics
