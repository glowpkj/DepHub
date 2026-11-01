do
    local cases = {
        {1, 2, "universal", true},
        {994732206, 2, "bloxfruits", false},
        {1, 994732206, "bloxfruits", false},
        {85211729168715, 2, "bloxfruits", false},
        {119048529960596, 2, "rt3", false},
        {1, 119048529960596, "rt3", false}
    }
    local function localVersionOf(ctx)
        return ctx.Sources["DepHub.lua"]:match('local VERSION = "([^"]+)"')
    end
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
        check(ctx.State.__DEPHUB.Mode == case[3], "loader records the backend label")
        -- A healthy load is quiet on the console: exactly one line, the DepHub
        -- version. The startup identity (executor, place, host) and progress are
        -- recorded in the Debug tab via Diagnostics.Log, not printed.
        check(ctx.Logs[1] == "DepHub v" .. localVersionOf(ctx), "the loader prints only the DepHub version on a healthy load")
        check(#ctx.Logs == 1, "a healthy load prints nothing else to the console")
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

    -- Regression: the loader used to declare `Players.LocalPlayer or
    -- Players.PlayerAdded:Wait()` and never use it, and later used
    -- `game.Loaded:Wait()` to gate startup. Both are blocking waits that, when
    -- the signal has already fired, never return -- no print, no error, no panel,
    -- the "I ran it and nothing happens" symptom. Neither may come back.
    do
        local ctx = sandbox()
        local loaderSource = ctx.Sources["DepHub.lua"]
        check(not loaderSource:find("PlayerAdded:Wait()", 1, true),
            "the loader has no blocking PlayerAdded:Wait() at startup")
        check(not loaderSource:find("game.Loaded:Wait()", 1, true),
            "the loader has no blocking game.Loaded:Wait() at startup")
    end

    -- A healthy load is QUIET: the console sees exactly one line, the DepHub
    -- version. The progress chatter (executor, place, host, module) lives only in
    -- the Debug tab via Diagnostics.Log, never on the console.
    do
        local ctx = sandbox()
        local localVersion = ctx.Sources["DepHub.lua"]:match('local VERSION = "([^"]+)"')
        ctx.Responses["src/version.txt"] = localVersion
        ctx:Provide("src/games/universal.lua", {})
        check(ctx:Run("DepHub.lua") == true, "a healthy load completes")
        local printed = {}
        for _, line in ipairs(ctx.Logs) do printed[#printed + 1] = line end
        -- The harness records warn() into Logs too; a healthy run logs no warn.
        check(#printed == 1 and printed[1] == "DepHub v" .. localVersion,
            "a healthy load prints exactly the DepHub version and nothing else")
        check(not ctx.Logs[1] or not ctx.Logs[1]:find("Starting loader", 1, true),
            "the loader does not announce its startup on the console")
        check(not ctx.Logs[1] or not ctx.Logs[1]:find("Executor detected", 1, true),
            "the loader does not print the executor on the console")
    end
end

do
    -- Source-host resolution: the loader probes its candidate hosts and accepts
    -- only the one whose src/version.txt is EXACTLY this loader's version -- the
    -- host that also serves the current modules. raw is first in the order, so it
    -- wins, and every module fetch reuses that base.
    local ctx = sandbox(1, 2)
    local localVersion = ctx.Sources["DepHub.lua"]:match('local VERSION = "([^"]+)"')
    ctx.Responses["src/version.txt"] = localVersion
    ctx:Provide("src/games/universal.lua", {})
    check(ctx:Run("DepHub.lua") == true, "loader succeeds and resolves a source host")
    check(ctx.State.__DEPHUB.SourceBaseURL == "https://raw.githubusercontent.com/glowpkj/DepHub/main/",
        "loader prefers raw, the first candidate serving this exact build")
    check(ctx.State.__DEPHUB.BaseVersion == localVersion, "loader records the version the chosen host served")

    -- Every module fetch goes through the resolved base, so no module URL (as
    -- opposed to the host probes) targets a mirror other than the winner.
    for _, url in ipairs(ctx.Requests) do
        if not url:find("src/version.txt", 1, true) then
            check(url:find("cdn.jsdelivr.net", 1, true) == nil, "no module fetch uses a losing mirror: " .. url)
        end
    end
end

do
    -- The exact-version rule is what stops a stale mirror from being chosen. raw
    -- here reports an OLD version (a stale edge cache); the loader must keep
    -- probing and pick the mirror that serves the current build, even though it
    -- comes later in the order -- never the host that answered first.
    local ctx = sandbox()
    local localVersion = ctx.Sources["DepHub.lua"]:match('local VERSION = "([^"]+)"')
    ctx.Responses["src/version.txt"] = localVersion
    ctx:Provide("src/games/universal.lua", {})
    ctx.HostResponses = {
        {Match = "raw.githubusercontent.com/glowpkj/DepHub", Responses = {["src/version.txt"] = "0.0.1"}},
    }
    check(ctx:Run("DepHub.lua") == true, "loader runs when the first host is stale")
    check(ctx.State.__DEPHUB.SourceBaseURL == "https://github.com/glowpkj/DepHub/raw/main/",
        "a stale first host is rejected in favour of the next host serving this exact build")
    check(ctx.State.__DEPHUB.BaseVersion == localVersion,
        "loader records the version of the host it actually chose")
end

do
    -- The executor can serve a stale loader body for the fixed bootstrap URL.
    -- When the remote version is newer than this build, the loader re-fetches
    -- and re-executes itself once, guarded so it cannot loop.
    local ctx = sandbox()
    ctx.Responses["src/version.txt"] = "9.9.9"
    ctx.Responses["DepHub.lua"] = 'local env=getgenv(); env.__DEPHUB_SELF_UPDATE_STUB_RAN=true; ' ..
        'env.__DEPHUB_STUB_SEEN_ATTEMPT=env.__DEPHUB_SELF_UPDATE_ATTEMPT; return true'
    check(ctx:Run("DepHub.lua") == true, "loader self-reload completes")
    check(ctx.State.__DEPHUB_SELF_UPDATE_STUB_RAN == true, "loader re-fetched and executed the remote build when versions differ")
    check(ctx.State.__DEPHUB_STUB_SEEN_ATTEMPT == "9.9.9", "self-reload guard is set to the target version before re-execution")
end

do
    -- No-loop: if the reloaded body is STILL stale (the executor ignored the
    -- cache-bust token), the same build must not re-reload itself. The guard
    -- flag, already set to the target version, makes the second execution fall
    -- through and run normally instead of reloading again.
    local ctx = sandbox()
    ctx.Responses["src/version.txt"] = "9.9.9"
    ctx.Responses["DepHub.lua"] = ctx.Sources["DepHub.lua"]
    ctx:Provide("src/games/universal.lua", {})
    check(ctx:Run("DepHub.lua") == true, "stale reloaded build still completes without looping")
    -- Exactly one self-reload happened: the guard stopped the second attempt.
    local reloadFetches = 0
    for _, url in ipairs(ctx.Requests) do
        if url:find("/DepHub.lua", 1, true) then reloadFetches += 1 end
    end
    check(reloadFetches == 1, "a stale build re-fetches itself only once per session")
end

do
    -- Version matches: the loader runs normally and never re-fetches itself,
    -- so a healthy session is not reloaded on every execution. The remote
    -- version is read from the loader source so the match is exact.
    local ctx = sandbox()
    local localVersion = ctx.Sources["DepHub.lua"]:match('local VERSION = "([^"]+)"')
    check(localVersion ~= nil, "loader declares a version")
    ctx.Responses["src/version.txt"] = localVersion
    ctx:Provide("src/games/universal.lua", {})
    check(ctx:Run("DepHub.lua") == true, "loader runs when versions match")
    for _, url in ipairs(ctx.Requests) do
        check(not url:find("/DepHub.lua", 1, true), "loader does not re-fetch itself when the version matches")
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
    -- Blox Fruits runs its own per-feature modules (one file per feature under
    -- features/bloxfruits/), not the vendored open-source adapter. The features
    -- are self-contained, so the sandbox only has to serve their files -- no
    -- oss/ tree is resolved any more, and there is no global on/off flag: what
    -- is listed in the backend is what loads.
    local ctx = sandbox()
    for _, name in ipairs(BF_FEATURES) do
        local path = BF_FEATURE_PREFIX .. name .. ".lua"
        ctx.Responses[path] = sources[path]
    end
    for _, name in ipairs(BF_INFRA) do
        local path = BF_FEATURE_PREFIX .. name .. ".lua"
        ctx.Responses[path] = sources[path]
    end
    local state = ctx:Run("src/games/bloxfruits.lua")
    check(type(state) == "table" and state.Destroyed == false, "actual Blox Fruits entry starts the backend")
    check(state.Features.bladhits ~= nil, "Blox Fruits loads the blade hit feature")
    check(state.Instances.bladhits == nil, "no feature turns itself on at load")
    -- Infra loads itself: the teleport motor is ready without a toggle.
    check(state.Infra.teleport ~= nil, "the teleport motor is published as infra")
    check(state.Infra.teleport:IsEnabled() == true, "the teleport motor comes up enabled")

    check(state:SetToggle("bladhits", true) or state.Instances.bladhits ~= nil, "the blade hit toggle routes through the backend")
    check(state:SetToggle("does not exist", true) == false, "an unknown feature is rejected")
    check(state:SetToggle("teleport", true) == false, "infra is not a toggleable feature")
    check(state:SetFeatureRange("does not exist", 5) == false, "a knob on an unknown feature is rejected")

    local requests = #ctx.Requests
    ctx.Player.CharacterAdded:Fire({})
    ctx:FlushDeferred()
    check(#ctx.Requests == requests, "Blox Fruits respawn does not reload features")

    state:Destroy()
    check(state.Destroyed and ctx.State.__DEPHUB.BloxFruits == nil, "Blox Fruits cleanup releases state")
end

do
    -- The features that were not ported yet live in features/bloxfruits/parked/
    -- -- out of the active folder, not loaded, not in the manifest. Nothing was
    -- deleted: the backend simply never resolves them, and no parked feature
    -- can be toggled back on.
    local ctx = sandbox()
    ctx.Responses[BF_FEATURE_PREFIX .. "parked/farm.lua"] = "error('parked feature must not be fetched')"
    local state = ctx:Run("src/games/bloxfruits.lua")
    check(type(state) == "table" and state.Destroyed == false, "the backend starts with parked/ beside it")
    check(state.Instances["farm"] == nil, "a parked feature does not instantiate")
    check(state:SetToggle("farm", true) == false, "a parked feature cannot be toggled on")
    state:Destroy()
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

-- Blade hit behaviour: the feature must find a live target in the folders the
-- game uses and fire the real RegisterAttack/RegisterHit remotes, carrying the
-- hitId as the 4th argument. It is exercised through its own public API, with
-- no backend and no adapter in the way -- it is self-contained.
do
    local ctx = sandbox(2753915549, 994732206)
    ctx.Responses[BF_FEATURE_PREFIX .. "bladhits.lua"] = sources[BF_FEATURE_PREFIX .. "bladhits.lua"]

    -- Remotes the feature resolves through ReplicatedStorage.
    local rstorage = ctx.Services.ReplicatedStorage
    local modules = Instance.new("Folder"); modules.Name = "Modules"; modules.Parent = rstorage
    local netFolder = Instance.new("Folder"); netFolder.Name = "Net"; netFolder.Parent = modules
    local attack = Instance.new("RemoteEvent"); attack.Name = "RE/RegisterAttack"; attack.Parent = netFolder
    local hit = Instance.new("RemoteEvent"); hit.Name = "RE/RegisterHit"; hit.Parent = netFolder

    -- Local player character with a rooted humanoid.
    local char = Instance.new("Model"); char.Name, char.Parent = "Character", ctx.Player
    ctx.Player.Character = char
    local charHumanoid = Instance.new("Humanoid"); charHumanoid.Health, charHumanoid.Parent = 100, char
    local charRoot = Instance.new("Part"); charRoot.Name, charRoot.Position, charRoot.Parent = "HumanoidRootPart", Vector3.new(0, 0, 0), char

    -- A live enemy in Workspace.Enemies.
    local enemies = Instance.new("Folder"); enemies.Name = "Enemies"; enemies.Parent = ctx.Services.Workspace
    local enemy = Instance.new("Model"); enemy.Name = "Bandit"; enemy.Parent = enemies
    local enemyHumanoid = Instance.new("Humanoid"); enemyHumanoid.Health, enemyHumanoid.Parent = 100, enemy
    local enemyRoot = Instance.new("Part"); enemyRoot.Name, enemyRoot.Position, enemyRoot.Parent = "HumanoidRootPart", Vector3.new(0, 0, 4), enemy

    local BladeHit = ctx.Env.loadstring(sources[BF_FEATURE_PREFIX .. "bladhits.lua"])()
    local blade = BladeHit.new()
    check(blade:ResolveRemotes(), "a blade hit acha os remotes em Modules.Net")

    local targets = blade:CollectEnemies(100)
    check(#targets == 1 and targets[1].model == enemy, "a blade hit acha o inimigo vivo no alcance")
    check(targets[1].distance == 4, "a blade hit calcula a distancia do alvo")

    charRoot.Position = Vector3.new(500, 0, 500)
    check(#blade:CollectEnemies(10) == 0, "a blade hit ignora alvo fora do alcance")
    charRoot.Position = Vector3.new(0, 0, 0)

    -- Um modelo sem Humanoid vivo nao entra na lista.
    local humanoidless = Instance.new("Model"); humanoidless.Name, humanoidless.Parent = "NoHumanoid", enemies
    local ghost = Instance.new("Part"); ghost.Name, ghost.Position, ghost.Parent = "HumanoidRootPart", Vector3.new(0, 0, 2), humanoidless
    check(#blade:CollectEnemies(100) == 1, "a blade hit ignora um alvo sem Humanoid")

    -- Um inimigo morto tambem nao entra.
    enemyHumanoid.Health = 0
    check(#blade:CollectEnemies(100) == 0, "a blade hit ignora alvo morto")
    enemyHumanoid.Health = 100

    -- O golpe dispara os dois remotes e conta o hit.
    check(blade:AttackNearest(), "a blade hit ataca o alvo no alcance")
    check(blade.hits == 1, "a blade hit conta o golpe")

    -- Desligar limpa a thread e nao explode.
    blade:Disable()
    check(blade:IsEnabled() == false, "depois de Disable a blade hit esta parada")
    blade:Destroy()

    -- Sem os remotes por perto, Enable recusa em vez de explodir.
    modules.Parent = nil
    local bare = BladeHit.new()
    check(bare:AttackNearest() == false, "sem remotes resolvidos a blade hit nao ataca")
    check(bare:Enable() == false, "Enable falha quando os remotes nao existem")
    check(bare:IsEnabled() == false, "uma blade hit sem remotes fica desligada")
    bare:Destroy()
end

-- Teleport motor: the piece every feature will use to move. It must fly the
-- character to a position by tweening the HumanoidRootPart, resolve a named
-- island/boss to the same call, and accept a world Instance (what the fruit
-- feature will hand it). No remotes, no UI -- pure movement.
do
    local ctx = sandbox(2753915549, 994732206)
    ctx.Responses[BF_FEATURE_PREFIX .. "teleport.lua"] = sources[BF_FEATURE_PREFIX .. "teleport.lua"]

    local char = Instance.new("Model"); char.Name, char.Parent = "Character", ctx.Player
    ctx.Player.Character = char
    local root = Instance.new("Part"); root.Name, root.Position, root.Parent = "HumanoidRootPart", Vector3.new(0, 0, 0), char
    local humanoid = Instance.new("Humanoid"); humanoid.Parent = char

    local Teleport = ctx.Env.loadstring(sources[BF_FEATURE_PREFIX .. "teleport.lua"])()
    local tp = Teleport.new()
    check(tp:Enable() == true, "o motor de teleporte liga")

    -- Go tweena o HRP ate o destino, e o tween carrega o CFrame alvo.
    local tween = tp:Go(Vector3.new(0, 0, 600))
    check(tween ~= nil, "Go dispara um voo ate a posicao")
    check(tp:IsFlying() == true, "durante o voo IsFlying e verdadeiro")
    check(tween.Instance == root, "o voo tweena o HumanoidRootPart")

    -- O atalho GoTo soma o offset de chegada (5 studs acima).
    tp:Cancel()
    local tween2 = tp:GoTo(Vector3.new(10, 10, 10))
    check(tween2 ~= nil, "GoTo dispara um voo")
    check(tween2.Goal.CFrame.Position.Y == 15, "GoTo soma o offset de chegada (Y+5)")
    tp:Cancel()
    check(tp:IsFlying() == false, "Cancel limpa o voo corrente")

    -- Um destino nomeado resolve pela tabela e voa pro mesmo lugar.
    local jungle = Teleport:Find(Teleport.islands, "Jungle")
    local named = tp:GoToIsland("Jungle")
    check(named ~= nil, "GoToIsland voa ate a ilha pelo nome")
    tp:Cancel()

    -- GoToInstance aceita um BasePart do mundo -- o contrato da feature de fruta.
    local fruitPart = Instance.new("Part"); fruitPart.Position = Vector3.new(100, 5, 200); fruitPart.Parent = ctx.Services.Workspace
    local viaInstance = tp:GoToInstance(fruitPart)
    check(viaInstance ~= nil, "GoToInstance voa ate um BasePart do mundo")
    check(viaInstance.Goal.CFrame.Position.X == 100, "GoToInstance usa a posicao do Part (com offset)")

    -- Sem character, nada explode: Go devolve nil.
    ctx.Player.Character = nil
    check(tp:Go(Vector3.new(1, 1, 1)) == nil, "sem character Go devolve nil")

    tp:Disable()
    check(tp:IsEnabled() == false and tp:IsFlying() == false, "Disable para o voo e o loop")
    tp:Destroy()
end
