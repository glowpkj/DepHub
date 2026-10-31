-- Behaviour checks for the vendored open-source Blox Fruits script. The module
-- bodies that drive the game are exercised through the adapter's control
-- registry; remote-touching code paths are not re-tested here.
local OSS_PREFIX = "src/games/features/bloxfruits/oss/"
local OSS_MODULES = {"adapter", "ui-headless", "core", "teleport", "combat", "bladhits", "flashstep", "farm",
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

-- The Blox Fruits backend is PARKED (see DISABLED in src/games/bloxfruits.lua).
-- A parked backend still resolves and returns its State so the loader routing
-- keeps working, but no module initialises and the frontend is never built --
-- no tab, section, category or sea category exists. Nothing is deleted: the
-- module files are still fetched and compiled, so every file stays on disk and
-- lifting the flag restores the old behaviour with no other change.
do
    local ctx = ossContext(994732206, 994732206)
    local state = ctx:Run("src/games/bloxfruits.lua")
    check(type(state) == "table" and state.Destroyed == false, "a parked Blox Fruits backend still resolves")
    check(state.Disabled == true, "the backend reports itself disabled")

    -- Nothing may skip the fetch: every vendored module is still compiled, which
    -- is what keeps the file tree intact and revertible.
    for _, name in ipairs(OSS_MODULES) do
        if name ~= "adapter" and name ~= "ui-headless" then
            check(type(state.Modules[name]) == "table", "the " .. name .. " module is still loaded (not deleted)")
        end
    end

    check(state.UI ~= nil and type(state.UI.build) == "function", "the headless UI is still installed")
    check(#state:ListControls() == 0, "no module registered a control while disabled")
    check(#state.UI._defs == 0, "the control registry is empty while disabled")
    check(next(state.UI.tabs) == nil, "no page was created while disabled")
    check(state.UI._pages == nil and state.UI.gui == nil, "no window and no page list exist while disabled")
    check(state.Toggles ~= nil and next(state.Toggles) == nil, "no toggle is published while disabled")
    check(state.UIFrontend == nil and state.UITabs == nil, "the frontend was never built while disabled")
    check(type(state.Errors) == "table" and #state.Errors == 0, "parking the backend raises no module error")

    -- The registry API keeps working and reports the empty state instead of
    -- failing, so a generic frontend driving it never raises.
    check(state:SetToggle("Kill aura", true) == false, "a toggle cannot be flipped while disabled")
    check(state:GetToggle("Kill aura") == false, "an unknown toggle reads back off while disabled")
    check(state:SetSea("Sea3") and state.Sea == "Sea3", "the sea still publishes while disabled")
    check(state:SetSea(nil) == false, "sea still rejects a non-string while disabled")

    local status = state:GetStatus()
    check(status.Controls == 0 and status.Disabled == true, "status reports zero controls and the disabled flag")
    check(type(status.Errors) == "table" and #status.Errors == 0, "no error surfaced in the parked status")

    state:Destroy()
    check(state.Destroyed and ctx.State.__DEPHUB.BloxFruits == nil and ctx.State.__DEPHUB_BLOXFRUITS_OSS == nil, "destroy clears published state")
    check(state:SetToggle("Kill aura", true) == false, "a destroyed backend rejects further toggles")
end

-- A parked backend must not build any frontend even when a window is mounted:
-- that is the whole point of parking it, no category or tab may appear.
do
    local ctx = ossContext(994732206, 994732206)
    local ui = ctx:MountUI()
    local tabsBefore = #ui.Library._Tabs
    local state = ctx:Run("src/games/bloxfruits.lua")
    check(type(state) == "table", "a parked backend still builds against a mounted window")
    check(#ui.Library._Tabs == tabsBefore, "a parked backend creates no tab of its own")
    check(state.UIFrontend == nil, "a parked backend never claims the frontend")
end

-- The same backend served from the other route (the Sea 1 placeId) must park
-- identically, so neither sea turns the tree back on by accident.
do
    local ctx = ossContext(85211729168715, 85211729168715)
    local state = ctx:Run("src/games/bloxfruits.lua")
    check(type(state) == "table" and state.Disabled == true, "Blox Fruits is parked on the Sea 1 route too")
    check(#state:ListControls() == 0, "no control is registered on the Sea 1 route either")
    check(ctx.State.__DEPHUB.BloxFruits == state, "loader contract still points at the parked backend")
end

-- The frontend and the sea filter are backend features, so they are exercised
-- through modules restarted with the flag lifted. This is the revert contract:
-- Disabled = false has to bring the whole tree back exactly as it was.
do
    local ctx = ossContext(994732206, 994732206)
    local state = ctx:Run("src/games/bloxfruits.lua", {__DEPHUB_BF_DISABLED = false})
    check(type(state) == "table" and state.Disabled == false, "the backend runs again once the flag is lifted")
    local controls = state:ListControls()
    check(#controls > 100, "every module registers its controls when re-enabled (" .. #controls .. ")")

    local function controlFor(fragment)
        for _, definition in ipairs(controls) do
            if definition.key:find(fragment, 1, true) then return definition end
        end
        return nil
    end

    -- Each module still reaches its own config: the parked period changed no
    -- behaviour, only whether init ran.
    local combat = state.Modules.combat
    check(combat ~= nil and type(combat.config) == "table", "the combat module exposes its config when re-enabled")
    local aimRange = controlFor("Aimbot range")
    check(aimRange ~= nil and aimRange.kind == "slider", "aimbot range is a slider when re-enabled")
    aimRange.set(500)
    check(combat.config.aimRange == 500, "aimbot range writes through to combat config when re-enabled")

    local bladhits = state.Modules.bladhits
    check(bladhits ~= nil and type(bladhits.config) == "table", "the bladhits module is back when re-enabled")
    local bladeRange = controlFor("Blade range")
    check(bladeRange ~= nil and bladeRange.kind == "slider", "blade range is a slider when re-enabled")
    bladeRange.set(220)
    check(bladhits.config.range == 220, "blade range writes through when re-enabled")
    check(combat._onHitId == bladhits.syncHitId, "the hitId broadcast is rewired when re-enabled")

    local flashstep = state.Modules.flashstep
    check(flashstep ~= nil and type(flashstep.set) == "function", "the flashstep module is back when re-enabled")

    local farm = state.Modules.farm
    check(farm ~= nil and type(farm.config) == "table", "the farm module exposes its config when re-enabled")

    local toggleCount = 0
    for _ in pairs(state.Toggles or {}) do toggleCount = toggleCount + 1 end
    check(toggleCount > 40, "the published toggles come back when re-enabled (" .. toggleCount .. ")")

    -- Frontend: the sea categories, the tab names and the sea filter all return.
    local ui = ctx:MountUI()
    local state2 = ctx:Run("src/games/bloxfruits.lua", {__DEPHUB_BF_DISABLED = false})
    check(type(state2) == "table" and state2.Disabled == false, "the re-enabled backend builds against a mounted window")
    check(#ui.Library._Tabs > 0, "the tabs come back when re-enabled (" .. #ui.Library._Tabs .. ")")
    local tabNames = {}
    for _, tab in ipairs(ui.Library._Tabs) do tabNames[tab.Name] = true end
    local count = 0
    for _ in pairs(tabNames) do count += 1 end
    check(count == #ui.Library._Tabs, "no duplicate tab name reached the library when re-enabled")
    check(tabNames["Farm"] == true, "the shared Farm tab is created when re-enabled")

    local buttons = ui.Library._STATE.CategoryButtons
    local function visible(name)
        local data = buttons[name]
        return data ~= nil and data.button ~= nil and data.button.Visible == true
    end
    ui:SetCurrentSea("Sea1")
    check(visible("General") and visible("Sea 1"), "the General and Sea 1 categories come back")
    check(not visible("Sea 2") and not visible("Sea 3"), "the other sea categories stay hidden on Sea 1")
    ui:SetCurrentSea("Sea2")
    check(visible("Sea 2") and not visible("Sea 1"), "the sea filter still switches categories when re-enabled")

    ui:Search("farm")
    local farmShown = false
    for _, tab in pairs(ui.Tabs) do
        if tab.DisplayName == "Farm" and tab.Visible then farmShown = true end
    end
    check(farmShown, "feature search still narrows the visible tabs when re-enabled")
    ui:Search("")
end

-- Config management: save/load/list/delete/rename and the reset operations,
-- exercised with the flag lifted so there are live controls to persist.
do
    local ctx = ossContext(994732206, 994732206)
    local state = ctx:Run("src/games/bloxfruits.lua", {__DEPHUB_BF_DISABLED = false})
    check(type(state) == "table", "Blox Fruits builds for the config test")
    local core = state.Core
    check(type(core) == "table" and type(core.gatherConfig) == "function", "the core module is reachable through the adapter")

    -- Save then load a named config; the value must survive the round trip.
    -- Config is gathered from the live controls, so the test drives the control
    -- (exactly what the panel does) rather than poking the module table.
    local combat = state.Modules.combat
    local aimControl
    for _, d in ipairs(combat and state:ListControls() or {}) do
        if d.kind == "slider" and d.key:find("Aimbot range", 1, true) then aimControl = d break end
    end
    check(aimControl ~= nil, "the aimbot range control is reachable for the config test")
    aimControl.set(777)
    check(state:SaveConfig("t1"), "a named config is saved")
    aimControl.set(100)
    check(state:LoadConfig("t1"), "the named config loads back")
    check(combat.config.aimRange == 777, "a saved value is restored on load")

    local names = state:ListConfigs()
    local found = false
    for _, n in ipairs(names) do if n == "t1" then found = true end end
    check(found, "the saved config appears in the list")

    -- Rename moves the file and drops the old name.
    check(state:RenameConfig("t1", "t2"), "a config can be renamed")
    local names2 = state:ListConfigs()
    local has2, has1 = false, false
    for _, n in ipairs(names2) do if n == "t2" then has2 = true end; if n == "t1" then has1 = true end end
    check(has2 and not has1, "rename replaces the old name with the new one")
    check(state:RenameConfig("t2", "t2") == false, "renaming onto itself is rejected")

    -- Delete removes it.
    check(state:DeleteConfig("t2"), "a config can be deleted")
    check(state:DeleteConfig("nope") == false, "deleting a missing config reports false")

    -- Reset one module leaves other modules alone. Drive values through the
    -- controls so the reset has live state to undo.
    local player = state.Modules.player
    local walkControl
    for _, d in ipairs(state:ListControls()) do
        if d.kind == "slider" and d.key:find("Walk speed", 1, true) then walkControl = d break end
    end
    check(walkControl ~= nil, "the walk speed control is reachable for the reset test")
    aimControl.set(999)
    walkControl.set(250)
    local resetCount = state:ResetModule("combat")
    check(resetCount > 0, "resetting a module touches at least one control")
    check(combat.config.aimRange == 300, "the reset module went back to its registered default")
    check(player.config.walkSpeed == 250, "another module was left untouched by a single-module reset")

    -- Reset everything restores defaults across every module.
    aimControl.set(999)
    check(state:ResetDefaults(), "reset defaults runs")
    check(combat.config.aimRange == 300 and player.config.walkSpeed == 50, "reset defaults restores every module")

    local status = state:GetStatus()
    check(type(status.Errors) == "table" and #status.Errors == 0, "no error surfaced during config operations")
end

-- A parked backend must not create a ScreenGui either: the backend always owns
-- no presentation, and while disabled it owns no UI at all.
do
    local ctx = ossContext(994732206, 994732206)
    local state = ctx:Run("src/games/bloxfruits.lua")
    check(type(state) == "table", "Blox Fruits loads on a second route (placeId) too")
    check(ctx.State.__DEPHUB.BloxFruits == state, "loader contract points at the OSS backend")
    check(state.UI and state.UI._defs and #state.UI._defs == 0, "no control registry survives while disabled")
end

-- With the flag lifted, the frontend renders every page again. The library
-- indexes tabs by name alone, so two categories that both want a "Farm" tab must
-- not collide: the shell makes the name unique and the backend never retries a
-- tab that could not be created.
do
    local ctx = ossContext(994732206, 994732206)
    local ui = ctx:MountUI()
    local state = ctx:Run("src/games/bloxfruits.lua", {__DEPHUB_BF_DISABLED = false})
    check(type(state) == "table", "the re-enabled Blox Fruits builds against a mounted window")

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
    local state = ctx:Run("src/games/bloxfruits.lua", {__DEPHUB_BF_DISABLED = false})
    check(type(state) == "table", "the re-enabled Blox Fruits builds for the sea-filter test")

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
    check(not visible("Sea 1/2"), "on Sea 1 the Sea 1/2 category is hidden")

    ui:SetCurrentSea("Sea2")
    check(visible("Sea 2"), "on Sea 2 the Sea 2 category is shown")
    check(not visible("Sea 1"), "on Sea 2 the Sea 1 category is hidden")
    check(not visible("Sea 3"), "on Sea 2 the Sea 3 category is hidden")
    -- The header must never show a combined category: a cross-sea feature is
    -- filed under the current sea, so only General + the current sea remain.
    check(not visible("Sea 2/3"), "on Sea 2 the Sea 2/3 category is hidden")
    check(not visible("Sea 1/2"), "on Sea 2 the Sea 1/2 category is hidden")

    ui:SetCurrentSea("Sea3")
    check(visible("Sea 3"), "on Sea 3 the Sea 3 category is shown")
    check(not visible("Sea 1"), "on Sea 3 the Sea 1 category is hidden")
    check(not visible("Sea 2"), "on Sea 3 the Sea 2 category is hidden")
    check(not visible("Sea 2/3"), "on Sea 3 the Sea 2/3 category is hidden")

    -- The sea-scoped tabs are what decide visibility per tab, and Teleport must
    -- never be scoped (it is how the player travels between seas).
    local teleport = ui.Tabs["General|Teleport"]
    check(teleport ~= nil and teleport.Sea == nil, "the Teleport tab is never sea-scoped")
    local farmSea2 = ui.Tabs["Sea 2|Farm"]
    check(farmSea2 ~= nil and farmSea2.Sea == "Sea2", "the Sea 2 Farm tab carries its sea scope")

    -- A tab scoped to several seas is re-filed into the current sea's category, so
    -- the header stays on a single sea and the feature stays reachable: on Sea 2 a
    -- "Sea2,Sea3" tab lives under "Sea 2", not under a hidden combined category.
    ui:SetCurrentSea("Sea2")
    local eventsTab = ui.Tabs["Sea 2/3|Events"]
    check(eventsTab ~= nil and eventsTab.Category == "Sea 2", "a Sea2,Sea3 tab is re-filed under Sea 2 on Sea 2")
    local travelTab = ui.Tabs["Sea 1|Travel"]
    check(travelTab ~= nil and travelTab.Category == "Sea 2", "a Sea1,Sea2 tab is re-filed under Sea 2 on Sea 2")
    check(not visible("Sea 1/2") and not visible("Sea 2/3"), "no combined category is shown on Sea 2")
end

-- §11 panel: the feature search narrows the visible tabs by name and combines
-- with the sea filter, and clearing it restores exactly the sea-filtered set.
do
    local ctx = ossContext(994732206, 994732206)
    local ui = ctx:MountUI()
    local state = ctx:Run("src/games/bloxfruits.lua", {__DEPHUB_BF_DISABLED = false})
    check(type(state) == "table", "the re-enabled Blox Fruits builds for the search test")
    check(state.UIFrontend == ui, "the backend publishes the mounted frontend for the panel controls")

    ui:SetCurrentSea("Sea3")
    local function visibleCount()
        local n = 0
        for _, tab in pairs(ui.Tabs) do if tab.Visible then n = n + 1 end end
        return n
    end
    local baseline = visibleCount()
    check(baseline > 0, "the sea filter leaves at least one tab visible")

    ui:Search("farm")
    local hiddenSeen = false
    for _, tab in pairs(ui.Tabs) do if not tab.Visible then hiddenSeen = true end end
    check(hiddenSeen, "search hides tabs whose name does not contain the query")
    local farmShown = false
    for _, tab in pairs(ui.Tabs) do
        if tab.DisplayName == "Farm" and tab.Visible then farmShown = true end
    end
    check(farmShown, "a tab matching the query stays visible")

    -- A hidden tab must stay hidden when the sea changes (search is re-applied on
    -- top of the sea filter, not replaced by it).
    ui:SetCurrentSea("Sea2")
    local shopHidden = true
    for _, tab in pairs(ui.Tabs) do
        if tab.DisplayName == "Shop" and tab.Visible then shopHidden = false end
    end
    check(shopHidden, "a non-matching tab stays hidden across a sea change")

    ui:Search("")
    ui:SetCurrentSea("Sea3")
    check(visibleCount() == baseline, "clearing the search restores the sea-filtered baseline")
end
