-- Volleyball 4.2: the assistance features must drive real state, not just
-- register controls. Auto Position moves the character's root toward the
-- predicted landing, Pulo forcado applies and then restores the humanoid's
-- jump values, and Ceiling noclip clears and restores collision.
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

    -- Auto SET: the two set positions must exist as soon as the backend loads,
    -- with no control to create them and nothing that can switch them off.
    local setFolder = ctx.Services.Workspace:FindFirstChild("DepHubAutoSet")
    check(setFolder ~= nil, "the auto SET folder is created on load")
    local setParts = setFolder and setFolder:GetChildren() or {}
    check(#setParts == 2, "the auto SET folder holds exactly two set positions")
    local positions = {}
    for _, part in ipairs(setParts) do
        positions[part.Name] = part.CFrame.Position
        check(part.Size == Vector3.new(1, 1, 1), "each set position is a 1x1x1 part: " .. part.Name)
        check(part.Anchored == true and part.CanCollide == false, "each set position is anchored and non-colliding: " .. part.Name)
    end
    check(positions.SetPosition1 == Vector3.new(-22, 15, 0), "set position 1 is at (-22, 15, 0)")
    check(positions.SetPosition2 == Vector3.new(22, 15, 0), "set position 2 is at (22, 15, 0)")

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

    -- Pulo forcado (JumpForce): one toggle that applies the jump power and keeps
    -- the jump itself usable. It is the old boost and bypass in a single
    -- operation, so it must both set the power and survive a no-jump zone.
    state:SetToggle("JumpForce", true)
    tick()
    check(humanoid.JumpPower == state.Config.jumpPower and humanoid.UseJumpPower == true, "jump force applies the configured power")

    state.Config.jumpPower = 200
    tick()
    check(humanoid.JumpPower == 200, "changing the jump power slider sticks while jump force is on")

    -- A no-jump zone zeroes the power and disables the jumping state; the next
    -- frame must write both back.
    humanoid.JumpPower, humanoid.JumpHeight = 0, 0
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    tick()
    check(humanoid.JumpPower == state.Config.jumpPower, "jump force restores the power a no-jump zone zeroed")
    check(humanoid.JumpHeight >= 7.2, "jump force restores a usable jump height")
    check(humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping) == true, "jump force re-enables the jumping state")

    -- Auto Jump makes the humanoid jump each frame while jump force is on.
    state.Config.autoJump = true
    humanoid.Jump = false
    tick()
    check(humanoid.Jump == true, "auto jump triggers the humanoid jump")
    state.Config.autoJump = false

    state:SetToggle("JumpForce", false)
    check(humanoid.JumpPower == 55 and humanoid.UseJumpPower == false and humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping) == true,
        "disabling jump force restores the game's values")

    -- Auto Position: the root moves toward the predicted landing point. The ball
    -- keeps moving so the prediction stays valid (a static ball reads as a zero
    -- velocity).
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
    state:SetToggle("JumpForce", true)
    tick()
    check(humanoid.JumpPower == state.Config.jumpPower, "jump force is re-applied while live")
    state:Destroy()
    check(state.Destroyed and humanoid.JumpPower == 55, "destroy restores the jump power")
    check(ctx.State.__DEPHUB.Volleyball42 == nil, "destroy clears the published state")
    check(ctx.Services.Workspace:FindFirstChild("DepHubAutoSet") == nil, "destroy removes the auto SET folder")

    -- The new controls are registered on the Ball Predict tab.
    local labels = {}
    for _, control in ipairs(ui.Library._Controls) do
        if control.Label then labels[control.Label] = true end
    end
    for _, expected in ipairs({"Auto Position", "Instant", "Movement smoothing", "Offset above ground", "Minimum distance", "Forced jump", "Jump Power", "Prediction range", "Auto Jump", "Ceiling no collision"}) do
        check(labels[expected] == true, "Volleyball registers its control: " .. expected)
    end

    -- The tabs group related controls into horizontal rows: the Prediction
    -- section puts the Ball Predict switch next to the range slider it gates,
    -- the Auto Position section puts its two switches on one line, and the Jump
    -- section puts its two switches on one line. Each row must hold the pair it
    -- was built for, so the grouping is real and not just a layout hint.
    local groups = ui.Library._Groups or {}
    check(#groups >= 3, "Volleyball built at least three control rows")
    local rowPairs = {}
    for _, group in ipairs(groups) do
        if group.Kind == "HStack" and group._n == 2 then rowPairs[#rowPairs + 1] = true end
    end
    check(#rowPairs >= 3, "every Volleyball pair row is a two-control horizontal stack")
end

-- Volleyball 4.2 actions: the remotes/animations the game uses to spawn the ball,
-- set, spike, block, bump, dive and serve, exposed to the automations through
-- State:Act. The harness has no PlayerAction remote or Animations tree by
-- default, so the module must survive their absence (only the branches it needs
-- fail), and fire the right remote argument names when they do exist.
do
    local ctx = sandbox(1316421563, 1316421563)
    ctx:MountUI()

    -- Build the real instances the game exposes: the PlayerAction RemoteEvent
    -- (recording every FireServer so we can assert the exact arguments), the
    -- Animations tree, and an Animator under the humanoid's Animator slot.
    local fired = {}
    local remote = Instance.new("RemoteEvent"); remote.Name = "PlayerAction"
    remote.FireServer = function(_, ...) fired[#fired + 1] = {...} end

    local remotes = Instance.new("Folder"); remotes.Name = "Remotes"; remotes.Parent = ctx.Services.ReplicatedStorage
    remote.Parent = remotes

    local animations = Instance.new("Folder"); animations.Name = "Animations"; animations.Parent = ctx.Services.ReplicatedStorage
    local assets = Instance.new("Folder"); assets.Name = "Assets"; assets.Parent = ctx.Services.ReplicatedStorage
    animations.Parent = assets

    -- Mirror the game tree: Animations.<Kind>.<index>[.<dir>].
    local function animation(name, parent)
        local node = Instance.new("Animation")
        node.Name, node.AnimationId, node.Parent = name, "rbxassetid://" .. name, parent
        return node
    end

    local function kind(name)
        local folder = Instance.new("Folder"); folder.Name, folder.Parent = name, animations
        return folder
    end

    -- Set[1] holds the Front/Back variants; the rest are flat ids.
    local setKind = kind("Set")
    local setIndex = Instance.new("Folder"); setIndex.Name, setIndex.Parent = "1", setKind
    animation("Front", setIndex); animation("Back", setIndex)
    animation("Spike", kind("Spike"))
    animation("Block", kind("Block"))
    animation("Receive", kind("Receive"))
    animation("Dive", kind("Dive"))
    local serveKind = kind("Serve")
    animation("Hit", serveKind)

    -- PlayerData_m drives which animation index is equipped. The harness has no
    -- require(), so the module falls back to index 1 -- which is the folder built
    -- above, so the animation assertions stay meaningful.

    -- The module resolves the Animator through LocalPlayer.Character.Humanoid.
    local character = Instance.new("Model"); character.Name, character.Parent = "Character", ctx.Player
    local humanoid = Instance.new("Humanoid"); humanoid.Name, humanoid.Parent = "Humanoid", character
    ctx.Player.Character = character

    -- Animator with a recording LoadAnimation so we can see which animation each
    -- action plays.
    local played = {}
    local animator = Instance.new("Animator"); animator.Name, animator.Parent = "Animator", humanoid
    animator.LoadAnimation = function(_, animation)
        played[#played + 1] = animation
        return {Play = function() end}
    end

    local state = ctx:Run("src/games/volleyball42.lua")
    check(type(state.Act) == "function", "Volleyball exposes State:Act for the automations")
    check(state.Actions ~= nil, "the actions module is loaded at startup")

    -- SpawnBall fires "SpawnBall","Spawn" (exactly the game's arguments).
    state:Act("SpawnBall")
    check(fired[#fired][1] == "SpawnBall" and fired[#fired][2] == "Spawn", "SpawnBall fires the spawn arguments")

    -- Set frontal vs de costas.
    state:Act("Set", true)
    check(fired[#fired][1] == "Setting", "a front set fires 'Setting'")
    state:Act("Set", false)
    check(fired[#fired][1] == "Backsetting", "a back set fires 'Backsetting'")

    -- Spike / Block.
    state:Act("Spike")
    check(fired[#fired][1] == "Spiking", "spike fires 'Spiking'")
    state:Act("Block")
    check(fired[#fired][1] == "Blocking", "block fires 'Blocking'")

    -- Bump and Dive play an animation but fire NO remote.
    local beforeBump = #fired
    state:Act("Bump")
    state:Act("Dive")
    check(#fired == beforeBump, "bump and dive do not fire a remote")

    -- Every action that plays an animation went through LoadAnimation.
    local animationsPlayed = {}
    for _, animation in ipairs(played) do animationsPlayed[animation.Name] = true end
    check(animationsPlayed.Front and animationsPlayed.Back, "the set animations come from the equipped index")
    check(animationsPlayed.Spike and animationsPlayed.Block, "spike and block play their animations")
    check(animationsPlayed.Receive and animationsPlayed.Dive, "bump and dive play their animations")

    -- Serve: fires the spawn, then the delayed "Serving" runs as a spawned task.
    local beforeServe = #fired
    state:Act("Serve")
    check(fired[#fired][1] == "SpawnBall" and fired[#fired][2] == "Serve", "serve fires the ball spawn")
    check(state.ServeTask ~= nil, "serve schedules the delayed hit")
    ctx:FlushSpawned()
    check(#fired > beforeServe and fired[#fired][1] == "Serving", "serve fires 'Serving' after the delay")

    state:Destroy()
end

-- The actions module must not take the backend down when the game's remotes are
-- absent (a patch, or a different place). State:Act reports unavailable instead
-- of erroring.
do
    local ctx = sandbox(1316421563, 1316421563)
    ctx:MountUI()
    local state = ctx:Run("src/games/volleyball42.lua")
    local ok = state:Act("Spike")
    check(ok == false, "an action with no PlayerAction remote reports failure instead of erroring")
    state:Destroy()
end

-- Auto Set Aim: while on, the exact instant a set fires ("Setting"/"Backsetting")
-- the character's body turns to face the nearest fixed set position -- and only
-- then. Other actions never turn it, and disabling/Destroy restores the original
-- FireServer so nothing stays wrapped.
do
    local ctx = sandbox(1316421563, 1316421563)
    ctx:MountUI()

    -- The PlayerAction remote, with a plain FireServer (as the game has). The
    -- wrapper replaces this attribute and must put it back.
    local remotes = Instance.new("Folder"); remotes.Name, remotes.Parent = "Remotes", ctx.Services.ReplicatedStorage
    local actions = Instance.new("RemoteEvent"); actions.Name, actions.Parent = "PlayerAction", remotes
    local firedCalls = {}
    local originalFireServer = function(_, ...) firedCalls[#firedCalls + 1] = {...} end
    actions.FireServer = originalFireServer

    -- Character with a root at the origin: the two set parts are (-22,15,0) and
    -- (22,15,0), so the origin is between them -- we place the root nearer one
    -- side to prove the NEAREST one is chosen.
    local character = Instance.new("Model"); character.Name, character.Parent = "Character", ctx.Player
    local root = Instance.new("Part"); root.Name, root.Parent = "HumanoidRootPart", character
    root.CFrame = CFrame.new(-20, 5, 3)
    ctx.Player.Character = character

    local state = ctx:Run("src/games/volleyball42.lua")

    -- Off by default and nothing is wrapped until it is turned on.
    check(state.Toggles.AutoSetAim == false, "auto set aim is off by default")
    check(state.AimWrapped == false, "the remote is not wrapped while off")

    local enabled = state:SetToggle("AutoSetAim", true)
    check(enabled == true and state.AimWrapped == true, "enabling auto set aim wraps the remote")

    -- Firing a set turns the body toward the NEAREST part: the root sits at
    -- x=-20, so SetPosition1 (-22,15,0) is the nearest -- the character must end
    -- up facing -X (towards it), not +X.
    local beforeCalls = #firedCalls
    state:Act("Set", true)
    check(#firedCalls == beforeCalls + 1 and firedCalls[#firedCalls][1] == "Setting", "the set still fires through the wrapper")
    check(state.AimCount == 1, "the set counted one aim")
    check(state.LastSetAim == "Setting", "the aim recorded the set it came from")
    -- The look
    local look = root.CFrame.LookVector
    check(look.X < 0, "the body turned toward the nearest set position (-X side)")

    -- The root must not have moved: only the facing changes.
    check(root.CFrame.Position.X == -20 and root.CFrame.Position.Z == 3, "aiming turns the body without moving it")

    -- A backset also aims (it is the same set action, other variant).
    state:Act("Set", false)
    check(state.AimCount == 2 and state.LastSetAim == "Backsetting", "a backset aims too")

    -- Other actions never turn the body: spike/block/spawn/serve leave it alone.
    local aimedBefore = state.AimCount
    state:Act("Spike")
    state:Act("Block")
    state:Act("SpawnBall")
    check(state.AimCount == aimedBefore, "spike/block/spawn do not trigger the aim")

    -- Disabling restores the original FireServer exactly.
    state:SetToggle("AutoSetAim", false)
    check(actions.FireServer == originalFireServer, "disabling restores the original FireServer")
    check(state.AimWrapped == false, "the remote is no longer wrapped after disabling")

    -- Re-enable and prove Destroy unwraps too.
    state:SetToggle("AutoSetAim", true)
    check(state.AimWrapped == true, "re-enabling wraps again")
    state:Destroy()
    check(actions.FireServer == originalFireServer, "destroy restores the original FireServer")
end

