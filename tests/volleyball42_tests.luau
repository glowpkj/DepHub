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

    -- The removed prediction/positioning engine stays absent; the new visual
    -- ESP is feature-owned and starts disabled.
    check(state.Toggles == nil, "the feature toggles are gone")
    check(state.Config == nil, "the feature config table is gone")
    check(state.CurrentBall == nil and state.History == nil, "the ball-prediction engine is gone")
    check(ctx.Services.Workspace:FindFirstChild("DepHubAutoSet") == nil, "no fixed set parts are spawned")
    check(ctx.Services.Workspace:FindFirstChild("BallPredictions") == nil, "no prediction marker folder is created")

    -- The backend tears down cleanly without spawning world objects at load.
    state:Destroy()
    check(state.Destroyed, "destroy marks the backend destroyed")
    check(ctx.State.__DEPHUB.Volleyball42 == nil, "destroy clears the published state")
end


-- ESP Character Direction: the Visual toggle starts the per-player jump
-- direction indicators and disabling/unloading removes every visual.
do
    local ctx = sandbox(1316421563, 1316421563)
    ctx:MountUI()

    local target, character = ctx:AddPlayer("DirectionTarget")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    humanoid.FloorMaterial = "Ground"
    humanoid.GetState = function()
        return Enum.HumanoidStateType.Freefall
    end
    root.AssemblyLinearVelocity = Vector3.new(0, 12, 0)

    local state = ctx:Run("src/games/volleyball42.lua")
    check(state.CharacterDirection ~= nil, "character direction feature loads")
    check(state.CharacterDirectionEnabled == false, "character direction starts disabled")
    check(state:SetCharacterDirectionEnabled(true) == true, "character direction enables")
    ctx:FlushSpawned()

    humanoid.FloorMaterial = Enum.Material.Air
    ctx.Services.RunService.Heartbeat:Fire(0.05)

    local folder = ctx.Services.Workspace:FindFirstChild("DepHubCharacterDirection")
    check(folder ~= nil, "enabling creates the ESP folder")
    check(folder:FindFirstChild("DepHubDirectionTarget") ~= nil, "jump detection creates a target part")
    check(state.CharacterDirection.Active == true, "the feature is active")

    check(state:SetCharacterDirectionEnabled(false) == true, "character direction disables")
    check(ctx.Services.Workspace:FindFirstChild("DepHubCharacterDirection") == nil,
        "disabling destroys all ESP visuals")
    check(state.CharacterDirection.Active == false, "the feature is inactive")

    state:SetCharacterDirectionEnabled(true)
    ctx:FlushSpawned()
    state:Destroy()
    check(ctx.Services.Workspace:FindFirstChild("DepHubCharacterDirection") == nil,
        "destroy removes the ESP folder")
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

-- Jump Anywhere: the bypass reapplies JumpPower, JumpHeight and the
-- Jumping/Climbing states every frame, and restores the exact original values.
do
    local ctx = sandbox(1316421563, 1316421563)
    ctx:MountUI()

    local character = Instance.new("Model"); character.Name, character.Parent = "Character", ctx.Player
    local humanoid = Instance.new("Humanoid"); humanoid.Parent = character
    humanoid.JumpPower = 50
    humanoid.UseJumpPower = false
    humanoid.JumpHeight = 7.2
    local stateEnabled = {
        [Enum.HumanoidStateType.Jumping] = false,
        [Enum.HumanoidStateType.Climbing] = false,
    }
    humanoid.GetStateEnabled = function(_, state) return stateEnabled[state] end
    humanoid.SetStateEnabled = function(_, state, enabled) stateEnabled[state] = enabled end
    ctx.Player.Character = character

    local state = ctx:Run("src/games/volleyball42.lua")
    check(state.Jump ~= nil, "the jump feature is loaded")
    check(state.JumpEnabled == false, "Jump Anywhere starts disabled")
    check(state.JumpPower == 120, "Jump Power defaults to 120")

    check(state:SetJumpEnabled(true) == true, "Jump Anywhere enables")
    check(state.JumpEnabled == true, "the jump bypass is active")
    check(humanoid.UseJumpPower == true and humanoid.JumpPower == 120,
        "enabling applies the configured JumpPower")
    check(humanoid.JumpHeight >= 7.2, "enabling keeps JumpHeight usable")
    check(stateEnabled[Enum.HumanoidStateType.Jumping] == true
        and stateEnabled[Enum.HumanoidStateType.Climbing] == true,
        "enabling restores the jump-related Humanoid states")

    humanoid.JumpPower = 0
    humanoid.JumpHeight = 0
    humanoid.UseJumpPower = false
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
    ctx.Services.RunService.Heartbeat:Fire(0.05)
    check(humanoid.JumpPower == 120 and humanoid.UseJumpPower == true,
        "the bypass reapplies JumpPower after the zone blocks it")
    check(humanoid.JumpHeight >= 7.2, "the bypass reapplies JumpHeight")
    check(stateEnabled[Enum.HumanoidStateType.Jumping] == true
        and stateEnabled[Enum.HumanoidStateType.Climbing] == true,
        "the bypass re-enables states after the zone disables them")

    check(state:SetJumpPower(300) == true, "the Jump Power slider updates")
    check(state.JumpPower == 300 and humanoid.JumpPower == 300,
        "the new slider value is applied immediately")
    check(state:SetJumpPower(900) == true and state.JumpPower == 500,
        "Jump Power is clamped to its maximum")
    check(state:SetJumpPower(1) == true and state.JumpPower == 50,
        "Jump Power is clamped to its minimum")
    state:SetJumpPower(300)

    check(state:SetJumpEnabled(false) == true, "Jump Anywhere disables")
    check(humanoid.JumpPower == 50 and humanoid.UseJumpPower == false
        and humanoid.JumpHeight == 7.2,
        "disabling restores the original Humanoid jump values")
    check(stateEnabled[Enum.HumanoidStateType.Jumping] == false
        and stateEnabled[Enum.HumanoidStateType.Climbing] == false,
        "disabling restores the original Humanoid states")
    check(state.JumpEnabled == false, "the jump bypass is off again")

    state:Destroy()
end

-- Jump Anywhere follows respawns and restores the old Humanoid before binding
-- the new one. Unloading also restores the currently bound character.
do
    local ctx = sandbox(1316421563, 1316421563)
    ctx:MountUI()

    local function makeCharacter(name, power, height)
        local character = Instance.new("Model"); character.Name, character.Parent = name, ctx.Player
        local humanoid = Instance.new("Humanoid"); humanoid.Parent = character
        humanoid.JumpPower = power
        humanoid.UseJumpPower = false
        humanoid.JumpHeight = height
        local states = {
            [Enum.HumanoidStateType.Jumping] = false,
            [Enum.HumanoidStateType.Climbing] = true,
        }
        humanoid.GetStateEnabled = function(_, state) return states[state] end
        humanoid.SetStateEnabled = function(_, state, enabled) states[state] = enabled end
        return character, humanoid, states
    end

    local firstCharacter, firstHumanoid, firstStates = makeCharacter("FirstCharacter", 50, 7.2)
    ctx.Player.Character = firstCharacter
    local state = ctx:Run("src/games/volleyball42.lua")
    state:SetJumpEnabled(true)

    local secondCharacter, secondHumanoid, secondStates = makeCharacter("SecondCharacter", 65, 9)
    ctx.Player.Character = secondCharacter
    ctx.Services.RunService.Heartbeat:Fire(0.05)

    check(firstHumanoid.JumpPower == 50 and firstHumanoid.UseJumpPower == false
        and firstHumanoid.JumpHeight == 7.2,
        "respawn restores the previous Humanoid")
    check(firstStates[Enum.HumanoidStateType.Jumping] == false
        and firstStates[Enum.HumanoidStateType.Climbing] == true,
        "respawn restores the previous Humanoid state flags")
    check(secondHumanoid.JumpPower == 120 and secondHumanoid.UseJumpPower == true
        and secondHumanoid.JumpHeight >= 9,
        "respawn applies the bypass to the new Humanoid")
    check(secondStates[Enum.HumanoidStateType.Jumping] == true
        and secondStates[Enum.HumanoidStateType.Climbing] == true,
        "respawn enables jump states on the new Humanoid")

    state:Destroy()
    check(secondHumanoid.JumpPower == 65 and secondHumanoid.UseJumpPower == false
        and secondHumanoid.JumpHeight == 9,
        "unload restores the current Humanoid values")
    check(secondStates[Enum.HumanoidStateType.Jumping] == false
        and secondStates[Enum.HumanoidStateType.Climbing] == true,
        "unload restores the current Humanoid state flags")
end

-- The UI registers the Jump Anywhere and ESP Character Direction toggles, plus one Jump Power slider.
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
    check(toggles == 2, "Volleyball registers Jump Anywhere and ESP Character Direction")
    check(sliders == 1, "the jump feature has one Jump Power slider")
end
