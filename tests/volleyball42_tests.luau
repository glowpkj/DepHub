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

    -- A court ("green" area) centred on the origin, plus a Ceiling part so the
    -- noclip feature has something to act on. Both must exist before Run so the
    -- start-up scan caches them.
    local court = Instance.new("Part"); court.Name, court.Parent = "LockCourt", ctx.Services.Workspace
    court.CFrame, court.Size, court.Position, court.CanCollide = CFrame.new(0, 0, 0), Vector3.new(60, 1, 30), Vector3.new(0, 0, 0), true
    local ceiling = Instance.new("Part"); ceiling.Name, ceiling.Parent = "Ceiling", ctx.Services.Workspace
    ceiling.CanCollide = true

    -- Character with a root part and a humanoid whose jump values we can watch.
    local character = Instance.new("Model"); character.Name, character.Parent = "Character", ctx.Player
    local humanoid = Instance.new("Humanoid")
    humanoid.WalkSpeed, humanoid.JumpPower, humanoid.UseJumpPower, humanoid.Health = 16, 55, false, 100
    humanoid.JumpHeight = 7.2
    humanoid.GetState = function() return "Running" end
    -- A jump-lock double: the game "disables" the jumping state and zeroes the
    -- values, which is exactly what the bypass has to undo each frame.
    local states = {}
    humanoid.SetStateEnabled = function(_, state, enabled) states[state] = enabled end
    humanoid.GetStateEnabled = function(_, state) return states[state] ~= false end
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

    -- Jump Bypass: the game trips a no-jump zone (power zeroed, state disabled),
    -- and the bypass must undo it on the next frame.
    state:SetToggle("JumpBypass", true)
    humanoid.JumpPower, humanoid.JumpHeight = 0, 0
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    tick()
    check(humanoid.JumpPower == state.Config.bypassJumpPower, "jump bypass restores the jump power the zone zeroed")
    check(humanoid.JumpHeight >= 7.2, "jump bypass restores a usable jump height")
    check(humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping) == true, "jump bypass re-enables the jumping state")

    state.Config.bypassJumpPower = 300
    tick()
    check(humanoid.JumpPower == 300, "changing the bypass power slider sticks")

    -- Auto Jump makes the humanoid jump each frame while the bypass is on.
    state.Config.autoJump = true
    humanoid.Jump = false
    tick()
    check(humanoid.Jump == true, "auto jump triggers the humanoid jump")

    state:SetToggle("JumpBypass", false)
    check(humanoid.JumpPower == 55 and humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping) == true,
        "disabling jump bypass restores the game's values")

    -- Look at Ball: the camera rotates onto the ball, keeping its position, and
    -- only on the yaw axis (the look target keeps the camera's own Y).
    local camera = ctx.Services.Workspace.CurrentCamera
    camera.CFrame = CFrame.new(0, 0, -10)
    state:SetToggle("LookAtBall", true)
    tick()
    check(camera.CFrame.LookAt ~= nil, "look at ball points the camera at the ball")
    check(camera.CFrame.Position.X == 0 and camera.CFrame.Position.Z == -10, "look at ball preserves the camera position")
    check(camera.CFrame.LookAt.Y == camera.CFrame.Position.Y, "look at ball does not tilt the camera up or down")

    -- Turn to Ball: the character yaws toward the ball, face-only, still level.
    state:SetToggle("TurnToBall", true)
    root.CFrame = CFrame.new(0, 0, 0)
    tick()
    check(root.CFrame.LookAt ~= nil and root.CFrame.LookAt.Y == root.CFrame.Position.Y,
        "turn to ball yaws the character at the ball without tilting")

    -- Court gating: off a court (the red area) nothing is touched even when the
    -- toggles are on.
    local frozenCamera, frozenRoot = CFrame.new(0, 0, -10), root.CFrame
    camera.CFrame = frozenCamera
    ballPart.Position = Vector3.new(0, 40, 40); tick()
    check(camera.CFrame.LookAt == nil, "off-court ball leaves the camera alone")
    check(root.CFrame.Position == frozenRoot.Position, "off-court ball leaves the character alone")
    state:SetToggle("LookAtBall", false)
    state:SetToggle("TurnToBall", false)

    -- Auto Position: the root moves toward the predicted landing point, but only
    -- for a landing on a court. The ball keeps moving so the prediction stays
    -- valid (a static ball reads as a zero velocity).
    state:SetToggle("AutoPosition", true)
    state.Config.moveThreshold = 1
    state.Config.moveSmoothing = 0.5
    root.CFrame = CFrame.new(-500, 0, -500)
    ballPart.Position = Vector3.new(6, 40, 6); tick()
    ballPart.Position = Vector3.new(8, 40, 8); tick()
    local moved = root.CFrame.Position
    check(moved.X > -500 and moved.Z > -500, "auto position moves the character toward the landing point")
    check(moved.X < 0, "auto position eases part-way rather than snapping with no instant mode")

    -- Instant mode snaps straight onto the landing point instead of lerping.
    state.Config.instantMove = true
    root.CFrame = CFrame.new(-500, 0, -500)
    ballPart.Position = Vector3.new(10, 40, 10); tick()
    ballPart.Position = Vector3.new(12, 40, 12); tick()
    check(root.CFrame.Position.X == 0 and root.CFrame.Position.Z == 0, "instant mode snaps the character onto the landing point")
    state.Config.instantMove = false

    -- A landing off the court (red) is not chased even with Auto Position on.
    state.Config.instantMove = true
    root.CFrame = CFrame.new(0, 0, 0)
    local held = root.CFrame.Position
    ballPart.Position = Vector3.new(0, 40, 60); tick()
    ballPart.Position = Vector3.new(0, 40, 64); tick()
    check(root.CFrame.Position.Z == held.Z, "auto position ignores a landing off the court")

    -- Hitbox: with it on, the character is left alone once the landing is inside
    -- the box, and the box is drawn where the character is.
    state.Config.hitboxEnabled, state.Config.hitboxVisible = true, true
    root.CFrame = CFrame.new(0, 0, 0)
    ballPart.Position = Vector3.new(1, 40, 1); tick()
    ballPart.Position = Vector3.new(2, 40, 2); tick()
    check(root.CFrame.Position.X == 0, "hitbox leaves the character alone when the landing is already covered")
    state.Config.hitboxEnabled, state.Config.hitboxVisible = false, false

    -- A far ball is ignored while the distance gate is set.
    state.Config.instantMove = true
    state.Config.maxPredictDistance = 5
    root.CFrame = CFrame.new(0, 0, 0)
    local before = root.CFrame.Position
    ballPart.Position = Vector3.new(900, 40, 900); tick()
    ballPart.Position = Vector3.new(904, 40, 904); tick()
    check(root.CFrame.Position.X == before.X, "the distance gate stops auto position from chasing a far ball")
    state.Config.maxPredictDistance = 0

    -- Ceiling noclip is on by default and clears the ceiling's collision; turning
    -- it off restores the original flag.
    check(ceiling.CanCollide == false, "ceiling collision is cleared while the noclip is on")
    state:SetToggle("CeilingNoClip", false)
    check(ceiling.CanCollide == true, "disabling the ceiling noclip restores collision")
    state:SetToggle("CeilingNoClip", true)

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
    for _, expected in ipairs({"Auto Position", "Instantâneo", "Suavidade do movimento", "Olhar pra bola", "Virar o personagem", "Só nas áreas verdes", "Usar hitbox", "Hitbox visível", "Tamanho da hitbox", "Jump Boost", "Jump Power", "Alcance da previsão", "Jump Bypass", "Jump Bypass Power", "Auto Jump", "Ceiling sem colisão"}) do
        check(labels[expected] == true, "Volleyball registers its control: " .. expected)
    end
end
