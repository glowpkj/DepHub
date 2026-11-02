-- Steal An Exu: the backend plus its Auto Steal Exu feature.
--
-- What is checked here is the CONTRACT and the mechanism against API doubles, not
-- the live game: the backend routes from its own ids, loads the feature from the
-- repo, mounts the toggle + terreiro dropdown, and the steal step finds the
-- player's pen by the Owner attribute (never a fixed Pen1), teleports to the
-- Nest, fires the right Runtime prompt and returns to the base -- all without
-- erroring when the world is missing.
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
    return ctx
end

-- Builds the minimal world the feature reads: Map.Terreiros.TerreiroN.Nests with
-- Nest1..NestM, Map.Pens with one pen owned by the local player (Owner attribute)
-- and a BadgeAnchor, and Runtime with exu models carrying Root.ProximityPrompt.
--
-- RootOffset: the exu Root sits this far from its Nest (studs). The default is 0
-- (Root on the Nest); tests that care about the "teleport to the Root, not the
-- Nest" fix pass a nonzero offset so the two positions differ.
local function buildWorld(ctx, options)
    options = options or {}
    local ws = ctx.Services.Workspace

    local map = Instance.new("Folder"); map.Name = "Map"; map.Parent = ws
    local terreiros = Instance.new("Folder"); terreiros.Name = "Terreiros"; terreiros.Parent = map
    local terreiro = Instance.new("Folder"); terreiro.Name = options.terreiro or "Terreiro1"; terreiro.Parent = terreiros
    local nests = Instance.new("Folder"); nests.Name = "Nests"; nests.Parent = terreiro
    for index = 1, (options.nestCount or 2) do
        local nest = Instance.new("Part"); nest.Name = "Nest" .. index; nest.Parent = nests
        -- The feature reads a part's CFrame (what the game exposes), so the world
        -- sets CFrame -- Position on a part only mirrors it.
        nest.CFrame = CFrame.new(index * 100, 0, 0)
    end

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

    local runtime = Instance.new("Folder"); runtime.Name = "Runtime"; runtime.Parent = ws
    local fired, roots = {}, {}
    local offset = options.rootOffset or 0
    for index = 1, (options.exuCount or 2) do
        local exu = Instance.new("Model"); exu.Name = "Exu"; exu.Parent = runtime
        local root = Instance.new("Part"); root.Name = "Root"; root.Parent = exu
        root.CFrame = CFrame.new(index * 100, offset, 0)   -- near Nest{index}
        roots[#roots + 1] = root
        local prompt = Instance.new("ProximityPrompt"); prompt.Name = "ProximityPrompt"; prompt.Parent = root
        fired[#fired + 1] = prompt
    end
    return {
        fired = fired, roots = roots, pen = pen, anchor = anchor,
        baseDetector = baseDetector, treadDetector = treadDetector,
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

-- The entry loads, registers the feature, and mounts exactly the two controls.
do
    local ctx = saeContext(103076400317371, 10771168447)
    local ui = ctx:MountUI()

    local backend = ctx:Run("src/games/steal-an-exu.lua")
    check(type(backend) == "table" and backend.Destroyed == false, "Steal An Exu entry returns a live backend")
    check(backend.Started == true, "the backend starts itself")
    check(type(backend.Features.AutoSteal) == "table", "the Auto Steal feature is registered")
    check(ctx.State.__DEPHUB.StealAnExu == backend, "the backend publishes itself")

    local labels = {}
    for _, control in ipairs(ui.Library._Controls) do labels[control.Label] = control end
    check(labels["Auto Steal Exu"] ~= nil and labels["Auto Steal Exu"].Kind == "toggle",
        "the panel has the Auto Steal Exu toggle")
    local dropdown = labels["Terreiro"]
    check(dropdown ~= nil and dropdown.Kind == "dropdown", "the panel has the Terreiro dropdown")
    check(dropdown.Options and #dropdown.Options == 9 and dropdown.Options[1] == "Terreiro1"
        and dropdown.Options[9] == "Terreiro9", "the dropdown lists Terreiro1..Terreiro9")
    check(labels["Steal All"] ~= nil and labels["Steal All"].Kind == "button",
        "the panel has the Steal All button")

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

-- The steal step: find the pen by Owner (not Pen1), teleport ONTO the Exu Root
-- (not the Nest -- the bug where the Nest sat far from the exu), fire the Runtime
-- prompt, then return to the base BadgeAnchor.
do
    local ctx = saeContext(103076400317371, 10771168447)
    ctx:MountUI()
    -- The exu Root sits 3 studs off its Nest, so a teleport to the Nest would end
    -- up at the Nest, distinct from the Root. The feature must land on the Root.
    local world = buildWorld(ctx, {rootOffset = 3})
    local root = makeCharacter(ctx)

    local backend = ctx:Run("src/games/steal-an-exu.lua")
    local feature = backend.Features.AutoSteal

    -- The pen is Pen7, but it is MINE (Owner == my UserId), so it is the base.
    check(feature:MyPen() == world.pen, "the base is found by the Owner attribute, not by Pen1")
    local anchor = feature:PenAnchor()
    check(anchor ~= nil and anchor.Position == Vector3.new(0, 50, 0), "the base anchor is the BadgeAnchor")

    -- The executor global the feature calls to use a prompt. It lives on the
    -- sandbox env (the same table a real executor publishes it to).
    local firedCount = 0
    ctx.Env.fireproximityprompt = function(prompt)
        for _, candidate in ipairs(world.fired) do if candidate == prompt then firedCount = firedCount + 1 end end
    end

    -- Record where each teleport lands, so the test can prove the target is the
    -- exu Root (y = 3 beside Nest1) and never the Nest (y = 0).
    local teleports = {}
    local originalTeleport = feature.TeleportTo
    feature.TeleportTo = function(self, cframe)
        teleports[#teleports + 1] = cframe.Position
        return originalTeleport(self, cframe)
    end

    local ok, stole = feature:StealOnce()
    check(ok == true and stole >= 1, "StealOnce reaches and counts exu prompts")
    check(firedCount >= 1, "the Runtime ProximityPrompt is fired")

    -- The teleport onto an exu lands on its Root (offset 3 from the Nest); it
    -- must not use the bare Nest position.
    local landedOnRoot = false
    for _, position in ipairs(teleports) do
        if position.Y == 3 then landedOnRoot = true end
    end
    check(landedOnRoot, "the steal teleports onto the Exu Root, not the Nest")

    -- After the step the character is back at the base anchor (it started at 0,0,0
    -- and the anchor is at 0,50,0).
    check(root.Position == Vector3.new(0, 50, 0), "the step returns to the base anchor")
    ctx.Env.fireproximityprompt = nil
    feature.TeleportTo = originalTeleport

    -- With the toggle on, the loop runs; with it off it stops.
    check(feature:SetEnabled(true) == true and feature:IsEnabled() == true, "the feature turns on")
    check(feature:SetEnabled(false) == true and feature:IsEnabled() == false, "the feature turns off")

    backend:Destroy()
end

-- While the run is on, the character floats (anchored) and clips through the
-- world (noclip); when it stops, both are restored.
do
    local ctx = saeContext(103076400317371, 10771168447)
    ctx:MountUI()
    local world = buildWorld(ctx)
    local root = makeCharacter(ctx)
    local torso = Instance.new("Part"); torso.Name = "Torso"; torso.Parent = root.Parent
    torso.CanCollide = true
    root.Anchored = false

    local backend = ctx:Run("src/games/steal-an-exu.lua")
    local feature = backend.Features.AutoSteal

    ctx.Env.fireproximityprompt = function() end
    -- Entering the steal state freezes the body and turns collision off.
    feature:_enterStealState()
    check(root.Anchored == true, "the body is anchored while stealing (floats in place)")
    check(root.CanCollide == false, "the body has no collision while stealing (noclip)")
    check(torso.CanCollide == false, "noclip covers every part, not just the root")

    local ok, stolen = feature:StealAll()
    check(ok == true and stolen == 2, "Steal All counts the exus it steals (2)")

    -- Leaving the state restores the original collision and anchoring.
    feature:_leaveStealState()
    check(root.Anchored == false, "anchoring is restored after the run")
    check(root.CanCollide == true, "collision is restored after the run")
    check(torso.CanCollide == true, "collision is restored on every part")

    -- Destroy must also leave nothing frozen behind.
    feature:_enterStealState()
    backend:Destroy()
    check(root.Anchored == false, "destroy unfreezes the body")
    check(root.CanCollide == true, "destroy restores collision")

    ctx.Env.fireproximityprompt = nil
end

-- Degrades cleanly when the world is missing: no pen, no crash, and a reason.
do
    local ctx = saeContext(103076400317371, 10771168447)
    ctx:MountUI()
    makeCharacter(ctx)
    local backend = ctx:Run("src/games/steal-an-exu.lua")
    local feature = backend.Features.AutoSteal

    check(feature:MyPen() == nil, "no pen when the base is missing")
    check(feature:PenAnchor() == nil, "no anchor when the base is missing")
    local ok = feature:StealOnce()
    check(ok == false, "StealOnce does not throw without a base")
    check(type(feature.LastError) == "string", "a failed step records a reason")

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

-- Steal All: one pass over every Terreiro (9 down to 1), firing each Runtime
-- prompt, and returning to the CFrame the pass started from. The pass is driven
-- directly (StealAll) because the harness does not run spawned threads.
do
    local ctx = saeContext(103076400317371, 10771168447)
    ctx:MountUI()
    local ws = ctx.Services.Workspace

    local map = Instance.new("Folder"); map.Name = "Map"; map.Parent = ws
    local terreiros = Instance.new("Folder"); terreiros.Name = "Terreiros"; terreiros.Parent = map
    local runtime = Instance.new("Folder"); runtime.Name = "Runtime"; runtime.Parent = ws
    local fired = {}

    -- Two terreiros, each with two nests; every nest gets a Runtime exu whose Root
    -- sits on it. Nest positions are unique so nearestRuntimeExu picks the right one.
    local nestPositions = {}
    for _, terreiroName in ipairs({"Terreiro1", "Terreiro9"}) do
        local terreiro = Instance.new("Folder"); terreiro.Name = terreiroName; terreiro.Parent = terreiros
        local nests = Instance.new("Folder"); nests.Name = "Nests"; nests.Parent = terreiro
        for index = 1, 2 do
            local x = (#nestPositions + 1) * 100
            local nest = Instance.new("Part"); nest.Name = "Nest" .. index; nest.Parent = nests
            nest.CFrame = CFrame.new(x, 0, 0)
            nestPositions[#nestPositions + 1] = x

            local exu = Instance.new("Model"); exu.Name = "Exu"; exu.Parent = runtime
            local root = Instance.new("Part"); root.Name = "Root"; root.Parent = exu
            root.CFrame = CFrame.new(x, 0, 0)
            local prompt = Instance.new("ProximityPrompt"); prompt.Name = "ProximityPrompt"; prompt.Parent = root
            prompt.MaxActivationDistance = 6.5
            fired[#fired + 1] = prompt
        end
    end

    -- A base for the origin position, and a character that starts at a known spot.
    local pens = Instance.new("Folder"); pens.Name = "Pens"; pens.Parent = map
    local pen = Instance.new("Model"); pen.Name = "Pen3"; pen.Parent = pens
    pen:SetAttribute("Owner", MY_USER_ID)
    local anchor = Instance.new("Part"); anchor.Name = "BadgeAnchor"; anchor.Parent = pen
    anchor.CFrame = CFrame.new(0, 50, 0)

    local character = Instance.new("Model"); character.Name = "Character"; character.Parent = ws
    ctx.Player.Character = character
    local hrp = Instance.new("Part"); hrp.Name = "HumanoidRootPart"; hrp.Parent = character
    hrp.CFrame = CFrame.new(0, 50, 0)   -- standing at the base

    local backend = ctx:Run("src/games/steal-an-exu.lua")
    local feature = backend.Features.AutoSteal

    local firedCount = 0
    ctx.Env.fireproximityprompt = function(prompt)
        for _, candidate in ipairs(fired) do if candidate == prompt then firedCount = firedCount + 1 end end
    end

    local ok, count = feature:StealAll()
    check(ok == true and count == 4, "Steal All counts every exu it fired (4)")
    -- Each exu is fired twice: once from range, once after the blink-teleport.
    check(firedCount == 8, "each exu prompt is fired, wide then on arrival")
    -- The pass hands every prompt back its original range; the widened value must
    -- not be left behind after the pass.
    local restored = true
    for _, prompt in ipairs(fired) do if prompt.MaxActivationDistance ~= 6.5 then restored = false end end
    check(restored, "each prompt's MaxActivationDistance is restored after firing")
    check(hrp.Position == Vector3.new(0, 50, 0), "the pass returns to the base it started from")
    ctx.Env.fireproximityprompt = nil

    backend:Destroy()
end
