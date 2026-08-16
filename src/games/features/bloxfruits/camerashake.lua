local Feature = {}
Feature.__index = Feature

local function safeName(instance)
    if not instance then return "nil" end
    local ok, name = pcall(function() return instance:GetFullName() end)
    return ok and tostring(name) or tostring(instance)
end

local function inspectAttributes(instance, label, seen)
    if not instance or type(instance.GetAttributes) ~= "function" then return 0 end
    local count = 0
    local attributes = instance:GetAttributes()
    for name, value in pairs(attributes) do
        local lowered = string.lower(tostring(name))
        if string.find(lowered, "camera", 1, true) or string.find(lowered, "shake", 1, true) or string.find(lowered, "effect", 1, true) or string.find(lowered, "screen", 1, true) then
            count = count + 1
            print("[DepHub][CameraShake][ATTRIBUTE]", label, tostring(name), "=", tostring(value))
            if seen then seen[label .. "." .. tostring(name)] = true end
        end
    end
    return count
end

local function inspectTree(root, label, seen, limit)
    if not root then return 0 end
    local count = 0
    local ok, descendants = pcall(root.GetDescendants, root)
    if not ok or type(descendants) ~= "table" then return 0 end
    for _, instance in ipairs(descendants) do
        if count >= (limit or 250) then break end
        local name = string.lower(tostring(instance.Name))
        if string.find(name, "camera", 1, true) or string.find(name, "shake", 1, true) or string.find(name, "effect", 1, true) or string.find(name, "screen", 1, true) then
            count = count + 1
            print("[DepHub][CameraShake][TREE]", label, safeName(instance), instance.ClassName)
            inspectAttributes(instance, safeName(instance), seen)
        end
    end
    return count
end

local function watchAttributes(instance, label, connections)
    if not instance or type(instance.GetAttributes) ~= "function" then return end
    local ok, attributes = pcall(instance.GetAttributes, instance)
    if not ok or type(attributes) ~= "table" then return end
    for name in pairs(attributes) do
        local okSignal, signal = pcall(instance.GetAttributeChangedSignal, instance, name)
        if okSignal and signal then
            connections[#connections + 1] = signal:Connect(function()
                local value = instance:GetAttribute(name)
                print("[DepHub][CameraShake][ATTRIBUTE_CHANGED]", label, tostring(name), "->", tostring(value))
            end)
        end
    end
end

function Feature.new(context)
    local self = setmetatable({}, Feature)
    self.Context = context
    self.State = context.State
    self.Enabled = false
    self.DebugConnections = {}
    self.DiagnosticRuns = 0
    return self
end

function Feature:ClearDebugWatchers()
    for index = #self.DebugConnections, 1, -1 do
        local connection = self.DebugConnections[index]
        self.DebugConnections[index] = nil
        if connection then pcall(connection.Disconnect, connection) end
    end
end

function Feature:Debug()
    self.DiagnosticRuns = self.DiagnosticRuns + 1
    print("[DepHub][CameraShake][DEBUG] ===== DIAGNOSTIC " .. tostring(self.DiagnosticRuns) .. " =====")
    print("[DepHub][CameraShake][DEBUG] This diagnostic sends no setting remote.")

    local replicatedStorage = game:GetService("ReplicatedStorage")
    local remotes = replicatedStorage:FindFirstChild("Remotes")
    local changeSetting = remotes and remotes:FindFirstChild("ChangeSetting")
    local modules = replicatedStorage:FindFirstChild("Modules")
    local net = modules and modules:FindFirstChild("Net")
    local analytics = net and net:FindFirstChild("RE/OnAnalyticsActivity")

    print("[DepHub][CameraShake][REMOTE] ChangeSetting =", changeSetting and changeSetting.ClassName or "nil")
    print("[DepHub][CameraShake][REMOTE] OnAnalyticsActivity =", analytics and analytics.ClassName or "nil")
    if analytics then
        print("[DepHub][CameraShake][NOTE] OnAnalyticsActivity is telemetry, not proof that the setting changed.")
    end

    local localPlayer = self.Context.LocalPlayer
    local character = localPlayer and localPlayer.Character
    local playerGui = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
    local playerScripts = localPlayer and localPlayer:FindFirstChild("PlayerScripts")
    local currentCamera = workspace.CurrentCamera
    local seen = {}

    inspectAttributes(localPlayer, "LocalPlayer", seen)
    inspectAttributes(character, "Character", seen)
    inspectAttributes(playerGui, "PlayerGui", seen)
    inspectAttributes(playerScripts, "PlayerScripts", seen)
    inspectAttributes(currentCamera, "CurrentCamera", seen)

    local treeCount = 0
    treeCount = treeCount + inspectTree(playerGui, "PlayerGui", seen, 200)
    treeCount = treeCount + inspectTree(playerScripts, "PlayerScripts", seen, 250)

    print("[DepHub][CameraShake][DEBUG] Matching tree entries:", treeCount)
    print("[DepHub][CameraShake][DEBUG] ===== END DIAGNOSTIC =====")

    self:ClearDebugWatchers()
    watchAttributes(localPlayer, "LocalPlayer", self.DebugConnections)
    watchAttributes(character, "Character", self.DebugConnections)
    watchAttributes(playerGui, "PlayerGui", self.DebugConnections)
    watchAttributes(playerScripts, "PlayerScripts", self.DebugConnections)
    watchAttributes(currentCamera, "CurrentCamera", self.DebugConnections)
end

function Feature:BindRuntimeWatchers()
    self:ClearDebugWatchers()
    local localPlayer = self.Context.LocalPlayer
    if localPlayer then
        local characterConnection = localPlayer.CharacterAdded:Connect(function(character)
            print("[DepHub][CameraShake][CHARACTER] CharacterAdded:", safeName(character))
            task.defer(function()
                if not self.Context or not self.State or self.State.Destroyed then return end
                self:Debug()
            end)
        end)
        self.DebugConnections[#self.DebugConnections + 1] = characterConnection
    end

    local workspaceCameraConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        print("[DepHub][CameraShake][CAMERA] CurrentCamera changed:", safeName(workspace.CurrentCamera))
        task.defer(function()
            if not self.Context or not self.State or self.State.Destroyed then return end
            self:Debug()
        end)
    end)
    self.DebugConnections[#self.DebugConnections + 1] = workspaceCameraConnection
end

function Feature:SetEnabled(enabled)
    if self.State.Destroyed then return false end
    self.Enabled = enabled == true
    self.State.CameraShakeDisabled = not self.Enabled
    self:BindRuntimeWatchers()
    self:Debug()
    return true
end

function Feature:Enable() return self:SetEnabled(true) end
function Feature:Disable() return self:SetEnabled(false) end
function Feature:IsEnabled() return self.Enabled end

function Feature:Destroy()
    if not self.Context then return end
    self:ClearDebugWatchers()
    self.Enabled = false
    self.Context = nil
    self.State = nil
end

return Feature
