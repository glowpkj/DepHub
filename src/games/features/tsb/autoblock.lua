local game = game
local task = task
local type = type
local tonumber = tonumber
local tostring = tostring
local ipairs = ipairs
local pairs = pairs
local math_max = math.max
local math_min = math.min
local math_abs = math.abs
local math_floor = math.floor
local os_clock = os.clock

local Factory = {}

local function disconnectAll(list)
    if not list then return end
    for index = #list, 1, -1 do
        local connection = list[index]
        list[index] = nil
        if connection then
            pcall(connection.Disconnect, connection)
        end
    end
end

local function clamp(value, minimum, maximum)
    return math_min(maximum, math_max(minimum, value))
end

local function getAnimationId(track)
    if not track then return nil end
    local okAnimation, animation = pcall(function()
        return track.Animation
    end)
    if not okAnimation or not animation then return nil end

    local okId, rawId = pcall(function()
        return animation.AnimationId
    end)
    if not okId or type(rawId) ~= "string" then return nil end

    return tonumber(rawId:match("%d+"))
end

local function makeSet(list)
    local result = {}
    if type(list) ~= "table" then return result end
    for _, value in ipairs(list) do
        local id = tonumber(value)
        if id then result[id] = true end
    end
    return result
end

function Factory.new(context)
    context = context or {}

    local Players = context.Players or game:GetService("Players")
    local RunService = context.RunService or game:GetService("RunService")
    local VirtualInputManager = context.VirtualInputManager or game:GetService("VirtualInputManager")
    local Workspace = context.Workspace or game:GetService("Workspace")
    local LocalPlayer = context.LocalPlayer or Players.LocalPlayer
    local AnimationData = type(context.AnimationData) == "table" and context.AnimationData or {}

    local groups = type(AnimationData.Groups) == "table" and AnimationData.Groups or {}
    local comboIds = makeSet(AnimationData.ComboIds)
    local skillIds = makeSet(AnimationData.SkillIds)
    local normalToGroup = {}
    local specialIds = {}
    local knownSkillCount = 0

    for id in pairs(skillIds) do
        knownSkillCount = knownSkillCount + 1
    end

    for groupIndex, group in ipairs(groups) do
        if type(group) == "table" then
            local normal = type(group.Normal) == "table" and group.Normal or {}
            for _, value in ipairs(normal) do
                local id = tonumber(value)
                if id then normalToGroup[id] = groupIndex end
            end
            local special = tonumber(group.Special)
            if special then specialIds[special] = true end
        end
    end

    local self = {
        Enabled = false,
        Destroyed = false,
        Connections = {},
        PlayerBindings = {},
        DetectionPart = nil,
        DetectionCharacter = nil,
        CharacterToken = 0,
        BlockActive = false,
        BlockUntil = 0,
        BlockSource = nil,
        CatchKeysDown = false,
        CatchToken = 0,
        LastCatch = 0,
        ScanAccumulator = 0,
        Config = {
            M1Block = context.M1Block == true,
            M1AfterBlock = context.M1AfterBlock == true,
            M1Catch = context.M1Catch == true,
            DashBlock = context.DashBlock == true,
            SkillBlock = context.SkillBlock == true,
            ShowDetectionBox = context.ShowDetectionBox == true,
            Debug = context.Debug == true,
            NormalRange = clamp(tonumber(context.NormalRange) or 12, 2, 30),
            SpecialRange = clamp(tonumber(context.SpecialRange) or 50, 5, 80),
            SkillRange = clamp(tonumber(context.SkillRange) or 50, 5, 80),
            SkillHold = clamp(tonumber(context.SkillHold) or 1.2, 0.1, 2),
            DetectionBoxSize = clamp(tonumber(context.DetectionBoxSize) or 12, 2, 40),
            ScanHz = clamp(tonumber(context.ScanHz) or 30, 10, 60)
        },
        DebugInfo = {
            Runtime = "idle",
            Character = "none",
            Remote = "missing",
            Live = "missing",
            LastEvent = "none",
            LastReason = "none",
            LastAnimation = "none",
            LastPlayer = "none",
            LastDistance = 0,
            Blocks = 0,
            Releases = 0,
            AnimationEvents = 0,
            M1Events = 0,
            TrackedPlayers = 0,
            KnownSkillAnimations = knownSkillCount,
            ScanHz = clamp(tonumber(context.ScanHz) or 30, 10, 60),
            LastError = "none"
        }
    }

    function self:_debug(message)
        self.DebugInfo.LastEvent = tostring(message)
        if self.Config.Debug then
            print("[DepHub TSB] " .. tostring(message))
        end
    end

    function self:_setError(message)
        self.DebugInfo.LastError = tostring(message or "none")
        if message and self.Config.Debug then
            print("[DepHub TSB] error: " .. tostring(message))
        end
    end

    function self:_localCharacter()
        return LocalPlayer and LocalPlayer.Character or nil
    end

    function self:_localRoot()
        local character = self:_localCharacter()
        return character and character:FindFirstChild("HumanoidRootPart") or nil
    end

    function self:_localAlive()
        local character = self:_localCharacter()
        local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
        return humanoid ~= nil and humanoid.Health > 0
    end

    function self:_communicate(goal, mobile)
        if self.Destroyed or not LocalPlayer then return false end

        local character = LocalPlayer.Character
        local remote = character and character:FindFirstChild("Communicate")

        self.DebugInfo.Character = character and character.Name or "none"
        self.DebugInfo.Remote = remote and remote:IsA("RemoteEvent") and "ready" or "missing"

        if not remote or not remote:IsA("RemoteEvent") then
            return false
        end

        local payload = {Goal = goal}
        if mobile == true then payload.Mobile = true end
        if goal == "KeyPress" or goal == "KeyRelease" then
            payload.Key = Enum.KeyCode.F
        end

        local ok, err = pcall(remote.FireServer, remote, payload)
        if not ok then
            self:_setError(err)
            return false
        end

        self.DebugInfo.LastError = "none"
        return true
    end

    function self:_destroyDetectionBox()
        local part = self.DetectionPart
        self.DetectionPart = nil
        self.DetectionCharacter = nil
        if part then
            pcall(part.Destroy, part)
        end
    end

    function self:_ensureDetectionBox()
        local character = self:_localCharacter()
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not character or not root then return nil end

        local size = self.Config.DetectionBoxSize
        local part = self.DetectionPart

        if part and part.Parent and self.DetectionCharacter == character then
            part.Size = Vector3.new(size, size, size)
            part.Transparency = self.Config.ShowDetectionBox and 0.68 or 1
            return part
        end

        self:_destroyDetectionBox()

        part = Instance.new("Part")
        part.Name = "DepHubDetectionBox"
        part.Size = Vector3.new(size, size, size)
        part.CFrame = root.CFrame
        part.Color = Color3.fromRGB(255, 55, 55)
        part.Material = Enum.Material.Plastic
        part.Transparency = self.Config.ShowDetectionBox and 0.68 or 1
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        part.CastShadow = false
        part.Massless = true
        part.Anchored = false
        part.Parent = character

        local weld = Instance.new("WeldConstraint")
        weld.Part0 = root
        weld.Part1 = part
        weld.Parent = part

        self.DetectionPart = part
        self.DetectionCharacter = character
        self:_debug("hitbox ready: " .. tostring(size))
        return part
    end

    function self:_insideDetectionBox(enemyRoot, myRoot)
        if not enemyRoot or not myRoot then return false end
        local relative = myRoot.CFrame:PointToObjectSpace(enemyRoot.Position)
        local half = self.Config.DetectionBoxSize * 0.5
        return math_abs(relative.X) <= half
            and math_abs(relative.Y) <= half
            and math_abs(relative.Z) <= half
    end

    function self:_releaseBlock(reason)
        if not self.BlockActive then
            self.BlockUntil = 0
            self.BlockSource = nil
            return false
        end

        self:_communicate("KeyRelease")
        self.BlockActive = false
        self.BlockUntil = 0
        self.BlockSource = nil
        self.DebugInfo.Releases = self.DebugInfo.Releases + 1

        if reason then
            self:_debug("block release: " .. tostring(reason))
        end

        return true
    end

    function self:_pressBlock(duration, source, reason, player, animationId, distance)
        if self.Destroyed or not self.Enabled or not self:_localAlive() then
            return false, false
        end

        local now = os_clock()
        local hold = clamp(tonumber(duration) or 0.15, 0.05, 3)
        self.BlockUntil = math_max(self.BlockUntil, now + hold)
        self.BlockSource = source or self.BlockSource or "unknown"

        self.DebugInfo.LastReason = tostring(reason or source or "unknown")
        self.DebugInfo.LastAnimation = animationId and tostring(animationId) or "none"
        self.DebugInfo.LastPlayer = player and player.Name or "none"
        self.DebugInfo.LastDistance = tonumber(distance) or 0

        if reason then
            self:_debug(
                "block " .. tostring(reason)
                .. " | " .. self.DebugInfo.LastPlayer
                .. " | id=" .. self.DebugInfo.LastAnimation
                .. " | dist=" .. string.format("%.1f", self.DebugInfo.LastDistance)
            )
        end

        if self.BlockActive then
            return true, false
        end

        if not self:_communicate("KeyPress") then
            self.BlockUntil = 0
            self.BlockSource = nil
            return false, false
        end

        self.BlockActive = true
        self.DebugInfo.Blocks = self.DebugInfo.Blocks + 1
        return true, true
    end

    function self:_leftClick()
        if self.Destroyed or not self.Enabled then return false end
        if not self:_communicate("LeftClick", true) then return false end

        task.delay(0.3, function()
            if not self.Destroyed and self.Enabled then
                self:_communicate("LeftClickRelease", true)
            end
        end)

        return true
    end

    function self:_scheduleAfterBlock(player, tracker)
        if not self.Config.M1AfterBlock or not tracker then return end
        local characterToken = self.CharacterToken
        local expectedCharacter = tracker.Character

        task.delay(0.16, function()
            if self.Destroyed or not self.Enabled or not self.Config.M1AfterBlock then return end
            if characterToken ~= self.CharacterToken then return end
            if tracker.Character ~= expectedCharacter or not expectedCharacter.Parent then return end

            local myRoot = self:_localRoot()
            local enemyRoot = tracker.Root
            if not myRoot or not enemyRoot or not enemyRoot.Parent then return end

            if (enemyRoot.Position - myRoot.Position).Magnitude <= 10 then
                self:_debug("M1 After Block: " .. tostring(player and player.Name or "unknown"))
                self:_leftClick()
            end
        end)
    end

    function self:_releaseCatchKeys()
        if not self.CatchKeysDown then return end
        self.CatchKeysDown = false
        pcall(VirtualInputManager.SendKeyEvent, VirtualInputManager, false, Enum.KeyCode.Q, false, game)
        pcall(VirtualInputManager.SendKeyEvent, VirtualInputManager, false, Enum.KeyCode.D, false, game)
    end

    function self:_startCatch(player, tracker)
        if not self.Config.M1Catch or self.Destroyed or not self.Enabled then return false end
        if os_clock() - self.LastCatch < 5 then return false end
        if not tracker or not tracker.Root then return false end

        local myRoot = self:_localRoot()
        if not myRoot then return false end

        local enemyRoot = tracker.Root
        local firstDistance = (enemyRoot.Position - myRoot.Position).Magnitude
        if firstDistance > self.Config.SpecialRange then return false end

        self.CatchToken = self.CatchToken + 1
        local token = self.CatchToken

        task.delay(0.1, function()
            if self.Destroyed or not self.Enabled or not self.Config.M1Catch then return end
            if token ~= self.CatchToken then return end
            if not enemyRoot.Parent then return end

            local currentRoot = self:_localRoot()
            if not currentRoot then return end

            local secondDistance = (enemyRoot.Position - currentRoot.Position).Magnitude
            if secondDistance >= firstDistance - 0.5 then return end
            if os_clock() - self.LastCatch < 5 then return end

            self.LastCatch = os_clock()
            self:_debug("M1 Catch: " .. tostring(player and player.Name or "unknown"))
            self:_leftClick()

            self:_releaseCatchKeys()
            self.CatchKeysDown = true
            pcall(VirtualInputManager.SendKeyEvent, VirtualInputManager, true, Enum.KeyCode.D, false, game)
            pcall(VirtualInputManager.SendKeyEvent, VirtualInputManager, true, Enum.KeyCode.Q, false, game)

            task.delay(1, function()
                if token == self.CatchToken then
                    self:_releaseCatchKeys()
                end
            end)
        end)

        return true
    end

    function self:_trackerReady(tracker)
        if not tracker or not tracker.Character or not tracker.Character.Parent then return false end
        if not tracker.Root or not tracker.Root.Parent then return false end
        if not tracker.Humanoid or tracker.Humanoid.Health <= 0 then return false end

        local live = Workspace:FindFirstChild("Live")
        self.DebugInfo.Live = live and "ready" or "missing"
        if not live then return false end

        return tracker.Character.Parent == live
    end

    function self:_distance(tracker)
        if not self:_trackerReady(tracker) then return nil, nil end
        local myRoot = self:_localRoot()
        if not myRoot then return nil, nil end
        return (tracker.Root.Position - myRoot.Position).Magnitude, myRoot
    end

    function self:_activeCount(tracker, set)
        local count = 0
        for id in pairs(set) do
            if (tracker.ActiveIds[id] or 0) > 0 then
                count = count + 1
            end
        end
        return count
    end

    function self:_groupActiveNormals(tracker, group)
        local count = 0
        if type(group) ~= "table" or type(group.Normal) ~= "table" then return 0 end
        for _, value in ipairs(group.Normal) do
            local id = tonumber(value)
            if id and (tracker.ActiveIds[id] or 0) > 0 then
                count = count + 1
            end
        end
        return count
    end

    function self:_checkDashCombo(player, tracker, distance)
        if not self.Config.DashBlock or distance > self.Config.SpecialRange then return false end
        if self:_activeCount(tracker, comboIds) < 2 then return false end

        for _, group in ipairs(groups) do
            if self:_groupActiveNormals(tracker, group) >= 2 then
                self:_pressBlock(0.7, "dash", "combo/dash", player, nil, distance)
                return true
            end
        end

        return false
    end

    function self:_handleM1(player, tracker, reason)
        if not self.Config.M1Block or not self:_trackerReady(tracker) then return false end

        local distance, myRoot = self:_distance(tracker)
        if not distance or distance > self.Config.NormalRange then return false end
        if not self:_insideDetectionBox(tracker.Root, myRoot) then return false end

        local ok, newlyPressed = self:_pressBlock(0.15, "m1", reason or "M1ing", player, nil, distance)
        if ok then
            tracker.InsideLast = true
        end
        if ok and newlyPressed then
            self:_scheduleAfterBlock(player, tracker)
        end
        return ok
    end

    function self:_handleAnimation(player, tracker, animationId)
        if not self:_trackerReady(tracker) then return end

        local distance, myRoot = self:_distance(tracker)
        if not distance or not myRoot then return end

        if self:_checkDashCombo(player, tracker, distance) then
            return
        end

        local groupIndex = normalToGroup[animationId]
        if groupIndex and self.Config.M1Block then
            if distance <= self.Config.NormalRange and self:_insideDetectionBox(tracker.Root, myRoot) then
                local ok, newlyPressed = self:_pressBlock(0.15, "m1", "M1 animation", player, animationId, distance)
                if ok and newlyPressed then
                    self:_scheduleAfterBlock(player, tracker)
                end
                return
            end
        end

        if specialIds[animationId] and distance <= self.Config.SpecialRange then
            if animationId == 10479335397 and self.Config.M1Block and self.Config.M1Catch then
                self:_startCatch(player, tracker)
                return
            end

            if self.Config.DashBlock then
                self:_pressBlock(1, "dash", "special/dash", player, animationId, distance)
                return
            end
        end

        if self.Config.SkillBlock and skillIds[animationId] and distance <= self.Config.SkillRange then
            self:_pressBlock(self.Config.SkillHold, "skill", "skill", player, animationId, distance)
        end
    end

    function self:_registerTrack(player, tracker, track, process)
        if not tracker or not track or tracker.TrackIds[track] then return end

        local animationId = getAnimationId(track)
        if not animationId then return end

        tracker.TrackIds[track] = animationId
        tracker.ActiveIds[animationId] = (tracker.ActiveIds[animationId] or 0) + 1
        self.DebugInfo.AnimationEvents = self.DebugInfo.AnimationEvents + 1

        local connection
        local okConnect, result = pcall(function()
            return track.Stopped:Connect(function()
                if tracker.Destroyed then return end
                local storedId = tracker.TrackIds[track]
                tracker.TrackIds[track] = nil

                local storedConnection = tracker.TrackConnections[track]
                tracker.TrackConnections[track] = nil
                if storedConnection then
                    pcall(storedConnection.Disconnect, storedConnection)
                end

                if storedId then
                    local count = (tracker.ActiveIds[storedId] or 1) - 1
                    if count <= 0 then
                        tracker.ActiveIds[storedId] = nil
                    else
                        tracker.ActiveIds[storedId] = count
                    end
                end
            end)
        end)

        if okConnect and result then
            connection = result
            tracker.TrackConnections[track] = connection
        end

        if process ~= false then
            self:_handleAnimation(player, tracker, animationId)
        end
    end

    function self:_destroyTracker(binding)
        local tracker = binding and binding.Tracker
        if not tracker then return end
        binding.Tracker = nil
        tracker.Destroyed = true

        disconnectAll(tracker.Connections)
        for track, connection in pairs(tracker.TrackConnections) do
            tracker.TrackConnections[track] = nil
            if connection then
                pcall(connection.Disconnect, connection)
            end
        end
    end

    function self:_attachTracker(player, binding, character, humanoid, root, animator)
        if self.Destroyed or not self.Enabled or not binding or binding.Character ~= character then return end

        self:_destroyTracker(binding)

        local tracker = {
            Destroyed = false,
            Character = character,
            Humanoid = humanoid,
            Root = root,
            Animator = animator,
            M1ing = character:FindFirstChild("M1ing", true) ~= nil,
            InsideLast = false,
            ActiveIds = {},
            TrackIds = setmetatable({}, {__mode = "k"}),
            TrackConnections = setmetatable({}, {__mode = "k"}),
            Connections = {}
        }

        binding.Tracker = tracker

        tracker.Connections[#tracker.Connections + 1] = animator.AnimationPlayed:Connect(function(track)
            if self.Destroyed or not self.Enabled or tracker.Destroyed then return end
            self:_registerTrack(player, tracker, track, true)
        end)

        tracker.Connections[#tracker.Connections + 1] = character.DescendantAdded:Connect(function(instance)
            if tracker.Destroyed or instance.Name ~= "M1ing" then return end
            tracker.M1ing = true
            tracker.InsideLast = false
            self.DebugInfo.M1Events = self.DebugInfo.M1Events + 1
            self:_handleM1(player, tracker, "M1ing")
        end)

        tracker.Connections[#tracker.Connections + 1] = character.DescendantRemoving:Connect(function(instance)
            if tracker.Destroyed or instance.Name ~= "M1ing" then return end
            task.defer(function()
                if tracker.Destroyed or not tracker.Character.Parent then return end
                tracker.M1ing = tracker.Character:FindFirstChild("M1ing", true) ~= nil
                if not tracker.M1ing then tracker.InsideLast = false end
            end)
        end)

        local okTracks, tracks = pcall(animator.GetPlayingAnimationTracks, animator)
        if okTracks and type(tracks) == "table" then
            for _, track in ipairs(tracks) do
                self:_registerTrack(player, tracker, track, true)
            end
        end

        if tracker.M1ing then
            self:_handleM1(player, tracker, "M1ing existing")
        end
    end

    function self:_queueCharacter(player, binding, character)
        if not binding then return end

        binding.Generation = binding.Generation + 1
        local generation = binding.Generation
        binding.Character = character
        self:_destroyTracker(binding)

        if not character then return end

        task.spawn(function()
            local humanoid = character:FindFirstChildWhichIsA("Humanoid") or character:WaitForChild("Humanoid", 8)
            if self.Destroyed or not self.Enabled then return end
            if binding.Generation ~= generation or binding.Character ~= character then return end
            if not humanoid then return end

            local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 8)
            if self.Destroyed or not self.Enabled then return end
            if binding.Generation ~= generation or binding.Character ~= character then return end
            if not root then return end

            local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 8)
            if self.Destroyed or not self.Enabled then return end
            if binding.Generation ~= generation or binding.Character ~= character then return end
            if not animator then return end

            self:_attachTracker(player, binding, character, humanoid, root, animator)
        end)
    end

    function self:_refreshTrackedCount()
        local count = 0
        for player, binding in pairs(self.PlayerBindings) do
            if player ~= LocalPlayer and binding and binding.Tracker and not binding.Tracker.Destroyed then
                count = count + 1
            end
        end
        self.DebugInfo.TrackedPlayers = count
    end

    function self:_bindPlayer(player)
        if not player or player == LocalPlayer or self.PlayerBindings[player] then return end

        local binding = {
            Player = player,
            Character = nil,
            Generation = 0,
            Tracker = nil,
            Connections = {}
        }
        self.PlayerBindings[player] = binding

        binding.Connections[#binding.Connections + 1] = player.CharacterAdded:Connect(function(character)
            self:_queueCharacter(player, binding, character)
        end)

        binding.Connections[#binding.Connections + 1] = player.CharacterRemoving:Connect(function(character)
            if binding.Character == character then
                binding.Generation = binding.Generation + 1
                binding.Character = nil
                self:_destroyTracker(binding)
                self:_refreshTrackedCount()
            end
        end)

        if player.Character then
            self:_queueCharacter(player, binding, player.Character)
        end
    end

    function self:_unbindPlayer(player)
        local binding = self.PlayerBindings[player]
        if not binding then return end

        self.PlayerBindings[player] = nil
        binding.Generation = binding.Generation + 1
        self:_destroyTracker(binding)
        disconnectAll(binding.Connections)
        self:_refreshTrackedCount()
    end

    function self:_unbindAllPlayers()
        local players = {}
        for player in pairs(self.PlayerBindings) do
            players[#players + 1] = player
        end
        for _, player in ipairs(players) do
            self:_unbindPlayer(player)
        end
        self.DebugInfo.TrackedPlayers = 0
    end

    function self:_spatialTick()
        if not self.Config.M1Block then return end

        local myRoot = self:_localRoot()
        if not myRoot then return end

        for player, binding in pairs(self.PlayerBindings) do
            local tracker = binding and binding.Tracker
            if tracker and self:_trackerReady(tracker) then
                local distance = (tracker.Root.Position - myRoot.Position).Magnitude
                local inside = distance <= self.Config.NormalRange and self:_insideDetectionBox(tracker.Root, myRoot)

                if inside and not tracker.InsideLast then
                    if tracker.M1ing then
                        self:_handleM1(player, tracker, "M1ing enter")
                    else
                        local activeNormalId = nil
                        for animationId in pairs(normalToGroup) do
                            if (tracker.ActiveIds[animationId] or 0) > 0 then
                                activeNormalId = animationId
                                break
                            end
                        end

                        if activeNormalId then
                            local ok, newlyPressed = self:_pressBlock(0.15, "m1", "M1 animation enter", player, activeNormalId, distance)
                            if ok and newlyPressed then
                                self:_scheduleAfterBlock(player, tracker)
                            end
                        end
                    end
                end

                tracker.InsideLast = inside
            elseif tracker then
                tracker.InsideLast = false
            end
        end
    end

    function self:_onLocalCharacterRemoving(character)
        self.CharacterToken = self.CharacterToken + 1
        self.CatchToken = self.CatchToken + 1
        self:_releaseCatchKeys()
        self:_releaseBlock("character removing")
        self:_destroyDetectionBox()
        self.DebugInfo.Character = "respawning"
        self.DebugInfo.Remote = "missing"
    end

    function self:_onLocalCharacterAdded(character)
        self.CharacterToken = self.CharacterToken + 1
        local token = self.CharacterToken

        self.CatchToken = self.CatchToken + 1
        self:_releaseCatchKeys()
        self:_releaseBlock("character changed")
        self:_destroyDetectionBox()

        self.DebugInfo.Character = character and character.Name or "none"
        self.DebugInfo.Remote = "waiting"

        if not character then return end

        task.spawn(function()
            local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 8)
            if self.Destroyed or not self.Enabled or token ~= self.CharacterToken then return end
            if LocalPlayer.Character ~= character then return end
            if not root then
                self:_setError("HumanoidRootPart timeout")
                return
            end

            local remote = character:FindFirstChild("Communicate") or character:WaitForChild("Communicate", 8)
            if self.Destroyed or not self.Enabled or token ~= self.CharacterToken then return end

            self.DebugInfo.Remote = remote and remote:IsA("RemoteEvent") and "ready" or "missing"
            if self.Config.M1Block then
                self:_ensureDetectionBox()
            end
            self:_debug("respawn ready")
        end)
    end

    function self:_heartbeat(dt)
        if self.Destroyed or not self.Enabled then return end

        local character = self:_localCharacter()
        local remote = character and character:FindFirstChild("Communicate")
        local live = Workspace:FindFirstChild("Live")

        self.DebugInfo.Character = character and character.Name or "none"
        self.DebugInfo.Remote = remote and remote:IsA("RemoteEvent") and "ready" or "missing"
        self.DebugInfo.Live = live and "ready" or "missing"
        self.DebugInfo.ScanHz = self.Config.ScanHz

        if self.Config.M1Block and character and character:FindFirstChild("HumanoidRootPart") then
            self:_ensureDetectionBox()
        elseif not self.Config.M1Block then
            self:_destroyDetectionBox()
        end

        if self.BlockActive and os_clock() >= self.BlockUntil then
            self:_releaseBlock("timeout")
        end

        self.ScanAccumulator = self.ScanAccumulator + (tonumber(dt) or 0)
        local interval = 1 / self.Config.ScanHz
        if self.ScanAccumulator >= interval then
            self.ScanAccumulator = self.ScanAccumulator % interval
            self:_spatialTick()
            self:_refreshTrackedCount()
        end
    end

    function self:ResetCombatState(reason)
        self.CatchToken = self.CatchToken + 1
        self:_releaseCatchKeys()
        self:_releaseBlock(reason or "manual reset")
        self.BlockUntil = 0
        self.BlockSource = nil

        for _, binding in pairs(self.PlayerBindings) do
            local tracker = binding and binding.Tracker
            if tracker then
                tracker.InsideLast = false
            end
        end

        self:_debug(reason or "combat state reset")
        return true
    end

    function self:SetM1Block(value)
        self.Config.M1Block = value == true
        if not self.Config.M1Block then
            self:_destroyDetectionBox()
            if self.BlockActive and self.BlockSource == "m1" then
                self:_releaseBlock("M1 Block disabled")
            end
        elseif self.Enabled then
            self:_ensureDetectionBox()
        end
        return true
    end

    function self:SetM1AfterBlock(value)
        self.Config.M1AfterBlock = value == true
        return true
    end

    function self:SetM1Catch(value)
        self.Config.M1Catch = value == true
        if not self.Config.M1Catch then
            self.CatchToken = self.CatchToken + 1
            self:_releaseCatchKeys()
        end
        return true
    end

    function self:SetDashBlock(value)
        self.Config.DashBlock = value == true
        if not self.Config.DashBlock and self.BlockActive and self.BlockSource == "dash" then
            self:_releaseBlock("Dash Block disabled")
        end
        return true
    end

    function self:SetSkillBlock(value)
        self.Config.SkillBlock = value == true
        if not self.Config.SkillBlock and self.BlockActive and self.BlockSource == "skill" then
            self:_releaseBlock("Skill Block disabled")
        end
        return true
    end

    function self:SetShowDetectionBox(value)
        self.Config.ShowDetectionBox = value == true
        if self.Config.M1Block and self.Enabled then
            self:_ensureDetectionBox()
        end
        return true
    end

    function self:SetDebug(value)
        self.Config.Debug = value == true
        self:_debug(self.Config.Debug and "debug on" or "debug off")
        return true
    end

    function self:SetNormalRange(value)
        value = tonumber(value)
        if not value then return false end
        self.Config.NormalRange = clamp(value, 2, 30)
        return true
    end

    function self:SetSpecialRange(value)
        value = tonumber(value)
        if not value then return false end
        self.Config.SpecialRange = clamp(value, 5, 80)
        return true
    end

    function self:SetSkillRange(value)
        value = tonumber(value)
        if not value then return false end
        self.Config.SkillRange = clamp(value, 5, 80)
        return true
    end

    function self:SetSkillHold(value)
        value = tonumber(value)
        if not value then return false end
        self.Config.SkillHold = clamp(value, 0.1, 2)
        return true
    end

    function self:SetDetectionBoxSize(value)
        value = tonumber(value)
        if not value then return false end
        self.Config.DetectionBoxSize = clamp(value, 2, 40)
        if self.Config.M1Block and self.Enabled then
            self:_ensureDetectionBox()
        end
        return true
    end

    function self:SetScanHz(value)
        value = tonumber(value)
        if not value then return false end
        self.Config.ScanHz = clamp(math_floor(value + 0.5), 10, 60)
        self.DebugInfo.ScanHz = self.Config.ScanHz
        return true
    end

    function self:GetDebugInfo()
        local output = {}
        for key, value in pairs(self.DebugInfo) do
            output[key] = value
        end
        output.Enabled = self.Enabled
        output.BlockActive = self.BlockActive
        output.BlockSource = self.BlockSource or "none"
        output.M1Block = self.Config.M1Block
        output.DashBlock = self.Config.DashBlock
        output.SkillBlock = self.Config.SkillBlock
        return output
    end

    function self:GetConfig()
        return {
            M1Block = self.Config.M1Block,
            M1AfterBlock = self.Config.M1AfterBlock,
            M1Catch = self.Config.M1Catch,
            DashBlock = self.Config.DashBlock,
            SkillBlock = self.Config.SkillBlock,
            ShowDetectionBox = self.Config.ShowDetectionBox,
            Debug = self.Config.Debug,
            NormalRange = self.Config.NormalRange,
            SpecialRange = self.Config.SpecialRange,
            SkillRange = self.Config.SkillRange,
            SkillHold = self.Config.SkillHold,
            DetectionBoxSize = self.Config.DetectionBoxSize,
            ScanHz = self.Config.ScanHz
        }
    end

    function self:Enable()
        if self.Destroyed or not LocalPlayer then return false end
        if self.Enabled then return true end

        self.Enabled = true
        self.DebugInfo.Runtime = "running"
        self.ScanAccumulator = 0
        self:ResetCombatState("runtime started")

        self.Connections[#self.Connections + 1] = LocalPlayer.CharacterAdded:Connect(function(character)
            self:_onLocalCharacterAdded(character)
        end)

        self.Connections[#self.Connections + 1] = LocalPlayer.CharacterRemoving:Connect(function(character)
            self:_onLocalCharacterRemoving(character)
        end)

        self.Connections[#self.Connections + 1] = Players.PlayerAdded:Connect(function(player)
            self:_bindPlayer(player)
        end)

        self.Connections[#self.Connections + 1] = Players.PlayerRemoving:Connect(function(player)
            self:_unbindPlayer(player)
        end)

        self.Connections[#self.Connections + 1] = RunService.Heartbeat:Connect(function(dt)
            local ok, err = pcall(self._heartbeat, self, dt)
            if not ok then
                self:_setError(err)
            end
        end)

        for _, player in ipairs(Players:GetPlayers()) do
            self:_bindPlayer(player)
        end

        if LocalPlayer.Character then
            self:_onLocalCharacterAdded(LocalPlayer.Character)
        end

        return true
    end

    function self:Disable()
        if self.Destroyed then return false end
        if not self.Enabled then return true end

        self.Enabled = false
        self.DebugInfo.Runtime = "idle"
        self.CharacterToken = self.CharacterToken + 1
        self.CatchToken = self.CatchToken + 1

        disconnectAll(self.Connections)
        self:_unbindAllPlayers()
        self:_releaseCatchKeys()
        self:_releaseBlock("runtime stopped")
        self:_destroyDetectionBox()
        self.ScanAccumulator = 0

        return true
    end

    function self:Destroy()
        if self.Destroyed then return end
        self:Disable()
        self.Destroyed = true
        self.DebugInfo.Runtime = "destroyed"
        self.PlayerBindings = nil
    end

    return self
end

return Factory
