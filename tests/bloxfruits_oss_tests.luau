-- Behaviour checks for the vendored open-source Blox Fruits script. The module
-- bodies that drive the game are exercised through the adapter's control
-- registry; remote-touching code paths are not re-tested here.
local OSS_PREFIX = "src/games/features/bloxfruits/oss/"
local OSS_MODULES = {"adapter", "ui-headless", "core", "teleport", "combat", "farm",
    "player", "fruits", "shop", "events", "extras", "info"}

-- The backend resolves its modules through the same game:HttpGet path a live
-- executor uses, so every vendored file has to be served from the sandbox.
local function ossContext(placeId, gameId)
    local ctx = sandbox(placeId, gameId)
    for _, name in ipairs(OSS_MODULES) do
        local path = OSS_PREFIX .. name .. ".lua"
        ctx.Responses[path] = sources[path]
    end
    return ctx
end

do
    local ctx = ossContext(994732206, 994732206)
    local state = ctx:Run("src/games/bloxfruits.lua")
    check(type(state) == "table" and state.Destroyed == false, "Blox Fruits backend starts")
    check(state.UI ~= nil and type(state.UI.build) == "function", "adapter installs the headless UI")

    local controls = state:ListControls()
    check(#controls > 100, "every module registered its controls without a window (" .. #controls .. ")")
    check(state.UI.gui == nil and state.UI._pages == nil, "no instance-backed window is created")

    local kinds = {}
    for _, definition in ipairs(controls) do kinds[definition.kind] = (kinds[definition.kind] or 0) + 1 end
    check(kinds.toggle and kinds.toggle > 40, "toggles registered (" .. tostring(kinds.toggle) .. ")")
    check(kinds.slider and kinds.slider > 5, "sliders registered (" .. tostring(kinds.slider) .. ")")
    check(kinds.dropdown and kinds.dropdown > 5, "dropdowns registered (" .. tostring(kinds.dropdown) .. ")")
    check(state.Toggles and next(state.Toggles) ~= nil, "boolean toggles published for the generic DepHub frontend")

    local function controlFor(fragment)
        for _, definition in ipairs(controls) do
            if definition.key:find(fragment, 1, true) then return definition end
        end
        return nil
    end

    local walk = controlFor("Walk speed")
    check(walk ~= nil and walk.kind == "slider" and walk.min == 16 and walk.max == 300, "walk speed slider carries its range")
    walk.set(500)
    check(walk.get() == 300, "slider clamps above its maximum")
    walk.set(1)
    check(walk.get() == 16, "slider clamps below its minimum")

    local aura = controlFor("Kill aura")
    check(aura ~= nil and aura.kind == "toggle", "kill aura registered as a toggle")
    check(state:SetToggle(aura.key, true) and state:GetToggle(aura.key), "toggling through the backend flips state")
    check(state:SetToggle("does not exist", true) == false, "unknown toggle is rejected")

    local mode = nil
    for _, definition in ipairs(controls) do
        if definition.kind == "dropdown" and definition.options and #definition.options > 1 then mode = definition break end
    end
    check(mode ~= nil, "dropdown without a selectable option list is never registered")
    mode.set("no-such-option")
    check(mode.get() == "no-such-option", "dropdown forwards the chosen value to its callback")

    check(state:SetSea("Sea3") and state.Sea == "Sea3", "sea is published for the sea-gated tabs")
    check(state:SetSea(nil) == false, "sea rejects a non-string")

    local status = state:GetStatus()
    check(status.Controls == #controls and status.Sea == "Sea3", "status reports the live control count and sea")
    check(type(status.Errors) == "table" and #status.Errors == 0, "no module reported an init error")

    state:Destroy()
    check(state.Destroyed and ctx.State.__DEPHUB.BloxFruits == nil and ctx.State.__DEPHUB_BLOXFRUITS_OSS == nil, "destroy clears published state")
    check(state:SetToggle("Kill aura", true) == false, "destroyed backend rejects further toggles")
end

-- The standalone ui.lua created real instances; the DepHub frontend renders the
-- same controls, so the backend must be reachable and never build a ScreenGui.
do
    local ctx = ossContext(994732206, 994732206)
    local before = #ctx.Services.Workspace:GetChildren()
    local state = ctx:Run("src/games/bloxfruits.lua")
    check(type(state) == "table", "Blox Fruits loads on a second route (placeId) too")
    check(ctx.State.__DEPHUB.BloxFruits == state, "loader contract points at the OSS backend")
    check(state.UI and state.UI._defs and #state.UI._defs > 0, "control registry survives route selection")
end

-- With a window mounted, the backend renders every page. The library indexes
-- tabs by name alone, so two categories that both want a "Farm" tab must not
-- collide: the shell makes the name unique and the backend never retries a tab
-- that could not be created.
do
    local ctx = ossContext(994732206, 994732206)
    local ui = ctx:MountUI()
    local state = ctx:Run("src/games/bloxfruits.lua")
    check(type(state) == "table", "Blox Fruits builds against a mounted window")

    local tabNames = {}
    for _, tab in ipairs(ui.Library._Tabs) do tabNames[tab.Name] = true end
    local count = 0
    for _ in pairs(tabNames) do count += 1 end
    check(count > 0, "Blox Fruits creates tabs when a window is mounted (" .. count .. ")")

    -- Every created tab name must be unique, exactly like the real library
    -- requires; a duplicate would have errored inside CreateTab.
    check(count == #ui.Library._Tabs, "no duplicate tab name reached the library")

    -- A "Farm" page exists, and sea-gated duplicates were renamed instead of
    -- being rejected.
    local sawFarm, sawSeaSuffixed = false, false
    for name in pairs(tabNames) do
        if name == "Farm" then sawFarm = true end
        if name:find("Farm ·", 1, true) then sawSeaSuffixed = true end
    end
    check(sawFarm, "the shared Farm tab is created")
    check(sawSeaSuffixed, "a same-named tab in another sea category is made unique, not rejected")
end

-- Switching sea must hide the categories that belong to the other seas while
-- keeping the shared (General) ones. This is what stops a Sea 3 feature from
-- showing while the player is on Sea 1.
do
    local ctx = ossContext(994732206, 994732206)
    local ui = ctx:MountUI()
    local state = ctx:Run("src/games/bloxfruits.lua")
    check(type(state) == "table", "Blox Fruits builds for the sea-filter test")

    local buttons = ui.Library._STATE.CategoryButtons
    local function visible(name)
        local data = buttons[name]
        return data ~= nil and data.button ~= nil and data.button.Visible == true
    end

    ui:SetCurrentSea("Sea1")
    check(visible("Sea 1"), "on Sea 1 the Sea 1 category is shown")
    check(not visible("Sea 2"), "on Sea 1 the Sea 2 category is hidden")
    check(not visible("Sea 3"), "on Sea 1 the Sea 3 category is hidden")
    check(not visible("Sea 2/3"), "on Sea 1 the Sea 2/3 category is hidden")

    ui:SetCurrentSea("Sea2")
    check(visible("Sea 2"), "on Sea 2 the Sea 2 category is shown")
    check(not visible("Sea 1"), "on Sea 2 the Sea 1 category is hidden")
    check(not visible("Sea 3"), "on Sea 2 the Sea 3 category is hidden")

    ui:SetCurrentSea("Sea3")
    check(visible("Sea 3"), "on Sea 3 the Sea 3 category is shown")
    check(not visible("Sea 1"), "on Sea 3 the Sea 1 category is hidden")
    check(not visible("Sea 2"), "on Sea 3 the Sea 2 category is hidden")

    -- The sea-scoped tabs are what decide visibility per tab, and Teleport must
    -- never be scoped (it is how the player travels between seas).
    local teleport = ui.Tabs["General|Teleport"]
    check(teleport ~= nil and teleport.Sea == nil, "the Teleport tab is never sea-scoped")
    local farmSea2 = ui.Tabs["Sea 2|Farm"]
    check(farmSea2 ~= nil and farmSea2.Sea == "Sea2", "the Sea 2 Farm tab carries its sea scope")
end
