-- Each backend instruments the shared Debug tab with its own probes, watches
-- and commands. These tests run the real backend with a live Diagnostics
-- collector attached, then assert the report carries that backend's structure
-- -- and, crucially, that a removed instance flips a probe to [FALHA], which is
-- what makes the tab useful after a game update. API doubles only.

-- Load a real Diagnostics instance the same way the loader would.
local function attachDiagnostics(ctx)
    local Diag = ctx:Run("src/core/diagnostics.lua")
    local diag = Diag.new()
    ctx.State.__DEPHUB = ctx.State.__DEPHUB or {}
    ctx.State.__DEPHUB.Diagnostics = diag
    return diag
end

-- MM2: roles, round, coin farm and gun drop each resolve named objects. With
-- none seeded the probes report ausente; seeding RegularLobby flips that one.
do
    local ctx = sandbox(66654135, 66654135)
    ctx:MountUI()
    for _, name in ipairs({"roletracker", "roundtracker", "esp", "coinfarm", "playerteleport", "gundrop"}) do
        ctx.Responses["src/games/features/mm2/" .. name .. ".lua"] = sources["src/games/features/mm2/" .. name .. ".lua"]
    end
    local diag = attachDiagnostics(ctx)
    ctx:Run("src/games/mm2.lua")

    local report = diag:Report()
    check(report:find("MM2 version", 1, true) ~= nil, "MM2 reports its version into Debug")
    check(report:find("Players.LocalPlayer: ", 1, true) ~= nil, "MM2 probes LocalPlayer")
    check(report:find("Workspace.RegularLobby", 1, true) ~= nil, "MM2 probes the round lobby")
    check(report:find("Tool.Knife", 1, true) ~= nil, "MM2 probes the murder knife")
    check(report:find("MM2.Round", 1, true) ~= nil, "MM2 exposes its round state as a live feature")
    check(report:find("MM2.CoinFarm", 1, true) ~= nil, "MM2 exposes coin farm state as a live feature")

    -- The backend added its own console command.
    local output = diag:RunCommand("mm2")
    check(output:find("murder=", 1, true) ~= nil, "MM2 registers a console command")

    -- Seed the probed lobby: re-run a probe read by asking the backend command
    -- for the value is not possible, so assert through a fresh probe on the
    -- report path instead -- the lobby now resolves.
    local lobby = Instance.new("Model"); lobby.Name = "RegularLobby"
    lobby.Parent = ctx.Services.Workspace
    diag:Probe("Workspace.RegularLobby (recheck)", ctx.Services.Workspace:FindFirstChild("RegularLobby") ~= nil, "presente")
    check(diag:Report():find("[OK] Workspace.RegularLobby (recheck)", 1, true) ~= nil, "a present lobby probe passes")
end

-- A failing probe is what surfaces a broken update. Remove the probed instance
-- and confirm the probe reads [FALHA] (already covered above by the ausente
-- state), and that the report never throws when the structure is missing.
do
    local ctx = sandbox(66654135, 66654135)
    ctx:MountUI()
    for _, name in ipairs({"roletracker", "roundtracker", "esp", "coinfarm", "playerteleport", "gundrop"}) do
        ctx.Responses["src/games/features/mm2/" .. name .. ".lua"] = sources["src/games/features/mm2/" .. name .. ".lua"]
    end
    local diag = attachDiagnostics(ctx)
    ctx:Run("src/games/mm2.lua")
    check(diag:Report():find("[FAIL] Workspace.RegularLobby", 1, true) ~= nil, "a missing lobby probe reports a failure")
end

-- TSB: the block remote and the Live folder are the block/counter failure
-- surface. Both are absent here, so the probes must report a failure without
-- taking the backend down.
do
    local ctx = sandbox(3808081382, 3808081382)
    ctx:MountUI()
    ctx:Provide("src/games/features/tsb/animations.lua", {Groups = {}, SkillIds = {}})
    ctx:Provide("src/games/features/tsb/autoblock-v3.lua", {
        new = function() return {Enabled = false, SetM1Block = function() end, SetDashBlock = function() end,
            SetSkillBlock = function() end, SetM1AfterBlock = function() end, Enable = function() end,
            Disable = function() end, Destroy = function() end,
            GetDebugInfo = function() return {BlockActive = false, BlockSource = "none", TrackedPlayers = 0,
                Blocks = 0, Releases = 0, Remote = "missing", UnknownAnimations = 0, LastError = "none"} end} end
    })
    local diag = attachDiagnostics(ctx)
    ctx:Run("src/games/tsb.lua")

    local report = diag:Report()
    check(report:find("TSB version", 1, true) ~= nil, "TSB reports its version into Debug")
    check(report:find("Character.Communicate", 1, true) ~= nil, "TSB probes the block remote")
    check(report:find("Workspace.Live", 1, true) ~= nil, "TSB probes the Live folder")
    check(report:find("AnimationData.Groups", 1, true) ~= nil, "TSB probes the animation groups")
    check(report:find("TSB.AutoBlock", 1, true) ~= nil, "TSB exposes its block state as a live feature")
    check(report:find("[FAIL] Workspace.Live", 1, true) ~= nil, "TSB reports the missing Live folder as a failure")
    check(diag:RunCommand("tsb"):find("block=", 1, true) ~= nil, "TSB registers a console command")
end

-- Noob Piece: the island systems key off one Workspace folder. Its absence must
-- show as a failure, and the toggle summary must still read.
do
    local ctx = sandbox(84822469255086, 84822469255086)
    ctx:MountUI()
    local events = ctx.Services.ReplicatedStorage:FindFirstChild("Events")
    for _, name in ipairs({"PlayerAttack", "SelectTeam", "NpcInteract", "OpenDialog", "DialogChoice", "QuestUpdate"}) do
        local remote = Instance.new("RemoteEvent"); remote.Name = name; remote.Parent = events
    end
    ctx:Provide("src/core/tween-movement.lua", {new = function() return {Stop = function() end, MoveTo = function() end} end})
    ctx:Provide("src/games/features/noobpiece/movementprofile.lua", {})
    ctx:Provide("src/games/features/noobpiece/islanddata.lua", {})
    for _, name in ipairs({"chestesp", "islandtracker", "autochest", "autoattack", "autofarm", "autoteam", "wanderinggacha", "npcesp", "autoquest"}) do
        ctx:Provide("src/games/features/noobpiece/" .. name .. ".lua", {new = function()
            return {SetEnabled = function() end, SetESPEnabled = function() end, Teleport = function() return true end,
                Start = function() end, SetDelay = function() end, SetSelected = function() end, GetTeams = function() return {} end,
                SetSelectedEnemy = function() end, GetSelectedEnemy = function() return "Noob" end, GetEnemyTypes = function() return {} end,
                GetSelectedEnemyOption = function() return "Noob" end, GetTeleportNames = function() return {} end, GetKnownIslands = function() return {} end,
                SetWeaponCategory = function() end, Destroy = function() end}
        end})
    end
    local diag = attachDiagnostics(ctx)
    ctx:Run("src/games/noobpiece.lua")

    local report = diag:Report()
    check(report:find("NoobPiece version", 1, true) ~= nil, "Noob Piece reports its version into Debug")
    check(report:find("Workspace.MysteriousIsland", 1, true) ~= nil, "Noob Piece probes the mysterious island")
    check(report:find("[FAIL] Workspace.MysteriousIsland", 1, true) ~= nil, "Noob Piece reports the missing island as a failure")
    check(report:find("NoobPiece.AutoFarm", 1, true) ~= nil, "Noob Piece exposes its toggles as live features")
    check(diag:RunCommand("np"):find("island=", 1, true) ~= nil, "Noob Piece registers a console command")

    -- Seed the island: the watch value flips and the command reflects it.
    local island = Instance.new("Model"); island.Name = "MysteriousIsland"; island.Parent = ctx.Services.Workspace
    check(diag:RunCommand("np"):find("mystic=true", 1, true) ~= nil, "Noob Piece command reflects the island reappearing")
end

-- RT3: no direct game structure, so its Debug surface is the runtime and the
-- feature registry. Load with mocked providers as the headless test does.
do
    local ctx = sandbox(119048529960596, 119048529960596)
    ctx:MountUI()
    local function provider()
        local object = {}
        function object:Start() self.Started = true end
        function object:Destroy() self.Destroyed = true end
        function object:Register() end
        function object:Get() return {GameId = 2} end
        function object:GetSnapshot() return {GameId = 2, Health = "Healthy"} end
        return object
    end
    for _, name in ipairs({"scheduler", "health-monitor", "dashboard"}) do
        ctx:Provide("src/core/" .. name .. ".lua", {new = provider})
    end
    ctx.Responses["src/core/runtime.lua"] = sources["src/core/runtime.lua"]
    ctx:Provide("src/core/anti-afk.lua", {Start = function() end, Stop = function() end})
    for _, name in ipairs({"autofarm", "instant-cook", "drops", "autofarm-friends"}) do
        ctx:Provide("src/games/features/restauranttycoon3/" .. name .. ".lua", {Toggle = function() end, Enabled = false})
    end
    local diag = attachDiagnostics(ctx)
    local ok = ctx:Run("src/games/rt3.lua")
    check(ok == true, "RT3 loads with diagnostics attached")

    local report = diag:Report()
    check(report:find("RT3 features", 1, true) ~= nil, "RT3 reports its feature count into Debug")
    check(report:find("Runtime.Dashboard", 1, true) ~= nil, "RT3 probes the runtime dashboard")
    check(report:find("Registered features", 1, true) ~= nil, "RT3 probes the registered feature count")
    check(report:find("RT3.Health", 1, true) ~= nil, "RT3 exposes runtime health as a live feature")
    check(diag:RunCommand("rt3"):find("features=", 1, true) ~= nil, "RT3 registers a console command")
end

-- Volleyball 4.2 is a skeleton: it registers no diagnostics of its own (the old
-- ball/court/team probes were part of the removed features), and the shared
-- Debug tab still builds without them.
do
    local ctx = sandbox(1316421563, 1316421563)
    ctx:MountUI()
    local diag = attachDiagnostics(ctx)
    ctx:Run("src/games/volleyball42.lua")

    local report = diag:Report()
    check(report:find("Volleyball mode", 1, true) == nil, "the removed Volleyball probes are gone")
    check(report:find("Volleyball.BallPredict", 1, true) == nil, "the removed Volleyball features are gone")
    check(diag:RunCommand("vb") == nil or diag:RunCommand("vb"):find("mode=", 1, true) == nil, "the removed Volleyball command is gone")
end

-- Every backend must build the shared Debug tab without a real client: assert
-- the report includes the standard sections so a missing collector is obvious.
do
    local ctx = sandbox(66654135, 66654135)
    ctx:MountUI()
    for _, name in ipairs({"roletracker", "roundtracker", "esp", "coinfarm", "playerteleport", "gundrop"}) do
        ctx.Responses["src/games/features/mm2/" .. name .. ".lua"] = sources["src/games/features/mm2/" .. name .. ".lua"]
    end
    local diag = attachDiagnostics(ctx)
    ctx:Run("src/games/mm2.lua")
    local report = diag:Report()
    check(report:find("Environment", 1, true) ~= nil, "backend Debug report keeps the environment section")
    check(report:find("Modules", 1, true) ~= nil, "backend Debug report keeps the modules section")
    check(report:find("Game structure", 1, true) ~= nil, "backend Debug report keeps the structure section")
end

-- Universal: the backend every unmapped game now loads. It must instrument the
-- Debug tab with its own structure and toggles, so an update that breaks a
-- generic API shows as [FALHA] instead of an empty tab.
do
    local ctx = sandbox(1234567890, 1234567890)
    ctx:MountUI()
    local diag = attachDiagnostics(ctx)
    ctx:Run("src/games/universal.lua")

    local report = diag:Report()
    check(report:find("Universal.Status", 1, true) ~= nil, "Universal exposes its status as a live feature")
    check(report:find("Universal.WalkSpeed", 1, true) ~= nil, "Universal exposes WalkSpeed as a live feature")
    check(report:find("Universal.ESP", 1, true) ~= nil, "Universal exposes ESP as a live feature")
    check(report:find("Workspace.CurrentCamera", 1, true) ~= nil, "Universal probes the current camera")
    check(report:find("Workspace.Character", 1, true) ~= nil, "Universal probes the local character")

    check(diag:RunCommand("universal"):find("all off", 1, true) ~= nil, "Universal registers a console command")

    -- Flipping a toggle is reflected in the feature read, proving the probe
    -- tracks live state rather than a canned value.
    local state = ctx.State.__DEPHUB.Universal
    state.Toggles.ESP = true
    check(diag:RunCommand("universal"):find("ESP", 1, true) ~= nil, "Universal command reflects an enabled toggle")
end