-- DepHub adapter for the vendored Blox Fruits modules.
--
-- The open-source script ships a main.lua that builds its own window, its own
-- tab list and its own config page. Inside DepHub none of that exists: the
-- DepHub panel owns the screen, so this factory does the wiring main.lua used to
-- do (Core -> modules) but with no presentation at all.
--
-- Order matters: core first, then the feature modules, then the two modules
-- that read UI._currentSea at init (info, shop). Every module is loaded through
-- DepHub's own httpGet so the bundled sources resolve without the network.

local Factory = {}

local ORDER = {"core", "teleport", "combat", "farm", "player", "fruits", "shop", "events", "extras", "info"}

local function readSource(loader, path)
    local ok, source = pcall(loader, path)
    if not ok then return false, tostring(source) end
    if type(source) ~= "string" or #source == 0 then return false, "empty source" end
    return true, source
end

function Factory.new(context)
    context = context or {}
    local vendors = context.Vendors or {}
    local loadSource = context.LoadSource
    if type(loadSource) ~= "function" then return false, "adapter requires LoadSource" end

    -- The vendored modules read their globals (game, task) from the shared
    -- environment, because the loader compiles each one with loadstring and
    -- a chunk has no way to see the loader's locals. Publish the runtime the
    -- same way before any module is compiled. Each target is written under
    -- pcall: executors hand back readonly tables for some of these, and one
    -- failure must not stop the others.
    local runtime = {game = vendors.game, task = vendors.task}
    local published = false
    for _, target in ipairs({
        (type(getgenv) == "function") and select(2, pcall(getgenv)) or nil,
        shared,
        _G
    }) do
        if type(target) == "table" then
            local ok = pcall(function() target.__DEPHUB_OSS_RUNTIME = runtime end)
            published = published or ok
        end
    end
    if not published then return false, "no writable shared environment for __DEPHUB_OSS_RUNTIME" end

    local prefix = context.PathPrefix or "src/games/features/bloxfruits/oss/"
    local State = {Destroyed = false, Modules = {}, Errors = {}, Version = context.Version or "1.0"}
    local log = context.Warn or function() end

    local okUI, uiSource = readSource(loadSource, prefix .. "ui-headless.lua")
    if not okUI then return false, "ui-headless: " .. tostring(uiSource) end
    local uiChunk, uiError = loadstring(uiSource)
    if not uiChunk then return false, "ui-headless: " .. tostring(uiError) end
    local okRunUI, UI = pcall(uiChunk)
    if not okRunUI or type(UI) ~= "table" then return false, "ui-headless: " .. tostring(UI) end
    State.UI = UI

    for _, name in ipairs(ORDER) do
        local path = prefix .. name .. ".lua"
        local okSource, source = readSource(loadSource, path)
        if not okSource then
            State.Errors[#State.Errors + 1] = path .. ": " .. tostring(source)
            return false, "required module failed to load: " .. path
        end
        local chunk, chunkError = loadstring(source)
        if not chunk then
            State.Errors[#State.Errors + 1] = path .. ": " .. tostring(chunkError)
            return false, "required module failed to compile: " .. path
        end
        local okBuild, module = pcall(chunk, vendors)
        if not okBuild or type(module) ~= "table" then
            State.Errors[#State.Errors + 1] = path .. ": " .. tostring(module)
            return false, "required module failed to run: " .. path
        end
        State.Modules[name] = module
        if name == "core" then State.Core = module end
    end

    local Core = State.Core
    Core.configure({verbose = false})

    UI.build(Core)
    -- Every tab the modules call UI.page() for has to exist before they init,
    -- because addTab is what creates the page object they attach controls to.
    for _, tab in ipairs({
        {"Info", "Player and script info"},
        {"Farm", "Level farm and quests", "Sea1"},
        {"Farm 2", "Level farm and quests", "Sea2"},
        {"Farm 3", "Level farm and quests", "Sea3"},
        {"PVP", "Combat, aura, aimbot, players"},
        {"Teleport", "Move, islands and waypoints"},
        {"Sea", "Sea travel and transitions", "Sea1,Sea2"},
        {"Fruit", "Fruit ESP, collect and dealer"},
        {"Shop", "Buy Sea 1 items", "Sea1"},
        {"Shop 2", "Buy Sea 2 items", "Sea2"},
        {"Shop 3", "Buy Sea 3 items", "Sea3"},
        {"Raids/Events", "Raids, sea events, leviathan", "Sea2,Sea3"},
        {"Extras", "Race V4, awakening, special bosses", "Sea3"},
        {"Player", "Player ESP and mobility"},
        {"Config", "Save and restore settings"},
        {"Logs", "Actions and proofs"}
    }) do
        UI.addTab(tab[1], tab[2], tab[3])
    end

    for _, name in ipairs(ORDER) do
        if name ~= "core" then
            local module = State.Modules[name]
            if type(module.init) == "function" then
                local ok, err = pcall(module.init, Core, UI)
                if not ok then
                    State.Errors[#State.Errors + 1] = name .. ".init: " .. tostring(err)
                    log("Blox Fruits module init failed (" .. name .. "): " .. tostring(err))
                end
            end
        end
    end

    Core.register("ui", UI)
    Core.info("DepHub adapter loaded")

    local restored = false
    pcall(function() restored = Core.loadLastConfig() end)
    State.RestoredConfig = restored == true

    -- The sea changes the tab visibility and both info.lua and shop.lua read it
    -- during init, so publish the current sea and expose the hook the backend
    -- uses when the game reports a change.
    local sea = context.Sea or "Sea1"
    pcall(function() UI.setSea(sea) end)
    State.Sea = sea

    function State:SetSea(nextSea)
        if self.Destroyed or type(nextSea) ~= "string" then return false end
        self.Sea = nextSea
        pcall(function() UI.setSea(nextSea) end)
        return true
    end

    function State:GetControls()
        return self.UI and self.UI._controls or {}
    end

    function State:GetControl(key)
        local controls = self:GetControls()
        return controls[key]
    end

    function State:ListControls()
        return self.UI and self.UI._defs or {}
    end

    function State:SetControl(key, value)
        local control = self:GetControl(key)
        if not control then return false end
        local ok = pcall(control.set, value)
        return ok
    end

    function State:GetControlValue(key)
        local control = self:GetControl(key)
        if not control then return nil end
        local ok, value = pcall(control.get)
        return ok and value or nil
    end

    function State:GetStatus()
        return {
            Version = self.Version,
            Sea = self.Sea,
            RestoredConfig = self.RestoredConfig,
            Controls = self.UI and #self.UI._defs or 0,
            Modules = self.Modules,
            Errors = self.Errors
        }
    end

    function State:SaveConfig(name)
        local ok, result = pcall(Core.saveNamedConfig, name)
        return ok and result == true
    end

    function State:LoadConfig(name)
        local ok, result = pcall(Core.loadNamedConfig, name)
        return ok and result == true
    end

    function State:ListConfigs()
        local ok, result = pcall(Core.listConfigs)
        if ok and type(result) == "table" then return result end
        return {}
    end

    function State:Unload()
        if self.Destroyed then return end
        self.Destroyed = true
        pcall(function() Core.unload() end)
        pcall(function() UI.stop() end)
        self.Modules = {}
    end

    function State:Destroy()
        self:Unload()
        if context.Env then
            if context.Env.__DEPHUB_BLOXFRUITS_OSS == self then context.Env.__DEPHUB_BLOXFRUITS_OSS = nil end
            if context.Env.BF == Core then context.Env.BF = nil end
        end
    end

    return State
end

return Factory
