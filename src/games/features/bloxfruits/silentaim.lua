local game = game
local type = type
local pcall = pcall
local pairs = pairs
local math_huge = math.huge

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local Feature = {}
Feature.__index = Feature

function Feature.new(context)
    return setmetatable({
        Context = context,
        State = context.State,
        LocalPlayer = LocalPlayer,
        Enabled = false,
        Destroyed = false,
        Connections = {},
        CharacterConnections = {},
        ActiveTool = nil,
        MousePos = nil,
        Target = nil,
        TargetPosition = nil,
        TargetRefresh = 0,
        Characters = nil,
        Character = nil
    }, Feature)
end

function Feature:_disconnect(list)
    for index = #list, 1, -1 do
        local connection = list[index]
        list[index] = nil
        if connection then pcall(connection.Disconnect, connection) end
    end
end

function Feature:_getCharacter(player)
    if not player or player == self.LocalPlayer then return nil end
    local characters = self.Characters
    local character = characters and characters:FindFirstChild(player.Name)
    if character and character:IsA("Model") then return character end
    character = player.Character
    if character and character.Parent then return character end
    return nil
end

function Feature:_isProtected(character)
    if not character or character:FindFirstChildOfClass("ForceField") then return true end
    for _, name in pairs({"PvPDisabled", "PVPDisabled", "PvPProtection", "Protection", "Protected", "SafeZone", "NoPvP"}) do
        if character:GetAttribute(name) == true then return true end
    end
    for _, object in pairs(character:GetDescendants()) do
        local lowered = string.lower(object.Name)
        if lowered == "pvpdisabled" or lowered == "pvpdisabledvalue" or lowered == "pvpprotection" or lowered == "protection" or lowered == "protected" or lowered == "safezone" or lowered == "nopvp" then
            if object:IsA("BoolValue") and object.Value then return true end
            if (object:IsA("IntValue") or object:IsA("NumberValue")) and object.Value ~= 0 then return true end
            if object:IsA("ObjectValue") and object.Value ~= nil then return true end
        end
    end
    return false
end

function Feature:_isValidTarget(player)
    if not player or player == self.LocalPlayer then return false end
    if self.LocalPlayer.Team and player.Team == self.LocalPlayer.Team then return false end
    local character = self:_getCharacter(player)
    if not character or not character.Parent or self:_isProtected(character) then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    local root = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    return root and head and root:IsA("BasePart") and head:IsA("BasePart")
end

function Feature:_selectTarget()
    local localCharacter = self.LocalPlayer and self.LocalPlayer.Character
    local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
    if not localRoot or not localRoot:IsA("BasePart") then return nil, nil end

    local closestPlayer = nil
    local closestDistance = math_huge
    local closestPosition = nil

    for _, player in pairs(Players:GetPlayers()) do
        if self:_isValidTarget(player) then
            local character = self:_getCharacter(player)
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if root and root:IsA("BasePart") then
                local distance = (root.Position - localRoot.Position).Magnitude
                if distance < closestDistance then
                    local head = character:FindFirstChild("Head")
                    closestPlayer = player
                    closestDistance = distance
                    closestPosition = head and head:IsA("BasePart") and head.Position or root.Position
                end
            end
        end
    end

    return closestPlayer, closestPosition
end

function Feature:_clearTool()
    self.ActiveTool = nil
    self.MousePos = nil
end

function Feature:_bindTool(tool)
    if not self.Enabled or self.Destroyed or not tool or not tool:IsA("Tool") then return end
    local mousePos = tool:FindFirstChild("MousePos")
    if not mousePos or not mousePos:IsA("Vector3Value") then return end
    self:_clearTool()
    self.ActiveTool = tool
    self.MousePos = mousePos
end

function Feature:_scanCharacter(character)
    self:_disconnect(self.CharacterConnections)
    self.Character = character
    if not character then
        self:_clearTool()
        return
    end

    for _, child in pairs(character:GetChildren()) do
        if child:IsA("Tool") then self:_bindTool(child) end
    end

    self.CharacterConnections[#self.CharacterConnections + 1] = character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then self:_bindTool(child) end
    end)
    self.CharacterConnections[#self.CharacterConnections + 1] = character.ChildRemoved:Connect(function(child)
        if child == self.ActiveTool then self:_clearTool() end
    end)
end

function Feature:_findCharacter()
    local characters = self.Characters
    if not characters then return nil end
    local character = characters:FindFirstChild(self.LocalPlayer.Name)
    return character and character:IsA("Model") and character or nil
end

function Feature:_bindCharacters()
    local characters = Workspace:FindFirstChild("Characters")
    if not characters then return false end
    self.Characters = characters
    self:_scanCharacter(self:_findCharacter())
    self.Connections[#self.Connections + 1] = characters.ChildAdded:Connect(function(child)
        if child.Name == self.LocalPlayer.Name and child:IsA("Model") then self:_scanCharacter(child) end
    end)
    self.Connections[#self.Connections + 1] = characters.ChildRemoved:Connect(function(child)
        if child == self.Character then self:_scanCharacter(nil) end
    end)
    return true
end

function Feature:_refreshTarget()
    local target, position = self:_selectTarget()
    self.Target = target
    self.TargetPosition = position
    self.TargetRefresh = os.clock()
end

function Feature:_preSimulation()
    if not self.Enabled or self.Destroyed then return end
    local mousePos = self.MousePos
    if not mousePos or not mousePos.Parent or not self.ActiveTool or self.ActiveTool.Parent == nil then return end
    if os.clock() - self.TargetRefresh >= 0.05 then self:_refreshTarget() end
    local position = self.TargetPosition
    if position then pcall(function() mousePos.Value = position end) end
end

function Feature:Enable()
    if self.Destroyed or self.Enabled then return true end
    self.Enabled = true
    if not self:_bindCharacters() then
        self.Enabled = false
        return false
    end
    self.Connections[#self.Connections + 1] = RunService.PreSimulation:Connect(function()
        self:_preSimulation()
    end)
    self.Connections[#self.Connections + 1] = Workspace.ChildAdded:Connect(function(child)
        if child.Name == "Characters" and child:IsA("Folder") and not self.Characters then self:_bindCharacters() end
    end)
    self:_refreshTarget()
    return true
end

function Feature:Disable()
    if not self.Enabled then return true end
    self.Enabled = false
    self:_disconnect(self.Connections)
    self:_disconnect(self.CharacterConnections)
    self:_clearTool()
    self.Target = nil
    self.TargetPosition = nil
    self.TargetRefresh = 0
    self.Characters = nil
    self.Character = nil
    return true
end

function Feature:IsEnabled()
    return self.Enabled
end

function Feature:Destroy()
    if self.Destroyed then return end
    self:Disable()
    self.Destroyed = true
    self.Context = nil
    self.State = nil
    self.LocalPlayer = nil
end

return Feature
