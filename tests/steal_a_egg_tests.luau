-- Steal An Egg: the backend carries only the walk-speed feature ported from Blox
-- Fruits -- a toggle, a slider and a RenderStepped loop that re-applies the
-- value. Behavioral checks with API doubles; no claim of in-game functionality.
do
    -- Routing: the loader must pick this backend from the place id.
    local ctx = sandbox(107778070777162, 10563114921)
    ctx.Responses["src/version.txt"] = "0.0.77"
    ctx:Provide("src/games/steal-a-egg.lua", {Destroyed = false})
    check(ctx:Run("DepHub.lua") == true, "Steal An Egg routes from its place id")
    check(ctx.State.__DEPHUB.StealAnEgg ~= nil, "Steal An Egg route exposes its backend")
    check(ctx.State.__DEPHUB.BloodStrike == nil and ctx.State.__DEPHUB.BloxFruits == nil, "Steal An Egg route does not leak another backend")
    check(ctx.State.__DEPHUB.Mode == "steal-a-egg", "Steal An Egg route names its backend")
end

do
    local ctx = sandbox(107778070777162, 10563114921)
    ctx:MountUI()
    local function object(class, name, parent)
        local item = Instance.new(class); item.Name = name; item.Parent = parent; return item
    end
    local character = object("Model", "Character", ctx.Player); ctx.Player.Character = character
    local humanoid = object("Humanoid", "Humanoid", character); humanoid.WalkSpeed = 16

    local backend = ctx:Run("src/games/steal-a-egg.lua")
    check(type(backend) == "table" and backend.Destroyed == false, "Steal An Egg entry returns a live backend")
    check(backend.Values.WalkSpeed == 50, "walk speed defaults to 50")

    -- The loop re-applies the value on RenderStepped, but only while the toggle
    -- is on. Fire the render signal and assert it lands on the humanoid.
    check(backend:SetToggle("Speed", true) == true, "speed toggle turns on")
    backend:SetSpeed(120)
    ctx.Services.RunService.RenderStepped:Fire()
    check(humanoid.WalkSpeed == 120, "render loop applies the chosen walk speed")

    -- A game-side rewrite between frames is overwritten on the next frame, which
    -- is the whole reason the loop exists.
    humanoid.WalkSpeed = 16
    ctx.Services.RunService.RenderStepped:Fire()
    check(humanoid.WalkSpeed == 120, "render loop wins over a game-side rewrite")

    -- Slider clamps to the BF range (16..300) and rejects junk.
    check(backend:SetSpeed(999) and backend.Values.WalkSpeed == 300, "walk speed clamps to 300")
    check(backend:SetSpeed(1) and backend.Values.WalkSpeed == 16, "walk speed clamps to 16")
    check(backend:SetSpeed("x") == false and backend:SetSpeed(0/0) == false, "walk speed rejects invalid values")

    -- Turning the toggle off hands the value back to the game and the loop stops.
    check(backend:SetToggle("Speed", false) == true, "speed toggle turns off")
    check(humanoid.WalkSpeed == 16, "disabling restores the default walk speed")
    humanoid.WalkSpeed = 20
    ctx.Services.RunService.RenderStepped:Fire()
    check(humanoid.WalkSpeed == 20, "render loop is inert while the toggle is off")

    check(backend:GetToggle("Speed") == false and backend:SetToggle("Nope", true) == false, "unknown toggles are rejected")

    backend:Destroy()
    backend:Destroy()
    check(backend.Destroyed == true and backend:SetToggle("Speed", true) == false, "destroyed backend rejects toggles")
    check(ctx.State.__DEPHUB.StealAnEgg == nil, "destroy releases the published runtime")
end
