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
local STEP = 0.05
local MAX_SPEED = 700
local HISTORY_WINDOW = 0.09
local VELOCITY_SMOOTHING = 0.7
local STOP_SPEED = 0.5
local SURFACE_OFFSET = 0.03
local MARKER_DIAMETER = 2.5
local CIRCLE_SAMPLES = 48
local PREDICTION_INTERVAL = 0.075
local CONTACT_DEBOUNCE = 0.08

local GREEN = Color3.fromRGB(0, 255, 100)
local RED = Color3.fromRGB(255, 45, 45)

local State = {
    Version = "0.1.0",
    Destroyed = false,
    Started = false,
    Mode = "Personal",
    Modes = {"Personal", "Match", "Future"},
    Toggles = {BallPredict = true},
    ToggleLabels = {BallPredict = "Ball Predict"},
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

local function updateMarkerColor(position)
    local inside = false
    local radius = MARKER_DIAMETER / 2

    for _, court in ipairs(State.Courts) do
        if court.Parent then
            local center = Vector3.new(position.X, court.Position.Y, position.Z)
            local courtInside = true

            for i = 0, CIRCLE_SAMPLES - 1 do
                local angle = (2 * math.pi * i) / CIRCLE_SAMPLES
                local point = center + Vector3.new(
                    math.cos(angle) * radius,
                    0,
                    math.sin(angle) * radius
                )
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
                inside = true
                break
            end
        end
    end

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

    for _, part in ipairs(State.Courts) do
        if part.Parent then
            exclusions[#exclusions + 1] = part
        end
    end

    for _, part in ipairs(State.Ceilings) do
        if part.Parent then
            exclusions[#exclusions + 1] = part
        end
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = exclusions
    params.IgnoreWater = true

    return params, exclusions
end

local function predictLanding(part, velocity)
    if velocity.Magnitude < STOP_SPEED then
        return nil
    end

    local origin = part.Position
    local gravity = Workspace.Gravity
    local params, exclusions = getRaycastParams(State.CurrentBall)
    local ignored = {}
    local previousPosition = origin

    for t = STEP, MAX_TIME, STEP do
        local nextPosition = origin
            + velocity * t
            + Vector3.new(0, -0.5 * gravity * t * t, 0)

        local result = Workspace:Raycast(
            previousPosition,
            nextPosition - previousPosition,
            params
        )

        if result and result.Instance and result.Instance.CanCollide
            and not isException(result.Instance)
            and not isPlayerPart(result.Instance) then
            if result.Normal.Y >= 0.45 then
                return result.Position
                    + result.Normal * (marker.Size.Y / 2 + SURFACE_OFFSET)
            end

            if not ignored[result.Instance] then
                ignored[result.Instance] = true
                exclusions[#exclusions + 1] = result.Instance
                params.FilterDescendantsInstances = exclusions
            end
        end

        previousPosition = nextPosition
    end

    return nil
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
        or not otherPart or not otherPart:IsA("BasePart")
        or not otherPart.CanCollide
        or isException(otherPart)
        or isPlayerPart(otherPart) then
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
    history[#history + 1] = {Position = position, Time = now}

    while #history > 1 and now - history[1].Time > HISTORY_WINDOW do
        table.remove(history, 1)
    end

    if #history < 2 then
        return State.CurrentVelocity
    end

    local first = history[1]
    local last = history[#history]
    local dt = last.Time - first.Time

    if dt <= 0.003 then
        return State.CurrentVelocity
    end

    local velocity = (last.Position - first.Position) / dt

    if velocity.Magnitude > MAX_SPEED then
        clearHistory()
        return nil
    end

    if State.CurrentVelocity then
        State.CurrentVelocity = State.CurrentVelocity:Lerp(velocity, VELOCITY_SMOOTHING)
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
        if self.Destroyed or not self.Toggles.BallPredict or self.Mode == "Future" then
            marker.Transparency = 1
            tracer.Enabled = false
            return
        end

        dt = tonumber(dt) or 0
        self.SearchElapsed += dt
        self.PredictionElapsed += dt

        if not self.CurrentBall or not self.CurrentBall:IsDescendantOf(Workspace)
            or not isValidBall(self.CurrentBall) then
            if self.SearchElapsed >= 0.25 then
                self.SearchElapsed = 0
                if not acquireBall() then
                    marker.Transparency = 1
                    tracer.Enabled = false
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

        local velocity = estimateVelocity(root.Position, os.clock())
        if not velocity or self.PredictionElapsed < PREDICTION_INTERVAL then
            updateTracerVisibility()
            return
        end

        self.PredictionElapsed = 0
        local predicted = predictLanding(root, velocity)

        if predicted then
            marker.Position = predicted
            marker.Transparency = 0.15
            updateMarkerColor(predicted)
            updateTracerVisibility()
        elseif marker.Transparency >= 1 then
            tracer.Enabled = false
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
return State
