-- Diagnostics module: a collector plus a shared Debug tab. Exercised directly
-- through its public API with API doubles; no claim of in-game functionality.
do
    local ctx = sandbox()
    local Diag = ctx:Run("src/core/diagnostics.lua")

    local diag = Diag.new()
    diag:SetEnvironment({Executor = "Tester", Version = "1.2.3", PlaceId = "1"})
    diag:RegisterModule("um")
    diag:Module("um", true, "ok")
    diag:Module("dois", false, "explodiu")
    diag:Probe("Workspace.Titans", true, "3 titans")
    diag:Probe("Assets.Remotes.GET", false, "ausente")
    diag:Feature("Feature.A", function() return "rodando" end)
    diag:Feature("Feature.B", function() error("leitura falhou") end)
    diag:Note("linha livre")
    diag:Log("loader", "iniciando")

    local report = diag:Report()
    check(report:find("Executor: Tester", 1, true) ~= nil, "diagnostics report includes environment")
    check(report:find("[OK] um: ok", 1, true) ~= nil, "diagnostics report marks a healthy module")
    check(report:find("[FALHA] dois: explodiu", 1, true) ~= nil, "diagnostics report marks a failed module")
    check(report:find("[OK] Workspace.Titans: 3 titans", 1, true) ~= nil, "diagnostics report includes a passing probe")
    check(report:find("[FALHA] Assets.Remotes.GET: ausente", 1, true) ~= nil, "diagnostics report includes a failing probe")
    check(report:find("Feature.A: rodando", 1, true) ~= nil, "diagnostics report reads a live feature")
    check(report:find("Feature.B: ERRO DE LEITURA", 1, true) ~= nil, "diagnostics report contains a throwing feature instead of failing")
    check(report:find("linha livre", 1, true) ~= nil and report:find("iniciando", 1, true) ~= nil, "diagnostics report includes notes and log lines")
    check(report:find("Metricas", 1, true) ~= nil or report:find("FPS", 1, true) ~= nil, "diagnostics report includes live metrics")

    local summary = diag:Summary()
    check(summary:find("1 falha", 1, true) ~= nil, "diagnostics summary counts failures")

    -- A throw inside a deferred feature reader must never take the report down.
    diag:Feature("Feature.C", function() return nil + 1 end)
    check(type(diag:Report()) == "string", "diagnostics always returns a report string")

    -- Console commands: built-ins and a backend-added one, unknown names reported.
    check(diag:RunCommand("metrics"):find("fps=", 1, true) ~= nil, "console runs the metrics command")
    check(diag:RunCommand("sniff off") == "sniff de remotes desligado" and diag.SniffEnabled == false, "console toggles remote sniffing")
    check(diag:RunCommand("naoExiste"):find("desconhecido", 1, true) ~= nil, "console reports an unknown command")
    local ran = false
    diag:Command("custom", function(argument) ran = argument; return "feito:" .. tostring(argument) end)
    check(diag:RunCommand("custom 42") == "feito:42" and ran == "42", "console dispatches a registered command with its argument")

    -- Watch: a change is turned into a timestamped log line.
    local watched = 1
    diag:Watch("contador", function() return watched end)
    diag:_pollWatches()
    watched = 2
    diag:_pollWatches()
    check(diag:LogText():find("contador: 1 -> 2", 1, true) ~= nil, "watch turns a change into a log event")

    -- Copy prefers the executor clipboard and still prints.
    local copiedText = nil
    ctx.State.setclipboard = function(text) copiedText = text end
    local copied, text = diag:Copy()
    check(copied and copiedText == text, "diagnostics copies the full report to the clipboard")
    ctx.State.setclipboard = nil

    diag:Destroy()
end

-- A Stats service that exists but does not expose FrameStats/Network is exactly
-- the shape that made _collectMetrics raise in game (raw member indexes throw
-- when the member is absent). Metrics must degrade to "no data", never error.
do
    local ctx = sandbox()
    local stats = Instance.new("Stats")  -- present, but no FrameStats child
    ctx.Services.Stats = stats
    local Diag = ctx:Run("src/core/diagnostics.lua")
    local diag = Diag.new()
    local ok, metrics = pcall(function() return diag:_collectMetrics() end)
    check(ok, "metrics collection survives a Stats service without FrameStats")
    check(type(metrics) == "table" and type(metrics.Uptime) == "number", "metrics still reports uptime without Stats members")
    check(metrics.FPS == 0 or type(metrics.FPS) == "number", "missing FPS degrades to a number, not an error")
    check(diag:RunCommand("metrics"):find("fps=", 1, true) ~= nil, "the metrics console command works without Stats members")
    diag:Destroy()
end

-- And when Stats genuinely exposes the members the collector reads, the values
-- flow through: this guards the FindFirstChild path against silently resolving
-- nothing once the member does exist.
do
    local ctx = sandbox()
    local stats = Instance.new("Stats")
    local frameStats = Instance.new("Folder"); frameStats.Name = "FrameStats"; frameStats.Parent = stats
    -- FrameRate exposed as a value object read through GetValue() (the real
    -- shape), with no .Value, so the collector must use GetValue first.
    local frameRate = Instance.new("ObjectValue"); frameRate.Name = "FrameRate"
    function frameRate:GetValue() return 144 end
    frameRate.Parent = frameStats
    local network = Instance.new("Folder"); network.Name = "Network"; network.Parent = stats
    local serverStats = Instance.new("Folder"); serverStats.Name = "ServerStatsItem"; serverStats.Parent = network
    local dataPing = Instance.new("NumberValue"); dataPing.Name = "Data Ping"
    function dataPing:GetValue() return 42 end
    dataPing.Parent = serverStats
    function stats:GetTotalMemoryUsageMb() return 512 end
    ctx.Services.Stats = stats
    local Diag = ctx:Run("src/core/diagnostics.lua")
    local diag = Diag.new()
    local metrics = diag:_collectMetrics()
    check(metrics.FPS == 144, "metrics reads the frame rate via GetValue when FrameStats exists")
    check(metrics.Ping == 42, "metrics reads the ping when Network exists")
    check(metrics.Memory == 512, "metrics reads memory when the method exists")
    diag:Destroy()
end

-- FPS must never sit at 0 when Stats is unusable: the physics frame rate is the
-- fallback, so a runtime without FrameStats still shows a live FPS.
do
    local ctx = sandbox()
    function ctx.Services.Workspace:GetRealPhysicsFPS() return 58.7 end
    local Diag = ctx:Run("src/core/diagnostics.lua")
    local diag = Diag.new()
    local metrics = diag:_collectMetrics()
    check(metrics.FPS == 58.7, "metrics falls back to the physics frame rate when FrameStats is absent")
    diag:Destroy()
end

do
    local ctx = sandbox()
    local Diag = ctx:Run("src/core/diagnostics.lua")
    local diag = Diag.new()

    -- Global warn/print capture: install, emit through the executor's warn,
    -- and confirm the line landed in the console log.
    diag:_installLogHooks()
    check(diag.Hooks.warn ~= nil, "diagnostics installs a warn hook")
    if type(ctx.Env.warn) == "function" then ctx.Env.warn("linha do jogo 123") end
    check(diag:LogText():find("linha do jogo 123", 1, true) ~= nil, "game warn lines reach the console")

    -- Remote sniffer: an executor exposes hookfunction, so the sniffer wraps
    -- the method instead of relying on field assignment (which real Instances
    -- shadow through their metatable). Confirm the call is both logged and
    -- still forwarded to the original implementation.
    local remote = Instance.new("RemoteFunction")
    remote.Name = "GET"
    local forwarded = nil
    remote.InvokeServer = function(_, ...) forwarded = {...}; return "resp" end
    -- Provide an executor-style hookfunction that swaps a method on its owner.
    local originalMethod = remote.InvokeServer
    local hookCalls = 0
    ctx.State.hookfunction = function(target, replacement)
        hookCalls = hookCalls + 1
        -- Route the replacement to the method it corresponds to, the way a
        -- real hookfunction patches the closure in place.
        if target == originalMethod then
            remote._props.InvokeServer = replacement
        else
            remote._props.FireServer = replacement
        end
        return target
    end
    -- Make the double resolve InvokeServer from _props so the hook is visible.
    remote._props.InvokeServer = originalMethod
    diag:SniffRemote(remote, "Test.GET")
    check(hookCalls == 2, "sniffer hooks both the invoke and fire methods")
    local result = remote:InvokeServer("S_Skills", "Usage", "108")
    check(result == "resp" and forwarded and forwarded[1] == "S_Skills", "sniffed remote still forwards the call")
    check(diag:LogText():find("GET Test.GET(S_Skills, Usage, 108)", 1, true) ~= nil, "sniffed remote call is logged with arguments")
    ctx.State.hookfunction = nil

    -- In game, reading a method the type does not have raises rather than
    -- returning nil ("FireServer is not a valid member of RemoteFunction").
    -- The sniffer must survive that: a RemoteFunction only exposes InvokeServer,
    -- a RemoteEvent only FireServer. This double raises on the absent method.
    local remoteFunction = setmetatable({
        _props = {ClassName = "RemoteFunction", Name = "GET"},
        _children = {},
        __strict = {InvokeServer = true},
        InvokeServer = function() return "ok" end
    }, {
        __index = function(self, key)
            if self.__strict[key] then return rawget(self, key) end
            error(key .. " is not a valid member of RemoteFunction \"" .. self._props.Name .. "\"")
        end
    })
    -- Sniffing must not raise on the missing FireServer read.
    local okSniff = pcall(function() diag:SniffRemote(remoteFunction, "Strict.GET") end)
    check(okSniff, "sniffing a RemoteFunction does not raise on the absent FireServer method")

    -- And the same for a RemoteEvent, which lacks InvokeServer.
    local remoteEvent = setmetatable({
        _props = {ClassName = "RemoteEvent", Name = "POST"},
        _children = {},
        __strict = {FireServer = true},
        FireServer = function() return "fired" end
    }, {
        __index = function(self, key)
            if self.__strict[key] then return rawget(self, key) end
            error(key .. " is not a valid member of RemoteEvent \"" .. self._props.Name .. "\"")
        end
    })
    local okSniffEvent = pcall(function() diag:SniffRemote(remoteEvent, "Strict.POST") end)
    check(okSniffEvent, "sniffing a RemoteEvent does not raise on the absent InvokeServer method")

    diag:_removeLogHooks()
    check(diag.Hooks.warn == nil, "diagnostics removes its log hooks on teardown")
    diag:Destroy()
end

-- The Debug tab is opt-in: with env.__DEPHUB_ENABLE_DEBUG the loader installs
-- the shared tab for the game, and the AOT:R backend reports its own structure
-- into it.
do
    local ctx = sandbox(4658598196, 4658598196)
    ctx.State.__DEPHUB_ENABLE_DEBUG = true
    ctx.Responses["src/version.txt"] = "0.0.3"
    ctx:MountUI()
    check(ctx:Run("DepHub.lua") == true, "loader succeeds with the diagnostics collector")
    check(ctx.State.__DEPHUB.Diagnostics ~= nil, "loader publishes the diagnostics collector")
    check(ctx.State.__DEPHUB.Diagnostics.Installed, "loader installs the Debug tab when enabled")

    local ui = ctx.State.__DEPHUB.UI
    local names = {}
    for _, tab in ipairs(ui.Library._Tabs) do names[#names + 1] = tab.Name end
    local found = false
    for _, name in ipairs(names) do if name == "Debug" then found = true end end
    check(found, "shared Debug tab is registered when enabled")

    local report = ctx.State.__DEPHUB.Diagnostics:Report()
    check(report:find("Ambiente", 1, true) ~= nil, "Debug report has an environment section")
    check(report:find("AOTR.TitanRipper", 1, true) ~= nil, "AOT:R backend reports its combat features into Debug")
    check(report:find("Workspace.Titans", 1, true) ~= nil, "AOT:R backend reports its structure probes into Debug")

    -- Every module URL the loader issues carries a per-session cache-bust token,
    -- so an executor's HttpGet cache cannot serve a stale older revision.
    check(type(ctx.State.__DEPHUB.SourceCacheBust) == "string" and #ctx.State.__DEPHUB.SourceCacheBust > 0,
        "loader publishes a cache-bust token for module fetches")
    local token = ctx.State.__DEPHUB.SourceCacheBust
    local bustedCalls = 0
    for _, url in ipairs(ctx.Requests) do
        if url:find("cb=" .. token, 1, true) then bustedCalls = bustedCalls + 1 end
    end
    check(bustedCalls > 0, "loader module fetches carry the cache-bust token")
end

-- By default the Debug tab is NOT installed: the collector is still built and
-- backends still instrument it, but no tab and no print/warn hooks are added.
do
    local ctx = sandbox(4658598196, 4658598196)
    ctx.Responses["src/version.txt"] = "0.0.3"
    ctx:MountUI()
    check(ctx:Run("DepHub.lua") == true, "loader succeeds with Debug disabled")
    check(ctx.State.__DEPHUB.Diagnostics ~= nil, "collector is still created when Debug is off")
    check(not ctx.State.__DEPHUB.Diagnostics.Installed, "Debug tab is not installed by default")

    local ui = ctx.State.__DEPHUB.UI
    local found = false
    for _, tab in ipairs(ui.Library._Tabs) do if tab.Name == "Debug" then found = true end end
    check(not found, "no Debug tab is registered by default")

    -- The live switch brings the tab back without a reload.
    check(type(ctx.State.__DEPHUB_DEBUG) == "function", "a global re-enables Debug without a reload")
    check(ctx.State.__DEPHUB_DEBUG() ~= nil, "calling the global installs the tab")
    check(ctx.State.__DEPHUB.Diagnostics.Installed, "Debug tab is installed after the live switch")
end
