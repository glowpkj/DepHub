do
    local cases = {
        {1, 2, "universal", true},
        {994732206, 2, "bloxfruits", false},
        {1, 994732206, "bloxfruits", false},
        {85211729168715, 2, "bloxfruits", false},
        {119048529960596, 2, "rt3", false},
        {1, 119048529960596, "rt3", false}
    }
    for _, case in ipairs(cases) do
        local ctx = sandbox(case[1], case[2])
        ctx.Responses["src/version.txt"] = "0.0.3"
        local result = case[3] == "rt3" and true or {}
        if case[3] == "rt3" then ctx.State.__DEPHUB = {Runtime={Destroyed=false}} end
        ctx:Provide("src/games/" .. case[3] .. ".lua", result)
        if case[3] == "rt3" then ctx.Responses["src/games/rt3.lua"]='local env=getgenv(); env.__DEPHUB.Runtime={Destroyed=false}; return true' end
        ctx:Provide("src/core/updater.lua", {new=function()
            return {Start=function(self) self.Started = true end}
        end})
        ctx.State.__DEPHUB_SOURCE_CACHE = {["src/core/updater.lua"]='error("stale updater")'}
        check(ctx:Run("DepHub.lua") == true, "loader succeeds for route " .. case[3])
        check(ctx.State.__DEPHUB_LOADER_STATE.status == "success", "successful loader records success state")
        check(ctx.State.__DEPHUB.Mode == (case[3] == "rt3" and "RT3" or case[3] == "bloxfruits" and "BloxFruits" or "Universal"), "loader records the correct mode")
        check(#ctx.Logs == 4, "loader emits four startup identity lines")
        check(ctx.Logs[1] and ctx.Logs[1]:match("^Iniciando loader v%d+%.%d+%.%d+$") ~= nil and ctx.Logs[2] == "Executor detectado: Test", "startup logs have no old prefix")
        check(ctx.Logs[3] == "PlaceId: " .. case[1] and ctx.Logs[4] == "GameId: " .. case[2], "game identity logs preserved")
        if case[3] == "rt3" then check(ctx.State.__DEPHUB.BloxFruits == nil, "RT3 boolean never stored as Blox Fruits state") end
        ctx:FlushDeferred()
        check(ctx.State.__DEPHUB.Updater.Started, "updater still starts using fresh code")
        local requestCount = #ctx.Requests
        ctx:Run("DepHub.lua")
        check(#ctx.Requests == requestCount, "duplicate library execution does not reload modules")
    end
    for _, name in ipairs({"bloxfruits", "universal", "rt3"}) do
        local ctx = sandbox(name == "rt3" and 119048529960596 or name == "bloxfruits" and 994732206 or 1, 2)
        ctx.Responses["src/version.txt"] = "0.0.3"
        ctx:Provide("src/games/" .. name .. ".lua", false)
        check(ctx:Run("DepHub.lua") == false and ctx.State.__DEPHUB_LOADER_STATE.status == "failed", "failed " .. name .. " cannot report loader success")
    end
    do
        local ctx = sandbox()
        local removed = {}
        local function old(name) return {Destroy=function() removed[name] = true end} end
        ctx.State.__DEPHUB = {Universal=old("Universal"), Updater=old("Updater"), Runtime=old("Runtime"), Window=old("Window")}
        ctx.State.__DEPHUB_LOADING_INSTANCE = old("Loading")
        ctx.State.__DEPHUB_UI_MODULES = {old=true}
        ctx.State.__DEPHUB_UI_LOADING = {}
        ctx.State.__DEPHUB_LOADER_EXECUTED = true
        ctx.State.__DEPHUB_LOADER_STATE = {status="success"}
        ctx.Responses["src/version.txt"] = "0.0.3"
        ctx:Provide("src/games/universal.lua", {})
        check(ctx:Run("DepHub.lua") == true, "old UI session migrates without duplicate-success guard blocking it")
        check(removed.Loading and removed.Universal and removed.Updater and removed.Runtime and removed.Window, "migration destroys legacy handles despite missing game keys")
        check(ctx.State.__DEPHUB_UI_MODULES == nil and ctx.State.__DEPHUB_UI_LOADING == nil and ctx.State.__DEPHUB.Window == nil, "legacy frontend handles cleared")
    end
end

do
    local ctx = sandbox()
    local universal = ctx:Run("src/games/universal.lua")
    check(type(universal) == "table" and universal.UI == nil and #ctx.Requests == 0, "actual Universal starts without UI, PlayerGui, or downloads")
    local character = Instance.new("Model"); character.Name, character.Parent = "Character", ctx.Player
    local humanoid = Instance.new("Humanoid"); humanoid.WalkSpeed, humanoid.JumpPower, humanoid.UseJumpPower, humanoid.Health, humanoid.Parent = 18, 55, false, 100, character
    ctx.Player.Character = character
    universal.Values.WalkSpeed = 90; universal:SetWalkSpeedEnabled(true)
    check(humanoid.WalkSpeed == 90, "Universal WalkSpeed setter applies configured value")
    universal:SetWalkSpeedEnabled(false)
    check(humanoid.WalkSpeed == 18, "disabling WalkSpeed restores actual previous value")
    universal.Values.JumpPower = 120; universal:SetJumpEnabled(true)
    check(humanoid.JumpPower == 120 and humanoid.UseJumpPower, "Universal jump setter applies configured value")
    universal:SetJumpEnabled(false)
    check(humanoid.JumpPower == 55 and not humanoid.UseJumpPower, "disabling jump restores actual previous values")
    universal:SetInfiniteZoom(true)
    check(ctx.Player.CameraMaxZoomDistance == 100000, "zoom action preserved outside UI callbacks")
    universal:SetInfiniteZoom(false)
    check(ctx.Player.CameraMaxZoomDistance == 128, "zoom restores original limit")
    universal:Rejoin()
    check(ctx.Services.TeleportService.Calls == 1, "rejoin action preserved outside UI callbacks")
    universal:Notify("Done", "Success")
    check(universal.LastNotification.Message == "Done", "feedback stored as data without popup")
    universal:SetTracers(true)
    check(universal.Toggles.Tracers and universal.FeatureConnections.Tracers ~= nil, "tracers toggle installs a render feature")
    universal:SetTracers(false)
    check(not universal.Toggles.Tracers and universal.FeatureConnections.Tracers == nil, "disabling tracers tears the feature down")
    universal:SetAntiFling(true)
    local root = Instance.new("Part"); root.Name, root.Parent = "HumanoidRootPart", character
    local angular = Instance.new("BodyAngularVelocity"); angular.Parent = root
    ctx.Services.RunService.Heartbeat:Fire(0.016)
    check(angular.Parent == nil, "anti-fling destroys injected angular velocity")
    universal:SetAntiFling(false)
    universal.Values.VoidHeight = -50
    universal:SetAntiVoid(true)
    root.Position = Vector3.new(0, 100, 0)
    ctx.Services.RunService.Heartbeat:Fire(0.016)
    check(universal.LastSafePosition ~= nil, "anti-void remembers a safe position while above the limit")
    root.Position = Vector3.new(0, -100, 0)
    ctx.Services.RunService.Heartbeat:Fire(0.016)
    check(root.CFrame.Position.Y == 100, "anti-void lifts a fallen character back to the safe spot")
    universal:SetAntiVoid(false)
    universal:SetBunnyHop(true)
    ctx.Services.RunService.Heartbeat:Fire(0.016)
    check(humanoid.Jump == true, "bunny hop requests a jump on landing")
    universal:SetBunnyHop(false)
    universal:SetInfiniteJump(true)
    ctx.Services.UserInputService.JumpRequest:Fire()
    check(universal.Toggles.InfiniteJump, "infinite jump stays armed after a jump request")
    universal:SetInfiniteJump(false)
    universal:SetSilentAim(true)
    local camera = ctx.Services.Workspace.CurrentCamera
    local enemy = Instance.new("Player"); enemy.Name = "Enemy"
    local enemyChar = Instance.new("Model"); enemyChar.Parent = enemy
    local enemyRoot = Instance.new("Part"); enemyRoot.Name, enemyRoot.Position, enemyRoot.Parent = "HumanoidRootPart", Vector3.new(10, 0, 0), enemyChar
    local enemyHumanoid = Instance.new("Humanoid"); enemyHumanoid.Health, enemyHumanoid.Parent = 100, enemyChar
    enemy.Character = enemyChar
    ctx.Services.Players.GetPlayers = function() return {ctx.Player, enemy} end
    ctx.Services.UserInputService.InputBegan:Fire({UserInputType = Enum.UserInputType.MouseButton1}, false)
    check(camera.CFrame.LookAt == enemyRoot.Position, "silent aim turns the camera toward the nearest enemy on attack")
    universal:SetSilentAim(false)
    ctx.Player.CharacterAdded:Fire()
    ctx:FlushDeferred()
    check(#ctx.Requests == 0, "respawn does not recreate Universal UI")
    local connections = table.clone(universal.Connections)
    universal:Destroy()
    for _, connection in ipairs(connections) do check(not connection.Connected, "Universal cleanup disconnects listeners") end
    check(ctx.State.__DEPHUB.Universal == nil, "Universal cleanup releases state")
end

do
    local ctx = sandbox()
    local config = {Values={}}
    function config:Load(defaults) self.Values = table.clone(defaults) end
    function config:Get(name, fallback) if self.Values[name] == nil then return fallback end; return self.Values[name] end
    function config:Update(values) for name, value in pairs(values) do self.Values[name] = value end; return true end
    function config:Destroy() self.Destroyed = true end
    ctx:Provide("src/games/features/bloxfruits/config.lua", {new=function() return config end})
    ctx:Provide("src/games/features/bloxfruits/quests.lua", {Worlds={[1]={{1,9,"Bandit",{0,0,0}}}}, PlaceWorld={[1]=1}, For=function() return "Bandit", {0,0,0}, 1 end, RarityOf=function() return "Mythical" end})
    local features = {}
    for _, name in ipairs({"playeresp", "fruit", "observation", "unbreakable", "camerashake", "dash", "flashstep", "waterwalking", "team", "fruitvfx", "bladhits", "autofarm"}) do
        local feature = {Records={}, Enabled=false, BindCount=0}
        function feature:Enable() self.Enabled = true; return true end
        function feature:Disable() self.Enabled = false; return true end
        function feature:Debug() end
        function feature:_bind() self.BindCount += 1 end
        function feature:Destroy() self.Destroyed = true end
        features[name] = feature
        ctx:Provide("src/games/features/bloxfruits/" .. name .. ".lua", {new=function() return feature end})
    end
    local state = ctx:Run("src/games/bloxfruits.lua")
    check(type(state) == "table" and state.Started and state.UI == nil, "actual Blox Fruits entry starts with mocked features and no UI")
    check(state.Features.FruitVFX == features.fruitvfx and features.observation.Enabled and features.team.Enabled, "Blox Fruits features and existing startup defaults preserved")
    check(state:SetToggle("PlayerESP", true) and features.playeresp.Enabled, "Blox Fruits toggles still call feature backends")
    local requests = #ctx.Requests
    ctx.Player.CharacterAdded:Fire({})
    ctx:FlushDeferred()
    check(features.playeresp.BindCount == 1 and #ctx.Requests == requests, "Blox Fruits respawn rebinds backend without rebuilding UI")
    state:Destroy()
    for _, feature in pairs(features) do check(feature.Destroyed, "Blox Fruits cleanup preserves feature destruction") end
end

do
    local ctx = sandbox()
    local function provider()
        local object = {}
        function object:Start() self.Started = true end
        function object:Destroy() self.Destroyed = true end
        function object:Register() end
        function object:Get() return {GameId=2} end
        function object:GetSnapshot() return {GameId=2, Status="Healthy"} end
        return object
    end
    for _, name in ipairs({"scheduler", "health-monitor", "dashboard"}) do
        ctx:Provide("src/core/" .. name .. ".lua", {new=provider})
    end
    ctx.Responses["src/core/runtime.lua"] = sources["src/core/runtime.lua"]
    local antiAFK = {Started=false}
    function antiAFK.Start() antiAFK.Started = true end
    function antiAFK.Stop() antiAFK.Started = false end
    ctx:Provide("src/core/anti-afk.lua", antiAFK)
    local features = {}
    for _, name in ipairs({"autofarm", "instant-cook", "drops", "autofarm-friends"}) do
        local feature = {Enabled=false}
        function feature.Toggle(enabled) feature.Enabled = enabled end
        features[name] = feature
        ctx:Provide("src/games/features/restauranttycoon3/" .. name .. ".lua", feature)
    end
    check(ctx:Run("src/games/rt3.lua") == true, "actual RT3 starts with mocked providers/features and no UI")
    local runtime = ctx.State.__DEPHUB.Runtime
    check(runtime.Started and antiAFK.Started and runtime.Dashboard.Started, "RT3 runtime, telemetry and anti-AFK preserved")
    check(runtime.Features.AutoFarm == features.autofarm and runtime.Features.AutoDrop == features.drops, "RT3 feature handles retained for the frontend")
    for _, feature in pairs(features) do check(not feature.Enabled, "RT3 automations remain off until explicitly activated") end
    runtime.Features.AutoFarm.Toggle(true)
    check(features.autofarm.Enabled, "RT3 feature remains callable without its toggle control")
    runtime:Destroy()
    check(not features.autofarm.Enabled and not antiAFK.Started, "RT3 cleanup stops features and anti-AFK")
end

do
    local ctx = sandbox()
    local Updater = ctx:Run("src/core/updater.lua")
    local updater = Updater.new({CurrentVersion="v1", CurrentCommit="a", StartupGrace=0, Mode="rejoin"})
    local info = {Version="v2", Commit="b", Files={"src/games/bloxfruits.lua"}}
    function updater:FetchVersion() return true, info end
    function updater:ValidateBackendChange() return true end
    updater:Check()
    check(updater.PendingUpdate == info, "updater exposes pending update as data")
    check(#ctx.Spawned == 0 and ctx.Services.TeleportService.Calls == 0, "no hidden countdown or automatic server switch")
    updater:Cancel()
    updater:Check()
    check(updater.PendingUpdate == nil and updater.CancelledVersions.v2, "cancelled updates remain cancelled without UI")
    check(not updater:ApplyPending(), "cannot apply absent pending update")
    info = {Version="v3", Commit="c", Files={}}
    updater:Check()
    check(updater:ApplyPending() and ctx.Services.TeleportService.Calls == 1, "explicit update action preserves rejoin backend")
    updater:Destroy()
    check(not updater:Teleport() and updater.PendingUpdate == nil, "destroyed updater cannot teleport")
    local validation = Updater.new({CurrentVersion="v1", CurrentCommit="a", StartupGrace=0})
    function validation:FetchVersion() return true, info end
    function validation:ValidateBackendChange() return false end
    validation:Check()
    check(validation.PendingUpdate == nil and validation.RejectedVersions.v3, "backend-change validation still rejects untracked updates")
end

-- Blox Fruits blade-hits + auto-farm behaviour: verifies the server remotes are
-- fired with a rate-limited, humanised cadence (the anti-detection contract).
do
    local ctx = sandbox(2753915549, 994732206)
    ctx:Provide("src/games/features/bloxfruits/quests.lua", {Worlds={}, PlaceWorld={}, For=function() return "Bandit", {100, 20, 100}, 1 end, RarityOf=function() return "Common" end})
    local context = {LocalPlayer=ctx.Player, Players=ctx.Services.Players, Workspace=ctx.Services.Workspace, GetRoot=function(c) return c and c:FindFirstChild("HumanoidRootPart") end, ClickDelay=0}
    local state = {Destroyed=false, Features={}, FruitRarityFilter={}}
    context.State = state
    local BladeHits = ctx:Run("src/games/features/bloxfruits/bladhits.lua")
    local blade = BladeHits.new(context)
    check(type(blade) == "table" and blade.Enabled == false, "BladeHits starts disabled")
    -- Wire the remotes the feature resolves at Enable time.
    local rstorage = ctx.Services.ReplicatedStorage
    local modules = Instance.new("Folder"); modules.Name = "Modules"; modules.Parent = rstorage
    local net = Instance.new("Folder"); net.Name = "Net"; net.Parent = modules
    local attack = Instance.new("RemoteEvent"); attack.Name = "RE/RegisterAttack"; attack.Parent = net
    local hit = Instance.new("RemoteEvent"); hit.Name = "RE/RegisterHit"; hit.Parent = net
    check(blade:_resolveRemotes() and blade.RegisterAttack == attack and blade.RegisterHit == hit, "BladeHits resolves RegisterAttack/RegisterHit remotes")
    -- A live enemy in Workspace.Enemies with a rooted humanoid.
    local enemies = Instance.new("Folder"); enemies.Name = "Enemies"; enemies.Parent = ctx.Services.Workspace
    local enemy = Instance.new("Model"); enemy.Name = "Bandit"; enemy.Parent = enemies
    local enemyHumanoid = Instance.new("Humanoid"); enemyHumanoid.Health, enemyHumanoid.Parent = 100, enemy
    local enemyHead = Instance.new("Part"); enemyHead.Name, enemyHead.Position, enemyHead.Parent = "Head", Vector3.new(0, 0, 0), enemy
    local enemyRoot = Instance.new("Part"); enemyRoot.Name, enemyRoot.Position, enemyRoot.Parent = "HumanoidRootPart", Vector3.new(0, 0, 0), enemy
    enemyRoot.CFrame = CFrame.new(0, 0, 0)
    local char = Instance.new("Model"); char.Name, char.Parent = "Character", ctx.Player
    ctx.Player.Character = char
    local charHumanoid = Instance.new("Humanoid"); charHumanoid.Health, charHumanoid.Parent = 100, char
    local charRoot = Instance.new("Part"); charRoot.Name, charRoot.Position, charRoot.Parent = "HumanoidRootPart", Vector3.new(0, 0, 5), char
    local fired = blade:AttackNearest(100)
    check(fired and #attack.Fired == 1 and attack.Fired[1][1] == 0, "BladeHits fires RegisterAttack with the click delay")
    check(#hit.Fired == 1 and hit.Fired[1][1] == enemyHead, "RegisterHit targets the nearest enemy head")
    check(type(hit.Fired[1][2]) == "table" and #hit.Fired[1][2] == 1, "RegisterHit carries the enemy table")
    -- Out of range: no fire.
    charRoot.Position = Vector3.new(500, 0, 500)
    local outOfRange = blade:AttackNearest(10)
    check(not outOfRange and #hit.Fired == 1, "BladeHits stays silent when no enemy is in range")
    check(blade:SetRange(250) and blade.AttackRange == 250, "BladeHits range is configurable")
    blade:Destroy()
    check(blade.Context == nil, "BladeHits releases its context on destroy")

    -- Auto-farm drives BladeHits and reports status as data.
    state.Features.BladeHits = {Enabled=true, AttackRange=100, AttackNearest=function() return true end}
    local AutoFarm = ctx:Run("src/games/features/bloxfruits/autofarm.lua")
    local farm = AutoFarm.new(context)
    farm.QuestData = {For=function() return "Bandit", {100, 20, 100}, 1 end}
    check(type(farm) == "table" and farm.Enabled == false, "AutoFarm starts disabled")
    farm:_step()
    local status = farm:GetStatus()
    check(status.Monster == "Bandit" and status.Status == "farming Bandit", "AutoFarm targets the quest monster and copies its position")
    check(enemyHumanoid.WalkSpeed == 0 and enemyRoot.CanCollide == false, "AutoFarm freezes the live target's humanoid and root")
    check(charRoot.CFrame and charRoot.CFrame.Position.Y == 25, "AutoFarm offsets the pivot above the target (not inside it)")
    state.Destroyed = true
    farm:Destroy()
    check(farm.Context == nil and farm.Enabled == false, "AutoFarm tears down cleanly")
end
