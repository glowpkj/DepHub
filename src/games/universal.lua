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
    Destroyed = false, Connections = {}, FeatureConnections = {}, ESPObjects = {}, Keys = {},
    Values = {WalkSpeed = 16, JumpPower = 50, FlySpeed = 70, ESPRange = 2000, ESPTextSize = 14, ESPColor = Color3.fromRGB(90, 170, 255), AimbotFOV = 180, AimPart = "Head", ChatMessage = "DepHub Universal", ChatInterval = 5},
    Toggles = {WalkSpeed = false, Jump = false, Fly = false, Noclip = false, ESP = false, ESPNames = true, ESPDistance = true, ESPHealth = true, TeamCheck = false, TeamColors = true, Chams = true, Fullbright = false, InfiniteZoom = false, Aimbot = false, ChatLoop = false},
    TeleportTool = nil, FlyVelocity = nil, FlyGyro = nil, OriginalCollisions = {}, OriginalLighting = nil, OriginalMovement = {}, OriginalZoom = LocalPlayer.CameraMaxZoomDistance
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
    tool.Parent = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack")
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
    if player == LocalPlayer or not self.Toggles.ESP then return end
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
        if general then general:SendAsync(message) else ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents"):WaitForChild("SayMessageRequest"):FireServer(message, "All") end
    end)
    if not ok then self:Notify("O chat deste jogo não aceitou a mensagem.", "Error") end
    return ok
end

function State:SetChatLoop(enabled)
    enabled = enabled == true
    if self.Toggles.ChatLoop == enabled then return end
    self.Toggles.ChatLoop = enabled
    if enabled then task.spawn(function() while not self.Destroyed and self.Toggles.ChatLoop do self:SendChat(); task.wait(math.max(3, self.Values.ChatInterval)) end end) end
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
    self:StopFly(); self:SetNoclip(false); self:SetESP(false); self:SetFullbright(false)
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
connect(State.Connections, RunService.RenderStepped, function()
    if State.Destroyed then return end
    State:UpdateESP()
    if State.Toggles.WalkSpeed or State.Toggles.Jump then State:ApplyMovement() end
    if State.Toggles.Aimbot and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local target = State:GetAimTarget()
        local camera = Workspace.CurrentCamera
        if target then camera.CFrame = CFrame.lookAt(camera.CFrame.Position, target.Position) end
    end
end)
connect(State.Connections, Players.PlayerAdded, function(player) connect(State.Connections, player.CharacterAdded, function() task.wait(0.5); State:CreateESP(player) end) end)
for _, player in ipairs(Players:GetPlayers()) do if player ~= LocalPlayer then connect(State.Connections, player.CharacterAdded, function() task.wait(0.5); State:CreateESP(player) end) end end
connect(State.Connections, Players.PlayerRemoving, function(player) State:RemoveESP(player) end)
connect(State.Connections, LocalPlayer.CharacterAdded, function() task.wait(0.5); State:ApplyMovement(); if State.Toggles.Fly then State:SetFly(true) end end)

return State
