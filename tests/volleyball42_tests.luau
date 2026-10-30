-- Volleyball 4.2: the new assistance features must drive real state, not just
-- register controls. Auto Position moves the character's root toward the
-- predicted landing, Look at Ball rotates the camera onto the ball, and Jump
-- Boost applies and then restores the humanoid's jump values.
do
    local ctx = sandbox(1316421563, 1316421563)
    local ui = ctx:MountUI()

    -- A fake clock so the prediction history has a stable time base: the module
    -- reads os.clock() for velocity/contact debounce, and real wall time between
    -- Heartbeat fires would be near zero and could trip the MAX_SPEED guard.
    local clock = 0
    ctx.Env.os = {clock = function() return clock end}
    local function tick(dt)
        dt = dt or 0.05
        clock = clock + dt
        ctx.Services.RunService.Heartbeat:Fire(dt)
    end

    -- The prediction ray only resolves against a floor; this double always
    -- reports a flat hit so predictLanding returns a landing point.
    local floor = Instance.new("Part"); floor.Name, floor.CanCollide, floor.Parent = "Floor", true, ctx.Services.Workspace
    ctx.Services.Workspace.Raycast = function(_, _, _, _)
        return {Instance = floor, Position = Vector3.new(0, 0, 0), Normal = Vector3.new(0, 1, 0)}
    end

    -- Character with a root part and a humanoid whose jump values we can watch.
    local character = Instance.new("Model"); character.Name, character.Parent = "Character", ctx.Player
    local humanoid = Instance.new("Humanoid")
    humanoid.WalkSpeed, humanoid.JumpPower, humanoid.UseJumpPower, humanoid.Health = 16, 55, false, 100
    humanoid.GetState = function() return "Running" end
    humanoid.Parent = character
    local root = Instance.new("Part"); root.Name, root.Parent = "HumanoidRootPart", character
    root.CFrame = CFrame.new(0, 0, 0)
    ctx.Player.Character = character

    local state = ctx:Run("src/games/volleyball42.lua")
    check(type(state) == "table", "Volleyball 4.2 starts with a mounted window")
    check(type(state.Config) == "table", "Volleyball exposes its config table")

    -- A ball owned by the local player, so isOwner/Personal mode accept it.
    local ball = Instance.new("Model"); ball.Name = "Ball"; ball.Parent = ctx.Services.Workspace
    local ballPart = Instance.new("Part"); ballPart.Name = "Ball"; ballPart.Parent = ball
    ball.PrimaryPart = ballPart
    ballPart.Position = Vector3.new(10, 40, 10)
    ball:SetAttribute("SpawnedBy", ctx.Player.Name)

    -- Seed the acquisition so the first tick does not have to wait out the
    -- 0.25s search interval, and give the history a real moving position.
    state:SetToggle("BallPredict", true)
    state.CurrentBall = ball
    state.RootPart = ballPart
    for i = 1, 3 do
        ballPart.Position = Vector3.new(10 + i, 40, 10 + i)
        tick()
    end
    check(state.CurrentBall == ball and state.CurrentVelocity ~= nil, "the loop locks onto the ball and estimates a velocity")

    -- Jump Boost: applied while on, and restored to the game's original values.
    state:SetToggle("JumpBoost", true)
    tick()
    check(humanoid.JumpPower == state.Config.jumpPower and humanoid.UseJumpPower == true, "jump boost applies the configured power")

    state.Config.jumpPower = 200
    tick()
    check(humanoid.JumpPower == 200, "changing the jump power slider sticks while boosted")

    state:SetToggle("JumpBoost", false)
    check(humanoid.JumpPower == 55 and humanoid.UseJumpPower == false, "disabling jump boost restores the original values")

    -- Look at Ball: the camera rotates onto the ball, keeping its position.
    local camera = ctx.Services.Workspace.CurrentCamera
    camera.CFrame = CFrame.new(0, 0, -10)
    state:SetToggle("LookAtBall", true)
    tick()
    check(camera.CFrame.LookAt ~= nil, "look at ball points the camera at the ball")
    check(camera.CFrame.Position.X == 0 and camera.CFrame.Position.Z == -10, "look at ball preserves the camera position")
    state:SetToggle("LookAtBall", false)

    -- Auto Position: the root moves toward the predicted landing point. The ball
    -- has to keep moving for the prediction to stay valid (a static ball reads as
    -- a zero velocity), so each tick nudges it.
    state:SetToggle("AutoPosition", true)
    state.Config.moveThreshold = 1
    state.Config.moveSmoothing = 0.5
    root.CFrame = CFrame.new(-500, 0, -500)
    ballPart.Position = Vector3.new(20, 40, 20); tick()
    ballPart.Position = Vector3.new(24, 40, 24); tick()
    local moved = root.CFrame.Position
    check(moved.X > -500 and moved.Z > -500, "auto position moves the character toward the landing point")
    check(moved.X < 0, "auto position eases part-way rather than snapping when instant mode is off")

    -- Instant mode snaps straight to the target instead of lerping part-way.
    state.Config.instantMove = true
    root.CFrame = CFrame.new(-500, 0, -500)
    ballPart.Position = Vector3.new(28, 40, 28); tick()
    ballPart.Position = Vector3.new(32, 40, 32); tick()
    check(root.CFrame.Position.X == 0 and root.CFrame.Position.Z == 0, "instant mode snaps the character onto the landing point")

    -- A far ball is ignored while the distance gate is set.
    state.Config.instantMove = false
    state.Config.maxPredictDistance = 5
    root.CFrame = CFrame.new(0, 0, 0)
    local before = root.CFrame.Position
    ballPart.Position = Vector3.new(900, 40, 900); tick()
    ballPart.Position = Vector3.new(904, 40, 904); tick()
    check(root.CFrame.Position.X == before.X, "the distance gate stops auto position from chasing a far ball")
    state.Config.maxPredictDistance = 0

    -- Destroying restores the jump values and clears published state.
    state:SetToggle("JumpBoost", true)
    tick()
    check(humanoid.JumpPower == state.Config.jumpPower, "jump boost is re-applied while live")
    state:Destroy()
    check(state.Destroyed and humanoid.JumpPower == 55, "destroy restores the jump power")
    check(ctx.State.__DEPHUB.Volleyball42 == nil, "destroy clears the published state")

    -- The new controls are registered on the Ball Predict tab.
    local labels = {}
    for _, control in ipairs(ui.Library._Controls) do
        if control.Label then labels[control.Label] = true end
    end
    for _, expected in ipairs({"Auto Position", "Instantâneo", "Olhar pra bola", "Jump Boost", "Jump Power", "Alcance da previsão"}) do
        check(labels[expected] == true, "Volleyball registers its control: " .. expected)
    end
end
