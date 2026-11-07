local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local JumpAnywhere = {}
JumpAnywhere.__index = JumpAnywhere

JumpAnywhere.Id = "DepHub_JumpAnywhere"
JumpAnywhere.RetryFrames = 30

local function getDebugLibrary()
    local environment = type(getgenv) == "function" and getgenv() or _G
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
    local fallback
    for index = 1, 32 do
        local name, value = readUpvalue(library, jumpFunction, index)
        if value == nil then break end
        if type(value) == "function" then
            if type(name) == "string" and name:lower():find("checklinefault", 1, true) then
                return index, value
            end
            if index == 3 then
                fallback = {index, value}
            end
        end
    end
    if fallback then
        return fallback[1], fallback[2]
    end
    return nil, nil
end

function JumpAnywhere.new()
    return setmetatable({
        Active = false,
        Connection = nil,
        RetryCounter = 0,
        BypassReady = false,
        BypassError = nil,
        PatchedJump = nil,
        PatchedIndex = nil,
        OriginalCheck = nil,
        PatchedCheck = nil,
    }, JumpAnywhere)
end

function JumpAnywhere:_restoreBypass()
    local library = getDebugLibrary()
    if library and self.PatchedJump and self.PatchedIndex and self.PatchedCheck then
        local _, current = readUpvalue(library, self.PatchedJump, self.PatchedIndex)
        if current == self.PatchedCheck then
            writeUpvalue(library, self.PatchedJump, self.PatchedIndex, self.OriginalCheck)
        end
    end

    self.BypassReady = false
    self.PatchedJump = nil
    self.PatchedIndex = nil
    self.OriginalCheck = nil
    self.PatchedCheck = nil
end

function JumpAnywhere:_applyBypass()
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
        self.BypassError = "checkLinefault nao encontrado em CharacterActions.Jump"
        return false, self.BypassError
    end

    local patched = function()
        return nil
    end

    if not writeUpvalue(library, jumpFunction, index, patched) then
        self.BypassError = "nao foi possivel aplicar o bypass de zona"
        return false, self.BypassError
    end

    self.PatchedJump = jumpFunction
    self.PatchedIndex = index
    self.OriginalCheck = original
    self.PatchedCheck = patched
    self.BypassReady = true
    self.BypassError = nil
    return true
end

function JumpAnywhere:Start()
    if self.Active then
        return self.BypassReady, self.BypassError
    end

    local ok, err = self:_applyBypass()
    if not ok then
        return false, err
    end

    self.Active = true
    self.RetryCounter = 0
    self.Connection = RunService.Heartbeat:Connect(function()
        if not self.Active then return end
        self.RetryCounter += 1
        if self.RetryCounter >= JumpAnywhere.RetryFrames then
            self.RetryCounter = 0
            self:_applyBypass()
        end
    end)

    return true
end

function JumpAnywhere:Stop()
    self.Active = false

    if self.Connection then
        pcall(self.Connection.Disconnect, self.Connection)
        self.Connection = nil
    end

    self:_restoreBypass()
    self.RetryCounter = 0
    return true
end

function JumpAnywhere:Destroy()
    return self:Stop()
end

return JumpAnywhere
