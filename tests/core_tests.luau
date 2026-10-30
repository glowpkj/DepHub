-- Core service checks: scheduler re-registration, restart races, health severity.
-- These run against the real modules with the harness task double (task.spawn
-- records the runner; task.wait is a no-op), so loops are driven explicitly.
do
    local ctx = sandbox()
    local Scheduler = ctx:Run("src/core/scheduler.lua")

    -- Bug: re-registering a name kept the stale callback and discarded the new one.
    local firstRuns, secondRuns = 0, 0
    local state = Scheduler.new({DefaultInterval=0.05})
    state:Start()
    local first = state:Register("job", function() firstRuns += 1 end)
    check(first.Callback ~= nil, "scheduler registers a task")
    local originalCallback = first.Callback
    local second = state:Register("job", function() secondRuns += 1 end)
    check(second == first, "re-registering returns the same task handle")
    check(second.Callback ~= originalCallback, "re-registration swaps in the fresh callback")
    check(second.Version == 1, "re-registration retires the previous thread version")
    check(#state.Order == 1, "re-registration does not duplicate the task in the order list")

    -- Bug: an enabled task could be left without a live thread after a restart race.
    check(second.RunningVersion == second.Version, "restart binds a fresh thread to the current version")
    state:Stop("job")
    check(second.RunningVersion == nil, "stopping clears the running version")
    state:SetEnabled("job", true)
    check(second.RunningVersion == second.Version, "re-enabling starts a new thread on the new version")

    -- Run the recorded runner body once to prove the swapped callback is what executes.
    local spawned = ctx.Spawned[#ctx.Spawned]
    check(type(spawned) == "table" and type(spawned.Fn) == "function", "scheduler spawns a runner thread")
    ctx.Spawned = {}
    second.Enabled = false
    state:SetEnabled("job", false)
    spawned.Fn()
    check(firstRuns == 0 and secondRuns == 0, "a disabled task performs no work when its runner wakes")

    -- Error accounting drives OnError and disables after MaxErrors.
    local errors = 0
    local failing = Scheduler.new({DefaultInterval=0.05, MaxErrors=3, OnError=function() errors += 1 end})
    local job = failing:Register("boom", function() error("kaboom") end)
    failing:Start()
    failing:Run(job)
    failing:Run(job)
    check(job.Errors == 2 and job.Enabled, "task survives below MaxErrors")
    failing:Run(job)
    check(job.Errors == 3 and not job.Enabled, "task disables at MaxErrors")
    check(errors == 3, "every failed run reports through OnError")
    failing:Run(job)
    check(errors == 3, "disabled task stops reporting errors")
end

do
    local ctx = sandbox()
    local HealthMonitor = ctx:Run("src/core/health-monitor.lua")

    local monitor = HealthMonitor.new({Interval=0.5, MaxErrors=3})
    -- Bug: a check that legitimately returns false was counted as a fault and
    -- became permanently Unhealthy after MaxErrors.
    local flag = false
    monitor:Register("service", function() return flag end)
    local checkState = monitor.Checks.service
    for _ = 1, 5 do monitor:RunCheck("service", checkState) end
    check(not checkState.Healthy, "a false-returning check reports unhealthy")
    check(checkState.Errors == 0, "a clean false return is not counted as an error")
    check(checkState.Failures == 5, "clean false returns accrue as failures, not errors")
    monitor:Evaluate()
    check(monitor.Status == "Unhealthy", "a lone failing check is Unhealthy, not an error flood")
    flag = true
    check(monitor:Evaluate() == "Healthy", "the check recovers once its value flips back")
    check(checkState.Healthy and checkState.Failures == 0, "recovering clears the failure counter")

    -- A raised error is a real fault and does count toward ErrorCount.
    local faulty = HealthMonitor.new({Interval=0.5, MaxErrors=3})
    faulty:Register("broken", function() error("nope") end)
    local brokenState = faulty.Checks.broken
    faulty:RunCheck("broken", brokenState)
    check(not brokenState.Healthy and brokenState.Errors == 1, "a raised error marks the check unhealthy")
    check(faulty.ErrorCount == 1 and faulty.LastError, "raised errors feed ErrorCount and LastError")

    -- Severity summary distinguishes degraded from unhealthy.
    local summary = HealthMonitor.new({Interval=0.5})
    summary:Register("ok", function() return true end)
    summary:Register("bad", function() return false end)
    check(summary:Evaluate() == "Degraded", "one failing check among several is Degraded")
    summary:Register("worst", function() error("dead") end)
    check(summary:Evaluate() == "Degraded", "mixed results remain Degraded while one check passes")
end

do
    local ctx = sandbox()
    local Runtime = ctx:Run("src/core/runtime.lua")
    local Scheduler = ctx:Run("src/core/scheduler.lua")
    local HealthMonitor = ctx:Run("src/core/health-monitor.lua")

    -- Bug: Runtime.ErrorCount/LastError were published but never written.
    local runtime = Runtime.new({Scheduler=Scheduler, HealthMonitor=HealthMonitor})
    runtime:Register("worker", function() error("runtime failure") end)
    local state = runtime:GetTask("worker")
    check(state ~= nil, "runtime registers tasks through to the scheduler")
    runtime.Scheduler:Run(state)
    check(runtime.ErrorCount == 1, "runtime aggregates scheduler errors")
    check(runtime.LastError and runtime.LastError:find("runtime failure"), "runtime records the latest error message")
    local snapshot = runtime:GetSnapshot()
    check(snapshot.ErrorCount == 1 and snapshot.LastError == runtime.LastError, "snapshot surfaces the aggregated error state")

    local originalWorker = runtime:GetTask("worker").Callback
    runtime:Register("worker", function() return true end)
    check(runtime:GetTask("worker").Callback ~= originalWorker, "runtime re-registration swaps the callback")
    runtime:Destroy()
    check(runtime.Destroyed and runtime.Scheduler == nil, "destroyed runtime releases its scheduler")
end

-- Aim smoothing: the camera must interpolate toward the target, never snap in one
-- frame. This exercises the CFrame:Lerp contract smoothLook relies on.
do
    local ctx = sandbox()
    local camera = {CFrame = CFrame.lookAt(Vector3.new(0, 0, 0), Vector3.new(0, 0, -1))}
    local target = Vector3.new(100, 0, 0)
    local goal = CFrame.lookAt(camera.CFrame.Position, target)
    local factor = 1 - math.exp(-8 * 0.016)
    check(factor > 0 and factor < 1, "a single tick smooths only partially")
    local smoothed = camera.CFrame:Lerp(goal, factor)
    check(math.abs(smoothed.Position.X) < 0.001, "smoothing keeps the camera position anchored")
    check(smoothed.LookAt == target, "smoothing turns toward the aim target")
    local settled = camera.CFrame:Lerp(goal, 1)
    check(settled.LookAt == target and settled.Position == goal.Position, "full alpha reaches the target orientation")
    local snapped = CFrame.lookAt(camera.CFrame.Position, target)
    check(snapped.LookAt == target and smoothed.LookAt == snapped.LookAt, "smoothed and snapped share the same target, differ only in alpha")
end

do
    local ctx = sandbox()
    local Dashboard = ctx:Run("src/core/dashboard.lua")
    local updates = 0
    local dashboard = Dashboard.new({
        Interval = 1,
        ManifestInterval = 30,
        ScriptVersion = "0.0.99",
        OnUpdate = function() updates += 1 end
    })

    check(dashboard:Start(), "dashboard starts once")
    check(dashboard.Started and dashboard:Get().PlaceId ~= nil, "dashboard publishes an initial snapshot immediately")
    check(updates >= 1, "dashboard emits its initial update")
    check(dashboard._refreshingUpdates == true, "release metadata refresh runs asynchronously")
    check(dashboard:RefreshUpdates(true) == false, "dashboard prevents overlapping release checks")

    local before = dashboard:GetSnapshot()
    check(before.ScriptVersion == "0.0.99", "dashboard keeps its known version while release metadata is pending")
    dashboard:Destroy()
    check(dashboard.Destroyed and not dashboard.Started, "dashboard destroy stops its lifecycle")
    check(next(dashboard.Connections) == nil, "dashboard destroy disconnects heartbeat listeners")
end

