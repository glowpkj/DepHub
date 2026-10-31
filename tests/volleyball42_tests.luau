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

-- Jump Anywhere: one toggle drives two things -- the jump bypass (patches the
-- check upvalue inside CharacterActions.Jump so "NoJump" is cleared) and the
-- extra impulse (raises vertical velocity on the jump frame). The bypass needs
-- the executor's debug.getupvalue/setupvalue; the impulse does not, so the
-- backend must stay usable when the patch cannot apply.
do
    local ctx = sandbox(1316421563, 1316421563)
    ctx:MountUI()

    -- Build the game's CharacterScript.CharacterActions ModuleScript with a Jump
    -- function that carries a check upvalue at index 3 (the contract the feature
    -- patches). The check returns "NoJump" until the patch clears it.
    local checkCalls = 0
    local function checkLinefault()
        checkCalls += 1
        return "NoJump"
    end

    local ca = {State = {Jumped = false}}
    ca.Jump = function()
        return checkLinefault()
    end
    ctx.Env.debug.setregistry(ca.Jump, {
        [1] = {Name = "self", Value = ca},
        [2] = {Name = "args", Value = {}},
        [3] = {Name = "checkLinefault", Value = checkLinefault},
    })

    local root = Instance.new("Folder"); root.Name = "guilhermealone1"; root.Parent = ctx.Services.Workspace
    local scriptFolder = Instance.new("Folder"); scriptFolder.Name = "CharacterScript"; scriptFolder.Parent = root
    local actionsModule = Instance.new("ModuleScript")
    actionsModule.Name = "CharacterActions"
    actionsModule._props.Module = ca
    actionsModule.Parent = scriptFolder

    -- A character with a root the impulse can write to.
    local character = Instance.new("Model"); character.Name, character.Parent = "Character", ctx.Player
    local hrp = Instance.new("Part"); hrp.Name, hrp.Parent = "HumanoidRootPart", character
    hrp.AssemblyLinearVelocity = Vector3.new(3, 0, 4)
    ctx.Player.Character = character

    local state = ctx:Run("src/games/volleyball42.lua")
    check(state.Jump ~= nil, "the jump feature is loaded")

    -- Toggle off: the patch is NOT applied -- the game's check still vetoes.
    check(state.JumpEnabled == false, "the feature starts disabled")
    check(checkLinefault() == "NoJump", "with the feature off, the game check still vetoes")

    -- Toggle on: the bypass applies (the original check is saved and swapped).
    local ok = state:SetJumpEnabled(true)
    check(ok == true, "enabling the feature reports success")
    check(state.JumpEnabled == true, "the feature is on")
    local _, patched = ctx.Env.debug.getupvalue(ca.Jump, 3)
    check(type(patched) == "function" and patched ~= checkLinefault, "enabling patches the check upvalue")
    check(patched() == nil, "the patched check clears the game's veto (returns nil)")
    check(patched() ~= "NoJump", "the patched check no longer vetoes")

    -- Impulse: the slider value drives the vertical velocity on the jump frame.
    state:SetJumpImpulse(100)
    check(state.JumpImpulse == 100, "the impulse percentage is stored")
    ca.State.Jumped = true
    ctx.Services.RunService.Heartbeat:Fire(0.05)   -- jump edge detected, spawns the apply
    ctx:FlushSpawned()                             -- the spawned body runs one frame later
    local velocity = hrp.AssemblyLinearVelocity
    local base = math.sqrt(2 * 196.2 * ((50 * 50) / (2 * 196.2)))
    check(math.abs(velocity.Y - base * 2) < 0.5, "100% impulse doubles the jump velocity")
    check(velocity.X == 3 and velocity.Z == 4, "the horizontal velocity is untouched")

    -- With the impulse at 0, only the bypass is active and the jump keeps its
    -- original speed (the impulse must not fire at all).
    hrp.AssemblyLinearVelocity = Vector3.new(0, 7, 0)
    state:SetJumpImpulse(0)
    ca.State.Jumped = false
    ctx.Services.RunService.Heartbeat:Fire(0.05)
    ca.State.Jumped = true
    ctx.Services.RunService.Heartbeat:Fire(0.05)
    ctx:FlushSpawned()
    check(hrp.AssemblyLinearVelocity.Y == 7, "0% impulse leaves the jump velocity as the game set it")

    -- Disable restores the original check.
    state:SetJumpEnabled(false)
    local _, restored = ctx.Env.debug.getupvalue(ca.Jump, 3)
    check(restored == checkLinefault, "disabling restores the original check upvalue")
    check(state.JumpEnabled == false, "the feature is off again")

    -- Destroy is a clean teardown: re-enable, then Destroy must restore the patch.
    state:SetJumpEnabled(true)
    state:Destroy()
    local _, afterDestroy = ctx.Env.debug.getupvalue(ca.Jump, 3)
    check(afterDestroy == checkLinefault, "destroy restores the original check upvalue")
    check(state.Destroyed == true, "destroy marks the backend destroyed")
end

-- No executor debug library (an executor without getupvalue/setupvalue): the
-- bypass cannot apply, so the feature reports unavailable -- but it must NOT
-- error, and the backend must keep running with everything else intact.
do
    local ctx = sandbox(1316421563, 1316421563)
    ctx:MountUI()
    ctx.Env.debug = {getupvalue = nil, setupvalue = nil}
    ctx.State.debug = ctx.Env.debug

    local ca = {State = {Jumped = false}, Jump = function() return "NoJump" end}
    local root = Instance.new("Folder"); root.Name = "guilhermealone1"; root.Parent = ctx.Services.Workspace
    local scriptFolder = Instance.new("Folder"); scriptFolder.Name = "CharacterScript"; scriptFolder.Parent = root
    local actionsModule = Instance.new("ModuleScript")
    actionsModule.Name = "CharacterActions"; actionsModule._props.Module = ca; actionsModule.Parent = scriptFolder

    local state = ctx:Run("src/games/volleyball42.lua")
    local ok, err = state:SetJumpEnabled(true)
    check(ok == false, "without the debug library the bypass reports failure instead of erroring")
    check(type(err) == "string" and err:find("debug", 1, true) ~= nil, "the failure names the missing primitive")
    check(state.Destroyed == false, "the backend keeps running when the bypass cannot apply")
    state:Destroy()
end

-- The UI registers exactly one toggle and one slider for this one feature.
do
    local ctx = sandbox(1316421563, 1316421563)
    local ui = ctx:MountUI()
    ctx:Run("src/games/volleyball42.lua")
    local controls = ctx.State.__DEPHUB.UI.Library._Controls
    local toggles, sliders = 0, 0
    for _, control in ipairs(controls) do
        if control.Kind == "toggle" then toggles += 1 end
        if control.Kind == "slider" then sliders += 1 end
    end
    check(toggles == 1, "the jump feature is one toggle")
    check(sliders == 1, "the jump feature has one impulse slider")
end
