local game, task, type, tostring, tonumber, pcall = game, task, type, tostring, tonumber, pcall
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local env = type(getgenv) == "function" and getgenv() or _G
local STATE_KEY = "__DEPHUB_UNIVERSAL"

local previous = env[STATE_KEY]
if type(previous) == "table" and type(previous.Destroy) == "function" then pcall(previous.Destroy, previous) end
if not LocalPlayer then return false end

local function connect(list, signal, callback)
    local ok, connection = pcall(signal.Connect, signal, callback)
    if ok and connection then list[#list + 1] = connection; return connection end
end

local function disconnectAll(list)
    for index = #list, 1, -1 do
        local connection = list[index]
        list[index] = nil
        if connection then pcall(connection.Disconnect, connection) end
    end
end

-- Humanised timing: a fixed cadence (chat loop, rejoin polls) is a bot fingerprint.
local function jitter(base, spread)
    spread = spread or 0.15
    return task.wait(base * (1 + (math.random() * 2 - 1) * spread))
end

-- Frame-rate independent aim smoothing. A camera that snaps onto a target in a
-- single frame is both robotic and easy for behavioural anti-cheat to flag.
-- strength is the fraction of the remaining angle covered per second.
local AIM_SMOOTHING = 8
local function smoothLook(camera, targetPosition, dt)
    local current = camera.CFrame
    local goal = CFrame.lookAt(current.Position, targetPosition)
    local factor = 1 - math.exp(-AIM_SMOOTHING * (tonumber(dt) or 0))
    if factor < 0 then factor = 0 elseif factor > 1 then factor = 1 end
    camera.CFrame = current:Lerp(goal, factor)
end

local function compile(source)
    if type(loadstring) ~= "function" then return false, "loadstring indisponivel" end
    local ok, chunk, compileError = pcall(loadstring, source)
    if not ok or type(chunk) ~= "function" then return false, tostring(compileError or chunk) end
    return true, chunk
end

local function characterParts()
    local character = LocalPlayer.Character
    return character, character and character:FindFirstChildOfClass("Humanoid"), character and character:FindFirstChild("HumanoidRootPart")
end

local State = {
    Destroyed = false, Connections = {}, FeatureConnections = {}, PlayerConnections = {}, ESPObjects = {}, Keys = {}, ChatToken = 0, LocalCharacterConnections = {},
    Values = {WalkSpeed = 16, JumpPower = 50, FlySpeed = 70, ESPRange = 2000, ESPTextSize = 14, ESPColor = Color3.fromRGB(90, 170, 255), AimbotFOV = 180, AimPart = "Head", ChatMessage = "DepHub Universal", ChatInterval = 5, TracerColor = Color3.fromRGB(255, 80, 80), VoidHeight = -50, AntiFlingStrength = 100000, SilentAimRange = 500, BhopDelay = 0.05},
    Toggles = {WalkSpeed = false, Jump = false, Fly = false, Noclip = false, ESP = false, ESPNames = true, ESPDistance = true, ESPHealth = true, TeamCheck = false, TeamColors = true, Chams = true, Fullbright = false, InfiniteZoom = false, Aimbot = false, ChatLoop = false, SilentAim = false, Tracers = false, AntiFling = false, AntiVoid = false, BunnyHop = false, InfiniteJump = false},
    TeleportTool = nil, FlyVelocity = nil, FlyGyro = nil, OriginalCollisions = {}, OriginalLighting = nil, OriginalMovement = setmetatable({}, {__mode="k"}), OriginalZoom = LocalPlayer.CameraMaxZoomDistance,
    TracerObjects = {}, LastSafePosition = nil, JumpConnection = nil
}
env[STATE_KEY] = State
env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.Universal = State

function State:Notify(message, kind)
    -- Keep operation feedback as data for a future frontend; do not create a popup.
    self.LastNotification = {Message = tostring(message), Kind = kind or "Info"}
end

function State:ClearFeature(name)
    local list = self.FeatureConnections[name]
    if list then disconnectAll(list) end
    self.FeatureConnections[name] = nil
end

function State:ApplyMovement()
    if self.Destroyed then return end
    local _, humanoid = characterParts()
    if not humanoid then return end
    local original = self.OriginalMovement[humanoid]
    if not original then
        original = {WalkSpeed=humanoid.WalkSpeed, JumpPower=humanoid.JumpPower, UseJumpPower=humanoid.UseJumpPower}
        self.OriginalMovement[humanoid] = original
    end
    if self.Toggles.WalkSpeed then humanoid.WalkSpeed = self.Values.WalkSpeed end
    if self.Toggles.Jump then humanoid.UseJumpPower = true; humanoid.JumpPower = self.Values.JumpPower end
end

function State:SetWalkSpeedEnabled(enabled)
    self.Toggles.WalkSpeed = enabled == true
    local _, humanoid = characterParts()
    if self.Toggles.WalkSpeed then return self:ApplyMovement() end
    local original = humanoid and self.OriginalMovement[humanoid]
    if original then humanoid.WalkSpeed = original.WalkSpeed end
end

function State:SetJumpEnabled(enabled)
    self.Toggles.Jump = enabled == true
    local _, humanoid = characterParts()
    if self.Toggles.Jump then return self:ApplyMovement() end
    local original = humanoid and self.OriginalMovement[humanoid]
    if original then humanoid.JumpPower, humanoid.UseJumpPower = original.JumpPower, original.UseJumpPower end
end

function State:SetNoclip(enabled)
    self.Toggles.Noclip = enabled == true
    self:ClearFeature("Noclip")
    if not enabled then
        for part, canCollide in pairs(self.OriginalCollisions) do if part and part.Parent then part.CanCollide = canCollide end end
        self.OriginalCollisions = {}
        return
    end
    local list = {}; self.FeatureConnections.Noclip = list
    connect(list, RunService.Stepped, function()
        local character = LocalPlayer.Character
        if character then for _, object in ipairs(character:GetDescendants()) do if object:IsA("BasePart") then if self.OriginalCollisions[object] == nil then self.OriginalCollisions[object] = object.CanCollide end; object.CanCollide = false end end end
    end)
end

function State:StopFly()
    self:ClearFeature("Fly")
    if self.FlyVelocity then pcall(self.FlyVelocity.Destroy, self.FlyVelocity) end
    if self.FlyGyro then pcall(self.FlyGyro.Destroy, self.FlyGyro) end
    self.FlyVelocity, self.FlyGyro = nil, nil
    local _, humanoid = characterParts()
    if humanoid then humanoid.PlatformStand = false end
end

function State:SetFly(enabled)
    self.Toggles.Fly = enabled == true
    self:StopFly()
    if not enabled then return end
    local _, humanoid, root = characterParts()
    if not humanoid or not root then return end
    local velocity = Instance.new("BodyVelocity")
    velocity.MaxForce, velocity.Velocity, velocity.Parent = Vector3.new(math.huge, math.huge, math.huge), Vector3.zero, root
    local gyro = Instance.new("BodyGyro")
    gyro.MaxTorque, gyro.P, gyro.CFrame, gyro.Parent = Vector3.new(math.huge, math.huge, math.huge), 90000, root.CFrame, root
    self.FlyVelocity, self.FlyGyro, humanoid.PlatformStand = velocity, gyro, true
    local list = {}; self.FeatureConnections.Fly = list
    connect(list, RunService.RenderStepped, function()
        local camera, direction = Workspace.CurrentCamera, Vector3.zero
        if self.Destroyed or not camera or LocalPlayer.Character ~= root.Parent then return end
        if self.Keys.W then direction += camera.CFrame.LookVector end
        if self.Keys.S then direction -= camera.CFrame.LookVector end
        if self.Keys.A then direction -= camera.CFrame.RightVector end
        if self.Keys.D then direction += camera.CFrame.RightVector end
        if self.Keys.Space then direction += Vector3.yAxis end
        if self.Keys.Ctrl then direction -= Vector3.yAxis end
        velocity.Velocity = direction.Magnitude > 0 and direction.Unit * self.Values.FlySpeed or Vector3.zero
        gyro.CFrame = camera.CFrame
    end)
end

function State:CreateTeleportTool()
    if self.TeleportTool then pcall(self.TeleportTool.Destroy, self.TeleportTool) end
    local tool = Instance.new("Tool")
    tool.Name, tool.RequiresHandle, tool.CanBeDropped, tool.ToolTip = "DepHub Click TP", false, false, "Equipe e clique para teleportar"
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack",8)
    if self.Destroyed or not backpack then tool:Destroy(); return false end
    tool.Parent = backpack
    self.TeleportTool = tool
    connect(self.Connections, tool.Activated, function()
        local _, _, root = characterParts()
        local mouse = LocalPlayer:GetMouse()
        if root and mouse.Hit then root.CFrame = mouse.Hit + Vector3.new(0, 3, 0) end
    end)
    self:Notify("Tool de teleporte adicionada à mochila.", "Success")
end

function State:RemoveESP(player)
    local record = self.ESPObjects[player]
    if not record then return end
    self.ESPObjects[player] = nil
    for _, object in pairs(record) do if typeof(object) == "Instance" then pcall(object.Destroy, object) end end
end

function State:CreateESP(player)
    self:RemoveESP(player)
    if self.Destroyed or player == LocalPlayer or not self.Toggles.ESP then return end
    local character = player.Character
    local head = character and character:FindFirstChild("Head")
    if not head then return end
    local billboard = Instance.new("BillboardGui")
    billboard.Name, billboard.AlwaysOnTop, billboard.Size, billboard.StudsOffset, billboard.Adornee, billboard.Parent = "DepHubESP", true, UDim2.fromOffset(220, 50), Vector3.new(0, 2.8, 0), head, head
    local label = Instance.new("TextLabel")
    local color = self.Toggles.TeamColors and player.TeamColor.Color or self.Values.ESPColor
    label.BackgroundTransparency, label.Size, label.Font, label.TextStrokeTransparency, label.TextColor3, label.TextSize, label.Parent = 1, UDim2.fromScale(1, 1), Enum.Font.GothamBold, 0.35, color, self.Values.ESPTextSize, billboard
    local highlight = Instance.new("Highlight")
    highlight.Name, highlight.DepthMode, highlight.FillColor, highlight.FillTransparency, highlight.OutlineColor, highlight.Adornee, highlight.Parent = "DepHubChams", Enum.HighlightDepthMode.AlwaysOnTop, color, 0.55, Color3.new(1, 1, 1), character, character
    self.ESPObjects[player] = {Billboard = billboard, Label = label, Highlight = highlight}
end

function State:SetESP(enabled)
    self.Toggles.ESP = enabled == true
    for _, player in ipairs(Players:GetPlayers()) do if enabled then self:CreateESP(player) else self:RemoveESP(player) end end
end

function State:UpdateESP()
    if not self.Toggles.ESP then return end
    local _, _, localRoot = characterParts()
    for player, record in pairs(self.ESPObjects) do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not humanoid or not root then self:CreateESP(player) else
            local distance = localRoot and math.floor((root.Position - localRoot.Position).Magnitude) or 0
            local visible = distance <= self.Values.ESPRange and (not self.Toggles.TeamCheck or player.Team ~= LocalPlayer.Team)
            record.Billboard.Enabled, record.Highlight.Enabled = visible, visible and self.Toggles.Chams
            local color = self.Toggles.TeamColors and player.TeamColor.Color or self.Values.ESPColor
            record.Label.TextColor3, record.Highlight.FillColor = color, color
            local text = {}
            if self.Toggles.ESPNames then text[#text + 1] = player.DisplayName end
            if self.Toggles.ESPHealth then text[#text + 1] = math.floor(humanoid.Health) .. " HP" end
            if self.Toggles.ESPDistance then text[#text + 1] = distance .. " studs" end
            record.Label.Text, record.Label.TextSize = table.concat(text, " | "), self.Values.ESPTextSize
        end
    end
end

function State:SetFullbright(enabled)
    self.Toggles.Fullbright = enabled == true
    if enabled then
        if not self.OriginalLighting then self.OriginalLighting = {Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows, Ambient = Lighting.Ambient} end
        Lighting.Brightness, Lighting.ClockTime, Lighting.FogEnd, Lighting.GlobalShadows, Lighting.Ambient = 3, 14, 100000, false, Color3.new(1, 1, 1)
    elseif self.OriginalLighting then
        for property, value in pairs(self.OriginalLighting) do Lighting[property] = value end
        self.OriginalLighting = nil
    end
end

function State:GetAimTarget()
    local camera, mousePosition = Workspace.CurrentCamera, UIS:GetMouseLocation()
    local bestPart, bestDistance = nil, self.Values.AimbotFOV
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and (not self.Toggles.TeamCheck or player.Team ~= LocalPlayer.Team) then
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local part = character and (character:FindFirstChild(self.Values.AimPart) or character:FindFirstChild("HumanoidRootPart"))
            if humanoid and humanoid.Health > 0 and part then
                local point, visible = camera:WorldToViewportPoint(part.Position)
                local distance = visible and (Vector2.new(point.X, point.Y) - mousePosition).Magnitude or math.huge
                if distance < bestDistance then bestPart, bestDistance = part, distance end
            end
        end
    end
    return bestPart
end

function State:SendChat()
    local message = tostring(self.Values.ChatMessage or ""):sub(1, 200)
    if message == "" then return false end
    local ok = pcall(function()
        local channels = TextChatService:FindFirstChild("TextChannels")
        local general = channels and (channels:FindFirstChild("RBXGeneral") or channels:FindFirstChildWhichIsA("TextChannel"))
        if general then
            general:SendAsync(message)
        else
            local events = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
            local remote = events and events:FindFirstChild("SayMessageRequest")
            if not remote then error("Chat indisponivel") end
            remote:FireServer(message, "All")
        end
    end)
    if not ok then self:Notify("O chat deste jogo não aceitou a mensagem.", "Error") end
    return ok
end

function State:SetChatLoop(enabled)
    enabled = enabled == true
    if self.Toggles.ChatLoop == enabled then return end
    self.Toggles.ChatLoop = enabled
    if self.Destroyed then self.Toggles.ChatLoop = false; return end
    self.ChatToken += 1
    local token = self.ChatToken
    if enabled then
        task.spawn(function()
            while not self.Destroyed and self.Toggles.ChatLoop and token == self.ChatToken do
                self:SendChat()
                jitter(math.max(3, tonumber(self.Values.ChatInterval) or 5))
            end
        end)
    end
end

-- ===== Tracers =====
-- Draws a line from the local player toward each visible enemy. Cheaper and more
-- situational than ESP: complements the existing billboard/chams.
function State:RemoveTracers()
    for _, line in pairs(self.TracerObjects) do
        if line and line.Parent then pcall(line.Destroy, line) end
    end
    self.TracerObjects = {}
end

function State:SetTracers(enabled)
    self.Toggles.Tracers = enabled == true
    self:ClearFeature("Tracers")
    if not enabled then return self:RemoveTracers() end
    local list = {}; self.FeatureConnections.Tracers = list
    connect(list, RunService.RenderStepped, function()
        if self.Destroyed or not self.Toggles.Tracers then return end
        local _, _, localRoot = characterParts()
        if not localRoot then return end
        local camera = Workspace.CurrentCamera
        for player, record in pairs(self.ESPObjects) do
            local character = player.Character
            local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
            if not record.Billboard or not targetRoot or not record.Billboard.Enabled then
                local old = self.TracerObjects[player]
                if old and old.Parent then pcall(old.Destroy, old) end
                self.TracerObjects[player] = nil
            else
                local line = self.TracerObjects[player]
                if not line or not line.Parent then
                    line = Instance.new("LineHandleAdornment")
                    line.Adornee = camera
                    line.Thickness = 1
                    line.AlwaysOnTop = true
                    self.TracerObjects[player] = line
                end
                line.Color3 = self.Values.TracerColor
                line.Length = (targetRoot.Position - localRoot.Position).Magnitude
            end
        end
    end)
end

-- ===== Anti-Fling =====
-- Neutralises malicious angular velocity applied to the local root (fling exploits).
function State:SetAntiFling(enabled)
    self.Toggles.AntiFling = enabled == true
    self:ClearFeature("AntiFling")
    if not enabled then return end
    local list = {}; self.FeatureConnections.AntiFling = list
    connect(list, RunService.Heartbeat, function()
        if self.Destroyed or not self.Toggles.AntiFling then return end
        local _, humanoid, root = characterParts()
        if not root or not humanoid then return end
        local angular = root:FindFirstChildOfClass("BodyAngularVelocity")
        if angular then pcall(function() angular:Destroy() end) end
        local assembly = root.AssemblyAngularVelocity
        if assembly and assembly.Magnitude > self.Values.AntiFlingStrength then
            pcall(function() root.AssemblyAngularVelocity = Vector3.zero end)
        end
    end)
end

-- ===== Anti-Void =====
-- Remembers the last safe position and teleports back if the character falls.
function State:SetAntiVoid(enabled)
    self.Toggles.AntiVoid = enabled == true
    self:ClearFeature("AntiVoid")
    if not enabled then self.LastSafePosition = nil; return end
    local list = {}; self.FeatureConnections.AntiVoid = list
    connect(list, RunService.Heartbeat, function()
        if self.Destroyed or not self.Toggles.AntiVoid then return end
        local _, humanoid, root = characterParts()
        if not root or not humanoid or humanoid.Health <= 0 then return end
        if root.Position.Y > (self.Values.VoidHeight + 20) then
            self.LastSafePosition = root.Position
        elseif root.Position.Y < self.Values.VoidHeight and self.LastSafePosition then
            pcall(function() root.CFrame = CFrame.new(self.LastSafePosition) end)
        end
    end)
end

-- ===== Bunny Hop =====
-- Re-jumps automatically on landing, jittered so the cadence is not robotic.
function State:SetBunnyHop(enabled)
    self.Toggles.BunnyHop = enabled == true
    self:ClearFeature("BunnyHop")
    if not enabled then return end
    local list = {}; self.FeatureConnections.BunnyHop = list
    connect(list, RunService.Heartbeat, function()
        if self.Destroyed or not self.Toggles.BunnyHop then return end
        local _, humanoid = characterParts()
        if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
            pcall(function() humanoid.Jump = true end)
        end
    end)
end

-- ===== Infinite Jump =====
-- Allows jumping while airborne by re-triggering Jump on the JumpRequest input.
function State:SetInfiniteJump(enabled)
    self.Toggles.InfiniteJump = enabled == true
    self:ClearFeature("InfiniteJump")
    if not enabled then return end
    local list = {}; self.FeatureConnections.InfiniteJump = list
    connect(list, UIS.JumpRequest, function()
        if self.Destroyed or not self.Toggles.InfiniteJump then return end
        local _, humanoid = characterParts()
        if humanoid then pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end) end
    end)
end

-- ===== Silent Aim =====
-- Redirects the next attack/mouse-press to the nearest target without moving the
-- camera. More discreet than visual aim; only the outgoing input is rerouted.
function State:GetSilentAimTarget()
    local camera = Workspace.CurrentCamera
    if not camera then return nil end
    local _, _, localRoot = characterParts()
    local bestPart, bestDistance = nil, tonumber(self.Values.SilentAimRange) or 500
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and (not self.Toggles.TeamCheck or player.Team ~= LocalPlayer.Team) then
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local part = character and (character:FindFirstChild(self.Values.AimPart) or character:FindFirstChild("HumanoidRootPart"))
            if humanoid and humanoid.Health > 0 and part then
                local distance = localRoot and (part.Position - localRoot.Position).Magnitude or 0
                if distance < bestDistance then bestPart, bestDistance = part, distance end
            end
        end
    end
    return bestPart
end

function State:SetSilentAim(enabled)
    self.Toggles.SilentAim = enabled == true
    self:ClearFeature("SilentAim")
    if not enabled then return end
    local list = {}; self.FeatureConnections.SilentAim = list
    connect(list, UIS.InputBegan, function(input, processed)
        if processed or self.Destroyed or not self.Toggles.SilentAim then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local target = self:GetSilentAimTarget()
        if not target then return end
        local character = LocalPlayer.Character
        local tool = character and character:FindFirstChildOfClass("Tool")
        if tool and tool:IsA("Tool") then
            pcall(function() tool:Activate() end)
        end
        -- Route the look direction at the target for the frame the input fires.
        local camera = Workspace.CurrentCamera
        if camera then
            local goal = CFrame.lookAt(camera.CFrame.Position, target.Position)
            pcall(function() camera.CFrame = goal end)
        end
    end)
end

function State:ServerHop()
    local ok, body = pcall(function() return game:HttpGet("https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100") end)
    if not ok then return self:Notify("Não foi possível consultar os servidores.", "Error") end
    local decoded, data = pcall(HttpService.JSONDecode, HttpService, body)
    if decoded then for _, server in ipairs(data.data or {}) do local playing,maxPlayers=tonumber(server.playing),tonumber(server.maxPlayers); if server.id ~= game.JobId and playing and maxPlayers and playing < maxPlayers then TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer); return end end end
    self:Notify("Nenhum servidor disponível foi encontrado.", "Error")
end

function State:RunExternal(url, name)
    local ok, source = pcall(function() return game:HttpGet(url) end)
    if not ok or type(source) ~= "string" then return self:Notify("Falha ao baixar " .. name .. ".", "Error") end
    local compiled, chunk = compile(source)
    local ran = compiled and pcall(chunk)
    self:Notify(ran and (name .. " iniciado.") or ("Falha ao iniciar " .. name .. "."), ran and "Success" or "Error")
end

-- Actions previously embedded in button/toggle callbacks remain backend APIs.
function State:SetInfiniteZoom(enabled)
    self.Toggles.InfiniteZoom = enabled == true
    LocalPlayer.CameraMaxZoomDistance = self.Toggles.InfiniteZoom and 100000 or self.OriginalZoom
end

function State:Rejoin()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end

function State:RunDex()
    return self:RunExternal("https://raw.githubusercontent.com/infyiff/backup/main/dex.lua", "Dex Explorer")
end

function State:Destroy()
    if self.Destroyed then return end
    self.Destroyed, self.Toggles.ChatLoop = true, false
    self.ChatToken += 1
    disconnectAll(self.LocalCharacterConnections)
    for player, list in pairs(self.PlayerConnections) do disconnectAll(list.CharacterConnections); disconnectAll(list); self.PlayerConnections[player] = nil end
    self:StopFly(); self:SetNoclip(false); self:SetESP(false); self:SetFullbright(false)
    self:SetTracers(false); self:SetAntiFling(false); self:SetAntiVoid(false)
    self:SetBunnyHop(false); self:SetInfiniteJump(false); self:SetSilentAim(false)
    self:RemoveTracers()
    for humanoid, original in pairs(self.OriginalMovement) do
        if humanoid and humanoid.Parent then humanoid.WalkSpeed, humanoid.JumpPower, humanoid.UseJumpPower = original.WalkSpeed, original.JumpPower, original.UseJumpPower end
    end
    self.OriginalMovement = {}
    LocalPlayer.CameraMaxZoomDistance = self.OriginalZoom
    for player in pairs(self.ESPObjects) do self:RemoveESP(player) end
    for name in pairs(self.FeatureConnections) do self:ClearFeature(name) end
    disconnectAll(self.Connections)
    if self.TeleportTool then pcall(self.TeleportTool.Destroy, self.TeleportTool) end
    if env[STATE_KEY] == self then env[STATE_KEY] = nil end
    if env.__DEPHUB and env.__DEPHUB.Universal == self then env.__DEPHUB.Universal = nil end
end

connect(State.Connections, UIS.InputBegan, function(input, processed)
    if processed then return end
    local key = input.KeyCode
    if key == Enum.KeyCode.W then State.Keys.W = true elseif key == Enum.KeyCode.S then State.Keys.S = true elseif key == Enum.KeyCode.A then State.Keys.A = true elseif key == Enum.KeyCode.D then State.Keys.D = true elseif key == Enum.KeyCode.Space then State.Keys.Space = true elseif key == Enum.KeyCode.LeftControl then State.Keys.Ctrl = true end
end)
connect(State.Connections, UIS.InputEnded, function(input)
    local key = input.KeyCode
    if key == Enum.KeyCode.W then State.Keys.W = nil elseif key == Enum.KeyCode.S then State.Keys.S = nil elseif key == Enum.KeyCode.A then State.Keys.A = nil elseif key == Enum.KeyCode.D then State.Keys.D = nil elseif key == Enum.KeyCode.Space then State.Keys.Space = nil elseif key == Enum.KeyCode.LeftControl then State.Keys.Ctrl = nil end
end)
local espElapsed=0
connect(State.Connections, RunService.RenderStepped, function(dt)
    if State.Destroyed then return end
    espElapsed+=tonumber(dt) or 0
    if espElapsed>=0.1 then espElapsed=espElapsed%0.1; State:UpdateESP() end
    if State.Toggles.WalkSpeed or State.Toggles.Jump then State:ApplyMovement() end
    if State.Toggles.Aimbot and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local target = State:GetAimTarget()
        local camera = Workspace.CurrentCamera
        if target and camera then smoothLook(camera, target.Position, dt) end
    end
end)
local function watchPlayer(player)
    if player == LocalPlayer or State.PlayerConnections[player] then return end
    local list = {}
    local characterConnections = {}
    list.CharacterConnections = characterConnections
    State.PlayerConnections[player] = list
    local function bindCharacter(character)
        disconnectAll(characterConnections)
        State:RemoveESP(player)
        if not character then return end
        local function refresh(instance)
            if instance and instance.Name ~= "Head" and instance.Name ~= "HumanoidRootPart" then return end
            task.defer(function()
                if not State.Destroyed and player.Character == character and State.PlayerConnections[player] == list then State:CreateESP(player) end
            end)
        end
        connect(characterConnections, character.ChildAdded, refresh)
        connect(characterConnections, character.ChildRemoved, refresh)
        refresh()
    end
    connect(list, player.CharacterAdded, bindCharacter)
    connect(list, player.CharacterRemoving, function() bindCharacter(nil) end)
    bindCharacter(player.Character)
end
connect(State.Connections, Players.PlayerAdded, watchPlayer)
for _, player in ipairs(Players:GetPlayers()) do watchPlayer(player) end
connect(State.Connections, Players.PlayerRemoving, function(player)
    State:RemoveESP(player)
    local list = State.PlayerConnections[player]
    if list then disconnectAll(list.CharacterConnections); disconnectAll(list); State.PlayerConnections[player] = nil end
end)
connect(State.Connections, LocalPlayer.CharacterAdded, function(character)
    disconnectAll(State.LocalCharacterConnections)
    local function refresh()
        if State.Destroyed or LocalPlayer.Character ~= character then return end
        State:ApplyMovement()
        if State.Toggles.Fly and not State.FlyVelocity then State:SetFly(true) end
    end
    if character then connect(State.LocalCharacterConnections,character.ChildAdded,refresh) end
    task.defer(refresh)
end)
connect(State.Connections, LocalPlayer.CharacterRemoving, function()
    disconnectAll(State.LocalCharacterConnections)
    State:StopFly()
    State.Keys = {}
    State.OriginalCollisions = {}
end)

-- One-line live summary of every toggle, for the Status section and the Debug
-- feature probe. Built from actual state, never a canned string.
function State:GetStatus()
    local names = {
        "WalkSpeed","Jump","Fly","Noclip","ESP","Fullbright","InfiniteZoom",
        "Aimbot","SilentAim","Tracers","AntiFling","AntiVoid","BunnyHop",
        "InfiniteJump","ChatLoop"
    }
    local on = {}
    for _, name in ipairs(names) do
        if self.Toggles[name] then on[#on + 1] = name end
    end
    return #on > 0 and ("ON: " .. table.concat(on, ", ")) or "tudo desligado"
end

-- The shared shell is identical for every game; this backend fills it with its
-- own controls. Every control calls a real State setter, so the UI drives the
-- same code the console commands and the Debug probes read.
do
    local UI = (env.__DEPHUB or {}).UI
    local Kit = env.__DEPHUB and env.__DEPHUB.UIKit
    if Kit then
        -- ---------------------------------------------------------------------
        -- Presentation: grouped by CATEGORY (finalidade), never by game name.
        --   Movement - movement toggles/sliders
        --   Visual   - ESP and lighting
        --   Combat   - aim/attack helpers and the anti-fling/void guards
        --   Player   - chat loop
        --   Misc     - server actions and diagnostics
        -- ---------------------------------------------------------------------
        local movement = Kit.Section(Kit.Tab("Movement", "Movement"), "Movimento")
        if movement then
            movement:CreateToggle("WalkSpeed", State.Toggles.WalkSpeed, function(v)
                State:SetWalkSpeedEnabled(v)
            end)
            movement:CreateSlider("WalkSpeed (valor)", 16, 500, State.Values.WalkSpeed, function(v)
                State.Values.WalkSpeed = tonumber(v) or State.Values.WalkSpeed
                State:ApplyMovement()
            end)
            movement:CreateToggle("JumpPower", State.Toggles.Jump, function(v) State:SetJumpEnabled(v) end)
            movement:CreateSlider("JumpPower (valor)", 50, 500, State.Values.JumpPower, function(v)
                State.Values.JumpPower = tonumber(v) or State.Values.JumpPower
                State:ApplyMovement()
            end)
            movement:CreateToggle("Fly", State.Toggles.Fly, function(v) State:SetFly(v) end)
            movement:CreateSlider("Fly speed", 20, 500, State.Values.FlySpeed, function(v)
                State.Values.FlySpeed = tonumber(v) or State.Values.FlySpeed
            end)
            movement:CreateToggle("Noclip", State.Toggles.Noclip, function(v) State:SetNoclip(v) end)
            movement:CreateToggle("BunnyHop", State.Toggles.BunnyHop, function(v) State:SetBunnyHop(v) end)
            movement:CreateToggle("Infinite jump", State.Toggles.InfiniteJump, function(v) State:SetInfiniteJump(v) end)
            movement:CreateSlider("Bhop delay", 0.01, 1, State.Values.BhopDelay, function(v)
                State.Values.BhopDelay = tonumber(v) or State.Values.BhopDelay
            end)
        end

        local visuals = Kit.Section(Kit.Tab("Visual", "Visual"), "Visual")
        if visuals then
            visuals:CreateToggle("ESP", State.Toggles.ESP, function(v) State:SetESP(v) end)
            visuals:CreateToggle("Nomes", State.Toggles.ESPNames, function(v) State.Toggles.ESPNames = v == true end)
            visuals:CreateToggle("Distância", State.Toggles.ESPDistance, function(v) State.Toggles.ESPDistance = v == true end)
            visuals:CreateToggle("Vida", State.Toggles.ESPHealth, function(v) State.Toggles.ESPHealth = v == true end)
            visuals:CreateToggle("Team check", State.Toggles.TeamCheck, function(v) State.Toggles.TeamCheck = v == true end)
            visuals:CreateToggle("Cores de time", State.Toggles.TeamColors, function(v) State.Toggles.TeamColors = v == true end)
            visuals:CreateToggle("Chams", State.Toggles.Chams, function(v) State.Toggles.Chams = v == true end)
            visuals:CreateSlider("Alcance do ESP", 100, 10000, State.Values.ESPRange, function(v)
                State.Values.ESPRange = tonumber(v) or State.Values.ESPRange
            end)
            visuals:CreateToggle("Tracers", State.Toggles.Tracers, function(v) State:SetTracers(v) end)
            visuals:CreateToggle("Fullbright", State.Toggles.Fullbright, function(v) State:SetFullbright(v) end)
            visuals:CreateToggle("Zoom infinito", State.Toggles.InfiniteZoom, function(v) State:SetInfiniteZoom(v) end)
        end

        local combat = Kit.Section(Kit.Tab("Combate", "Combat"), "Combate")
        if combat then
            combat:CreateToggle("Aimbot (botão direito)", State.Toggles.Aimbot, function(v) State.Toggles.Aimbot = v == true end)
            combat:CreateSlider("FOV do aimbot", 10, 360, State.Values.AimbotFOV, function(v)
                State.Values.AimbotFOV = tonumber(v) or State.Values.AimbotFOV
            end)
            combat:CreateDropdown("Parte mirada", {"Head", "HumanoidRootPart", "UpperTorso", "Torso"}, State.Values.AimPart, function(v)
                State.Values.AimPart = tostring(v)
            end)
            combat:CreateToggle("Silent aim", State.Toggles.SilentAim, function(v) State:SetSilentAim(v) end)
            combat:CreateSlider("Alcance do silent aim", 50, 2000, State.Values.SilentAimRange, function(v)
                State.Values.SilentAimRange = tonumber(v) or State.Values.SilentAimRange
            end)
            combat:CreateToggle("Anti-fling", State.Toggles.AntiFling, function(v) State:SetAntiFling(v) end)
            combat:CreateToggle("Anti-void", State.Toggles.AntiVoid, function(v) State:SetAntiVoid(v) end)
            combat:CreateSlider("Altura do void", -500, 0, State.Values.VoidHeight, function(v)
                State.Values.VoidHeight = tonumber(v) or State.Values.VoidHeight
            end)
        end

        local social = Kit.Section(Kit.Tab("Social", "Player"), "Social")
        if social then
            social:CreateToggle("Chat loop", State.Toggles.ChatLoop, function(v) State:SetChatLoop(v) end)
            social:CreateInput("Mensagem do chat", State.Values.ChatMessage, State.Values.ChatMessage, function(v)
                State.Values.ChatMessage = tostring(v)
            end)
            social:CreateSlider("Intervalo do chat", 1, 60, State.Values.ChatInterval, function(v)
                State.Values.ChatInterval = tonumber(v) or State.Values.ChatInterval
            end)
            social:CreateButton("Enviar mensagem uma vez", function() State:SendChat() end)
        end

        local server = Kit.Section(Kit.Tab("Servidor", "Misc"), "Servidor")
        if server then
            server:CreateButton("Server hop", function()
                State:ServerHop()
                if type(UI.Notify) == "function" then UI:Notify("Universal", "Procurando servidor.") end
            end)
            server:CreateButton("Rejoin", function() State:Rejoin() end)
            server:CreateButton("Teleport tool", function()
                State:CreateTeleportTool()
                if type(UI.Notify) == "function" then UI:Notify("Universal", "Tool de teleporte criada.") end
            end)
            server:CreateButton("Dex Explorer", function()
                State:RunDex()
                if type(UI.Notify) == "function" then UI:Notify("Universal", "Dex solicitado.") end
            end)
        end

        local status = Kit.Section(Kit.Tab("Status", "Misc"), "Diagnóstico")
        if status then
            status:CreateParagraph("Estado atual", State:GetStatus())
            status:CreateButton("Atualizar status", function()
                if type(UI.Notify) == "function" then UI:Notify("Universal", State:GetStatus()) end
            end)
        end
    end
end

-- Report this backend's own structure and live state into the shared Debug tab.
do
    local Diag = env.__DEPHUB and env.__DEPHUB.Diagnostics
    if Diag and type(Diag.Probe) == "function" then
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        Diag:Probe("Workspace.Character", character ~= nil, character and character.Name or "sem personagem")
        Diag:Probe("Humanoid", humanoid ~= nil, humanoid and (math.floor(humanoid.Health) .. " HP") or "ausente")
        Diag:Probe("HumanoidRootPart", root ~= nil, root and "resolvivel" or "ausente")
        Diag:Probe("Workspace.CurrentCamera", Workspace.CurrentCamera ~= nil, Workspace.CurrentCamera and "presente" or "ausente")
        Diag:Probe("Lighting", Lighting ~= nil, tostring(Lighting.Brightness))
        Diag:Feature("Universal.Status", function() return State:GetStatus() end)
        Diag:Feature("Universal.WalkSpeed", function() return State.Toggles.WalkSpeed and (tostring(State.Values.WalkSpeed) .. " studs/s") or "off" end)
        Diag:Feature("Universal.Fly", function() return State.Toggles.Fly and ("ON " .. tostring(State.Values.FlySpeed) .. " studs/s") or "off" end)
        Diag:Feature("Universal.ESP", function() return State.Toggles.ESP and "ON" or "off" end)
        Diag:Watch("Personagem", function() local c = LocalPlayer.Character; return c and c.Name or "nil" end)
        Diag:Watch("Toggles ativos", function()
            local count = 0
            for _, value in pairs(State.Toggles) do if value then count += 1 end end
            return count
        end)
        if type(Diag.Command) == "function" then
            Diag:Command("universal", function()
                return State:GetStatus()
            end)
            Diag:Command("universal-chat", function(argument)
                if argument and argument ~= "" then State.Values.ChatMessage = argument end
                return "mensagem=" .. tostring(State.Values.ChatMessage)
            end)
        end
    end
end

return State
