local game = game
local task = task
local type = type
local tonumber = tonumber
local tostring = tostring
local pairs = pairs
local ipairs = ipairs
local math_max = math.max
local os_clock = os.clock

local Factory = {}

local comboIDs = {
    [10480793962] = true,
    [10480796021] = true
}

local allIDs = {
    Saitama = {
        10469493270,
        10469630950,
        10469639222,
        10469643643,
        special = 10479335397
    },
    Garou = {
        13532562418,
        13532600125,
        13532604085,
        13294471966,
        special = 10479335397
    },
    Cyborg = {
        13491635433,
        13296577783,
        13295919399,
        13295936866,
        special = 10479335397
    },
    Sonic = {
        13370310513,
        13390230973,
        13378751717,
        13378708199,
        special = 13380255751
    },
    Metal = {
        14004222985,
        13997092940,
        14001963401,
        14136436157,
        special = 13380255751
    },
    Blade = {
        15259161390,
        15240216931,
        15240176873,
        15162694192,
        special = 13380255751
    },
    Tatsumaki = {
        16515503507,
        16515520431,
        16515448089,
        16552234590,
        special = 10479335397
    },
    Dragon = {
        17889458563,
        17889461810,
        17889471098,
        17889290569,
        special = 10479335397
    },
    Tech = {
        123005629431309,
        100059874351664,
        104895379416342,
        134775406437626,
        special = 10479335397
    }
}

local skillIDs = {
    [10468665991] = true,
    [10466974800] = true,
    [10471336737] = true,
    [12510170988] = true,
    [12272894215] = true,
    [12296882427] = true,
    [12307656616] = true,
    [101588604872680] = true,
    [105442749844047] = true,
    [109617620932970] = true,
    [131820095363270] = true,
    [135289891173395] = true,
    [125955606488863] = true,
    [12534735382] = true,
    [12502664044] = true,
    [12509505723] = true,
    [12618271998] = true,
    [12684390285] = true,
    [13376869471] = true,
    [13294790250] = true,
    [13376962659] = true,
    [13501296372] = true,
    [13556985475] = true,
    [145162735010] = true,
    [14046756619] = true,
    [14299135500] = true,
    [14351441234] = true,
    [15290930205] = true,
    [15145462680] = true,
    [15295895753] = true,
    [15295336270] = true,
    [16139108718] = true,
    [16515850153] = true,
    [16431491215] = true,
    [16597322398] = true,
    [16597912086] = true,
    [17799224866] = true,
    [17838006839] = true,
    [17857788598] = true,
    [18179181663] = true,
    [113166426814229] = true,
    [116753755471636] = true,
    [116153572280464] = true,
    [114095570398448] = true,
    [77509627104305] = true
}

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

local function getAnimationId(track)
    if not track then return nil end
    local ok, animation = pcall(function()
        return track.Animation
    end)
    if not ok or not animation then return nil end
    local okId, animationId = pcall(function()
        return animation.AnimationId
    end)
    if not okId or type(animationId) ~= "string" then return nil end
    return tonumber(animationId:match("%d+"))
end

function Factory.new(context)
    context = context or {}

    local Players = context.Players or game:GetService("Players")
    local RunService = context.RunService or game:GetService("RunService")
    local VirtualInputManager = context.VirtualInputManager or game:GetService("VirtualInputManager")
    local Workspace = context.Workspace or game:GetService("Workspace")
    local LocalPlayer = context.LocalPlayer or Players.LocalPlayer

    local self = {
        Enabled = false,
        Destroyed = false,
        Connections = {},
        Playing = setmetatable({}, {__mode = "k"}),
        CatchPending = setmetatable({}, {__mode = "k"}),
        LastCatch = 0,
        BlockActive = false,
        BlockUntil = 0,
        Config = {
            NormalRange = tonumber(context.NormalRange) or 30,
            SpecialRange = tonumber(context.SpecialRange) or 50,
            SkillRange = tonumber(context.SkillRange) or 50,
            SkillHold = tonumber(context.SkillHold) or 1.2,
            M1AfterBlock = context.M1AfterBlock == true,
            M1Catch = context.M1Catch == true
        }
    }

    function self:_communicate(goal, mobile)
        if self.Destroyed or not LocalPlayer then return false end
        local character = LocalPlayer.Character
        if not character then return false end
        local remote = character:FindFirstChild("Communicate")
        if not remote or not remote:IsA("RemoteEvent") then return false end

        local payload = {
            Goal = goal,
            Mobile = mobile or nil
        }

        if goal == "KeyPress" or goal == "KeyRelease" then
            payload.Key = Enum.KeyCode.F
        end

        return pcall(remote.FireServer, remote, payload)
    end

    function self:_pressBlock(duration)
        if self.Destroyed or not self.Enabled then return end
        duration = tonumber(duration) or 0.15
        local now = os_clock()
        self.BlockUntil = math_max(self.BlockUntil, now + duration)
        if self.BlockActive then return end
        if self:_communicate("KeyPress") then
            self.BlockActive = true
        end
    end

    function self:_releaseBlock()
        if not self.BlockActive then return end
        self:_communicate("KeyRelease")
        self.BlockActive = false
        self.BlockUntil = 0
    end

    function self:_leftClick()
        if self.Destroyed or not self.Enabled then return end
        self:_communicate("LeftClick", true)
        task.delay(0.3, function()
            if self.Destroyed or not self.Enabled then return end
            self:_communicate("LeftClickRelease", true)
        end)
    end

    function self:_afterBlock(enemyRoot)
        if not self.Config.M1AfterBlock or not enemyRoot or self.Destroyed or not self.Enabled then return end
        local character = LocalPlayer and LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        if (enemyRoot.Position - root.Position).Magnitude <= 10 then
            self:_leftClick()
        end
    end

    function self:_startCatch(player, enemyRoot)
        if not self.Config.M1Catch or self.Destroyed or not self.Enabled then return end
        if self.CatchPending[player] then return end
        if os_clock() - self.LastCatch < 5 then return end

        local character = LocalPlayer and LocalPlayer.Character
        local myRoot = character and character:FindFirstChild("HumanoidRootPart")
        if not myRoot or not enemyRoot then return end

        local dist1 = (enemyRoot.Position - myRoot.Position).Magnitude
        if dist1 > 30 then return end

        self.CatchPending[player] = true

        task.delay(0.1, function()
            self.CatchPending[player] = nil
            if self.Destroyed or not self.Enabled or not self.Config.M1Catch then return end
            local currentCharacter = LocalPlayer and LocalPlayer.Character
            local currentRoot = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
            if not currentRoot or not enemyRoot.Parent then return end

            local dist2 = (enemyRoot.Position - currentRoot.Position).Magnitude
            if dist2 >= dist1 - 0.5 then return end
            if os_clock() - self.LastCatch < 5 then return end

            self.LastCatch = os_clock()
            self:_communicate("LeftClick", true)

            task.delay(0.2, function()
                if self.Destroyed or not self.Enabled then return end
                self:_communicate("LeftClickRelease", true)
            end)

            pcall(VirtualInputManager.SendKeyEvent, VirtualInputManager, true, Enum.KeyCode.D, false, game)
            pcall(VirtualInputManager.SendKeyEvent, VirtualInputManager, true, Enum.KeyCode.Q, false, game)

            task.delay(1, function()
                pcall(VirtualInputManager.SendKeyEvent, VirtualInputManager, false, Enum.KeyCode.Q, false, game)
                pcall(VirtualInputManager.SendKeyEvent, VirtualInputManager, false, Enum.KeyCode.D, false, game)
            end)
        end)
    end

    function self:_scanPlayer(player, live, myRoot)
        if player == LocalPlayer then return end
        local character = player.Character
        if not character or character.Parent ~= live then
            self.Playing[player] = nil
            return
        end

        local enemyRoot = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChildWhichIsA("Humanoid")
        if not enemyRoot or not humanoid then return end

        local distance = (enemyRoot.Position - myRoot.Position).Magnitude
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then return end

        local current = {}
        local started = {}

        local okTracks, tracks = pcall(animator.GetPlayingAnimationTracks, animator)
        if not okTracks or type(tracks) ~= "table" then return end

        local previous = self.Playing[player]
        if type(previous) ~= "table" then previous = {} end

        for _, track in ipairs(tracks) do
            local id = getAnimationId(track)
            if id then
                current[id] = true
                if not previous[id] then
                    started[id] = true
                end
            end
        end

        self.Playing[player] = current

        local hasStarted = false
        for _ in pairs(started) do
            hasStarted = true
            break
        end
        if not hasStarted then return end

        local comboCount = 0
        for id in pairs(comboIDs) do
            if current[id] then comboCount = comboCount + 1 end
        end

        for _, group in pairs(allIDs) do
            local normalHits = 0
            local normalStarted = false

            for index = 1, 4 do
                local id = group[index]
                if current[id] then normalHits = normalHits + 1 end
                if started[id] then normalStarted = true end
            end

            if comboCount == 2 and normalHits >= 2 and distance <= self.Config.SpecialRange then
                self:_pressBlock(0.7)
                return
            end

            if normalStarted and distance <= self.Config.NormalRange then
                self:_pressBlock(0.15)
                if self.Config.M1AfterBlock then
                    task.delay(0.15, function()
                        self:_afterBlock(enemyRoot)
                    end)
                end
                return
            end

            if started[group.special] and distance <= self.Config.SpecialRange then
                if self.Config.M1Catch then
                    self:_startCatch(player, enemyRoot)
                else
                    self:_pressBlock(1)
                end
                return
            end
        end

        for id in pairs(started) do
            if skillIDs[id] and distance <= self.Config.SkillRange then
                self:_pressBlock(self.Config.SkillHold)
                return
            end
        end
    end

    function self:_step()
        if self.Destroyed or not self.Enabled then return end

        if self.BlockActive and os_clock() >= self.BlockUntil then
            self:_releaseBlock()
        end

        local live = Workspace:FindFirstChild("Live")
        local character = LocalPlayer and LocalPlayer.Character
        local myRoot = character and character:FindFirstChild("HumanoidRootPart")
        if not live or not myRoot then return end

        for _, player in ipairs(Players:GetPlayers()) do
            self:_scanPlayer(player, live, myRoot)
        end
    end

    function self:SetNormalRange(value)
        value = tonumber(value)
        if not value then return false end
        self.Config.NormalRange = math.max(0, value)
        return true
    end

    function self:SetSpecialRange(value)
        value = tonumber(value)
        if not value then return false end
        self.Config.SpecialRange = math.max(0, value)
        return true
    end

    function self:SetSkillRange(value)
        value = tonumber(value)
        if not value then return false end
        self.Config.SkillRange = math.max(0, value)
        return true
    end

    function self:SetSkillHold(value)
        value = tonumber(value)
        if not value or value <= 0 then return false end
        self.Config.SkillHold = value
        return true
    end

    function self:SetM1AfterBlock(enabled)
        self.Config.M1AfterBlock = enabled == true
        return true
    end

    function self:SetM1Catch(enabled)
        self.Config.M1Catch = enabled == true
        return true
    end

    function self:GetConfig()
        return {
            NormalRange = self.Config.NormalRange,
            SpecialRange = self.Config.SpecialRange,
            SkillRange = self.Config.SkillRange,
            SkillHold = self.Config.SkillHold,
            M1AfterBlock = self.Config.M1AfterBlock,
            M1Catch = self.Config.M1Catch
        }
    end

    function self:Enable()
        if self.Destroyed or self.Enabled then return false end
        self.Enabled = true
        self.Playing = setmetatable({}, {__mode = "k"})
        local connection = RunService.Heartbeat:Connect(function()
            local ok = pcall(self._step, self)
            if not ok then return end
        end)
        self.Connections[#self.Connections + 1] = connection
        return true
    end

    function self:Disable()
        if self.Destroyed then return false end
        self.Enabled = false
        disconnectAll(self.Connections)
        self:_releaseBlock()
        self.Playing = setmetatable({}, {__mode = "k"})
        self.CatchPending = setmetatable({}, {__mode = "k"})
        return true
    end

    function self:Destroy()
        if self.Destroyed then return end
        self:Disable()
        self.Destroyed = true
        self.Playing = nil
        self.CatchPending = nil
    end

    return self
end

return Factory
