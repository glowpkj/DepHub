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

    -- Farm tuning controls must drive real behaviour, not just sit in the panel.
    -- "Approach distance" (hoverRange) and "Attack interval" both feed the farm
    -- loops; the farm module reads them back through the same config table.
    local approach = controlFor("Approach distance")
    check(approach ~= nil and approach.kind == "slider", "farm approach distance is a slider")
    approach.set(600)
    check(approach.get() == 600, "approach distance reads back after set")
    approach.set(1)
    check(approach.get() == 30, "approach distance clamps below its minimum")

    local farm = state.Modules and state.Modules.farm
    check(farm ~= nil and type(farm.config) == "table", "the farm module exposes its config")
    approach.set(333)
    check(farm.config.hoverRange == 333, "approach distance writes through to farm config")

    local atk = controlFor("Attack interval")
    check(atk ~= nil and atk.kind == "slider", "farm attack interval is a slider")
    atk.set(0.05)
    check(farm.config.attackInterval == 0.05, "attack interval writes through to farm config")
    -- A fractional slider must keep its precision: rounding every value to an
    -- integer would make the low end of the range unreachable.
    atk.set(0.35)
    check(atk.get() == 0.35, "a fractional slider keeps sub-integer precision")

    -- PVP: the aimbot range/part, the skill rotation order and the bounty ignore
    -- list are all real mechanisms the module reads at runtime.
    local combat = state.Modules and state.Modules.combat
    check(combat ~= nil and type(combat.config) == "table", "the combat module exposes its config")

    local aimRange = controlFor("Aimbot range")
    check(aimRange ~= nil and aimRange.kind == "slider", "aimbot range is a slider")
    aimRange.set(500)
    check(combat.config.aimRange == 500, "aimbot range writes through to combat config")

    local aimPart = controlFor("Aim part")
    check(aimPart ~= nil and aimPart.kind == "dropdown", "aim part is a dropdown")
    aimPart.set("Head")
    check(combat.config.aimPart == "Head", "aim part writes through to combat config")

    -- The skill rotation must be deterministic. It used to iterate a hash table
    -- with pairs(), so the order changed between sessions; now it follows the
    -- configured sequence.
    local skillOrder = controlFor("Skill order")
    check(skillOrder ~= nil and skillOrder.kind == "textbox", "skill order is a textbox")
    skillOrder.set("F V Z")
    check(combat._skillOrder ~= nil and #combat._skillOrder == 3, "skill order parses into a key list")
    check(combat._skillOrder[1] == "F" and combat._skillOrder[2] == "V" and combat._skillOrder[3] == "Z", "skill order keeps the configured sequence")
    skillOrder.set("")
    check(#combat._skillOrder == 5, "an empty skill order falls back to the default rotation")

    local ignore = controlFor("Ignore players")
    check(ignore ~= nil and ignore.kind == "textbox", "bounty ignore list is a textbox")
    ignore.set("Aurora, bob123")
    check(combat.bounty.ignore.aurora == true and combat.bounty.ignore.bob123 == true, "ignore list lowercases and splits on commas")
    ignore.set("")
    check(next(combat.bounty.ignore) == nil, "clearing the ignore list empties it")

    -- Fruits: ESP range, collect range/skip and store keep-list all gate real
    -- behaviour, and the name-list parser drives the skip/keep matchers.
    local fruits = state.Modules and state.Modules.fruits
    check(fruits ~= nil and type(fruits.config) == "table", "the fruits module exposes its config")

    local espRange = controlFor("Fruit / ESP max distance")
    check(espRange ~= nil and espRange.kind == "slider", "fruit ESP max distance is a slider")
    espRange.set(400)
    check(fruits.config.espRange == 400, "ESP max distance writes through to fruits config")

    local collectRange = controlFor("Collect max distance")
    check(collectRange ~= nil and collectRange.kind == "slider", "collect max distance is a slider")
    collectRange.set(150)
    check(fruits.config.collectRange == 150, "collect max distance writes through to fruits config")

    local skip = controlFor("Collect skip list")
    check(skip ~= nil and skip.kind == "textbox", "collect skip list is a textbox")
    skip.set("Dragon, Rocket")
    check(fruits.config.collectSkip.dragon == true and fruits.config.collectSkip.rocket == true, "collect skip list parses names")
    skip.set("")
    check(next(fruits.config.collectSkip) == nil, "clearing the collect skip list empties it")

    local keep = controlFor("Store keep list")
    check(keep ~= nil and keep.kind == "textbox", "store keep list is a textbox")
    keep.set("Leopard")
    check(fruits.config.storeKeep.leopard == true, "store keep list parses names")

    local chestCd = controlFor("Chest cooldown")
    check(chestCd ~= nil and chestCd.kind == "slider", "chest cooldown is a slider")
    chestCd.set(2)
    check(fruits.config.chestCooldown == 2, "chest cooldown writes through to fruits config")

    -- Events: the raid loop's pacing was hardcoded; the three waits now drive it.
    local events = state.Modules and state.Modules.events
    check(events ~= nil and type(events.config) == "table", "the events module exposes its config")

    local waveWait = controlFor("Wave wait")
    check(waveWait ~= nil and waveWait.kind == "slider", "raid wave wait is a slider")
    waveWait.set(0.75)
    check(events.config.waveWait == 0.75, "wave wait writes through to events config")

    local startWait = controlFor("Start wait")
    check(startWait ~= nil and startWait.kind == "slider", "raid start wait is a slider")
    startWait.set(4)
    check(events.config.startWait == 4, "start wait writes through to events config")

    local chipWait = controlFor("Chip wait")
    check(chipWait ~= nil and chipWait.kind == "slider", "raid chip wait is a slider")
    chipWait.set(3)
    check(events.config.chipWait == 3, "chip wait writes through to events config")

    local raidElement = controlFor("Raid element")
    check(raidElement ~= nil and raidElement.kind == "dropdown", "raid element is a dropdown")
    raidElement.set("Ice")
    check(events.config.element == "Ice", "raid element writes through to events config")
    check(controlFor("Next raid hint") ~= nil, "the raid hint button is now exposed")

    -- Player: ESP range/name and the mobility toggles all exist as real controls.
    local player = state.Modules and state.Modules.player
    check(player ~= nil and type(player.config) == "table", "the player module exposes its config")

    local pEspRange = controlFor("Player / ESP max distance")
    check(pEspRange ~= nil and pEspRange.kind == "slider", "player ESP max distance is a slider")
    pEspRange.set(900)
    check(player.config.espRange == 900, "player ESP max distance writes through to player config")

    local espName = controlFor("ESP show name")
    check(espName ~= nil and espName.kind == "toggle", "ESP show name is a toggle")
    espName.set(false)
    check(player.config.espName == false, "ESP show name writes through to player config")

    -- Teleport: flight speed gates how fast every teleport flies.
    local teleport = state.Modules and state.Modules.teleport
    check(teleport ~= nil and type(teleport.config) == "table", "the teleport module exposes its config")

    local flySpeed = controlFor("Fly speed")
    check(flySpeed ~= nil and flySpeed.kind == "slider", "fly speed is a slider")
    flySpeed.set(120)
    check(teleport.config.speed == 120, "fly speed writes through to teleport config")

    -- Teleport waypoints are data persisted through Core blobs, not controls: the
    -- panel renders a fixed set of slots and each reads the current list.
    check(type(teleport.saveWaypoints) == "function" and type(teleport.loadWaypoints) == "function", "waypoints expose save/load")
    teleport.waypoints = { { name = "Home", pos = Vector3.new(1, 2, 3) } }
    teleport.saveWaypoints()
    local blob = state.Core.loadBlob and state.Core.loadBlob("waypoints")
    check(type(blob) == "table" and blob[1] and blob[1].name == "Home", "a waypoint round-trips through the blob store")
    check(controlFor("Go to waypoint #1") ~= nil and controlFor("Clear waypoint #1") ~= nil, "waypoint slots are fixed controls")

    -- Shop: the legendary poll interval drives the auto-buy loop's cadence.
    local shop = state.Modules and state.Modules.shop
    check(shop ~= nil and type(shop.config) == "table", "the shop module exposes its config")

    local poll = controlFor("Legendary poll interval")
    check(poll ~= nil and poll.kind == "slider", "legendary poll interval is a slider")
    poll.set(7)
    check(shop.config.legendaryPoll == 7, "legendary poll interval writes through to shop config")

    -- Extras: the summon wait drives the gap between summoning and farming.
    local extras = state.Modules and state.Modules.extras
    check(extras ~= nil and type(extras.config) == "table", "the extras module exposes its config")

    local summonWait = controlFor("Summon wait")
    check(summonWait ~= nil and summonWait.kind == "slider", "summon wait is a slider")
    summonWait.set(2)
    check(extras.config.spawnWait == 2, "summon wait writes through to extras config")

    local status = state:GetStatus()
    check(status.Controls == #controls and status.Sea == "Sea3", "status reports the live control count and sea")
    check(type(status.Errors) == "table" and #status.Errors == 0, "no module reported an init error")

    state:Destroy()
    check(state.Destroyed and ctx.State.__DEPHUB.BloxFruits == nil and ctx.State.__DEPHUB_BLOXFRUITS_OSS == nil, "destroy clears published state")
    check(state:SetToggle("Kill aura", true) == false, "destroyed backend rejects further toggles")
end

-- Config management: save/load/list/delete/rename and the reset operations.
-- Exercised against the in-memory filesystem the harness exposes.
do
    local ctx = ossContext(994732206, 994732206)
    local state = ctx:Run("src/games/bloxfruits.lua")
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
    local state = ctx:Run("src/games/bloxfruits.lua")
    check(type(state) == "table", "Blox Fruits builds for the search test")
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
