local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Feature = {}
Feature.__index = Feature

local MAX_DISTANCE = 50
local BEAM_WIDTH = 0.85
local SURFACE_OFFSET = 1.5
local MAX_RAYCAST_SKIPS = 40

local COLORS = {
    Color3.fromRGB(255, 35, 75),
    Color3.fromRGB(0, 220, 255),
    Color3.fromRGB(190, 65, 255),
    Color3.fromRGB(255, 165, 25),
    Color3.fromRGB(40, 255, 115),
    Color3.fromRGB(255, 50, 220),
    Color3.fromRGB(255, 240, 40),
    Color3.fromRGB(65, 115, 255),
    Color3.fromRGB(255, 95, 35),
    Color3.fromRGB(80, 255, 230),
    Color3.fromRGB(255, 255, 255),
    Color3.fromRGB(170, 255, 40)
}

local function disconnect(connection)
    if connection then
        pcall(function()
            connection:Disconnect()
        end)
    end
end

function Feature.new()
    return setmetatable({
        Active = false,
        Destroyed = false,
        Players = {},
        Connections = {},
        Folder = nil
    }, Feature)
end

function Feature:_colorFor(player)
    local index = (math.abs(tonumber(player.UserId) or 0) % #COLORS) + 1
    return COLORS[index]
end

function Feature:_removeVisual(data)
    if not data or not data.Visual then return end

    for _, object in ipairs(data.Visual.Objects) do
        pcall(function()
            object:Destroy()
        end)
    end

    data.Visual = nil
end

function Feature:_createVisual(data)
    if not self.Active or not data or data.Visual then return end

    local root = data.Root
    local character = data.Character
    if not root or not root.Parent or not character then return end

    local objects = {}
    local color = data.Color

    local attachment0 = Instance.new("Attachment")
    attachment0.Name = "DepHubDirectionOrigin"
    attachment0.Parent = root
    objects[#objects + 1] = attachment0

    local target = Instance.new("Part")
    target.Name = "DepHubDirectionTarget"
    target.Size = Vector3.new(1.3, 1.3, 1.3)
    target.Anchored = true
    target.CanCollide = false
    target.CanTouch = false
    target.CanQuery = false
    target.CastShadow = false
    target.Material = Enum.Material.Neon
    target.Color = color
    target.Transparency = 0
    target.Parent = self.Folder
    objects[#objects + 1] = target

    local attachment1 = Instance.new("Attachment")
    attachment1.Parent = target
    objects[#objects + 1] = attachment1

    local beam = Instance.new("Beam")
    beam.Name = "DepHubDirectionBeam"
    beam.Attachment0 = attachment0
    beam.Attachment1 = attachment1
    beam.Color = ColorSequence.new(color)
    beam.Width0 = BEAM_WIDTH
    beam.Width1 = BEAM_WIDTH
    beam.FaceCamera = true
    beam.LightEmission = 1
    beam.LightInfluence = 0
    beam.Segments = 15
    beam.ZOffset = 2
    beam.Parent = self.Folder
    objects[#objects + 1] = beam

    data.Visual = {
        Objects = objects,
        Target = target
    }
end

function Feature:_getEndpoint(data)
    local root = data.Root
    local origin = root.Position
    local direction = root.CFrame.LookVector * MAX_DISTANCE

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {data.Character, self.Folder}
    params.IgnoreWater = false

    for _ = 1, MAX_RAYCAST_SKIPS do
        local result = Workspace:Raycast(origin, direction, params)
        if not result then
            return origin + direction
        end

        local hit = result.Instance
        local valid = hit == Workspace.Terrain

        if hit and hit:IsA("BasePart") then
            valid = hit.Transparency < 0.95
                and hit.LocalTransparencyModifier < 0.95
                and hit.CanCollide == true
        end

        if valid then
            return result.Position + result.Normal * SURFACE_OFFSET
        end

        local excluded = params.FilterDescendantsInstances
        excluded[#excluded + 1] = hit
        params.FilterDescendantsInstances = excluded
    end

    return origin + direction
end

function Feature:_setupCharacter(player, character)
    local data = self.Players[player]
    if not data or not self.Active then return end

    data.Generation = data.Generation + 1
    local generation = data.Generation

    self:_removeVisual(data)
    disconnect(data.StateConnection)
    disconnect(data.JumpConnection)

    data.Character = character
    data.Root = nil
    data.Humanoid = nil
    data.WasGrounded = false

    task.spawn(function()
        local humanoid = character:WaitForChild("Humanoid", 10)
        local root = character:WaitForChild("HumanoidRootPart", 10)

        if not self.Active
            or self.Destroyed
            or self.Players[player] ~= data
            or data.Generation ~= generation
            or not humanoid
            or not root then
            return
        end

        data.Humanoid = humanoid
        data.Root = root

        pcall(function()
            data.StateConnection = humanoid.StateChanged:Connect(function(_, state)
                if not self.Active or data.Generation ~= generation then return end

                if state == Enum.HumanoidStateType.Jumping then
                    self:_createVisual(data)
                elseif state == Enum.HumanoidStateType.Landed
                    or state == Enum.HumanoidStateType.Running
                    or state == Enum.HumanoidStateType.RunningNoPhysics then
                    self:_removeVisual(data)
                end
            end)
        end)

        pcall(function()
            data.JumpConnection = humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
                if self.Active and data.Generation == generation and humanoid.Jump then
                    self:_createVisual(data)
                end
            end)
        end)

        data.WasGrounded = humanoid.FloorMaterial ~= Enum.Material.Air
    end)
end

function Feature:_monitor(player)
    if player == Players.LocalPlayer or self.Players[player] then return end

    local data = {
        Color = self:_colorFor(player),
        Connections = {},
        Generation = 0,
        Visual = nil,
        WasGrounded = false
    }

    self.Players[player] = data

    data.Connections[#data.Connections + 1] = player.CharacterAdded:Connect(function(character)
        self:_setupCharacter(player, character)
    end)

    data.Connections[#data.Connections + 1] = player.CharacterRemoving:Connect(function()
        data.Generation = data.Generation + 1
        self:_removeVisual(data)
        disconnect(data.StateConnection)
        disconnect(data.JumpConnection)
        data.StateConnection = nil
        data.JumpConnection = nil
        data.Character = nil
        data.Root = nil
        data.Humanoid = nil
    end)

    if player.Character then
        self:_setupCharacter(player, player.Character)
    end
end

function Feature:_removePlayer(player)
    local data = self.Players[player]
    if not data then return end

    data.Generation = data.Generation + 1
    self:_removeVisual(data)
    disconnect(data.StateConnection)
    disconnect(data.JumpConnection)

    for _, connection in ipairs(data.Connections) do
        disconnect(connection)
    end

    self.Players[player] = nil
end

function Feature:Enable()
    if self.Destroyed then return false, "destroyed" end
    if self.Active then return true end

    self.Active = true

    local oldFolder = Workspace:FindFirstChild("DepHubCharacterDirection")
    if oldFolder then oldFolder:Destroy() end

    self.Folder = Instance.new("Folder")
    self.Folder.Name = "DepHubCharacterDirection"
    self.Folder.Parent = Workspace

    self.Connections[#self.Connections + 1] = Players.PlayerAdded:Connect(function(player)
        self:_monitor(player)
    end)

    self.Connections[#self.Connections + 1] = Players.PlayerRemoving:Connect(function(player)
        self:_removePlayer(player)
    end)

    self.Connections[#self.Connections + 1] = RunService.Heartbeat:Connect(function()
        if not self.Active then return end

        for player, data in pairs(self.Players) do
            local humanoid = data.Humanoid
            local root = data.Root

            if humanoid and root and root.Parent and humanoid.Parent then
                local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
                local velocityY = root.AssemblyLinearVelocity.Y
                local state = humanoid:GetState()

                local jumping = state == Enum.HumanoidStateType.Jumping
                    or humanoid.Jump == true
                    or (data.WasGrounded and not grounded and velocityY > 1.5)

                if jumping then
                    self:_createVisual(data)
                elseif grounded then
                    self:_removeVisual(data)
                end

                data.WasGrounded = grounded

                if data.Visual then
                    if not data.Visual.Target.Parent then
                        self:_removeVisual(data)
                    else
                        data.Visual.Target.Position = self:_getEndpoint(data)
                    end
                end
            elseif data.Visual then
                self:_removeVisual(data)
            end
        end
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        self:_monitor(player)
    end

    return true
end

function Feature:Disable()
    if not self.Active and not self.Folder then return true end

    self.Active = false

    for _, connection in ipairs(self.Connections) do
        disconnect(connection)
    end
    self.Connections = {}

    for player in pairs(self.Players) do
        self:_removePlayer(player)
    end

    self.Players = {}

    if self.Folder then
        pcall(function()
            self.Folder:Destroy()
        end)
        self.Folder = nil
    end

    return true
end

function Feature:GetStatus()
    local count = 0
    for _ in pairs(self.Players) do
        count = count + 1
    end
    return {
        Enabled = self.Active,
        Players = count
    }
end

function Feature:Destroy()
    if self.Destroyed then return true end
    self:Disable()
    self.Destroyed = true
    return true
end

return Feature
