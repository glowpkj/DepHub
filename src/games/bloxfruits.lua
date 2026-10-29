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
    local cb = tostring((env.__DEPHUB or {}).SourceCacheBust or "")
    local url = sourceBase .. path .. (cb ~= "" and ("?cb=" .. cb) or "")
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
local pageAliases = {
    ["Info"] = "Home",
    ["Farm"] = "Farm",
    ["Farm 2"] = "Farm",
    ["Farm 3"] = "Farm",
    ["PVP"] = "Combat",
    ["Teleport"] = "Teleport",
    ["Sea"] = "Travel",
    ["Fruit"] = "Fruits",
    ["Shop"] = "Shop",
    ["Shop 2"] = "Shop",
    ["Shop 3"] = "Shop",
    ["Raids/Events"] = "Events",
    ["Extras"] = "Extras",
    ["Player"] = "Player",
    ["Config"] = "Settings"
}
local tabOrder = {"Info", "Farm", "Farm 2", "Farm 3", "PVP", "Teleport", "Sea", "Fruit", "Shop", "Shop 2", "Shop 3", "Raids/Events", "Extras", "Player", "Config"}
local renderedTabs = {}
local renderedSections = {}
local function splitSeas(value)
    local result = {}
    for sea in string.gmatch(tostring(value or ""), "[^,]+") do
        result[string.gsub(sea, "%s+", "")] = true
    end
    return result
end
local function categoryForControl(sea)
    local value = tostring(sea or "All")
    if value == "All" or value == "" then return "General" end
    local seas = splitSeas(value)
    if seas.Sea1 and seas.Sea2 and seas.Sea3 then return "General" end
    if seas.Sea1 and seas.Sea2 then return "Sea 1/2" end
    if seas.Sea2 and seas.Sea3 then return "Sea 2/3" end
    if seas.Sea1 then return "Sea 1" end
    if seas.Sea2 then return "Sea 2" end
    if seas.Sea3 then return "Sea 3" end
    return "General"
end
-- Tabs that must stay reachable no matter which sea the player is on. Teleport
-- is the way to travel between seas (it holds the Sea 1/2/3 waypoints), and the
-- Info/PVP/Player/Config pages are game-wide rather than belonging to a sea.
local ALWAYS_VISIBLE = {
    Home = true, Combat = true, Teleport = true, Player = true, Settings = true
}

local function ensureTab(name, sea)
    local category = categoryForControl(sea)
    -- A logical tab can be shared by more than one sea (Farm, Shop). The sea
    -- scope stored on the shell tab is what decides whether it is shown, so a
    -- tab that carries a sea keeps it; the always-visible pages drop their scope.
    local scope = ALWAYS_VISIBLE[name] and nil or sea
    local key = category .. "|" .. name
    if renderedTabs[key] ~= nil then return renderedTabs[key] or nil end
    -- The Blox Fruits backend owns its sea categories: the shared shell only
    -- creates "General", so this backend registers the seas it uses.
    if type(visual.CreateCategory) == "function" then visual:CreateCategory(category) end
    local tab = visual:CreateTab(name, category, scope)
    if not tab then
        -- Remember the failure so the next control in this group does not try
        -- again: without this the same tab is retried for every control.
        renderedTabs[key] = false
        report("BloxFruits: não foi possível criar a aba " .. name .. " (" .. category .. ")")
        return nil
    end
    local record = {Tab = tab, Sea = scope, Name = name, Category = category, Key = key, Columns = {Left = 0, Right = 0}}
    renderedTabs[key] = record
    return record
end
local function groupFor(definition)
    local key = tostring(definition.key or ""):lower()
    local title = tostring(definition.title or ""):lower()
    local value = key .. " " .. title
    if value:find("config") or value:find("save") or value:find("load") then return "Configuration" end
    if value:find("quest") or value:find("level") or value:find("farm") or value:find("mastery") or value:find("stat") or value:find("bring") or value:find("collect") then return "Farming" end
    if value:find("fruit") or value:find("dealer") or value:find("spin") or value:find("storage") then return "Fruits" end
    if value:find("raid") or value:find("event") or value:find("leviathan") or value:find("mirage") or value:find("sea beast") or value:find("bones") then return "Events" end
    if value:find("island") or value:find("teleport") or value:find("waypoint") or value:find("travel") or value:find("sea travel") or value:find("boss") then return "Travel" end
    if value:find("player") or value:find("walk") or value:find("speed") or value:find("jump") or value:find("esp") or value:find("afk") or value:find("ken") or value:find("buso") then return "Player" end
    if value:find("shop") or value:find("buy") or value:find("weapon") or value:find("style") or value:find("accessory") or value:find("race") then return "Shop & Upgrades" end
    if value:find("aim") or value:find("attack") or value:find("combat") or value:find("aura") or value:find("bounty") or value:find("pvp") or value:find("skill") or value:find("stun") or value:find("target") or value:find("sword") or value:find("gun") then return "Combat" end
    if value:find("info") or value:find("status") or value:find("version") then return "Overview" end
    return "Other"
end
local function sectionFor(tabRecord, group)
    if not tabRecord or not tabRecord.Tab then return nil end
    local key = tabRecord.Key .. "|" .. group
    if renderedSections[key] then return renderedSections[key] end
    local column = tabRecord.Columns.Left <= tabRecord.Columns.Right and "Left" or "Right"
    tabRecord.Columns[column] += 1
    local section = tabRecord.Tab:CreateSection(group, column)
    renderedSections[key] = section
    return section
end
local function renderDefinition(definition, section)
    local title = tostring(definition.title or definition.key or "Control")
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
            local logicalName = pageAliases[pageName] or pageName
            if #page.controls == 0 then
                local record = ensureTab(logicalName, page.sea)
                if pageName == "Info" then
                    local section = sectionFor(record, "Overview")
                    if section then section:CreateParagraph("DepHub", "Controles organizados por categoria. Apenas Anti-AFK fica ligado por padrão.") end
                    local seaSection = sectionFor(record, "Sea")
                    if seaSection then
                        -- Single sea selector. The game reports the current sea
                        -- automatically (info.lua polls Realm) and this lets the
                        -- player override it; both paths end in applySea, which
                        -- filters the tabs down to the chosen sea.
                        local seaLabels = {Sea1 = "Sea 1", Sea2 = "Sea 2", Sea3 = "Sea 3"}
                        local seaValues = {["Sea 1"] = "Sea1", ["Sea 2"] = "Sea2", ["Sea 3"] = "Sea3"}
                        local currentLabel = seaLabels[State.Sea] or "Sea 1"
                        seaSection:CreateDropdown("Sea", {"Sea 1", "Sea 2", "Sea 3"}, currentLabel, function(value)
                            State:SetSea(seaValues[tostring(value)] or "Sea1")
                            visual:Notify("Sea", "Conteúdo filtrado para " .. tostring(value))
                        end)
                    end
                elseif pageName == "Config" then
                    local section = sectionFor(record, "Configuration")
                    if section then
                        local configName = "default"
                        section:CreateInput("Nome da configuração", "Nome da configuração", configName, function(value) configName = tostring(value or "default") end)
                        section:CreateButton("Salvar configuração", function()
                            local name = tostring(configName ~= "" and configName or "default")
                            if State:SaveConfig(name) then visual:Notify("Config", "Configuração salva: " .. name) else visual:Notify("Config", "Não foi possível salvar.") end
                        end)
                        section:CreateButton("Carregar configuração", function()
                            local name = tostring(configName ~= "" and configName or "default")
                            if State:LoadConfig(name) then visual:Notify("Config", "Configuração carregada: " .. name) else visual:Notify("Config", "Não foi possível carregar.") end
                        end)
                    end
                end
            else
                for _, definition in ipairs(page.controls) do
                    local sea = definition.sea or page.sea
                    local record = ensureTab(logicalName, sea)
                    local section = sectionFor(record, groupFor(definition))
                    if section then renderDefinition(definition, section) end
                end
            end
        end
    end
    local function applySea(sea)
        if type(visual.SetCurrentSea) == "function" then visual:SetCurrentSea(sea or "Sea1") end
    end
    if type(uiModel.onSea) == "function" then uiModel.onSea(applySea) else applySea(State.Sea or "Sea1") end
    State.UIFrontend = visual
    State.UITabs = renderedTabs
end

-- Report the Blox Fruits backend into the shared Debug tab. Modules are
-- reported by load outcome, then the control registry is exposed as live
-- features so the player can see exactly which toggles are on and why a module
-- failed to load.
do
    local Diag = env.__DEPHUB and env.__DEPHUB.Diagnostics
    if Diag and type(Diag.RegisterModule) == "function" then
        Diag:SetEnvironment({["BloxFruits sea"] = tostring(State.Sea or "?")})
        local modules = State.Modules or {}
        for _, name in ipairs({"core", "teleport", "combat", "farm", "player", "fruits", "shop", "events", "extras", "info"}) do
            Diag:RegisterModule("features/bloxfruits/oss/" .. name .. ".lua")
            local loaded = type(modules[name]) == "table"
            local detail = loaded and "carregado" or "ausente"
            if not loaded and type(State.Errors) == "table" and State.Errors[name] ~= nil then detail = tostring(State.Errors[name]) end
            Diag:Module("features/bloxfruits/oss/" .. name .. ".lua", loaded, detail)
        end
        local toggleCount, onCount = 0, 0
        for key, value in pairs(State.Toggles or {}) do
            toggleCount = toggleCount + 1
            if value then onCount = onCount + 1 end
        end
        Diag:Note("BloxFruits toggles: " .. tostring(onCount) .. " ligados de " .. tostring(toggleCount))
        Diag:Feature("BloxFruits.Sea", function() return tostring(State.Sea or "?") end)
        Diag:Feature("BloxFruits.Toggles ligados", function()
            local parts = {}
            for key, value in pairs(State.Toggles or {}) do
                if value then parts[#parts + 1] = key end
            end
            table.sort(parts)
            return #parts > 0 and table.concat(parts, ", ") or "nenhum"
        end)
        Diag:Feature("BloxFruits.LastError", function() return tostring(State.LastError or "none") end)
        if type(Diag.Watch) == "function" then
            Diag:Watch("BloxFruits sea", function() return tostring(State.Sea or "?") end)
            Diag:Watch("BloxFruits modulos", function()
                local loaded = 0
                for _, module in pairs(State.Modules or {}) do if type(module) == "table" then loaded = loaded + 1 end end
                return loaded
            end)
        end
        if type(Diag.Command) == "function" then
            Diag:Command("bf", function()
                return "sea=" .. tostring(State.Sea or "?") .. " modulos=" .. tostring((function()
                    local n = 0
                    for _, module in pairs(State.Modules or {}) do if type(module) == "table" then n = n + 1 end end
                    return n
                end)())
            end)
        end
    end
end

return State
