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
    hrp.AssemblyLinearVelocity = Vector3.new(3, 50, 4)
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
-- bypass cannot apply, so the toggle notes it -- but the IMPULSE must still
-- work. This was the bug: the impulse used to be gated on the CA, which was
-- only assigned when the patch succeeded, so a missing debug library killed the
-- impulse too. The impulse depends only on the game's own CA.State.Jumped.
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

    -- A character with a root the impulse writes to.
    local character = Instance.new("Model"); character.Name, character.Parent = "Character", ctx.Player
    local hrp = Instance.new("Part"); hrp.Name, hrp.Parent = "HumanoidRootPart", character
    hrp.AssemblyLinearVelocity = Vector3.new(1, 50, 2)
    ctx.Player.Character = character

    local state = ctx:Run("src/games/volleyball42.lua")
    local ok, err = state:SetJumpEnabled(true)
    check(ok == true, "the toggle reports success because the impulse itself is on")
    check(state.JumpEnabled == true, "the impulse path is armed")
    check(type(err) == "string" and err:find("bypass:", 1, true) == 1, "the note says only the bypass is missing")
    check(err:find("debug", 1, true) ~= nil, "the note names the missing primitive")
    check(state.Destroyed == false, "the backend keeps running when the bypass cannot apply")

    -- The impulse still has to fire: the CA is resolved independently.
    check(state.Jump.CA ~= nil, "the CA is resolved even when the patch cannot apply")
    state:SetJumpImpulse(50)
    ca.State.Jumped = true
    ctx.Services.RunService.Heartbeat:Fire(0.05)
    ctx:FlushSpawned()
    local base = math.sqrt(2 * 196.2 * ((50 * 50) / (2 * 196.2)))
    check(math.abs(hrp.AssemblyLinearVelocity.Y - base * 1.5) < 0.5,
        "with no bypass the impulse still raises the jump (50% = 1.5x)")
    check(hrp.AssemblyLinearVelocity.X == 1 and hrp.AssemblyLinearVelocity.Z == 2,
        "the impulse keeps the horizontal velocity")

    state:Destroy()
end

-- The hub now loads instantly, so CharacterActions may not have replicated when
-- the feature starts. The feature must RETRY: once the module appears, the
-- impulse arms without needing a reload or a toggle flip.
do
    local ctx = sandbox(1316421563, 1316421563)
    ctx:MountUI()

    local character = Instance.new("Model"); character.Name, character.Parent = "Character", ctx.Player
    local hrp = Instance.new("Part"); hrp.Name, hrp.Parent = "HumanoidRootPart", character
    hrp.AssemblyLinearVelocity = Vector3.new(0, 50, 0)
    ctx.Player.Character = character

    local state = ctx:Run("src/games/volleyball42.lua")
    state:SetJumpEnabled(true)
    check(state.Jump.CA == nil, "with CharacterActions absent, the CA starts nil")
    check(state.JumpEnabled == true, "the feature is still armed for the impulse")

    -- The module streams in after the toggle was already on.
    local ca = {State = {Jumped = false}, Jump = function() return "NoJump" end}
    local root = Instance.new("Folder"); root.Name = "guilhermealone1"; root.Parent = ctx.Services.Workspace
    local scriptFolder = Instance.new("Folder"); scriptFolder.Name = "CharacterScript"; scriptFolder.Parent = root
    local actionsModule = Instance.new("ModuleScript")
    actionsModule.Name = "CharacterActions"; actionsModule._props.Module = ca; actionsModule.Parent = scriptFolder

    -- Enough frames for the retry to resolve the CA.
    for _ = 1, 32 do ctx.Services.RunService.Heartbeat:Fire(0.05) end
    check(state.Jump.CA ~= nil, "the retry resolves the CA once it appears")

    -- Now a jump boosts normally.
    state:SetJumpImpulse(100)
    ca.State.Jumped = true
    ctx.Services.RunService.Heartbeat:Fire(0.05)
    ctx:FlushSpawned()
    local base = math.sqrt(2 * 196.2 * ((50 * 50) / (2 * 196.2)))
    check(math.abs(hrp.AssemblyLinearVelocity.Y - base * 2) < 0.5,
        "after the late resolve, the impulse boosts the jump")

    state:Destroy()
end

-- The impulse must not depend on any game module. In the live game the path the
-- feature used (workspace.guilhermealone1.CharacterScript.CharacterActions) did
-- not exist, so the impulse was dead. With NO CharacterActions anywhere, the
-- Humanoid's own jump event has to drive the boost.
do
    local ctx = sandbox(1316421563, 1316421563)
    ctx:MountUI()

    local character = Instance.new("Model"); character.Name, character.Parent = "Character", ctx.Player
    local humanoid = Instance.new("Humanoid"); humanoid.Parent = character
    local hrp = Instance.new("Part"); hrp.Name, hrp.Parent = "HumanoidRootPart", character
    hrp.AssemblyLinearVelocity = Vector3.new(2, 50, -3)
    -- The harness Humanoid double has no signals; wire the same `Jumping`
    -- surface a real Humanoid exposes.
    local handlers = {}
    humanoid.Jumping = {
        Connect = function(_, fn)
            handlers[#handlers + 1] = fn
            return {Disconnect = function() end}
        end,
    }
    ctx.Player.Character = character

    local state = ctx:Run("src/games/volleyball42.lua")
    local ok, err = state:SetJumpEnabled(true)
    check(ok == true, "with no CharacterActions the impulse still turns on")
    check(type(err) == "string" and err:find("CharacterActions", 1, true) ~= nil,
        "the note names CharacterActions as the only missing part")
    check(state.Jump.CA == nil, "no game module is required for the impulse")

    state:SetJumpImpulse(100)
    check(#handlers == 1, "the feature listens to the Humanoid's jump event")
    for _, fn in ipairs(handlers) do fn() end
    ctx:FlushSpawned()
    local velocity = hrp.AssemblyLinearVelocity
    check(math.abs(velocity.Y - 100) < 0.5, "the jump doubles from the character's own event")
    check(velocity.X == 2 and velocity.Z == -3, "the horizontal velocity is kept")

    state:Destroy()
end

-- Fallback trigger: if the Humanoid event does not reach the feature, the
-- airborne edge (FloorMaterial Air + rising velocity) still applies the boost.
do
    local ctx = sandbox(1316421563, 1316421563)
    ctx:MountUI()

    local character = Instance.new("Model"); character.Name, character.Parent = "Character", ctx.Player
    local humanoid = Instance.new("Humanoid"); humanoid.Parent = character
    humanoid.FloorMaterial = "Air"
    local hrp = Instance.new("Part"); hrp.Name, hrp.Parent = "HumanoidRootPart", character
    hrp.AssemblyLinearVelocity = Vector3.new(0, 50, 0)
    ctx.Player.Character = character

    local state = ctx:Run("src/games/volleyball42.lua")
    state:SetJumpEnabled(true)
    state:SetJumpImpulse(50)
    ctx.Services.RunService.Heartbeat:Fire(0.05)   -- sees the airborne edge, queues the boost
    ctx:FlushSpawned()
    check(math.abs(hrp.AssemblyLinearVelocity.Y - 75) < 0.5,
        "the airborne edge boosts a jump even without the Humanoid event")

    -- Standing on the ground does not boost anything.
    humanoid.FloorMaterial = "Plastic"
    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    ctx.Services.RunService.Heartbeat:Fire(0.05)
    ctx:FlushSpawned()
    check(hrp.AssemblyLinearVelocity.Y == 0, "standing on the ground is not a jump")

    state:Destroy()
end

-- Falling is not a jump: walking off a ledge must not be turned into a boost.
do
    local ctx = sandbox(1316421563, 1316421563)
    ctx:MountUI()

    local character = Instance.new("Model"); character.Name, character.Parent = "Character", ctx.Player
    local humanoid = Instance.new("Humanoid"); humanoid.Parent = character
    local hrp = Instance.new("Part"); hrp.Name, hrp.Parent = "HumanoidRootPart", character
    hrp.AssemblyLinearVelocity = Vector3.new(0, -25, 0)
    local handlers = {}
    humanoid.Jumping = {
        Connect = function(_, fn)
            handlers[#handlers + 1] = fn
            return {Disconnect = function() end}
        end,
    }
    ctx.Player.Character = character

    local state = ctx:Run("src/games/volleyball42.lua")
    state:SetJumpEnabled(true)
    state:SetJumpImpulse(150)
    -- Even if a trigger fires while falling, the negative vertical velocity
    -- must not become an upward boost.
    for _, fn in ipairs(handlers) do fn() end
    ctx:FlushSpawned()
    check(hrp.AssemblyLinearVelocity.Y == -25, "a fall is not converted into a jump")

    state:Destroy()
end

-- Physics may write the jump velocity one frame AFTER the trigger. The impulse
-- retries a few frames and applies once the vertical speed is there; it must
-- never invent a jump for a character standing still.
do
    local ctx = sandbox(1316421563, 1316421563)
    ctx:MountUI()

    local character = Instance.new("Model"); character.Name, character.Parent = "Character", ctx.Player
    local humanoid = Instance.new("Humanoid"); humanoid.Parent = character
    local hrp = Instance.new("Part"); hrp.Name, hrp.Parent = "HumanoidRootPart", character
    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    local handlers = {}
    humanoid.Jumping = {
        Connect = function(_, fn)
            handlers[#handlers + 1] = fn
            return {Disconnect = function() end}
        end,
    }
    ctx.Player.Character = character

    local state = ctx:Run("src/games/volleyball42.lua")
    state:SetJumpEnabled(true)
    state:SetJumpImpulse(100)

    -- Trigger fires while the character is still grounded (velocity 0).
    for _, fn in ipairs(handlers) do fn() end
    ctx:FlushSpawned()
    check(hrp.AssemblyLinearVelocity.Y == 0, "a still character is not launched by a trigger")

    -- Next jump: the velocity is written before the retry loop runs. Enough
    -- frames pass first so the debounce is clear.
    for _ = 1, 4 do ctx.Services.RunService.Heartbeat:Fire(0.05) end
    for _, fn in ipairs(handlers) do fn() end
    hrp.AssemblyLinearVelocity = Vector3.new(0, 50, 0)
    ctx:FlushSpawned()
    check(math.abs(hrp.AssemblyLinearVelocity.Y - 100) < 0.5,
        "the impulse applies once the physics writes the jump velocity")

    state:Destroy()
end


-- must find it by name anywhere under Workspace, and find the check upvalue by
-- name instead of trusting a fixed index.
do
    local ctx = sandbox(1316421563, 1316421563)
    ctx:MountUI()

    local renamed = Instance.new("Folder"); renamed.Name = "someRenamedFolder"; renamed.Parent = ctx.Services.ReplicatedStorage
    local scriptFolder = Instance.new("Folder"); scriptFolder.Name = "CharacterScript"; scriptFolder.Parent = renamed

    local function checkVeto() return "NoJump" end
    local ca = {State = {Jumped = false}}
    ca.Jump = function() return checkVeto() end
    ctx.Env.debug.setregistry(ca.Jump, {
        [1] = {Name = "checkAllowed", Value = checkVeto},
        [2] = {Name = "cooldown", Value = 0},
    })

    local actionsModule = Instance.new("ModuleScript")
    actionsModule.Name = "CharacterActions"; actionsModule._props.Module = ca; actionsModule.Parent = scriptFolder

    local state = ctx:Run("src/games/volleyball42.lua")
    local ok = state:SetJumpEnabled(true)
    check(ok == true, "the bypass applies from a module found by name")
    check(state.Jump.CA == ca, "the module found is the game's own CharacterActions")
    local _, patched = ctx.Env.debug.getupvalue(ca.Jump, 1)
    check(type(patched) == "function" and patched ~= checkVeto,
        "the check upvalue is found by name, not by a fixed index")
    check(patched() == nil, "the patched check clears the game's veto")

    state:SetJumpEnabled(false)
    local _, restored = ctx.Env.debug.getupvalue(ca.Jump, 1)
    check(restored == checkVeto, "disabling restores the upvalue it patched")

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
