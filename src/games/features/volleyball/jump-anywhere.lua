local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Visual = {}
Visual.__index = Visual

Visual.Id = "DepHub_JumpAnywhere"
Visual.MinPower = 50
Visual.MaxPower = 500
Visual.DefaultPower = 120
Visual.BypassStates = {
    Enum.HumanoidStateType.Jumping,
    Enum.HumanoidStateType.Climbing,
}

local function getEnvironment()
    return type(getgenv) == "function" and getgenv() or _G
end

local function getDebugLibrary()
    local environment = getEnvironment()
    local library = environment and environment.debug
    if type(library) ~= "table" then
        library = debug
    end
    if type(library) ~= "table"
        or type(library.getupvalue) ~= "function"
        or type(library.setupvalue) ~= "function" then
        return nil
    end
    return library
end

local function getHumanoid()
    local player = Players.LocalPlayer
    local character = player and player.Character
    return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function resolveCharacterActions()
    local player = Players.LocalPlayer
    if not player then return nil end

    local character = player.Character
    local roots = {
        character,
        player:FindFirstChild("PlayerScripts"),
        workspace:FindFirstChild(player.Name),
    }

    for _, root in ipairs(roots) do
        if root then
            local characterScript = root:FindFirstChild("CharacterScript")
            local module = characterScript and characterScript:FindFirstChild("CharacterActions")
            if module and module:IsA("ModuleScript") then
                local ok, actions = pcall(require, module)
                if ok and type(actions) == "table" and type(actions.Jump) == "function" then
                    return actions
                end
            end
        end
    end

    for _, root in ipairs(roots) do
        if root then
            local ok, module = pcall(function()
                return root:FindFirstChild("CharacterActions", true)
            end)
            if ok and module and module:IsA("ModuleScript") then
                local loaded, actions = pcall(require, module)
                if loaded and type(actions) == "table" and type(actions.Jump) == "function" then
                    return actions
                end
            end
        end
    end

    return nil
end

local function readUpvalue(library, fn, index)
    local ok, first, second = pcall(library.getupvalue, fn, index)
    if not ok then return nil, nil end
    if type(first) == "string" then
        return first, second
    end
    return nil, first
end

local function writeUpvalue(library, fn, index, value)
    local ok = pcall(library.setupvalue, fn, index, value)
    if not ok then return false end
    local _, current = readUpvalue(library, fn, index)
    return current == value
end

local function findLinefaultUpvalue(library, jumpFunction)
    local firstFunction
    for index = 1, 32 do
        local name, value = readUpvalue(library, jumpFunction, index)
        if value == nil then break end
        if type(value) == "function" then
            if type(name) == "string" and name:lower():find("checklinefault", 1, true) then
                return index, value
            end
            if index == 3 then
                firstFunction = {index, value}
            end
        end
    end
    if firstFunction then
        return firstFunction[1], firstFunction[2]
    end
    return nil, nil
end

function Visual.new()
    return setmetatable({
        Active = false,
        Power = Visual.DefaultPower,
        Humanoid = nil,
        Original = nil,
        Connection = nil,
        RetryCounter = 0,
        BypassReady = false,
        BypassError = nil,
        PatchedActions = nil,
        PatchedJump = nil,
        PatchedIndex = nil,
        OriginalCheck = nil,
        PatchedCheck = nil,
    }, Visual)
end

function Visual:_restoreBypass()
    local library = getDebugLibrary()
    if library and self.PatchedJump and self.PatchedIndex and self.PatchedCheck then
        local _, current = readUpvalue(library, self.PatchedJump, self.PatchedIndex)
        if current == self.PatchedCheck then
            writeUpvalue(library, self.PatchedJump, self.PatchedIndex, self.OriginalCheck)
        end
    end

    self.BypassReady = false
    self.PatchedActions = nil
    self.PatchedJump = nil
    self.PatchedIndex = nil
    self.OriginalCheck = nil
    self.PatchedCheck = nil
end

function Visual:_applyBypass()
    local actions = resolveCharacterActions()
    if not actions then
        self.BypassError = "CharacterActions indisponivel"
        return false, self.BypassError
    end

    local jumpFunction = actions.Jump
    if self.BypassReady and self.PatchedJump == jumpFunction then
        return true
    end

    self:_restoreBypass()

    local library = getDebugLibrary()
    if not library then
        self.BypassError = "debug.getupvalue/setupvalue indisponivel no executor"
        return false, self.BypassError
    end

    local index, original = findLinefaultUpvalue(library, jumpFunction)
    if not index or type(original) ~= "function" then
        self.BypassError = "funcao checkLinefault nao encontrada em CharacterActions.Jump"
        return false, self.BypassError
    end

    local patched = function()
        return nil
    end

    if not writeUpvalue(library, jumpFunction, index, patched) then
        self.BypassError = "nao foi possivel aplicar o bypass de zona"
        return false, self.BypassError
    end

    self.PatchedActions = actions
    self.PatchedJump = jumpFunction
    self.PatchedIndex = index
    self.OriginalCheck = original
    self.PatchedCheck = patched
    self.BypassReady = true
    self.BypassError = nil
    return true
end

function Visual:_capture(humanoid)
    local original = {
        JumpPower = humanoid.JumpPower,
        UseJumpPower = humanoid.UseJumpPower,
        JumpHeight = humanoid.JumpHeight,
        States = {},
    }

    for _, state in ipairs(Visual.BypassStates) do
        local ok, enabled = pcall(humanoid.GetStateEnabled, humanoid, state)
        if ok then
            original.States[state] = enabled
        end
    end

    return original
end

function Visual:_restore()
    local humanoid = self.Humanoid
    local original = self.Original
    if not humanoid or not original then return end

    pcall(function()
        if original.JumpPower ~= nil then humanoid.JumpPower = original.JumpPower end
        if original.UseJumpPower ~= nil then humanoid.UseJumpPower = original.UseJumpPower end
        if original.JumpHeight ~= nil then humanoid.JumpHeight = original.JumpHeight end
    end)

    for state, enabled in pairs(original.States) do
        pcall(humanoid.SetStateEnabled, humanoid, state, enabled)
    end

    self.Humanoid = nil
    self.Original = nil
end

function Visual:_apply()
    if not self.Active then return end

    local humanoid = getHumanoid()
    if humanoid ~= self.Humanoid then
        self:_restore()
        if not humanoid then return end
        self.Humanoid = humanoid
        self.Original = self:_capture(humanoid)
    end

    if not humanoid then return end

    pcall(function()
        humanoid.UseJumpPower = true
        humanoid.JumpPower = self.Power
        humanoid.JumpHeight = math.max(tonumber(self.Original.JumpHeight) or 0, 7.2)
    end)

    for _, state in ipairs(Visual.BypassStates) do
        pcall(humanoid.SetStateEnabled, humanoid, state, true)
    end

    self.RetryCounter += 1
    if not self.BypassReady or self.RetryCounter >= 30 then
        self.RetryCounter = 0
        self:_applyBypass()
    end
end

function Visual:Start()
    if self.Active then return self.BypassReady, self.BypassError end
    self.Active = true
    self.RetryCounter = 0
    self:_apply()
    self.Connection = RunService.Heartbeat:Connect(function()
        self:_apply()
    end)
    return self.BypassReady, self.BypassError
end

function Visual:Stop()
    if not self.Active and not self.Humanoid and not self.BypassReady then
        return false
    end

    self.Active = false

    if self.Connection then
        pcall(self.Connection.Disconnect, self.Connection)
        self.Connection = nil
    end

    self:_restoreBypass()
    self:_restore()
    return true
end

function Visual:SetPower(value)
    local numeric = tonumber(value)
    if not numeric then return false end
    self.Power = math.clamp(math.floor(numeric + 0.5), Visual.MinPower, Visual.MaxPower)
    if self.Active then self:_apply() end
    return true
end

function Visual:Destroy()
    self:Stop()
    return true
end

return Visual
