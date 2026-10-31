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
        check(ctx.State.__DEPHUB.Mode == case[3], "loader records the backend label")
        -- The loader proves liveness first (a raw print before any early return),
        -- then emits its identity lines, the resolved source host, and progress
        -- logs around the UI/backend load. Assert the meaningful lines appear in
        -- order instead of pinning the exact log count, so extra progress lines
        -- never break this test.
        local function logIndexOf(pattern)
            for i, line in ipairs(ctx.Logs) do if line:match(pattern) then return i end end
            return nil
        end
        check(ctx.Logs[1] == "[DepHub] loader starting...", "the loader proves liveness before any early return")
        local iStarting = logIndexOf("^Starting loader v%d+%.%d+%.%d+$")
        local iExecutor = logIndexOf("^Executor detected: Test$")
        local iPlace = logIndexOf("^PlaceId: " .. case[1] .. "$")
        local iGame = logIndexOf("^GameId: " .. case[2] .. "$")
        local iSource = logIndexOf("^Source: https://")
        check(iStarting and iExecutor and iPlace and iGame and iSource, "loader emits its startup identity lines plus the source host")
        check(iStarting < iExecutor and iExecutor < iPlace and iPlace < iGame and iGame < iSource, "startup identity lines are in order")
        check(logIndexOf("^Backend loaded%. DepHub v") ~= nil, "loader logs a final ready line")
        check(not table.find(ctx.Logs, "Starting loader v0.0.1"), "startup logs have no old prefix")
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
        check(loaderSource:find('pcall(print, "[DepHub] loader starting...")', 1, true) ~= nil,
            "the loader proves liveness before any early return")
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
    -- Blox Fruits now runs the vendored open-source script behind a headless
    -- adapter, so the loader contract is the control registry it publishes
    -- rather than the old per-feature mock modules.
    local ctx = sandbox()
    for _, name in ipairs(OSS_MODULES) do
        local path = OSS_PREFIX .. name .. ".lua"
        ctx.Responses[path] = sources[path]
    end
    local state = ctx:Run("src/games/bloxfruits.lua")
    check(type(state) == "table" and state.Destroyed == false, "actual Blox Fruits entry starts the OSS backend with no UI")
    check(state.UI ~= nil and state.UI.gui == nil, "Blox Fruits backend builds no window")
    check(state.Toggles and next(state.Toggles) ~= nil, "Blox Fruits publishes its toggles for the frontend")

    local toggled = false
    for key in pairs(state.Toggles) do toggled = key break end
    check(state:SetToggle(toggled, true) and state:GetToggle(toggled), "Blox Fruits toggles route through the backend")
    check(state:SetValue("does not exist", 1) == false, "unknown control is rejected")

    local requests = #ctx.Requests
    ctx.Player.CharacterAdded:Fire({})
    ctx:FlushDeferred()
    check(#ctx.Requests == requests, "Blox Fruits respawn does not reload modules")

    state:Destroy()
    check(state.Destroyed and ctx.State.__DEPHUB.BloxFruits == nil, "Blox Fruits cleanup releases state")
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

-- Vendored combat behaviour: the module must find the nearest Enemies folder
-- target and fire the real RegisterAttack/RegisterHit remotes with the
-- server-validated hit table. Exercised through the module's own public API.
do
    local ctx = sandbox(2753915549, 994732206)
    for _, name in ipairs(OSS_MODULES) do
        local path = OSS_PREFIX .. name .. ".lua"
        ctx.Responses[path] = sources[path]
    end

    -- Remotes the combat module resolves through ReplicatedStorage.
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

    local Combat = ctx.Env.loadstring(sources[OSS_PREFIX .. "combat.lua"])()
    local found = Combat.nearest(100)
    check(found == enemy, "combat finds the nearest enemy in range")

    charRoot.Position = Vector3.new(500, 0, 500)
    check(Combat.nearest(10) == nil, "combat ignores enemies outside the range")
    charRoot.Position = Vector3.new(0, 0, 0)

    check(type(Combat.hrp()) == "table", "combat resolves the local humanoid root part")
    check(type(Combat.nearestAny(100)) == "table", "combat can scan descendants for a live humanoid")
    Combat.stop()
end
