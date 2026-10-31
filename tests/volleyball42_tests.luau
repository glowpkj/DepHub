-- Volleyball 4.2 is a skeleton plus the game-action automations. The old
-- features (ball prediction, auto position, forced jump, ceiling noclip, Auto Set
-- Aim, the fixed set parts) were removed to restart from scratch, so this asserts
-- the lean contract: the backend mounts, exposes State:Act, and tears down clean
-- with nothing left behind.
do
    local ctx = sandbox(1316421563, 1316421563)
    ctx:MountUI()

    local state = ctx:Run("src/games/volleyball42.lua")
    check(type(state) == "table", "Volleyball 4.2 starts")
    check(type(state.Act) == "function", "Volleyball exposes State:Act for the automations")

    -- The removed features must not come back: no prediction/positioning state,
    -- no toggles, and nothing spawned into the Workspace at load.
    check(state.Toggles == nil, "the feature toggles are gone")
    check(state.Config == nil, "the feature config table is gone")
    check(state.CurrentBall == nil and state.History == nil, "the ball-prediction engine is gone")
    check(ctx.Services.Workspace:FindFirstChild("DepHubAutoSet") == nil, "no fixed set parts are spawned")
    check(ctx.Services.Workspace:FindFirstChild("BallPredictions") == nil, "no prediction marker folder is created")

    -- The UI registers no Volleyball controls while the features are gone.
    state:Destroy()
    check(state.Destroyed, "destroy marks the backend destroyed")
    check(ctx.State.__DEPHUB.Volleyball42 == nil, "destroy clears the published state")
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
    ctx:SetMethod(remote, "FireServer", function(_, ...) fired[#fired + 1] = {...} end)

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
