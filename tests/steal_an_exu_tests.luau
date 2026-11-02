-- Steal An Exu: the backend plus its Auto Upgrade and Auto Sell features.
--
-- What is checked here is the CONTRACT and the mechanism against API doubles, not
-- the live game: the backend routes from its own ids, loads the features from the
-- repo, and mounts the Sell All + Auto Upgrade controls. Auto Upgrade finds the
-- player's pen by the Owner attribute (never a fixed Pen1); Auto Sell finds the
-- "Vender Todos" clickable (a GuiButton inside a Frame) -- all without erroring
-- when the world is missing.
local FEATURE_PREFIX = "src/games/features/stealanexu/"

-- A real client always has a UserId on the LocalPlayer; the bare instance double
-- does not, so every context here carries one. The Owner attribute on the pen and
-- the feature's Owner lookup both read it.
local MY_USER_ID = 7091741787

local function saeContext(placeId, gameId)
    local ctx = sandbox(placeId, gameId)
    ctx.Player.UserId = MY_USER_ID
    ctx.Responses[FEATURE_PREFIX .. "autosteal.lua"] = sources[FEATURE_PREFIX .. "autosteal.lua"]
    ctx.Responses[FEATURE_PREFIX .. "autoupgrade.lua"] = sources[FEATURE_PREFIX .. "autoupgrade.lua"]
    ctx.Responses[FEATURE_PREFIX .. "autosell.lua"] = sources[FEATURE_PREFIX .. "autosell.lua"]
    ctx.Responses[FEATURE_PREFIX .. "autohop.lua"] = sources[FEATURE_PREFIX .. "autohop.lua"]
    ctx.Responses["src/core/config-store.lua"] = sources["src/core/config-store.lua"]
    return ctx
end

-- Builds the minimal world the backend's features read: Map.Pens with one pen
-- owned by the local player (Owner attribute) and a BadgeAnchor, plus the two
-- upgrade boards the Auto Upgrade toggles click. When `options.exuCount` is set,
-- also builds workspace.Runtime with that many exu models, each carrying a
-- Root.ProximityPrompt (what the Auto Steal Exu loop sweeps). `options.rootOffset`
-- lifts each Root off y=0 so a test can tell the Root from the Nest line.
local function buildWorld(ctx, options)
    options = options or {}
    local ws = ctx.Services.Workspace

    local map = Instance.new("Folder"); map.Name = "Map"; map.Parent = ws

    local pens = Instance.new("Folder"); pens.Name = "Pens"; pens.Parent = map
    -- Deliberately NOT Pen1: the feature must find the pen by Owner.
    local pen = Instance.new("Model"); pen.Name = "Pen7"; pen.Parent = pens
    pen:SetAttribute("Owner", ctx.Player.UserId)
    local anchor = Instance.new("Part"); anchor.Name = "BadgeAnchor"; anchor.Parent = pen
    anchor.CFrame = CFrame.new(0, 50, 0)

    -- The two upgrade boards the Auto Upgrade toggles click.
    local baseSign = Instance.new("Model"); baseSign.Name = "PenSign"; baseSign.Parent = pen
    local baseBoard = Instance.new("Part"); baseBoard.Name = "Board"; baseBoard.Parent = baseSign
    local baseDetector = Instance.new("ClickDetector"); baseDetector.Name = "ClickDetector"; baseDetector.Parent = baseBoard

    local treadSign = Instance.new("Model"); treadSign.Name = "TreadSign"; treadSign.Parent = pen
    local treadBoard = Instance.new("Part"); treadBoard.Name = "Board"; treadBoard.Parent = treadSign
    local treadDetector = Instance.new("ClickDetector"); treadDetector.Name = "ClickDetector"; treadDetector.Parent = treadBoard

    -- Optional Runtime with exu models (the Auto Steal Exu sweep).
    local fired, roots = {}, {}
    if options.exuCount then
        local runtime = Instance.new("Folder"); runtime.Name = "Runtime"; runtime.Parent = ws
        local offset = options.rootOffset or 0
        for index = 1, options.exuCount do
            local exu = Instance.new("Model"); exu.Name = "Exu"; exu.Parent = runtime
            local root = Instance.new("Part"); root.Name = "Root"; root.Parent = exu
            root.CFrame = CFrame.new(index * 100, offset, 0)
            roots[#roots + 1] = root
            local prompt = Instance.new("ProximityPrompt"); prompt.Name = "ProximityPrompt"; prompt.Parent = root
            prompt.HoldDuration = 0.5
            prompt.MaxActivationDistance = 6.5
            -- The prompt exposes the hold API the real game does. The steal widens
            -- the prompt (MaxActivationDistance=1000, HoldDuration=0,
            -- RequiresLineOfSight=false), then InputHoldBegin + End. The doubles
            -- record each call and the HoldDuration value seen AT THE MOMENT of
            -- InputHoldBegin, so the test can prove the zeroing.
            prompt.Hold = {began = 0, ended = 0, durationAtBegin = nil}
            prompt.InputHoldBegin = function(self)
                self.Hold.began = self.Hold.began + 1
                self.Hold.durationAtBegin = self.HoldDuration
            end
            prompt.InputHoldEnd = function(self)
                self.Hold.ended = self.Hold.ended + 1
            end
            fired[#fired + 1] = prompt
        end
    end

    return {
        pen = pen, anchor = anchor,
        baseDetector = baseDetector, treadDetector = treadDetector,
        fired = fired, roots = roots,
    }
end

-- A teleport is a direct CFrame write on the HumanoidRootPart; the harness records
-- it, so the test can assert where the character ended up.
local function makeCharacter(ctx)
    local character = Instance.new("Model"); character.Name = "Character"; character.Parent = ctx.Services.Workspace
    ctx.Player.Character = character
    local root = Instance.new("Part"); root.Name = "HumanoidRootPart"; root.Parent = character
    root.CFrame = CFrame.new(0, 0, 0)
    return root
end

-- Routing: the loader must pick this backend from the place id (and the universe
-- id), not fall back to the universal backend.
do
    local ctx = saeContext(103076400317371, 10771168447)
    ctx.Responses["src/version.txt"] = "0.0.1"
    ctx:Provide("src/games/steal-an-exu.lua", {Destroyed = false})
    check(ctx:Run("DepHub.lua") == true, "Steal An Exu routes from its place id")
    check(ctx.State.__DEPHUB.StealAnExu ~= nil, "Steal An Exu route exposes its backend")
    check(ctx.State.__DEPHUB.Universal == nil, "Steal An Exu does not fall back to the universal backend")
    check(ctx.State.__DEPHUB.BloxFruits == nil and ctx.State.__DEPHUB.Volleyball42 == nil,
        "Steal An Exu route does not leak another backend")
    check(ctx.State.__DEPHUB.Mode == "steal-an-exu", "Steal An Exu route names its backend")
end

do
    local ctx = saeContext(999, 10771168447)
    ctx.Responses["src/version.txt"] = "0.0.1"
    ctx:Provide("src/games/steal-an-exu.lua", {Destroyed = false})
    check(ctx:Run("DepHub.lua") == true, "Steal An Exu routes from its universe id")
    check(ctx.State.__DEPHUB.StealAnExu ~= nil, "universe id exposes the Steal An Exu backend")
end

-- The entry loads, registers the features, and mounts the controls.
do
    local ctx = saeContext(103076400317371, 10771168447)
    local ui = ctx:MountUI()

    local map = Instance.new("Folder"); map.Name = "Map"; map.Parent = ctx.Services.Workspace
    local terreiros = Instance.new("Folder"); terreiros.Name = "Terreiros"; terreiros.Parent = map
    for _, name in ipairs({"Terreiro1", "Terreiro4"}) do
        local terreiro = Instance.new("Folder"); terreiro.Name = name; terreiro.Parent = terreiros
        local nests = Instance.new("Folder"); nests.Name = "Nests"; nests.Parent = terreiro
    end

    local backend = ctx:Run("src/games/steal-an-exu.lua")
    check(type(backend) == "table" and backend.Destroyed == false, "Steal An Exu entry returns a live backend")
    check(backend.Started == true, "the backend starts itself")
    check(type(backend.Features.AutoSteal) == "table", "the Auto Steal Exu feature is registered")
    check(type(backend.Features.AutoStealSelection) == "table", "the selected Terreiro steal feature is registered")
    check(type(backend.Features.AutoSell) == "table", "the Auto Sell feature is registered")
    check(type(backend.Features.AutoHop) == "table", "the Auto Hop Server feature is registered")
    check(type(backend.Store) == "table", "the shared config store is loaded")
    check(ctx.State.__DEPHUB.StealAnExu == backend, "the backend publishes itself")

    local labels = {}
    for _, control in ipairs(ui.Library._Controls) do labels[control.Label] = control end
    check(labels["Auto Steal Exu"] ~= nil and labels["Auto Steal Exu"].Kind == "toggle",
        "the panel has the Auto Steal Exu toggle")
    check(labels["Steal Exu An Selection"] ~= nil and labels["Steal Exu An Selection"].Kind == "toggle",
        "the panel has the selected Terreiro steal toggle")
    local terreiroDropdown = labels["Terreiro"]
    check(terreiroDropdown ~= nil and terreiroDropdown.Kind == "dropdown",
        "the selected Terreiro feature has a dropdown")
    check(terreiroDropdown.Options and #terreiroDropdown.Options == 2
        and terreiroDropdown.Options[1] == "Terreiro1" and terreiroDropdown.Options[2] == "Terreiro4",
        "the dropdown maps available Terreiros from the live Map.Terreiros folder")
    check(labels["Auto Sell Exus"] ~= nil and labels["Auto Sell Exus"].Kind == "toggle",
        "the panel has the Auto Sell Exus toggle")
    check(labels["Auto Hop Server"] ~= nil and labels["Auto Hop Server"].Kind == "toggle",
        "the panel has the Auto Hop Server toggle")
    check(labels["Auto Execute"] ~= nil and labels["Auto Execute"].Kind == "toggle",
        "the panel has the Auto Execute toggle")
    check(labels["Save Config"] ~= nil and labels["Save Config"].Kind == "button",
        "the panel has the Save Config button")
    check(labels["Load Config"] ~= nil and labels["Load Config"].Kind == "button",
        "the panel has the Load Config button")

    -- Auto Upgrade: one toggle per board (base, tread), each a live feature.
    check(type(backend.Features.UpgradeBase) == "table", "the Auto Upgrade Base feature is registered")
    check(type(backend.Features.UpgradeTread) == "table", "the Auto Upgrade Esteira feature is registered")
    check(labels["Auto Upgrade Base"] ~= nil and labels["Auto Upgrade Base"].Kind == "toggle",
        "the panel has the Auto Upgrade Base toggle")
    check(labels["Auto Upgrade Esteira"] ~= nil and labels["Auto Upgrade Esteira"].Kind == "toggle",
        "the panel has the Auto Upgrade Esteira toggle")

    backend:Destroy()
    backend:Destroy()
    check(backend.Destroyed == true, "destroy marks the backend destroyed")
    check(ctx.State.__DEPHUB.StealAnExu == nil, "destroy clears the published state")
end

-- Auto Steal Exu: the loop collects the Runtime exus and, per exu, opens the
-- prompt (MaxActivationDistance=1000, HoldDuration=0, RequiresLineOfSight=false),
-- teleports onto the Root + 3 studs, fires InputHoldBegin/End, and returns to the
-- original position. Driven one step at a time (_step) because the harness does not
-- run the infinite loop.
do
    local ctx = saeContext(103076400317371, 10771168447)
    ctx:MountUI()
    local world = buildWorld(ctx, {exuCount = 2, rootOffset = 3})
    local root = makeCharacter(ctx)   -- starts at (0,0,0)

    local backend = ctx:Run("src/games/steal-an-exu.lua")
    local feature = backend.Features.AutoSteal

    -- The collection sees both exus (each {prompt, ref=Root}) and both are alive.
    local targets = feature:_targets()
    check(type(targets) == "table" and #targets == 2, "the steal collects the Runtime prompts (2)")
    check(feature:_alive(targets[1]) == true, "a fresh target is alive")

    -- Run one step over the first exu and check the mechanism.
    local originalPos = root.CFrame
    feature:_step(targets[1], root, originalPos)

    local prompt = world.fired[1]
    check(prompt.Hold.began == 1 and prompt.Hold.ended == 1,
        "the steal opens and closes the hold (InputHoldBegin then InputHoldEnd)")
    check(prompt.Hold.durationAtBegin == 0, "the steal zeroes HoldDuration before the hold")
    check(prompt.MaxActivationDistance == 1000, "the steal sets MaxActivationDistance to 1000")
    check(prompt.RequiresLineOfSight == false, "the steal disables RequiresLineOfSight")

    -- The step teleports onto the exu Root (y=3) + 3 studs, then returns to the
    -- original position (0,0,0).
    check(root.Position == Vector3.new(0, 0, 0), "the step returns to the original position")

    -- A dead target (the server took the exu): the exu is destroyed, exactly as the
    -- game reaps it -- the prompt and its root go with it. The loop must see it as
    -- not-alive and re-collect instead of firing a stale prompt.
    local gone = world.roots[1].Parent   -- the model owning Root 1
    gone:Destroy()
    check(feature:_alive(targets[1]) == false, "a target whose exu was destroyed is not alive")

    -- The toggle drives the feature and cleans up on destroy.
    check(feature:IsEnabled() == false, "the steal is off until the toggle turns it on")
    check(feature:SetEnabled(true) == true and feature:IsEnabled() == true, "the toggle turns the steal on")
    check(feature:SetEnabled(false) == true and feature:IsEnabled() == false, "the toggle turns the steal off")

    backend:Destroy()
    check(feature:SetEnabled(true) == false, "a destroyed steal refuses to turn on")
end

-- The stale-recovery step: when the loop's current target is gone, it re-collects
-- the Runtime so an exu that SPAWNED after the list was built is picked up -- the
-- "as vezes nao pega o prompt" fix. The refresh is the very code the loop runs, so
-- driving _targets() after a spawn proves the new exu is in the rebuilt list.
do
    local ctx = saeContext(103076400317371, 10771168447)
    ctx:MountUI()
    local world = buildWorld(ctx, {exuCount = 2})
    makeCharacter(ctx)

    local backend = ctx:Run("src/games/steal-an-exu.lua")
    local feature = backend.Features.AutoSteal

    -- The list built at the start sees only the two exus present then.
    local first = feature:_targets()
    check(#first == 2, "the first collection sees the two exus present")

    -- A THIRD exu spawns in the Runtime AFTER the list was built (exactly what the
    -- server does: clones an exu in). The old one-shot list would never see it.
    local runtime = ctx.Services.Workspace:FindFirstChild("Runtime")
    local exu = Instance.new("Model"); exu.Name = "Exu"; exu.Parent = runtime
    local root = Instance.new("Part"); root.Name = "Root"; root.Parent = exu
    root.CFrame = CFrame.new(999, 0, 0)
    local prompt = Instance.new("ProximityPrompt"); prompt.Name = "ProximityPrompt"; prompt.Parent = root

    -- A re-collect (what the loop does when a target is stale) now sees all three.
    local refreshed = feature:_targets()
    check(#refreshed == 3, "the re-collect picks up the exu that spawned after the list was built")

    backend:Destroy()
end

-- Selected Terreiro mode maps each Nest to its nearest unique Runtime Exu.
do
    local ctx = saeContext(103076400317371, 10771168447)
    ctx:MountUI()
    local ws = ctx.Services.Workspace

    local map = Instance.new("Folder"); map.Name = "Map"; map.Parent = ws
    local terreiros = Instance.new("Folder"); terreiros.Name = "Terreiros"; terreiros.Parent = map
    local selected = Instance.new("Folder"); selected.Name = "Terreiro3"; selected.Parent = terreiros
    local selectedNests = Instance.new("Folder"); selectedNests.Name = "Nests"; selectedNests.Parent = selected
    local other = Instance.new("Folder"); other.Name = "Terreiro8"; other.Parent = terreiros
    local otherNests = Instance.new("Folder"); otherNests.Name = "Nests"; otherNests.Parent = other

    local nest1 = Instance.new("Part"); nest1.Name = "Nest1"; nest1.Parent = selectedNests
    nest1.CFrame = CFrame.new(100, 0, 0)
    local nest2 = Instance.new("Part"); nest2.Name = "Nest2"; nest2.Parent = selectedNests
    nest2.CFrame = CFrame.new(200, 0, 0)
    local otherNest = Instance.new("Part"); otherNest.Name = "Nest1"; otherNest.Parent = otherNests
    otherNest.CFrame = CFrame.new(900, 0, 0)

    local runtime = Instance.new("Folder"); runtime.Name = "Runtime"; runtime.Parent = ws
    local prompts = {}
    local function addExu(name, x)
        local model = Instance.new("Model"); model.Name = name; model.Parent = runtime
        local rootPart = Instance.new("Part"); rootPart.Name = "Root"; rootPart.Parent = model
        rootPart.CFrame = CFrame.new(x, 0, 0)
        local prompt = Instance.new("ProximityPrompt"); prompt.Name = "ProximityPrompt"; prompt.Parent = rootPart
        prompt.HoldDuration = 0.5
        prompt.MaxActivationDistance = 6.5
        prompt.Hold = {began = 0, ended = 0, durationAtBegin = nil}
        prompt.InputHoldBegin = function(self)
            self.Hold.began = self.Hold.began + 1
            self.Hold.durationAtBegin = self.HoldDuration
        end
        prompt.InputHoldEnd = function(self)
            self.Hold.ended = self.Hold.ended + 1
        end
        prompts[#prompts + 1] = prompt
    end

    addExu("ExuA", 102)
    addExu("ExuB", 204)
    addExu("ExuC", 905)

    local characterRoot = makeCharacter(ctx)
    local backend = ctx:Run("src/games/steal-an-exu.lua")
    local feature = backend.Features.AutoStealSelection

    check(feature.SelectedOnly == true, "the new feature uses selected-only target filtering")
    check(feature.Terreiro == "Terreiro3", "the selection mode starts with the first discovered Terreiro")
    check(feature:SetTerreiro("Terreiro3") == true, "the selected Terreiro can be changed")
    local selectedTargets = feature:_targets()
    check(#selectedTargets == 2, "selected mode returns only the two Exus mapped to Terreiro3")
    check(selectedTargets[1].model.Name == "ExuA" and selectedTargets[2].model.Name == "ExuB",
        "the Nest-to-Exu mapping chooses the nearest distinct Runtime models")
    check(selectedTargets[1].nestName == "Nest1" and selectedTargets[2].nestName == "Nest2",
        "each mapped Runtime Exu retains its source Nest")

    check(feature:SetTerreiro("Terreiro8") == true, "the selected Terreiro can be switched without reloading")
    local otherTargets = feature:_targets()
    check(#otherTargets == 1 and otherTargets[1].model.Name == "ExuC",
        "switching the dropdown updates the filtered targets")

    feature.Enabled = true
    feature:SetTerreiro("Terreiro3")
    local origin = characterRoot.CFrame
    feature:_step(selectedTargets[1], characterRoot, origin)
    check(prompts[1].Hold.began == 1 and prompts[1].Hold.ended == 1,
        "selected mode reuses the same ProximityPrompt activation step")
    check(prompts[1].Hold.durationAtBegin == 0,
        "selected mode uses the same zero-duration prompt mechanism")
    check(characterRoot.Position == origin.Position,
        "selected mode returns to the exact position where the step started")

    backend:Destroy()
end

-- Auto Steal Exu degrades cleanly when the world is missing: no Runtime, no crash,
-- a reason.
do
    local ctx = saeContext(103076400317371, 10771168447)
    ctx:MountUI()
    makeCharacter(ctx)
    local backend = ctx:Run("src/games/steal-an-exu.lua")
    local feature = backend.Features.AutoSteal

    local targets, reason = feature:_targets()
    check(targets == nil, "no exu targets without workspace.Runtime")
    check(type(reason) == "string", "a missing Runtime records a reason")

    backend:Destroy()
end

-- Auto Hop waits for Runtime to exist and counts only actual Exus carrying
-- Root.ProximityPrompt; an empty Runtime returns zero without starting a hop.
do
    local ctx = saeContext(103076400317371, 10771168447)
    ctx:MountUI()
    local backend = ctx:Run("src/games/steal-an-exu.lua")
    local feature = backend.Features.AutoHop

    local count, reason = feature:RuntimeCount()
    check(count == nil and type(reason) == "string", "Auto Hop waits when Runtime has not spawned")

    local runtime = Instance.new("Folder"); runtime.Name = "Runtime"; runtime.Parent = ctx.Services.Workspace
    count = feature:RuntimeCount()
    check(count == 0, "Auto Hop sees an empty Runtime")

    local exu = Instance.new("Model"); exu.Name = "Exu"; exu.Parent = runtime
    local root = Instance.new("Part"); root.Name = "Root"; root.Parent = exu
    local prompt = Instance.new("ProximityPrompt"); prompt.Name = "ProximityPrompt"; prompt.Parent = root
    count = feature:RuntimeCount()
    check(count == 1, "Auto Hop counts an Exu with Root.ProximityPrompt")

    prompt:Destroy()
    count = feature:RuntimeCount()
    check(count == 0, "Auto Hop sees that the Runtime Exu prompt has disappeared")

    backend:Destroy()
end

-- Auto Upgrade: each toggle clicks the ClickDetector of MY pen (found by Owner,
-- never Pen1), on its own board. Driven directly because the harness does not run
-- spawned threads.
do
    local ctx = saeContext(103076400317371, 10771168447)
    ctx:MountUI()
    local world = buildWorld(ctx)
    makeCharacter(ctx)

    local backend = ctx:Run("src/games/steal-an-exu.lua")
    local base = backend.Features.UpgradeBase
    local tread = backend.Features.UpgradeTread

    check(base ~= nil and tread ~= nil, "both upgrade features are registered")

    -- Each upgrade resolves the ClickDetector on MY pen.
    check(base:Detector() == world.baseDetector, "Auto Upgrade Base targets PenSign.Board.ClickDetector of my pen")
    check(tread:Detector() == world.treadDetector, "Auto Upgrade Esteira targets TreadSign.Board.ClickDetector of my pen")

    -- A click counts how many times each detector is fired. fireclickdetector is
    -- the executor global; it lives on the sandbox env.
    local clicks = {}
    ctx.Env.fireclickdetector = function(detector) clicks[detector] = (clicks[detector] or 0) + 1 end

    check(base:Click(world.baseDetector) == true, "a base upgrade click reports success")
    check(tread:Click(world.treadDetector) == true, "a tread upgrade click reports success")
    check(clicks[world.baseDetector] == 1, "the base ClickDetector is fired")
    check(clicks[world.treadDetector] == 1, "the tread ClickDetector is fired")

    -- One loop body click per feature, driven directly.
    base:Click(base:Detector())
    tread:Click(tread:Detector())
    check(clicks[world.baseDetector] == 2, "a second base click lands on the same detector")
    check(clicks[world.treadDetector] == 2, "a second tread click lands on the same detector")

    -- Toggle contract + clean destroy.
    check(base:SetEnabled(true) == true and base:IsEnabled() == true, "the base upgrade turns on")
    check(base:SetEnabled(false) == true and base:IsEnabled() == false, "the base upgrade turns off")
    check(tread:SetEnabled(true) == true and tread:IsEnabled() == true, "the tread upgrade turns on")
    check(tread:SetEnabled(false) == true and tread:IsEnabled() == false, "the tread upgrade turns off")

    ctx.Env.fireclickdetector = nil
    backend:Destroy()
    check(base:SetEnabled(true) == false, "a destroyed upgrade refuses to turn on")
end

-- Auto Upgrade degrades cleanly with no pen: no detector, no crash, a reason.
do
    local ctx = saeContext(103076400317371, 10771168447)
    ctx:MountUI()
    makeCharacter(ctx)
    local backend = ctx:Run("src/games/steal-an-exu.lua")
    local base = backend.Features.UpgradeBase

    local detector, reason = base:Detector()
    check(detector == nil, "no upgrade detector without a pen")
    check(type(reason) == "string", "a missing upgrade target records a reason")
    check(base:Click(nil) == false, "clicking without a detector is a no-op")

    backend:Destroy()
end

-- Auto Sell: use the exact local GUI path and run as a toggle.
do
    local ctx = saeContext(103076400317371, 10771168447)
    ctx:MountUI()
    local characterRoot = makeCharacter(ctx)

    local clicks = 0
    local guiButton = {
        Kind = "button",
        ClassName = "ImageButton",
        IsA = function(_, class) return class == "GuiButton" or class == "ImageButton" or class == "GuiObject" end,
        GetFullName = function() return "PlayerGui.Menus.Vender Todos.Button.Face" end,
        MouseButton1Click = {Name = "MouseButton1Click"},
        Activate = function() clicks = clicks + 1 end,
    }
    local firedSignals = {}
    ctx.Env.firesignal = function(signal)
        firedSignals[#firedSignals + 1] = signal
        clicks = clicks + 1
    end

    local buttonFrame = Instance.new("Folder")
    buttonFrame.Name = "Button"
    buttonFrame.FindFirstChild = function(_, name)
        if name == "Face" then return guiButton end
    end

    local panel = Instance.new("Folder")
    panel.Name = "Vender Todos"
    panel.FindFirstChild = function(_, name)
        if name == "Button" then return buttonFrame end
    end

    local menus = Instance.new("Folder")
    menus.Name = "Menus"
    menus.FindFirstChild = function(_, name)
        if name == "Vender Todos" then return panel end
    end

    local playerGui = {}
    playerGui.FindFirstChild = function(_, name)
        if name == "Menus" then return menus end
    end
    ctx.Player.PlayerGui = playerGui

    local map = Instance.new("Folder"); map.Name = "Map"; map.Parent = ctx.Services.Workspace
    local plaza = Instance.new("Folder"); plaza.Name = "Plaza"; plaza.Parent = map
    local plazaPart = Instance.new("Part"); plazaPart.Name = "Part"; plazaPart.Parent = plaza
    plazaPart.Position = Vector3.new(900, 10, 900)
    plazaPart.Size = Vector3.new(40, 2, 40)

    local backend = ctx:Run("src/games/steal-an-exu.lua")
    local sell = backend.Features.AutoSell

    check(sell:MoveToPlaza() == true, "Auto Sell teleports to workspace.Map.Plaza.Part")
    check(characterRoot.Position == plazaPart.Position + Vector3.new(0, 4, 0), "Auto Sell stands above the Plaza part")
    check(sell.AtPlaza == true, "Auto Sell records that the player is at the Plaza")

    local lockOwner = {}
    check(sell.Ctx.AcquireMovement(lockOwner) == true, "shared movement lock can be acquired")
    local blockedMove = sell:MoveToPlaza()
    check(blockedMove == false, "Auto Sell does not teleport during another feature movement")
    check(sell.Ctx.ReleaseMovement(lockOwner) == true, "shared movement lock is released")

    check(sell:Button() == guiButton, "Auto Sell resolves the exact Button.Face GuiButton")
    check(sell:Click(guiButton) == true, "Auto Sell activates the exact Face button")
    check(firedSignals[1] == guiButton.MouseButton1Click, "Auto Sell fires Face MouseButton1Click")
    check(clicks == 1, "Auto Sell sends one click")

    check(sell:SetEnabled(true) == true and sell:IsEnabled() == true, "Auto Sell toggle turns on")
    check(sell:SetEnabled(false) == true and sell:IsEnabled() == false, "Auto Sell toggle turns off")

    backend:Destroy()
end

-- Auto Sell degrades cleanly with no PlayerGui: no button, no crash, a reason.
do
    local ctx = saeContext(103076400317371, 10771168447)
    ctx:MountUI()
    makeCharacter(ctx)
    local backend = ctx:Run("src/games/steal-an-exu.lua")
    local sell = backend.Features.AutoSell

    local button, reason = sell:Button()
    check(button == nil, "no sell button without a PlayerGui")
    check(type(reason) == "string", "a missing sell button records a reason")
    check(sell:SetEnabled(true) == true, "Auto Sell can be enabled while waiting for the GUI")
    check(sell:SetEnabled(false) == true, "Auto Sell can be disabled while the GUI is missing")

    backend:Destroy()
end
