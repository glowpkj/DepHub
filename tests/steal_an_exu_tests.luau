-- Steal An Exu: the backend plus its Auto Steal Exu feature.
--
-- What is checked here is the CONTRACT and the mechanism against API doubles, not
-- the live game: the backend routes from its own ids, loads the feature from the
-- repo, mounts the toggle + Steal All button, and the steal step finds the
-- player's pen by the Owner attribute (never a fixed Pen1), teleports onto the
-- Runtime Exu Root + 3 studs, widens the prompt (MaxActivationDistance=1000,
-- HoldDuration=0, RequiresLineOfSight=false) and fires the hold
-- (InputHoldBegin/End) -- all without erroring when the world is missing.
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
        prompt.HoldDuration = 0.5
        prompt.MaxActivationDistance = 6.5
        -- The prompt exposes the hold API the real game does. The steal mechanism
        -- (the updated reference) widens the prompt (MaxActivationDistance=1000,
        -- HoldDuration=0, RequiresLineOfSight=false), then InputHoldBegin + End.
        -- The doubles record each call and the HoldDuration value seen AT THE
        -- MOMENT of InputHoldBegin, so the test can prove the zeroing.
        prompt.Hold = {began = 0, ended = 0, durationAtBegin = nil, restored = nil}
        prompt.InputHoldBegin = function(self)
            self.Hold.began = self.Hold.began + 1
            self.Hold.durationAtBegin = self.HoldDuration
        end
        prompt.InputHoldEnd = function(self)
            self.Hold.ended = self.Hold.ended + 1
            self.Hold.restored = self.HoldDuration
        end
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
    check(type(backend.Features.AutoSell) == "table", "the Auto Sell feature is registered")
    check(ctx.State.__DEPHUB.StealAnExu == backend, "the backend publishes itself")

    local labels = {}
    for _, control in ipairs(ui.Library._Controls) do labels[control.Label] = control end
    check(labels["Auto Steal Exu"] ~= nil and labels["Auto Steal Exu"].Kind == "toggle",
        "the panel has the Auto Steal Exu toggle")
    check(labels["Terreiro"] == nil, "the panel no longer has a Terreiro dropdown (the sweep covers every exu)")
    check(labels["Steal All"] ~= nil and labels["Steal All"].Kind == "button",
        "the panel has the Steal All button")
    check(labels["Sell All Exus"] ~= nil and labels["Sell All Exus"].Kind == "button",
        "the panel has the Sell All Exus button")

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

-- The steal step: find the pen by Owner (not Pen1), teleport onto the exu's Root
-- (the reference script: ref.Position + 3 studs up), open the prompt
-- (MaxActivationDistance=1000, HoldDuration=0, RequiresLineOfSight=false), fire
-- InputHoldBegin/End, then return to the base.
do
    local ctx = saeContext(103076400317371, 10771168447)
    ctx:MountUI()
    -- The exu Root sits 3 studs off its Nest (y=3), so the reference teleport
    -- (Root + 3) lands at y=6 -- derived from the EXU, not the Nest (y=0).
    local world = buildWorld(ctx, {rootOffset = 3})
    local root = makeCharacter(ctx)

    local backend = ctx:Run("src/games/steal-an-exu.lua")
    local feature = backend.Features.AutoSteal

    -- The pen is Pen7, but it is MINE (Owner == my UserId), so it is the base.
    check(feature:MyPen() == world.pen, "the base is found by the Owner attribute, not by Pen1")
    local anchor = feature:PenAnchor()
    check(anchor ~= nil and anchor.Position == Vector3.new(0, 50, 0), "the base anchor is the BadgeAnchor")

    -- Record where each teleport lands, so the test can prove the target is the
    -- exu Root (y = 3 beside Nest1) plus 3, never the Nest (y = 0).
    local teleports = {}
    local originalTeleport = feature.TeleportTo
    feature.TeleportTo = function(self, cframe)
        teleports[#teleports + 1] = cframe.Position
        return originalTeleport(self, cframe)
    end

    local ok, stole = feature:StealOnce()
    check(ok == true and stole == 2, "StealOnce sweeps and counts every exu prompt (2)")

    -- The prompt is ACTED ON by the working mechanism: the hold is opened and
    -- closed (InputHoldBegin then InputHoldEnd), with HoldDuration zeroed at the
    -- moment of the hold.
    local actedAll, zeroedAll = true, true
    for _, prompt in ipairs(world.fired) do
        if not (prompt.Hold.began >= 1 and prompt.Hold.ended >= 1) then actedAll = false end
        if prompt.Hold.durationAtBegin ~= 0 then zeroedAll = false end
    end
    check(actedAll, "every reached prompt is held (InputHoldBegin then InputHoldEnd)")
    check(zeroedAll, "the steal zeroes HoldDuration before firing the hold")

    -- The prompt is WIDENED before the hold: infinite reach, no line-of-sight --
    -- that is what makes the server accept the steal (the updated reference).
    local widenedAll, losAll = true, true
    for _, prompt in ipairs(world.fired) do
        if prompt.MaxActivationDistance ~= 1000 then widenedAll = false end
        if prompt.RequiresLineOfSight ~= false then losAll = false end
    end
    check(widenedAll, "the steal sets MaxActivationDistance to 1000")
    check(losAll, "the steal disables RequiresLineOfSight")

    -- The teleport lands on the exu Root (y=3) plus 3 studs up, so y=6 -- it
    -- follows the exu, not the Nest (y=0). The updated reference mechanism.
    local landedOnExu = false
    for _, position in ipairs(teleports) do
        if position.Y == 6 then landedOnExu = true end
    end
    check(landedOnExu, "the steal teleports onto the exu Root + 3 studs, not the Nest")

    -- After the step the character is back at the base anchor (it started at 0,0,0
    -- and the anchor is at 0,50,0).
    check(root.Position == Vector3.new(0, 50, 0), "the step returns to the base anchor")
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
end

-- Fallback: a build whose prompt has no InputHold* (older/other executor) still
-- steals through the fireproximityprompt global instead of throwing.
do
    local ctx = saeContext(103076400317371, 10771168447)
    ctx:MountUI()
    local world = buildWorld(ctx)
    local root = makeCharacter(ctx)

    local backend = ctx:Run("src/games/steal-an-exu.lua")
    local feature = backend.Features.AutoSteal

    -- Strip the hold API so the feature must fall back.
    for _, prompt in ipairs(world.fired) do
        prompt.InputHoldBegin = nil
        prompt.InputHoldEnd = nil
    end
    local firedCount = 0
    ctx.Env.fireproximityprompt = function(prompt)
        for _, candidate in ipairs(world.fired) do if candidate == prompt then firedCount = firedCount + 1 end end
    end

    local ok, stole = feature:StealOnce()
    check(ok == true and stole >= 1, "without InputHold* the step still steals (fallback)")
    check(firedCount >= 1, "the fallback uses fireproximityprompt")
    check(root.Position == Vector3.new(0, 50, 0), "the fallback step still returns to the base")

    ctx.Env.fireproximityprompt = nil
    backend:Destroy()
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

-- The list of exus is collected ONCE, at the start of the pass -- exactly like the
-- reference script. So an exu already gone when the pass starts (the server took
-- it) is simply not in the list: the pass reaches only the ones still in Runtime.
do
    local ctx = saeContext(103076400317371, 10771168447)
    ctx:MountUI()
    local world = buildWorld(ctx, {exuCount = 2})
    local root = makeCharacter(ctx)

    local backend = ctx:Run("src/games/steal-an-exu.lua")
    local feature = backend.Features.AutoSteal

    -- Take the FIRST exu out of the Runtime BEFORE the pass (as a successful steal
    -- leaves it). The one-time collection then never sees it.
    local gone = world.roots[1].Parent            -- the model that owns Root 1
    gone.Parent = nil

    local ok, stole = feature:StealOnce()

    -- Only the exu still in the Runtime is in the collected list.
    check(ok == true and stole == 1, "the pass collects the exus once and reaches only the live one (1)")
    check(world.fired[1].Hold.began == 0, "the gone exu's prompt is never fired")
    check(world.fired[2].Hold.began == 1, "the exu still in the Runtime is fired")
    check(root.Position == Vector3.new(0, 50, 0), "the step returns to the base anchor")

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

-- Auto Sell: find the "Vender Todos" clickable in the PlayerGui and click it.
--
-- The REAL structure (from the game log) is:
--
--     PlayerGui.Menus["Vender Todos"]        -- a FRAME (the container)
--     ...                                             .<GuiButton inside>
--
-- The old code assumed PlayerGui.Menus["Vender Todos"].Button WAS a GuiButton and
-- blew up ("MouseButton1Click is not a valid member of Frame"). So this test builds
-- the container as a FRAME and puts the real GuiButton INSIDE it -- the feature must
-- descend to the GuiButton and activate it, never index the Frame.
do
    local ctx = saeContext(103076400317371, 10771168447)
    ctx:MountUI()
    makeCharacter(ctx)

    -- A clickable GuiButton double (records activations; exposes MouseButton1Click
    -- like a real GuiButton so the firesignal path is exercised).
    local clicks = 0
    local guiButton = {
        Kind = "button",
        ClassName = "TextButton",
        IsA = function(_, c) return c == "GuiButton" or c == "TextButton" or c == "GuiObject" end,
        GetFullName = function() return "PlayerGui.Menus.Vender Todos.Label" end,
        -- A non-nil signal value: the feature must only touch this AFTER checking
        -- the object actually has it (a Frame would error on the index).
        MouseButton1Click = {Name = "MouseButton1Click"},
        Activate = function() clicks = clicks + 1 end,
    }
    guiButton.FindFirstChild = function() end
    guiButton.FindFirstChildWhichIsA = function() end
    -- firesignal is the executor virtual-click: record it so we can prove the
    -- feature fired the right signal on the GuiButton.
    local firedSignals = {}
    ctx.Env.firesignal = function(signal) firedSignals[#firedSignals + 1] = signal end

    -- The container: a FRAME named "Vender Todos" (NOT a GuiButton). Indexing
    -- MouseButton1Click on it must never happen -- mirror Roblox, where the index
    -- errors ("MouseButton1Click is not a valid member of Frame").
    local frame = setmetatable({
        Kind = "frame",
        ClassName = "Frame",
        IsA = function(_, c) return c == "Frame" or c == "GuiObject" end,
        GetFullName = function() return "PlayerGui.Menus.Vender Todos" end,
    }, {
        __index = function(_, key)
            error(key .. " is not a valid member of Frame", 2)
        end,
    })
    frame.FindFirstChild = function(_, name) if name == "Label" then return guiButton end end
    frame.FindFirstChildWhichIsA = function(_, class) if class == "GuiButton" then return guiButton end end

    local menus = Instance.new("Folder"); menus.Name = "Menus"
    menus.FindFirstChild = function(_, name) if name == "Vender Todos" then return frame end end

    local playerGui = {}
    playerGui.FindFirstChild = function(_, name) if name == "Menus" then return menus end end
    ctx.Player.PlayerGui = playerGui

    local backend = ctx:Run("src/games/steal-an-exu.lua")
    local sell = backend.Features.AutoSell

    -- The feature must descend INTO the Frame and return the GuiButton -- and must
    -- never index MouseButton1Click on the Frame (that is the crash we fixed).
    check(sell:Button() == guiButton, "the sell feature descends into the Vender Todos Frame to the GuiButton")

    local ok, count = sell:Sell()
    check(ok == true and count >= 1, "Sell clicks the clickable and reports the sell")
    -- The click lands by firing the GuiButton's MouseButton1Click (the virtual
    -- click). Activate is only the fallback when no firesignal exists.
    check(firedSignals[1] == guiButton.MouseButton1Click, "the sell fires the GuiButton's MouseButton1Click")

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
    check(sell:Sell() == false, "selling with no button is a no-op")

    backend:Destroy()
end

-- Steal All: one pass over EVERY exu in the Runtime, stealing each and returning
-- to the CFrame the pass started from. The pass is driven directly (StealAll)
-- because the harness does not run spawned threads.
do
    local ctx = saeContext(103076400317371, 10771168447)
    ctx:MountUI()
    local ws = ctx.Services.Workspace

    local map = Instance.new("Folder"); map.Name = "Map"; map.Parent = ws
    local runtime = Instance.new("Folder"); runtime.Name = "Runtime"; runtime.Parent = ws
    local fired = {}

    -- Four exus in the Runtime, each with a Root.ProximityPrompt. The sweep is by
    -- Runtime children, so the count of steals must equal the exu count (this is
    -- the "pega varios" contract).
    for index = 1, 4 do
        local x = index * 100
        local exu = Instance.new("Model"); exu.Name = "Exu"; exu.Parent = runtime
        local root = Instance.new("Part"); root.Name = "Root"; root.Parent = exu
        root.CFrame = CFrame.new(x, 0, 0)
        local prompt = Instance.new("ProximityPrompt"); prompt.Name = "ProximityPrompt"; prompt.Parent = root
        prompt.MaxActivationDistance = 6.5
        prompt.HoldDuration = 0.5
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

    local ok, count = feature:StealAll()
    check(ok == true and count == 4, "Steal All counts every exu in the Runtime (4)")
    -- Every exu is ACTED ON by the working mechanism: HoldDuration zeroed at
    -- InputHoldBegin and the hold closed.
    local acted, zeroed = true, true
    for _, prompt in ipairs(fired) do
        if not (prompt.Hold.began >= 1 and prompt.Hold.ended >= 1) then acted = false end
        if prompt.Hold.durationAtBegin ~= 0 then zeroed = false end
    end
    check(acted, "every exu in the pass is held (InputHoldBegin then InputHoldEnd)")
    check(zeroed, "the pass zeroes HoldDuration before firing each hold")
    check(hrp.Position == Vector3.new(0, 50, 0), "the pass returns to the base it started from")

    backend:Destroy()
end
