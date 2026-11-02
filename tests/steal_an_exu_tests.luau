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
    return ctx
end

-- Builds the minimal world the feature reads: Map.Terreiros.TerreiroN.Nests with
-- Nest1..NestM, Map.Pens with one pen owned by the local player (Owner attribute)
-- and a BadgeAnchor, and Runtime with exu models carrying Root.ProximityPrompt.
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

    local runtime = Instance.new("Folder"); runtime.Name = "Runtime"; runtime.Parent = ws
    local fired = {}
    for index = 1, (options.exuCount or 2) do
        local exu = Instance.new("Model"); exu.Name = "Exu"; exu.Parent = runtime
        local root = Instance.new("Part"); root.Name = "Root"; root.Parent = exu
        root.CFrame = CFrame.new(index * 100, 0, 0)   -- sits on Nest{index}
        local prompt = Instance.new("ProximityPrompt"); prompt.Name = "ProximityPrompt"; prompt.Parent = root
        fired[#fired + 1] = prompt
    end
    return {fired = fired, pen = pen, anchor = anchor}
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

    backend:Destroy()
    backend:Destroy()
    check(backend.Destroyed == true, "destroy marks the backend destroyed")
    check(ctx.State.__DEPHUB.StealAnExu == nil, "destroy clears the published state")
end

-- The steal step: find the pen by Owner (not Pen1), teleport to the Nest, fire
-- the Runtime prompt, then return to the base BadgeAnchor.
do
    local ctx = saeContext(103076400317371, 10771168447)
    ctx:MountUI()
    local world = buildWorld(ctx)
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

    local ok = feature:StealOnce()
    check(ok == true, "StealOnce reaches an exu prompt")
    check(firedCount >= 1, "the Runtime ProximityPrompt is fired")

    -- After the step the character is back at the base anchor (it started at 0,0,0
    -- and the anchor is at 0,50,0).
    check(root.Position == Vector3.new(0, 50, 0), "the step returns to the base anchor")
    ctx.Env.fireproximityprompt = nil

    -- With the toggle on, the loop runs; with it off it stops.
    check(feature:SetEnabled(true) == true and feature:IsEnabled() == true, "the feature turns on")
    check(feature:SetEnabled(false) == true and feature:IsEnabled() == false, "the feature turns off")

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
