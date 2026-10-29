local game = game
local type = type
local tostring = tostring

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local env = type(getgenv) == "function" and getgenv() or _G
local report = (env.__DEPHUB and type(env.__DEPHUB.Log) == "function") and env.__DEPHUB.Log or function() end

-- Backend for the vendored open-source Blox Fruits script.
--
-- It owns no presentation: the DepHub frontend renders from this contract and
-- the feature state lives in the adapter's control registry. Every method is a
-- thin forwarder, so there is exactly one source of truth for a toggle.

local OSS_PATH = "src/games/features/bloxfruits/oss/"
local VERSION = "1.0.0"

local previous = type(env.__DEPHUB_BLOXFRUITS_OSS) == "table" and env.__DEPHUB_BLOXFRUITS_OSS or nil
if previous and type(previous.Destroy) == "function" then pcall(previous.Destroy, previous) end

local sourceBase = (env.__DEPHUB or {}).SourceBaseURL or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"

-- Prefer the bundle's resolver published on the shared environment. It is only
-- present in a bundled build; a source checkout resolves through the loader's
-- own fetch path, so fall back to the executor primitives in that order.
local function fetch(path)
    local url = sourceBase .. path
    local resolver = (type(env.__dephubHttpGet) == "function" and env.__dephubHttpGet)
        or (type(env.__DEPHUB_HTTP_GET) == "function" and env.__DEPHUB_HTTP_GET)
        or (type(_G.__dephubHttpGet) == "function" and _G.__dephubHttpGet)
        or (type(_G.__DEPHUB_HTTP_GET) == "function" and _G.__DEPHUB_HTTP_GET)
    if resolver then
        local ok, source = pcall(resolver, url)
        if ok and type(source) == "string" and #source > 0 then return true, source end
    end
    local ok, source = pcall(function() return game:HttpGet(url) end)
    if ok and type(source) == "string" and #source > 0 then return true, source end
    return false, tostring(source)
end

local function loadFactory(path)
    local okFetch, source = fetch(path)
    if not okFetch then return false, "fetch: " .. tostring(source) end
    local chunk, chunkError = loadstring(source)
    if not chunk then return false, "compile: " .. tostring(chunkError) end
    local okRun, factory = pcall(chunk)
    if not okRun or type(factory) ~= "table" then return false, "run: " .. tostring(factory) end
    return true, factory
end

-- The adapter's LoadSource contract is "hand me the source string", while fetch
-- reports (ok, source). Wrap so a missing module surfaces the failing path.
local function loadSource(path)
    local ok, source = fetch(path)
    if ok then return source end
    return nil, tostring(source)
end

local LocalPlayer = game:GetService("Players").LocalPlayer
if not LocalPlayer then
    report("BloxFruits: LocalPlayer ausente")
    return false
end

local okFactory, Adapter = loadFactory(OSS_PATH .. "adapter.lua")
if not okFactory then
    report("BloxFruits: adapter falhou: " .. tostring(Adapter))
    return false
end

local Context = {
    Vendors = {game = game, task = task},
    Env = env,
    Sea = "Sea1",
    Version = VERSION,
    Warn = report,
    PathPrefix = OSS_PATH,
    LoadSource = loadSource
}

local okNew, State, reason = pcall(Adapter.new, Context)
if not okNew or type(State) ~= "table" then
    report("BloxFruits: OSS nao inicializou: " .. tostring(State) .. (reason and (" | " .. tostring(reason)) or ""))
    return false
end

env.__DEPHUB_BLOXFRUITS_OSS = State
env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.BloxFruits = State
env.__DEPHUB.BloxFruitsOSS = State

-- Public toggles: one per control the modules registered, so a frontend can
-- mirror them with the generic SetToggle/GetToggle path it already uses.
State.Toggles = {}
State.ToggleLabels = {}
for _, definition in ipairs(State:ListControls()) do
    if definition.kind == "toggle" then
        State.Toggles[definition.key] = definition.get() == true
        State.ToggleLabels[definition.key] = definition.page .. " / " .. definition.title
    end
end

function State:SetToggle(name, enabled)
    if self.Destroyed or type(name) ~= "string" then return false end
    local control = self:GetControl(name)
    if not control or control.kind ~= "toggle" then return false end
    if not self:SetControl(name, enabled == true) then return false end
    self.Toggles[name] = control.get() == true
    return true
end

function State:GetToggle(name)
    if self.Destroyed then return false end
    local control = self:GetControl(name)
    if not control then return self.Toggles[name] == true end
    return control.get() == true
end

function State:GetValue(name, fallback)
    local value = self:GetControlValue(name)
    if value == nil then return fallback end
    return value
end

function State:SetValue(name, value)
    local ok = self:SetControl(name, value)
    local control = self:GetControl(name)
    if ok and control and control.kind == "toggle" then self.Toggles[name] = control.get() == true end
    return ok
end

-- Core.spawn hands every loop back so the frontend's Rejoin can restart the
-- work the game cancelled on teleport (resume.lua used to call this).
local CoreThreads = (State.Core and State.Core._threads) or {}

local function resumeAll()
    local resumed = 0
    for _, thread in ipairs(CoreThreads) do
        if type(thread) == "thread" and coroutine.status(thread) == "suspended" then
            local ok = pcall(task.spawn, thread)
            if ok then resumed += 1 end
        end
    end
    return resumed
end

State.ResumeAll = resumeAll

function State:Rejoin()
    self:ResumeAll()
    return true
end

function State:ServerHop()
    local ok, module = pcall(function() return self.Modules and self.Modules.events end)
    if ok and type(module) == "table" and type(module.serverHop) == "function" then
        pcall(module.serverHop, module)
        return true
    end
    return false
end

function State:Destroy()
    if self.Destroyed then return end
    pcall(function() self:Unload() end)
    self.Destroyed = true
    if env.__DEPHUB_BLOXFRUITS_OSS == self then env.__DEPHUB_BLOXFRUITS_OSS = nil end
    if env.__DEPHUB and env.__DEPHUB.BloxFruits == self then env.__DEPHUB.BloxFruits = nil end
    if env.__DEPHUB and env.__DEPHUB.BloxFruitsOSS == self then env.__DEPHUB.BloxFruitsOSS = nil end
end


local visual = env.__DEPHUB and env.__DEPHUB.UI
local uiModel = State.UI
local tabOrder = {
    "Info", "Farm", "Farm 2", "Farm 3", "PVP", "Teleport", "Sea",
    "Fruit", "Shop", "Shop 2", "Shop 3", "Raids/Events", "Extras",
    "Player", "Config"
}
local renderedTabs = {}
local renderedSections = {}
local function splitSeas(value)
    local result = {}
    for sea in string.gmatch(tostring(value or ""), "[^,]+") do
        result[string.gsub(sea, "%s+", "")] = true
    end
    return result
end
local function tabNameFor(pageName, pageSea, controlSea)
    if controlSea and not pageSea then
        local seas = splitSeas(controlSea)
        if seas.Sea1 and seas.Sea2 and seas.Sea3 then return pageName end
        if seas.Sea2 and seas.Sea3 then return pageName .. " · Sea 2/3" end
        if seas.Sea1 then return pageName .. " · Sea 1" end
        if seas.Sea2 then return pageName .. " · Sea 2" end
        if seas.Sea3 then return pageName .. " · Sea 3" end
    end
    return pageName
end
local function ensureTab(name, sea)
    if renderedTabs[name] then
        if sea then renderedTabs[name].Sea = sea end
        return renderedTabs[name]
    end
    local tab = visual:CreateTab(name)
    local record = {Tab = tab, Sea = sea, Name = name}
    renderedTabs[name] = record
    return record
end
local function sectionFor(tabRecord, pageName)
    local key = tabRecord.Name .. "|" .. pageName
    if renderedSections[key] then return renderedSections[key] end
    local section = tabRecord.Tab:CreateSection(pageName == tabRecord.Name and "Controls" or pageName)
    renderedSections[key] = section
    return section
end
local function renderDefinition(definition, section)
    local title = tostring(definition.title or definition.key)
    local function set(value) State:SetControl(definition.key, value) end
    if definition.kind == "toggle" then
        section:CreateToggle(title, definition.get and definition.get() == true, set)
    elseif definition.kind == "slider" then
        section:CreateSlider(title, definition.min, definition.max, definition.get and definition.get() or definition.default, set)
    elseif definition.kind == "dropdown" then
        section:CreateDropdown(title, definition.options or {}, definition.get and definition.get() or definition.default, set)
    elseif definition.kind == "button" then
        section:CreateButton(title, function() set(true) end)
    elseif definition.kind == "textbox" then
        section:CreateInput(title, title, definition.get and definition.get() or "", set)
    end
end
if type(visual) == "table" and type(visual.CreateTab) == "function" then
    for _, pageName in ipairs(tabOrder) do
        local page = uiModel.tabs[pageName]
        if page then
            local pageSea = page.sea
            if #page.controls == 0 then
                local record = ensureTab(pageName, pageSea)
                local section = sectionFor(record, pageName)
                if pageName == "Info" then
                    section:CreateParagraph("DepHub Blox Fruits", "Interface dinâmica por Sea. Apenas Anti-AFK fica ligado por padrão.")
                elseif pageName == "Config" then
                    local nameInput = section:CreateInput("Config name", "Nome da configuração", "default", function(value) end)
                    section:CreateButton("Save config", function()
                        local name = tostring(nameInput.Value or "default")
                        if State:SaveConfig(name) then visual:Notify("Config", "Configuração salva: " .. name) else visual:Notify("Config", "Não foi possível salvar.") end
                    end)
                    section:CreateButton("Load config", function()
                        local name = tostring(nameInput.Value or "default")
                        if State:LoadConfig(name) then visual:Notify("Config", "Configuração carregada: " .. name) else visual:Notify("Config", "Não foi possível carregar.") end
                    end)
                end
            else
                for _, definition in ipairs(page.controls) do
                    local effectiveSea = definition.sea or pageSea
                    local tabName = tabNameFor(pageName, pageSea, definition.sea)
                    local record = ensureTab(tabName, effectiveSea)
                    local section = sectionFor(record, pageName)
                    renderDefinition(definition, section)
                end
            end
        end
    end
    local function applySea(sea)
        local current = tostring(sea or "Sea1")
        for _, record in pairs(renderedTabs) do
            local visible = true
            if record.Sea then
                local allowed = splitSeas(record.Sea)
                visible = allowed[current] == true
            end
            record.Tab.Visible = visible
            if record.Tab.Control and record.Tab.Control.Asset then record.Tab.Control.Asset.Visible = visible end
            if record.Tab.Control and record.Tab.Control.ButtonAsset then record.Tab.Control.ButtonAsset.Visible = visible end
        end
        for _, record in pairs(renderedTabs) do
            if record.Tab.Visible and record.Tab.Control and record.Tab.Control.Asset and record.Tab.Control.ButtonAsset then
                pcall(function() visual.Bracket.Utilities.ChooseTab(record.Tab.Control.ButtonAsset, record.Tab.Control.Asset) end)
                break
            end
        end
    end
    if type(uiModel.onSea) == "function" then uiModel.onSea(applySea) else applySea(State.Sea or "Sea1") end
    State.UIFrontend = visual
    State.UITabs = renderedTabs
end

return State
