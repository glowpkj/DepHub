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
local BASE_URL = "https://raw.githubusercontent.com/glowpkj/DepHub/main/"

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

local function loadUI()
    local ok, source = pcall(function() return game:HttpGet(BASE_URL .. "src/ui/init.lua?universal=" .. tostring(os.clock())) end)
    if not ok or type(source) ~= "string" then return false end
    local compiled, chunk = compile(source)
    if not compiled then return false end
    local ran, library = pcall(chunk)
    return ran and type(library) == "table" and library or false
end

local function characterParts()
    local character = LocalPlayer.Character
    return character, character and character:FindFirstChildOfClass("Humanoid"), character and character:FindFirstChild("HumanoidRootPart")
end

local State = {
    Destroyed = false, Connections = {}, FeatureConnections = {}, ESPObjects = {}, Keys = {},
    Values = {WalkSpeed = 16, JumpPower = 50, FlySpeed = 70, ESPRange = 2000, ESPTextSize = 14, ESPColor = Color3.fromRGB(90, 170, 255), AimbotFOV = 180, AimPart = "Head", ChatMessage = "DepHub Universal", ChatInterval = 5},
    Toggles = {WalkSpeed = false, Jump = false, Fly = false, Noclip = false, ESP = false, ESPNames = true, ESPDistance = true, ESPHealth = true, TeamCheck = false, TeamColors = true, Chams = true, Fullbright = false, InfiniteZoom = false, Aimbot = false, ChatLoop = false},
    UI = nil, TeleportTool = nil, FlyVelocity = nil, FlyGyro = nil, OriginalCollisions = {}, OriginalLighting = nil, OriginalZoom = LocalPlayer.CameraMaxZoomDistance
}
env[STATE_KEY] = State
env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.Universal = State

function State:Notify(message, kind)
    if self.UI and type(self.UI.Notify) == "function" then pcall(self.UI.Notify, self.UI, "DepHub Universal", message, 3, kind or "Info") end
end

function State:ClearFeature(name)
    local list = self.FeatureConnections[name]
    if list then disconnectAll(list) end
    self.FeatureConnections[name] = nil
end

function State:ApplyMovement()
    local _, humanoid = characterParts()
    if not humanoid then return end
    if self.Toggles.WalkSpeed then humanoid.WalkSpeed = self.Values.WalkSpeed end
    if self.Toggles.Jump then humanoid.UseJumpPower = true; humanoid.JumpPower = self.Values.JumpPower end
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
    self.Toggles.ChatLoop = enabled == true
    if enabled then task.spawn(function() while not self.Destroyed and self.Toggles.ChatLoop do self:SendChat(); task.wait(math.max(3, self.Values.ChatInterval)) end end) end
end

function State:ServerHop()
    local ok, body = pcall(function() return game:HttpGet("https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100") end)
    if not ok then return self:Notify("Não foi possível consultar os servidores.", "Error") end
    local decoded, data = pcall(HttpService.JSONDecode, HttpService, body)
    if decoded then for _, server in ipairs(data.data or {}) do if server.id ~= game.JobId and tonumber(server.playing) < tonumber(server.maxPlayers) then TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer); return end end end
    self:Notify("Nenhum servidor disponível foi encontrado.", "Error")
end

function State:RunExternal(url, name)
    local ok, source = pcall(function() return game:HttpGet(url) end)
    if not ok or type(source) ~= "string" then return self:Notify("Falha ao baixar " .. name .. ".", "Error") end
    local compiled, chunk = compile(source)
    local ran = compiled and pcall(chunk)
    self:Notify(ran and (name .. " iniciado.") or ("Falha ao iniciar " .. name .. "."), ran and "Success" or "Error")
end

function State:CreateUI()
    local Library = loadUI()
    if not Library or type(Library.new) ~= "function" then return false end
    local ok, Window = pcall(Library.new, "DepHub Universal", "Universal", "rbxassetid://79507712997362")
    if not ok or type(Window) ~= "table" then return false end
    self.UI, env.__DEPHUB.Window = Window, Window
    local Movement = Window:CreateTab("Movimento", nil, "Movimento universal e teleporte.")
    local Visual = Window:CreateTab("Visual", nil, "ESP e ajustes de iluminação.")
    local Aim = Window:CreateTab("Mira", nil, "Assistência de câmera pelo cursor.")
    local Chat = Window:CreateTab("Chat", nil, "Envio configurável com intervalo seguro.")
    local Server = Window:CreateTab("Servidor", nil, "Reconexão e troca de servidor.")
    local Developer = Window:CreateTab("Desenvolvedor", nil, "Ferramentas externas de inspeção.")

    local Locomotion = Movement:CreateSection("Velocidade e salto")
    local Flight = Movement:CreateSection("Voo e teleporte")
    Movement = Locomotion
    local ESPInfo = Visual:CreateSection("Player ESP")
    local ESPStyle = Visual:CreateSection("Aparência do ESP")
    local Environment = Visual:CreateSection("Ambiente")
    Visual = ESPInfo
    Aim = Aim:CreateSection("Controle da mira")
    Chat = Chat:CreateSection("Mensagens")
    Server = Server:CreateSection("Conexão")
    Developer = Developer:CreateSection("Inspeção e desenvolvimento")

    Movement:CreateSlider("WalkSpeed", "Velocidade do personagem.", 16, 250, 16, function(v) self.Values.WalkSpeed = v; self:ApplyMovement() end)
    Movement:CreateToggle("Ativar WalkSpeed", "Mantém a velocidade configurada.", false, function(v) self.Toggles.WalkSpeed = v; self:ApplyMovement() end)
    Movement:CreateSlider("Jump Power", "Força do salto.", 50, 250, 50, function(v) self.Values.JumpPower = v; self:ApplyMovement() end)
    Movement:CreateToggle("Ativar Jump", "Mantém o salto configurado.", false, function(v) self.Toggles.Jump = v; self:ApplyMovement() end)
    Flight:CreateSlider("Fly Speed", "Velocidade do voo.", 20, 250, 70, function(v) self.Values.FlySpeed = v end)
    Flight:CreateToggle("Fly", "WASD, Espaço e Ctrl.", false, function(v) self:SetFly(v) end)
    Flight:CreateToggle("No Clip", "Desativa a colisão do personagem.", false, function(v) self:SetNoclip(v) end)
    Flight:CreateButton("Adicionar Click Teleport", function() self:CreateTeleportTool() end)

    Visual:CreateToggle("Player ESP", "Informações dos jogadores.", false, function(v) self:SetESP(v) end)
    Visual:CreateToggle("Nomes", "Nome no ESP.", true, function(v) self.Toggles.ESPNames = v end)
    Visual:CreateToggle("Vida", "Vida no ESP.", true, function(v) self.Toggles.ESPHealth = v end)
    Visual:CreateToggle("Distância", "Distância no ESP.", true, function(v) self.Toggles.ESPDistance = v end)
    ESPStyle:CreateToggle("Chams", "Destaque através de paredes.", true, function(v) self.Toggles.Chams = v end)
    ESPStyle:CreateToggle("Cores dos times", "Usa a cor do time de cada jogador.", true, function(v) self.Toggles.TeamColors = v end)
    ESPStyle:CreateColorPicker("Cor do ESP", "Cor usada quando Cores dos times está desligado.", self.Values.ESPColor, function(v) self.Values.ESPColor = v end)
    Visual:CreateToggle("Team Check", "Ignora o mesmo time no ESP e na mira.", false, function(v) self.Toggles.TeamCheck = v end)
    Visual:CreateSlider("Alcance do ESP", "Distância máxima em studs.", 100, 10000, 2000, function(v) self.Values.ESPRange = v end)
    ESPStyle:CreateSlider("Tamanho do texto", "Tamanho das informações.", 10, 30, 14, function(v) self.Values.ESPTextSize = v end)
    Environment:CreateToggle("Fullbright", "Clareia o mapa e remove neblina.", false, function(v) self:SetFullbright(v) end)
    Environment:CreateToggle("Infinite Zoom", "Amplia o limite da câmera.", false, function(v) self.Toggles.InfiniteZoom = v; LocalPlayer.CameraMaxZoomDistance = v and 100000 or self.OriginalZoom end)

    Aim:CreateToggle("Aimbot", "Segure o botão direito para mirar.", false, function(v) self.Toggles.Aimbot = v end)
    Aim:CreateSlider("FOV", "Raio de captura em pixels.", 30, 600, 180, function(v) self.Values.AimbotFOV = v end)
    Aim:CreateDropdown("Parte do corpo", "Ponto usado pela mira.", {"Head", "HumanoidRootPart", "UpperTorso"}, "Head", function(v) self.Values.AimPart = v end)

    Chat:CreateInput("Mensagem", "Texto enviado ao chat.", self.Values.ChatMessage, function(v) self.Values.ChatMessage = tostring(v) end)
    Chat:CreateSlider("Intervalo", "Segundos entre mensagens (mínimo 3).", 3, 60, 5, function(v) self.Values.ChatInterval = v end)
    Chat:CreateButton("Enviar uma vez", function() self:SendChat() end)
    Chat:CreateToggle("Envio automático", "Repete usando o intervalo configurado.", false, function(v) self:SetChatLoop(v) end)
    Chat:CreateLabel("Os filtros e a moderação do Roblox permanecem ativos.")

    Server:CreateButton("Rejoin", function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
    Server:CreateButton("Server Hop", function() self:ServerHop() end)
    Developer:CreateButton("Dex Explorer", function() self:RunExternal("https://raw.githubusercontent.com/infyiff/backup/main/dex.lua", "Dex Explorer") end)
    Developer:CreateLabel("O Dex só é baixado quando o botão é pressionado.")
    return true
end

function State:Destroy()
    if self.Destroyed then return end
    self.Destroyed, self.Toggles.ChatLoop = true, false
    self:StopFly(); self:SetNoclip(false); self:SetESP(false); self:SetFullbright(false)
    LocalPlayer.CameraMaxZoomDistance = self.OriginalZoom
    for player in pairs(self.ESPObjects) do self:RemoveESP(player) end
    for name in pairs(self.FeatureConnections) do self:ClearFeature(name) end
    disconnectAll(self.Connections)
    if self.TeleportTool then pcall(self.TeleportTool.Destroy, self.TeleportTool) end
    if self.UI then pcall(self.UI.Destroy, self.UI) end
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

if not State:CreateUI() then State:Destroy(); return false end
return State
