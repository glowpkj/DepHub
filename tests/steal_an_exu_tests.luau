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
    ctx.Responses[FEATURE_PREFIX .. "autoupgrade.lua"] = sources[FEATURE_PREFIX .. "autoupgrade.lua"]
    ctx.Responses[FEATURE_PREFIX .. "autosell.lua"] = sources[FEATURE_PREFIX .. "autosell.lua"]
    return ctx
end

-- Builds the minimal world the backend's features read: Map.Pens with one pen
-- owned by the local player (Owner attribute) and a BadgeAnchor, plus the two
-- upgrade boards the Auto Upgrade toggles click.
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

    return {
        pen = pen, anchor = anchor,
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

-- The entry loads, registers the features, and mounts the controls.
do
    local ctx = saeContext(103076400317371, 10771168447)
    local ui = ctx:MountUI()

    local backend = ctx:Run("src/games/steal-an-exu.lua")
    check(type(backend) == "table" and backend.Destroyed == false, "Steal An Exu entry returns a live backend")
    check(backend.Started == true, "the backend starts itself")
    check(type(backend.Features.AutoSell) == "table", "the Auto Sell feature is registered")
    check(ctx.State.__DEPHUB.StealAnExu == backend, "the backend publishes itself")

    local labels = {}
    for _, control in ipairs(ui.Library._Controls) do labels[control.Label] = control end
    check(labels["Auto Steal Exu"] == nil, "the panel no longer has the Auto Steal Exu toggle")
    check(labels["Steal All"] == nil, "the panel no longer has the Steal All button")
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
