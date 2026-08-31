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
        ctx:Provide("src/games/" .. case[3] .. ".lua", result)
        local frontend = {Destroy=function(self) self.Destroyed=true end}
        ctx:Provide("library/init.lua", {new=function(options)
            frontend.Options=options
            return frontend
        end})
        ctx:Provide("src/core/updater.lua", {new=function()
            return {Start=function(self) self.Started = true end}
        end})
        ctx.State.__DEPHUB_SOURCE_CACHE = {["src/core/updater.lua"]='error("stale updater")'}
        check(ctx:Run("DepHub.lua") == true, "loader succeeds for route " .. case[3])
        check(ctx.State.__DEPHUB_LOADER_STATE.Frontend == "library-1", "successful loader marks current library session")
        check(ctx.State.__DEPHUB.Frontend == frontend, "loader stores the new frontend")
        check(frontend.Options.Mode == (case[3] == "rt3" and "RT3" or case[3] == "bloxfruits" and "BloxFruits" or "Universal"), "loader passes the correct content mode")
        check(#ctx.Logs == 5, "loader emits exactly five startup/status lines")
        check(ctx.Logs[1] == "Iniciando loader v0.0.3" and ctx.Logs[2] == "Executor detectado: Test", "startup logs have no old prefix")
        check(ctx.Logs[3] == "PlaceId: " .. case[1] and ctx.Logs[4] == "GameId: " .. case[2], "game identity logs preserved")
        check(ctx.Logs[5] == (case[4] and "Status: Script universal carregado com sucesso" or "Status: Jogo compativel carregado com sucesso"), "final route status preserved")
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
    local libraryFailure = sandbox()
    local backend = {Destroyed=false, Destroy=function(self) self.Destroyed=true end}
    libraryFailure.Responses["src/version.txt"] = "0.0.3"
    libraryFailure:Provide("src/games/universal.lua", backend)
    libraryFailure:Provide("library/init.lua", false)
    check(libraryFailure:Run("DepHub.lua") == false and backend.Destroyed, "invalid library fails loader and cleans initialized backend")
    local ctx = sandbox()
    local removed = {}
    local function old(name) return {Destroy=function() removed[name] = true end} end
    ctx.State.__DEPHUB = {Frontend=old("Frontend"), Universal=old("Universal"), Updater=old("Updater"), Runtime=old("Runtime"), Window=old("Window")}
    ctx.State.__DEPHUB_LOADING_INSTANCE = old("Loading")
    ctx.State.__DEPHUB_UI_MODULES = {old=true}
    ctx.State.__DEPHUB_UI_LOADING = {}
    ctx.State.__DEPHUB_LOADER_EXECUTED = true
    ctx.State.__DEPHUB_LOADER_STATE = {status="success"}
    ctx.Responses["src/version.txt"] = "0.0.3"
    ctx:Provide("src/games/universal.lua", {})
    ctx:Provide("library/init.lua", {new=function() return {} end})
    check(ctx:Run("DepHub.lua") == true, "old UI session migrates without duplicate-success guard blocking it")
    check(removed.Loading and removed.Frontend and removed.Universal and removed.Updater and removed.Runtime and removed.Window, "migration destroys legacy handles despite missing Blox Fruits keys")
    check(ctx.State.__DEPHUB_UI_MODULES == nil and ctx.State.__DEPHUB_UI_LOADING == nil and ctx.State.__DEPHUB.Window == nil, "legacy frontend handles cleared")
end

do
    local ctx = sandbox()
    local universal = ctx:Run("src/games/universal.lua")
    check(type(universal) == "table" and universal.UI == nil and #ctx.Requests == 0, "actual Universal starts without UI, PlayerGui, or downloads")
    local character = Instance.new("Model"); character.Name, character.Parent = "Character", ctx.Player
    local humanoid = Instance.new("Humanoid"); humanoid.WalkSpeed, humanoid.JumpPower, humanoid.UseJumpPower, humanoid.Parent = 18, 55, false, character
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
    local features = {}
    for _, name in ipairs({"playeresp", "fruit", "observation", "unbreakable", "camerashake", "dash", "flashstep", "waterwalking", "team", "fruitvfx"}) do
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
    check(runtime.Features.AutoFarm == features.autofarm and runtime.Features.AutoDrop == features.drops, "RT3 feature handles retained for next frontend")
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
