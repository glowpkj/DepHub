local game, task, type, tostring, tonumber, pairs, ipairs, pcall = game, task, type, tostring, tonumber, pairs, ipairs, pcall
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local env = type(getgenv) == "function" and getgenv() or _G
local STATE_KEY = "__DEPHUB_VOLLEYBALL42"

local previous = env[STATE_KEY]
if type(previous) == "table" and type(previous.Destroy) == "function" then
    pcall(previous.Destroy, previous)
end

if not LocalPlayer then
    return false
end

local MAX_TIME = 4.5
local SIMULATION_STEP = 1 / 30
local MAX_SPEED = 700
local HISTORY_WINDOW = 0.16
local STOP_SPEED = 0.5
local SURFACE_OFFSET = 0.03
local MARKER_DIAMETER = 2.5
local PREDICTION_INTERVAL = 0.08
local STABLE_PREDICTION_INTERVAL = 0.25
local MAX_BOUNCES = 5
local MIN_LANDING_NORMAL = 0.68
local CONTACT_DEBOUNCE = 0.06

local GREEN = Color3.fromRGB(0, 255, 100)
local RED = Color3.fromRGB(255, 45, 45)

-- All the gameplay knobs the panel can change. Defaults are what the script
-- started with; the panel rewrites these live, so the module reads the table
-- instead of a craveted constant everywhere it matters.
local Config = {
    autoPosition = false,     -- teleport the character to the predicted landing
    instantMove = false,      -- true = snap CFrame every frame; false = smooth lerp
    positionOffsetY = 3,      -- studs above the landing point to stand
    moveThreshold = 2,        -- only move when further than this from the target (studs)
    moveSmoothing = 0.35,     -- lerp factor per frame for the safe (non-instant) path
    ceilingNoClip = true,     -- remove collision from Ceiling parts
    jumpEnabled = false,      -- force the jump on: set JumpPower and keep it usable
    jumpPower = 120,          -- JumpPower applied while jumpEnabled is on
    autoJump = false,         -- also make the humanoid jump on its own
    maxPredictDistance = 0,   -- 0 = predict at any distance; >0 ignores balls past it
}

local State = {
    Version = "0.2.0",
    Destroyed = false,
    Started = false,
    Mode = "Personal",
    Modes = {"Personal", "Match", "Future"},
    Toggles = {BallPredict = true, AutoPosition = false, JumpForce = false, CeilingNoClip = true},
    ToggleLabels = {
        BallPredict = "Ball Predict",
        AutoPosition = "Auto Position",
        JumpForce = "Pulo forçado",
        CeilingNoClip = "Ceiling NoClip",
    },
    Config = Config,
    Connections = {},
    TouchConnections = {},
    Courts = {},
    Ceilings = {},
    History = {},
    CurrentBall = nil,
    RootPart = nil,
    BallAttachment = nil,
    CurrentVelocity = nil,
    LastContactAt = 0,
    PredictionElapsed = 0,
    SearchElapsed = 0,
    InvalidPredictionElapsed = 0,
    PredictionDirty = true,
    LastSimulationAt = 0,
    LastSimulationPosition = nil,
    LastSimulationVelocity = nil,
    LastPrediction = nil,
    BaseJumpPower = nil,
    BaseUseJumpPower = nil,
    BaseJumpHeight = nil,
    BaseJumpStates = nil,
    BaseWalkSpeed = nil,
    BaseCeilingCollide = nil,
    LastNotification = nil
}

env[STATE_KEY] = State
env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.Volleyball42 = State

local oldFolder = Workspace:FindFirstChild("BallPredictions")
if oldFolder then
    oldFolder:Destroy()
end

local folder = Instance.new("Folder")
folder.Name = "BallPredictions"
folder.Parent = Workspace

local marker = Instance.new("Part")
marker.Name = "PredictedLanding"
marker.Shape = Enum.PartType.Block
marker.Size = Vector3.new(MARKER_DIAMETER, 0.05, MARKER_DIAMETER)
marker.Anchored = true
marker.CanCollide = false
marker.CanTouch = false
marker.CanQuery = false
marker.CastShadow = false
marker.Material = Enum.Material.Neon
marker.Color = GREEN
marker.Transparency = 1
marker.Parent = folder

local markerAttachment = Instance.new("Attachment")
markerAttachment.Name = "TracerEnd"
markerAttachment.Parent = marker

local tracer = Instance.new("Beam")
tracer.Name = "BallTracer"
tracer.Attachment1 = markerAttachment
tracer.Width0 = 0.07
tracer.Width1 = 0.07
tracer.FaceCamera = true
tracer.LightEmission = 0.7
tracer.LightInfluence = 0
tracer.Color = ColorSequence.new(GREEN)
tracer.Transparency = NumberSequence.new(0.05)
tracer.Enabled = false
tracer.Parent = folder

local function connect(list, signal, callback)
    local ok, connection = pcall(signal.Connect, signal, callback)
    if ok and connection then
        list[#list + 1] = connection
        return connection
    end
end

local function disconnectAll(list)
    for i = #list, 1, -1 do
        local connection = list[i]
        list[i] = nil
        if connection then
            pcall(connection.Disconnect, connection)
        end
    end
end

local function clearHistory()
    table.clear(State.History)
    State.CurrentVelocity = nil
    State.PredictionDirty = true
    State.LastSimulationAt = 0
    State.LastSimulationPosition = nil
    State.LastSimulationVelocity = nil
    State.LastPrediction = nil
    marker.Transparency = 1
    tracer.Enabled = false
end

-- Jump power override. The base values are captured the first time the loop
-- runs, so turning the boost off (or Destroy) restores exactly what the game
-- had instead of a hardcoded number.
local function rememberBaseJump()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid and State.BaseJumpPower == nil then
        State.BaseJumpPower = humanoid.JumpPower
        State.BaseUseJumpPower = humanoid.UseJumpPower
        State.BaseJumpHeight = humanoid.JumpHeight
    end
end

-- Forcing the jump: some maps stage a no-jump zone by zeroing JumpPower and
-- JumpHeight and disabling the Jumping state on the client humanoid. Re-asserting
-- both the values and the state flags every frame keeps the jump usable, and the
-- base values are captured on first use so turning it off (or unloading) restores
-- exactly what the game had.
local BYPASS_STATES = {Enum.HumanoidStateType.Jumping, Enum.HumanoidStateType.Climbing}

local function rememberBaseJumpStates(humanoid)
    if State.BaseJumpStates then return end
    local states = {}
    for _, state in ipairs(BYPASS_STATES) do
        local ok, enabled = pcall(function() return humanoid:GetStateEnabled(state) end)
        states[state] = ok and enabled or true
    end
    State.BaseJumpStates = states
end

local function applyJump()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    rememberBaseJump()
    rememberBaseJumpStates(humanoid)
    pcall(function()
        humanoid.UseJumpPower = true
        humanoid.JumpPower = Config.jumpPower
        humanoid.JumpHeight = math.max(tonumber(humanoid.JumpHeight) or 0, 7.2)
    end)
    for _, state in ipairs(BYPASS_STATES) do
        pcall(function() humanoid:SetStateEnabled(state, true) end)
    end

    if Config.autoJump and humanoid:GetState() ~= Enum.HumanoidStateType.Dead then
        pcall(function() humanoid.Jump = true end)
    end
end

local function restoreJump()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or State.BaseJumpPower == nil then return end
    pcall(function()
        humanoid.JumpPower = State.BaseJumpPower
        if State.BaseUseJumpPower ~= nil then humanoid.UseJumpPower = State.BaseUseJumpPower end
        if State.BaseJumpHeight ~= nil then humanoid.JumpHeight = State.BaseJumpHeight end
    end)
    -- Put the humanoid states back the way the game had them.
    if State.BaseJumpStates then
        for state, enabled in pairs(State.BaseJumpStates) do
            pcall(function() humanoid:SetStateEnabled(state, enabled) end)
        end
    end
end

-- Ceiling noclip: the "Ceiling" parts are what the ball bounces off, but they can
-- also block the player. Turning this on clears CanCollide on each cached ceiling
-- and re-asserts it as parts get added; the original collide flags are captured so
-- switching it off puts them back.
local function setCeilingNoClip(enabled)
    for _, part in ipairs(State.Ceilings) do
        if part.Parent then
            if enabled then
                if State.BaseCeilingCollide == nil then
                    State.BaseCeilingCollide = part.CanCollide
                end
                pcall(function() part.CanCollide = false end)
            elseif State.BaseCeilingCollide ~= nil then
                pcall(function() part.CanCollide = State.BaseCeilingCollide end)
            end
        end
    end
end

local function isException(part)
    local ancestor = part

    while ancestor and ancestor ~= Workspace do
        if ancestor.Name == "LockCourt" or ancestor.Name == "Ceiling" then
            return true
        end

        ancestor = ancestor.Parent
    end

    return false
end

local function cacheNamedPart(part, added)
    if not part:IsA("BasePart") then
        return
    end

    local list
    if part.Name == "LockCourt" then
        list = State.Courts
    elseif part.Name == "Ceiling" then
        list = State.Ceilings
    else
        return
    end

    if added then
        if not table.find(list, part) then
            table.insert(list, part)
        end
    else
        local index = table.find(list, part)
        if index then
            table.remove(list, index)
        end
    end
end

local function getRoot(object)
    if not object then
        return nil
    end

    if object:IsA("BasePart") then
        return object
    end

    if object:IsA("Model") then
        return object.PrimaryPart
            or object:FindFirstChild("Ball", true)
            or object:FindFirstChildWhichIsA("BasePart", true)
    end

    return nil
end

local function getSpawnerValue(ball)
    local value = ball and ball:GetAttribute("SpawnedBy")
    if value == nil then
        local root = getRoot(ball)
        value = root and root:GetAttribute("SpawnedBy")
    end
    return tostring(value or "")
end

local function getOwner(ball)
    local spawnedBy = getSpawnerValue(ball)
    if spawnedBy == "" then
        return nil
    end

    local owner = Players:FindFirstChild(spawnedBy)
    if owner then
        return owner
    end

    for _, candidate in ipairs(Players:GetPlayers()) do
        if candidate.Name:lower() == spawnedBy:lower()
            or tostring(candidate.UserId) == spawnedBy then
            return candidate
        end
    end

    return nil
end

local function isValidBall(ball)
    if not ball or not ball.Parent then
        return false
    end

    if not ball:IsA("Model") and not ball:IsA("BasePart") then
        return false
    end

    if ball.Name ~= "Ball" or not getRoot(ball) then
        return false
    end

    local owner = getOwner(ball)
    if not owner then
        return false
    end

    if State.Mode == "Personal" then
        return owner == LocalPlayer
    end

    if State.Mode == "Match" then
        return owner.Team ~= nil
            and (owner.Team.Name == "Blue" or owner.Team.Name == "Red")
    end

    return false
end

local function findBall()
    for _, object in ipairs(Workspace:GetDescendants()) do
        if object.Name == "Ball"
            and (object:IsA("Model") or object:IsA("BasePart"))
            and isValidBall(object) then
            return object
        end
    end

    return nil
end

local function getBallParts(ball)
    local parts = {}

    if ball:IsA("BasePart") then
        parts[1] = ball
    else
        for _, object in ipairs(ball:GetDescendants()) do
            if object:IsA("BasePart") then
                parts[#parts + 1] = object
            end
        end
    end

    return parts
end

local function isPlayerPart(part)
    local ancestor = part

    while ancestor and ancestor ~= Workspace do
        if ancestor:IsA("Model") and Players:GetPlayerFromCharacter(ancestor) then
            return true
        end

        ancestor = ancestor.Parent
    end

    return false
end

local function updateTracerVisibility()
    tracer.Enabled = not State.Destroyed
        and State.Toggles.BallPredict
        and State.Mode == "Personal"
        and State.BallAttachment ~= nil
        and State.BallAttachment.Parent ~= nil
        and marker.Transparency < 1
end

local function updateBallAttachment(part)
    if State.BallAttachment and State.BallAttachment.Parent == part then
        return
    end

    if State.BallAttachment then
        State.BallAttachment:Destroy()
        State.BallAttachment = nil
    end

    tracer.Attachment0 = nil

    if part then
        local attachment = Instance.new("Attachment")
        attachment.Name = "TracerStart"
        attachment.Parent = part
        State.BallAttachment = attachment
        tracer.Attachment0 = attachment
    end
end

-- True when a world position sits inside one of the courts ("green" areas): the
-- marker is drawn green where the ball counts and red where it does not.
local function isInsideCourt(position)
    local halfX = marker.Size.X / 2
    local halfZ = marker.Size.Z / 2
    local offsets = {
        Vector3.new(-halfX, 0, -halfZ),
        Vector3.new(-halfX, 0, halfZ),
        Vector3.new(halfX, 0, -halfZ),
        Vector3.new(halfX, 0, halfZ)
    }

    for _, court in ipairs(State.Courts) do
        if court.Parent then
            local center = Vector3.new(position.X, court.Position.Y, position.Z)
            local courtInside = true

            for _, offset in ipairs(offsets) do
                local point = center + offset
                local localPoint = court.CFrame:PointToObjectSpace(point)

                if math.abs(localPoint.X) + 0.001 > court.Size.X / 2
                    or math.abs(localPoint.Z) + 0.001 > court.Size.Z / 2 then
                    courtInside = false
                    break
                end
            end

            if courtInside then
                local localCenter = court.CFrame:PointToObjectSpace(center)
                courtInside = math.abs(localCenter.X) <= court.Size.X / 2
                    and math.abs(localCenter.Z) <= court.Size.Z / 2
            end

            if courtInside then
                return true, court
            end
        end
    end

    return false, nil
end

local function updateMarkerColor(position)
    local inside = isInsideCourt(position)
    local color = inside and GREEN or RED
    marker.Color = color
    tracer.Color = ColorSequence.new(color)
end

local function getRaycastParams(ball)
    local exclusions = {folder}

    if ball then
        exclusions[#exclusions + 1] = ball
    end

    if LocalPlayer.Character then
        exclusions[#exclusions + 1] = LocalPlayer.Character
    end

    for _, courtPart in ipairs(State.Courts) do
        if courtPart.Parent then
            exclusions[#exclusions + 1] = courtPart
        end
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = exclusions
    params.IgnoreWater = true
    pcall(function()
        params.RespectCanCollide = true
    end)

    return params
end

local function getBallRadius(part)
    local size = part.Size
    local radius = math.min(size.X, size.Y, size.Z) * 0.5
    return math.clamp(radius * 0.9, 0.25, 2.5)
end

local function predictLanding(part, velocity)
    if velocity.Magnitude < STOP_SPEED then
        return nil
    end

    local position = part.Position
    local currentVelocity = velocity
    local gravity = Vector3.new(0, -Workspace.Gravity, 0)
    local radius = getBallRadius(part)
    local params = getRaycastParams(State.CurrentBall)
    local bounceCount = 0
    local steps = math.ceil(MAX_TIME / SIMULATION_STEP)

    for _ = 1, steps do
        local dt = SIMULATION_STEP
        local nextVelocity = currentVelocity + gravity * dt
        local displacement = (currentVelocity + nextVelocity) * (0.5 * dt)

        if displacement.Magnitude > 0.001 then
            local result
            local castOk, castResult = pcall(function()
                return Workspace:Spherecast(position, radius, displacement, params)
            end)

            if castOk then
                result = castResult
            else
                local rayOk, rayResult = pcall(function()
                    return Workspace:Raycast(position, displacement, params)
                end)
                if rayOk then
                    result = rayResult
                end
            end

            if result then
                local hitPart = result.Instance
                if isPlayerPart(hitPart) then
                    return nil
                end

                local distance = math.clamp(result.Distance, 0, displacement.Magnitude)
                local fraction = distance / math.max(displacement.Magnitude, 0.001)
                local direction = displacement.Unit
                local impactVelocity = currentVelocity + gravity * (dt * fraction)
                local normal = result.Normal

                if normal.Y >= MIN_LANDING_NORMAL and impactVelocity:Dot(normal) < -1 then
                    return result.Position + normal * (marker.Size.Y * 0.5 + SURFACE_OFFSET)
                end

                local normalSpeed = impactVelocity:Dot(normal)
                if normalSpeed < 0 then
                    local ballElasticity = 0.45
                    local surfaceElasticity = 0.45
                    local surfaceFriction = 0.3

                    pcall(function()
                        ballElasticity = State.RootPart.CurrentPhysicalProperties.Elasticity
                    end)
                    pcall(function()
                        local properties = hitPart.CurrentPhysicalProperties
                        surfaceElasticity = properties.Elasticity
                        surfaceFriction = properties.Friction
                    end)

                    local restitution = math.clamp(math.max(ballElasticity, surfaceElasticity), 0.15, 0.9)
                    impactVelocity = impactVelocity - normal * ((1 + restitution) * normalSpeed)
                    local tangentVelocity = impactVelocity - normal * impactVelocity:Dot(normal)
                    impactVelocity = impactVelocity - tangentVelocity * math.clamp(surfaceFriction * 0.03, 0, 0.12)
                end

                position = position + direction * distance + normal * 0.06
                currentVelocity = impactVelocity + gravity * (dt * (1 - fraction))
                bounceCount += 1

                if bounceCount > MAX_BOUNCES then
                    return nil
                end
            else
                position = position + displacement
                currentVelocity = nextVelocity
            end
        else
            currentVelocity = nextVelocity
        end
    end

    return nil
end

-- Move the character toward the predicted landing point. Two paths:
--   instant = true  -> set CFrame directly every frame (fast, may rubber-band)
--   instant = false -> lerp the CFrame a fraction per frame and zero velocity,
--                      which is the smooth/safe path. Never Anchor the character:
--                      anchoring makes the physics engine reject ball contacts.
local function moveToLanding(target)
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local goal = target + Vector3.new(0, Config.positionOffsetY, 0)
    if (root.CFrame.Position - goal).Magnitude <= Config.moveThreshold then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid:GetState() == Enum.HumanoidStateType.Dead then return end

    if Config.instantMove then
        pcall(function()
            root.CFrame = CFrame.new(goal)
            root.AssemblyLinearVelocity = Vector3.zero
        end)
    else
        local factor = math.clamp(tonumber(Config.moveSmoothing) or 0.35, 0.05, 1)
        local nextCFrame = root.CFrame:Lerp(CFrame.new(goal), factor)
        pcall(function()
            root.CFrame = nextCFrame
            root.AssemblyLinearVelocity = Vector3.zero
        end)
    end
end

local function disconnectTouches()
    disconnectAll(State.TouchConnections)
end

local function resetBall()
    disconnectTouches()
    State.CurrentBall = nil
    State.RootPart = nil
    updateBallAttachment(nil)
    clearHistory()
    marker.Transparency = 1
    tracer.Enabled = false
end

local function onBallContact(otherPart)
    if State.Destroyed or not State.Toggles.BallPredict
        or not otherPart or not otherPart:IsA("BasePart") then
        return
    end

    if not otherPart.CanCollide and not isPlayerPart(otherPart) then
        return
    end

    local now = os.clock()
    if now - State.LastContactAt < CONTACT_DEBOUNCE then
        return
    end

    State.LastContactAt = now
    clearHistory()
end

local function watchBall(ball)
    disconnectTouches()

    local function bindPart(part)
        connect(State.TouchConnections, part.Touched, function(otherPart)
            if State.CurrentBall and otherPart
                and not otherPart:IsDescendantOf(State.CurrentBall) then
                onBallContact(otherPart)
            end
        end)
    end

    for _, part in ipairs(getBallParts(ball)) do
        bindPart(part)
    end

    if ball:IsA("Model") then
        connect(State.TouchConnections, ball.DescendantAdded, function(object)
            if object:IsA("BasePart") then
                bindPart(object)
            end
        end)
    end
end

local function acquireBall()
    local ball = findBall()

    if ball == State.CurrentBall then
        return ball ~= nil
    end

    resetBall()

    if not ball then
        return false
    end

    State.CurrentBall = ball
    State.RootPart = getRoot(ball)
    updateBallAttachment(State.RootPart)
    watchBall(ball)

    return State.RootPart ~= nil
end

local function estimateVelocity(position, now)
    local history = State.History
    local previous = history[#history]

    if previous then
        local sampleDt = now - previous.Time
        if sampleDt > 0.002 and sampleDt < 0.12 then
            local instantaneous = (position - previous.Position) / sampleDt
            if instantaneous.Magnitude > MAX_SPEED then
                clearHistory()
                history[1] = {Position = position, Time = now}
                return nil
            end

            local oldVelocity = State.CurrentVelocity
            if oldVelocity and oldVelocity.Magnitude > 8 and instantaneous.Magnitude > 8 then
                local directionDot = oldVelocity.Unit:Dot(instantaneous.Unit)
                local velocityDelta = (instantaneous - oldVelocity).Magnitude
                if directionDot < 0.78 or velocityDelta > math.max(75, oldVelocity.Magnitude * 0.65) then
                    table.clear(history)
                    history[1] = {Position = position, Time = now}
                    State.CurrentVelocity = instantaneous
                    State.PredictionDirty = true
                    State.LastSimulationAt = 0
                    return instantaneous
                end
            end
        end
    end

    history[#history + 1] = {Position = position, Time = now}

    while #history > 1 and now - history[1].Time > HISTORY_WINDOW do
        table.remove(history, 1)
    end

    if #history < 3 then
        return State.CurrentVelocity
    end

    local meanTime = 0
    local meanPosition = Vector3.zero
    for _, sample in ipairs(history) do
        meanTime += sample.Time
        meanPosition += sample.Position
    end
    meanTime /= #history
    meanPosition /= #history

    local numerator = Vector3.zero
    local denominator = 0
    for _, sample in ipairs(history) do
        local timeOffset = sample.Time - meanTime
        numerator += (sample.Position - meanPosition) * timeOffset
        denominator += timeOffset * timeOffset
    end

    if denominator <= 0.000001 then
        return State.CurrentVelocity
    end

    local gravityCorrection = Vector3.new(0, -Workspace.Gravity, 0) * (now - meanTime)
    local velocity = numerator / denominator + gravityCorrection

    if velocity.Magnitude > MAX_SPEED then
        clearHistory()
        return nil
    end

    if State.CurrentVelocity then
        local difference = (velocity - State.CurrentVelocity).Magnitude
        local alpha = difference > math.max(30, State.CurrentVelocity.Magnitude * 0.25) and 0.82 or 0.58
        State.CurrentVelocity = State.CurrentVelocity:Lerp(velocity, alpha)
    else
        State.CurrentVelocity = velocity
    end

    return State.CurrentVelocity
end

function State:SetBallPredictEnabled(value)
    self.Toggles.BallPredict = value == true

    if not self.Toggles.BallPredict then
        marker.Transparency = 1
        tracer.Enabled = false
        resetBall()
        return true
    end

    resetBall()
    self.SearchElapsed = 0
    self.LastNotification = {Message = "Ball Predict ativado", Kind = "Success"}
    return true
end

function State:SetToggle(name, value)
    if name == "BallPredict" then
        return self:SetBallPredictEnabled(value)
    end

    if name == "AutoPosition" then
        self.Toggles.AutoPosition = value == true
        Config.autoPosition = self.Toggles.AutoPosition
        return true
    end

    if name == "CeilingNoClip" then
        self.Toggles.CeilingNoClip = value == true
        Config.ceilingNoClip = self.Toggles.CeilingNoClip
        if not self.Toggles.CeilingNoClip then setCeilingNoClip(false) end
        return true
    end

    if name == "JumpForce" then
        self.Toggles.JumpForce = value == true
        Config.jumpEnabled = self.Toggles.JumpForce
        if not self.Toggles.JumpForce then restoreJump() end
        return true
    end

    return false
end

function State:GetToggle(name)
    return self.Toggles[name] == true
end

function State:SetMode(value)
    if value ~= "Personal" and value ~= "Match" and value ~= "Future" then
        return false
    end

    self.Mode = value
    resetBall()
    self.SearchElapsed = 0
    self.LastNotification = {
        Message = value == "Future" and "Future ainda não configurado" or ("Modo " .. value .. " selecionado"),
        Kind = "Info"
    }

    return true
end

function State:Start()
    if self.Started or self.Destroyed then
        return false
    end

    self.Started = true

    for _, object in ipairs(Workspace:GetDescendants()) do
        cacheNamedPart(object, true)
    end

    connect(self.Connections, Workspace.DescendantAdded, function(object)
        cacheNamedPart(object, true)
    end)

    connect(self.Connections, Workspace.DescendantRemoving, function(object)
        cacheNamedPart(object, false)
    end)

    connect(self.Connections, RunService.Heartbeat, function(dt)
        if self.Destroyed then return end

        -- Forcing the jump is independent of the ball: apply it as soon as it is
        -- on, and re-apply each frame because the game can reset the humanoid.
        if Config.jumpEnabled then applyJump() end
        -- Ceiling parts stay non-colliding for the player while this is on; a
        -- re-assert each frame covers ceilings that stream in later.
        if Config.ceilingNoClip then setCeilingNoClip(true) end

        if not self.Toggles.BallPredict or self.Mode == "Future" then
            marker.Transparency = 1
            tracer.Enabled = false
            return
        end

        dt = tonumber(dt) or 0
        self.SearchElapsed += dt
        self.PredictionElapsed += dt

        if not self.CurrentBall or not self.CurrentBall:IsDescendantOf(Workspace)
            or not isValidBall(self.CurrentBall) then
            marker.Transparency = 1
            tracer.Enabled = false

            if self.SearchElapsed >= 0.25 then
                self.SearchElapsed = 0
                if not acquireBall() then
                    return
                end
            else
                return
            end
        end

        local root = getRoot(self.CurrentBall)
        if not root then
            resetBall()
            return
        end

        if root ~= self.RootPart then
            self.RootPart = root
            updateBallAttachment(root)
        end

        -- Optional distance gate: ignore balls further than the configured range
        -- (0 = no limit). Uses the character's root when available.
        local maxRange = tonumber(Config.maxPredictDistance) or 0
        if maxRange > 0 then
            local character = LocalPlayer.Character
            local myRoot = character and character:FindFirstChild("HumanoidRootPart")
            if myRoot and (root.Position - myRoot.CFrame.Position).Magnitude > maxRange then
                marker.Transparency = 1
                tracer.Enabled = false
                return
            end
        end

        local now = os.clock()
        local velocity = estimateVelocity(root.Position, now)
        if not velocity then
            self.InvalidPredictionElapsed += dt
            if self.InvalidPredictionElapsed >= 0.25 then
                marker.Transparency = 1
                tracer.Enabled = false
            end
            updateTracerVisibility()
            return
        end

        local shouldRecalculate = self.PredictionDirty or self.LastSimulationAt == 0
        if self.LastSimulationVelocity then
            local velocityDelta = (velocity - self.LastSimulationVelocity).Magnitude
            local directionChanged = false
            if velocity.Magnitude > 5 and self.LastSimulationVelocity.Magnitude > 5 then
                directionChanged = velocity.Unit:Dot(self.LastSimulationVelocity.Unit) < 0.985
            end
            if velocityDelta >= math.max(14, self.LastSimulationVelocity.Magnitude * 0.12) or directionChanged then
                shouldRecalculate = true
            end
        end

        local predictionExpired = now - self.LastSimulationAt >= STABLE_PREDICTION_INTERVAL
        if not shouldRecalculate and not predictionExpired then
            updateTracerVisibility()
            if Config.autoPosition and self.LastPrediction then
                moveToLanding(self.LastPrediction)
            end
            return
        end

        if self.PredictionElapsed < PREDICTION_INTERVAL and not shouldRecalculate then
            updateTracerVisibility()
            return
        end

        self.PredictionElapsed = 0
        self.PredictionDirty = false
        self.LastSimulationAt = now
        self.LastSimulationPosition = root.Position
        self.LastSimulationVelocity = velocity
        local predicted = predictLanding(root, velocity)

        if predicted then
            self.InvalidPredictionElapsed = 0
            self.LastPrediction = predicted
            marker.Position = predicted
            marker.Transparency = 0.15
            updateMarkerColor(predicted)
            updateTracerVisibility()

            -- Auto Position walks the character to the predicted landing spot.
            if Config.autoPosition then moveToLanding(predicted) end
        else
            self.InvalidPredictionElapsed += PREDICTION_INTERVAL
            if self.InvalidPredictionElapsed >= 0.25 then
                marker.Transparency = 1
                tracer.Enabled = false
            else
                updateTracerVisibility()
            end
        end
    end)

    connect(self.Connections, Players.PlayerRemoving, function(leavingPlayer)
        if self.CurrentBall and getOwner(self.CurrentBall) == leavingPlayer then
            resetBall()
            self.SearchElapsed = 0
        end
    end)

    return true
end

function State:Destroy()
    if self.Destroyed then
        return
    end

    self.Destroyed = true
    disconnectAll(self.Connections)
    disconnectTouches()
    resetBall()
    restoreJump()
    setCeilingNoClip(false)

    if folder.Parent then
        folder:Destroy()
    end

    if env[STATE_KEY] == self then
        env[STATE_KEY] = nil
    end

    if env.__DEPHUB and env.__DEPHUB.Volleyball42 == self then
        env.__DEPHUB.Volleyball42 = nil
    end
end

State:Start()

local UI = (env.__DEPHUB or {}).UI
if type(UI) == "table" and type(UI.CreateTab) == "function" then
    local tabs = {}
    local function section(tabName, sectionName, column)
        local tab = tabs[tabName]
        if not tab then
            tab = UI:CreateTab(tabName, "All")
            tabs[tabName] = tab
        end
        if not tab then return nil end
        return tab:CreateSection(sectionName, column or "Left")
    end
    local function notify(message)
        if type(UI.Notify) == "function" then UI:Notify("Volleyball 4.2", message) end
    end

    -- Left column: prediction and the Auto Position that uses it.
    local predict = section("Ball Predict", "Previsão", "Left")
    if predict then
        predict:CreateToggle("Ball Predict", State.Toggles.BallPredict, function(v) State:SetToggle("BallPredict", v) end)
        predict:CreateDropdown("Modo", State.Modes, State.Mode, function(v)
            if State:SetMode(v) then
                notify("Modo " .. tostring(v) .. " selecionado.")
            else
                notify("Modo inválido.")
            end
        end)
        -- Distance gate: 0 predicts at any range. Only the marker/tracer respect
        -- it, so a far ball is ignored rather than shown with a bad prediction.
        predict:CreateSlider("Alcance da previsão", 0, 2000, Config.maxPredictDistance, function(v)
            Config.maxPredictDistance = tonumber(v) or 0
        end)
        predict:CreateParagraph("Previsão", "Personal prevê a bola do próprio jogador; Match cobre as equipes; Future ainda não está configurado. O marcador fica verde dentro da quadra (onde a bola conta) e vermelho fora.")
    end

    local assist = section("Ball Predict", "Auto Position", "Left")
    if assist then
        assist:CreateToggle("Auto Position", State.Toggles.AutoPosition, function(v) State:SetToggle("AutoPosition", v) end)
        assist:CreateToggle("Instantâneo", Config.instantMove, function(v) Config.instantMove = v == true end)
        assist:CreateSlider("Offset acima do chão", 0, 20, Config.positionOffsetY, function(v) Config.positionOffsetY = tonumber(v) or 0 end)
        assist:CreateSlider("Distância mínima", 0, 20, Config.moveThreshold, function(v) Config.moveThreshold = tonumber(v) or 0 end)
        assist:CreateSlider("Suavidade do movimento", 0.05, 1, Config.moveSmoothing, function(v) Config.moveSmoothing = tonumber(v) or 0.35 end)
        assist:CreateParagraph("Auto Position", "Leva o personagem ao ponto de queda previsto. Instantâneo teleporta direto; desligado usa movimento suave, cuja velocidade é o slider de suavidade.")
    end

    -- Right column: movement (jump) and collision.
    local movement = section("Ball Predict", "Pulo", "Right")
    if movement then
        movement:CreateToggle("Pulo forçado", State.Toggles.JumpForce, function(v)
            State:SetToggle("JumpForce", v)
            notify(v and "Pulo forçado LIGADO" or "Pulo forçado desligado")
        end)
        movement:CreateSlider("Jump Power", 50, 500, Config.jumpPower, function(v)
            Config.jumpPower = tonumber(v) or 120
            if State.Toggles.JumpForce then applyJump() end
        end)
        movement:CreateToggle("Auto Jump", Config.autoJump, function(v)
            Config.autoJump = v == true
        end)
        movement:CreateParagraph("Pulo", "Pulo forçado liga o pulo mesmo em zonas que o bloqueiam: aplica o Jump Power todo frame e mantém o estado de pulo habilitado. Ao desligar, restaura o que o jogo tinha. Auto Jump pula sozinho enquanto ele está ligado.")
    end

    -- Ceiling parts are what the ball bounces off; clearing their collision
    -- removes them as an obstacle for the player. On by default.
    local collision = section("Ball Predict", "Colisão", "Right")
    if collision then
        collision:CreateToggle("Ceiling sem colisão", State.Toggles.CeilingNoClip, function(v) State:SetToggle("CeilingNoClip", v) end)
        collision:CreateParagraph("Colisão", "Tira a colisão das parts Ceiling para você (padrão ligado). A bola continua batendo nelas. Ao desligar, a colisão volta ao original.")
    end
end

-- Report this backend's own structure and live state into the shared Debug tab.
-- The prediction loop depends on the ball object marked "Ball", the court and
-- ceiling parts, and each court's Blue/Red teams; a rename of any is what would
-- break it, so each is probed and its count watched live.
do
    local Diag=env.__DEPHUB and env.__DEPHUB.Diagnostics
    if Diag and type(Diag.Probe)=="function" then
        Diag:SetEnvironment({["Volleyball modo"]=tostring(State.Mode),["Volleyball versao"]=State.Version})
        Diag:Probe("Players.LocalPlayer",LocalPlayer~=nil,LocalPlayer and LocalPlayer.Name or "ausente")
        Diag:Probe("Workspace.Gravity",Workspace.Gravity~=nil,tostring(Workspace.Gravity))
        local ball=nil
        for _,object in ipairs(Workspace:GetDescendants()) do
            if object.Name=="Ball" and (object:IsA("Model") or object:IsA("BasePart")) then ball=object break end
        end
        Diag:Probe("Workspace.Ball",ball~=nil,ball and ball.ClassName or "ausente (predicao nao adquire a bola)")
        Diag:Probe("Workspace.LockCourt",#State.Courts>0,#State.Courts.." quadras cacheadas")
        Diag:Probe("Workspace.Ceiling",#State.Ceilings>0,#State.Ceilings.." tetos cacheados")
        local blue,red=false,false
        local okTeams,teams=pcall(function() return game:GetService("Teams") end)
        if okTeams and teams then
            pcall(function()
                for _,team in ipairs(teams:GetTeams()) do
                    if team.Name=="Blue" then blue=true end
                    if team.Name=="Red" then red=true end
                end
            end)
        end
        Diag:Probe("Teams.Blue",blue,blue and "ok" or "ausente (modo Match sem equipe)")
        Diag:Probe("Teams.Red",red,red and "ok" or "ausente (modo Match sem equipe)")
        Diag:Feature("Volleyball.BallPredict",function() return State.Toggles.BallPredict and "ON" or "off" end)
        Diag:Feature("Volleyball.Modo",function() return tostring(State.Mode) end)
        Diag:Feature("Volleyball.Bola atual",function() return State.CurrentBall and State.CurrentBall.Name or "nenhuma" end)
        Diag:Feature("Volleyball.Velocidade",function()
            local v=State.CurrentVelocity
            return v and string.format("(%.1f,%.1f,%.1f)",v.X,v.Y,v.Z) or "sem dado"
        end)
        Diag:Feature("Volleyball.Historico",function() return #State.History.." amostras" end)
        Diag:Feature("Volleyball.AutoPosition",function() return State.Toggles.AutoPosition and "ON" or "off" end)
        Diag:Feature("Volleyball.JumpForce",function() return State.Toggles.JumpForce and ("ON "..tostring(Config.jumpPower)) or "off" end)
        Diag:Feature("Volleyball.InstantMove",function() return Config.instantMove and "ON" or "off" end)
        Diag:Feature("Volleyball.CeilingNoClip",function() return State.Toggles.CeilingNoClip and "ON" or "off" end)
        Diag:Feature("Volleyball.PodePular",function()
            local ch=LocalPlayer.Character
            local h=ch and ch:FindFirstChildOfClass("Humanoid")
            if not h then return "sem humanoid" end
            local ok,enabled=pcall(function() return h:GetStateEnabled(Enum.HumanoidStateType.Jumping) end)
            return string.format("jumping=%s power=%s height=%s",
                tostring(ok and enabled or "?"),tostring(h.JumpPower),tostring(h.JumpHeight))
        end)
        Diag:Feature("Volleyball.Ponto previsto",function()
            local p=State.LastPrediction
            return p and string.format("(%.1f,%.1f,%.1f)",p.X,p.Y,p.Z) or "sem previsão"
        end)
        if type(Diag.Watch)=="function" then
            Diag:Watch("Volleyball bola",function() return State.CurrentBall and State.CurrentBall.Name or "nenhuma" end)
            Diag:Watch("Volleyball quadras",function() return #State.Courts end)
            Diag:Watch("Volleyball tetos",function() return #State.Ceilings end)
            Diag:Watch("Volleyball modo",function() return tostring(State.Mode) end)
        end
        if type(Diag.Command)=="function" then
            Diag:Command("vb",function()
                return "modo="..tostring(State.Mode)
                    .." bola="..tostring(State.CurrentBall and State.CurrentBall.Name or "nenhuma")
                    .." quadras="..#State.Courts.." tetos="..#State.Ceilings
                    .." amostras="..#State.History
                    .." autoPos="..tostring(State.Toggles.AutoPosition)
                    .." instant="..tostring(Config.instantMove)
                    .." jump="..tostring(State.Toggles.JumpForce)
            end)
            Diag:Command("vb-predict",function(argument)
                local on=argument~="off"
                State:SetToggle("BallPredict",on)
                return "BallPredict="..tostring(on)
            end)
            Diag:Command("vb-assist",function(argument)
                local on=argument~="off"
                State:SetToggle("AutoPosition",on)
                return "AutoPosition="..tostring(on)
            end)
            Diag:Command("vb-instant",function(argument)
                Config.instantMove = argument~="off"
                return "InstantMove="..tostring(Config.instantMove)
            end)
            Diag:Command("vb-jump",function(argument)
                if argument=="off" then
                    State:SetToggle("JumpForce",false)
                    return "JumpForce=off"
                end
                if argument and argument~="" then
                    local value=tonumber(argument)
                    if value then Config.jumpPower=value end
                end
                State:SetToggle("JumpForce",true)
                return "JumpForce=on power="..tostring(Config.jumpPower)
            end)
        end
    end
end

return State
