-- Per-game UI isolation. Each backend must register only its own tabs and must
-- never publish Blox Fruits categories or tab names. The Demon UI wrapper is
-- exercised through its real wrapper code with a library double.
do
    local BLOXFRUITS_TABS = {"Fruit", "Fruits", "PVP", "Combat", "Sea", "Farm 2", "Farm 3", "Shop 2", "Shop 3", "Raids/Events", "Raids"}
    local function tabNames(library)
        local names = {}
        for _, tab in ipairs(library._Tabs) do names[#names + 1] = tab.Name end
        return names
    end
    local function hasAny(names, needles)
        for _, name in ipairs(names) do
            for _, needle in ipairs(needles) do
                if name == needle then return true, needle end
            end
        end
        return false, nil
    end
    local function assertNoSeaCategories(library, label)
        local leaked = library._Categories["Sea 1"] or library._Categories["Sea 2"] or library._Categories["Sea 3"]
            or library._Categories["Sea 1/2"] or library._Categories["Sea 2/3"]
        check(not leaked, label .. " must not register Blox Fruits sea categories")
    end
    local function assertNoBloxTabs(library, label)
        local leak, name = hasAny(tabNames(library), BLOXFRUITS_TABS)
        check(not leak, label .. " must not register a Blox Fruits tab (saw " .. tostring(name) .. ")")
    end

    -- MM2
    do
        local ctx = sandbox(66654135, 66654135)
        ctx:MountUI()
        for _, name in ipairs({"roletracker", "roundtracker", "esp", "coinfarm", "playerteleport", "gundrop"}) do
            ctx.Responses["src/games/features/mm2/" .. name .. ".lua"] = sources["src/games/features/mm2/" .. name .. ".lua"]
        end
        local ui = ctx.State.__DEPHUB.UI
        ctx:Run("src/games/mm2.lua")
        assertNoSeaCategories(ui.Library, "MM2")
        assertNoBloxTabs(ui.Library, "MM2")
        local names = tabNames(ui.Library)
        check(#names > 0, "MM2 registers its own tabs")
        for _, expected in ipairs({"Roles", "Coin Farm", "Gun Drop", "Players"}) do
            local found = false
            for _, name in ipairs(names) do if name == expected then found = true end end
            check(found, "MM2 registers its tab: " .. expected)
        end
    end

    -- AOT:R
    do
        local ctx = sandbox(4658598196, 4658598196)
        ctx:MountUI()
        ctx.Responses["src/games/features/aotr/assistance.lua"] = sources["src/games/features/aotr/assistance.lua"]
        local ui = ctx.State.__DEPHUB.UI
        ctx:Run("src/games/aotr.lua")
        assertNoSeaCategories(ui.Library, "AOTR")
        assertNoBloxTabs(ui.Library, "AOTR")
        local names = tabNames(ui.Library)
        for _, expected in ipairs({"Titan ESP", "Assistência", "Movement", "Status"}) do
            local found = false
            for _, name in ipairs(names) do if name == expected then found = true end end
            check(found, "AOTR registers its tab: " .. expected)
        end
    end

    -- Noob Piece
    do
        local ctx = sandbox(84822469255086, 84822469255086)
        ctx:MountUI()
        -- Build the remotes the backend resolves from ReplicatedStorage.Events.
        local events = ctx.Services.ReplicatedStorage:FindFirstChild("Events")
        for _, name in ipairs({"PlayerAttack", "SelectTeam", "NpcInteract", "OpenDialog", "DialogChoice", "QuestUpdate"}) do
            local remote = Instance.new("RemoteEvent"); remote.Name = name; remote.Parent = events
        end
        for _, name in ipairs({"autoattack", "autochest", "autofarm", "autoquest", "autoteam", "chestesp", "islanddata", "islandtracker", "movementprofile", "npcesp", "wanderinggacha"}) do
            ctx.Responses["src/games/features/noobpiece/" .. name .. ".lua"] = sources["src/games/features/noobpiece/" .. name .. ".lua"]
        end
        local ui = ctx.State.__DEPHUB.UI
        ctx:Run("src/games/noobpiece.lua")
        assertNoSeaCategories(ui.Library, "NoobPiece")
        assertNoBloxTabs(ui.Library, "NoobPiece")
        local names = tabNames(ui.Library)
        for _, expected in ipairs({"Farm", "ESP", "Travel", "Team"}) do
            local found = false
            for _, name in ipairs(names) do if name == expected then found = true end end
            check(found, "Noob Piece registers its tab: " .. expected)
        end
    end

    -- TSB (newly gained a UI)
    do
        local ctx = sandbox(3808081382, 3808081382)
        ctx:MountUI()
        ctx.Responses["src/games/features/tsb/animations.lua"] = sources["src/games/features/tsb/animations.lua"]
        ctx.Responses["src/games/features/tsb/autoblock-v3.lua"] = sources["src/games/features/tsb/autoblock-v3.lua"]
        local ui = ctx.State.__DEPHUB.UI
        ctx:Run("src/games/tsb.lua")
        assertNoSeaCategories(ui.Library, "TSB")
        assertNoBloxTabs(ui.Library, "TSB")
        local names = tabNames(ui.Library)
        for _, expected in ipairs({"Autoblock", "Ranges", "Detection", "Prediction", "Debug"}) do
            local found = false
            for _, name in ipairs(names) do if name == expected then found = true end end
            check(found, "TSB registers its tab: " .. expected)
        end
        check(#ui.Library._Controls > 0, "TSB builds controls")
    end

    -- Volleyball 4.2 (newly gained a UI)
    do
        local ctx = sandbox(1316421563, 1316421563)
        ctx:MountUI()
        local ui = ctx.State.__DEPHUB.UI
        ctx:Run("src/games/volleyball42.lua")
        assertNoSeaCategories(ui.Library, "Volleyball42")
        assertNoBloxTabs(ui.Library, "Volleyball42")
        local names = tabNames(ui.Library)
        local found = false
        for _, name in ipairs(names) do if name == "Ball Predict" then found = true end end
        check(found, "Volleyball 4.2 registers its Ball Predict tab")
        check(#ui.Library._Controls > 0, "Volleyball 4.2 builds controls")
    end

    -- Universal
    do
        local ctx = sandbox()
        ctx:MountUI()
        local ui = ctx.State.__DEPHUB.UI
        ctx:Run("src/games/universal.lua")
        assertNoSeaCategories(ui.Library, "Universal")
        assertNoBloxTabs(ui.Library, "Universal")
    end

    -- Every game gets the same shared shell: the wrapper always registers the
    -- single default category, and only a backend that explicitly asks for more
    -- (Blox Fruits with its seas) ever gets extra categories.
    do
        for _, route in ipairs({
            {66654135, 66654135},
            {4658598196, 4658598196},
            {3808081382, 3808081382},
            {1316421563, 1316421563},
            {84822469255086, 84822469255086}
        }) do
            local ctx = sandbox(route[1], route[2])
            ctx:MountUI()
            local ui = ctx.State.__DEPHUB.UI
            check(ui.Library._Categories["General"], "shared shell registers the default category")
        end
    end

    -- The Demon UI wrapper is the single shared shell: two windows built the
    -- same way must produce the same category and layout defaults.
    do
        local ctxA = sandbox()
        local uiA = ctxA:MountUI()
        local ctxB = sandbox()
        local uiB = ctxB:MountUI()
        local categoriesA, categoriesB = {}, {}
        for name in pairs(uiA.Library._Categories) do categoriesA[#categoriesA + 1] = name end
        for name in pairs(uiB.Library._Categories) do categoriesB[#categoriesB + 1] = name end
        table.sort(categoriesA)
        table.sort(categoriesB)
        check(#categoriesA == #categoriesB, "shared shell builds the same categories for every window")
        for i = 1, #categoriesA do
            check(categoriesA[i] == categoriesB[i], "shared shell category set is identical across windows")
        end
    end
end
