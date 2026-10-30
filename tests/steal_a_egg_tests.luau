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

    -- Teleport: the CFrame tween fly ported from Blox Fruits. Go() tweens the
    -- HumanoidRootPart to the target; capture it on the existing TweenService
    -- (the backend grabbed the service at load time, so it must be mutated in
    -- place, not swapped after Run).
    local root = object("Part", "HumanoidRootPart", character); root.Position = Vector3.new(0, 0, 0)
    backend.Values.FlySpeed = 200
    check(backend:SetFlySpeed(300) and backend.Values.FlySpeed == 300, "fly speed is settable")
    check(backend:SetFlySpeed(0) == false and backend:SetFlySpeed("x") == false, "fly speed rejects invalid values")
    local captured = nil
    local realCreate = ctx.Services.TweenService.Create
    ctx.Services.TweenService.Create = function(_, target, info, goal)
        captured = {Target = target, Goal = goal}
        return {Play = function() captured.Played = true end, Cancel = function() captured.Cancelled = true end, Completed = {Connect = function() end}}
    end
    local okGo = backend:Go(Vector3.new(100, 0, 0))
    check(okGo == true, "Go starts a fly")
    check(captured ~= nil and captured.Target == root, "fly tweens the HumanoidRootPart")
    check(captured.Goal ~= nil and captured.Goal.CFrame.Position == Vector3.new(100, 0, 0), "fly tweens to the requested position")
    check(captured.Played == true, "fly plays the tween")
    -- While a fly is active the heartbeat zeroes velocity and strips collision.
    root.AssemblyLinearVelocity = Vector3.new(5, 5, 5)
    root.CanCollide = true   -- Roblox defaults a Part's CanCollide to true
    ctx.Services.RunService.Heartbeat:Fire()
    check(root.AssemblyLinearVelocity == Vector3.new(0, 0, 0), "fly heartbeat zeroes linear velocity")
    -- The same heartbeat strips collision (noclip) while the fly is active.
    check(root.CanCollide == false, "fly heartbeat disables collision")
    backend:CancelFly()
    check(captured.Cancelled == true and backend.Tween == nil, "cancel stops the active fly")
    check(backend:Go("not a vector") == false, "Go rejects a non-vector target")
    ctx.Services.TweenService.Create = realCreate

    -- Waypoints: saved in game (the map is not known ahead of time), keyed by the
    -- current position when no name is given.
    local before = #backend.Waypoints
    check(backend:AddWaypoint("Base") == true and #backend.Waypoints == before + 1, "AddWaypoint stores a waypoint")
    local wp = backend.Waypoints[#backend.Waypoints]
    check(wp.name == "Base" and wp.pos ~= nil, "waypoint carries a name and a position")
    check(backend:RemoveWaypoint("Base") == true and #backend.Waypoints == before, "RemoveWaypoint drops it")
    check(backend:RemoveWaypoint("Nope") == false, "RemoveWaypoint rejects an unknown name")

    backend:Destroy()
    backend:Destroy()
    check(backend.Destroyed == true and backend:SetToggle("Speed", true) == false, "destroyed backend rejects toggles")
    check(ctx.State.__DEPHUB.StealAnEgg == nil, "destroy releases the published runtime")
end
